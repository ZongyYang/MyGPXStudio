import Combine
import CryptoKit
import Foundation
import Security
import SwiftUI

enum TransportMode: String, CaseIterable, Identifiable {
    case driving
    case bicycling
    case walking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driving: "驾车"
        case .bicycling: "骑行"
        case .walking: "步行"
        }
    }

    var iconName: String {
        switch self {
        case .driving: "car.fill"
        case .bicycling: "bicycle"
        case .walking: "figure.walk"
        }
    }
}

struct Coordinate: Hashable, Codable {
    let latitude: Double
    let longitude: Double
}

struct Place: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let address: String
    let gcj02: Coordinate
    let category: String

    init(id: String, name: String, address: String, gcj02: Coordinate, category: String = "") {
        self.id = id
        self.name = name
        self.address = address
        self.gcj02 = gcj02
        self.category = category
    }

    var displayName: String {
        address.isEmpty || address == "[]" ? name : "\(name)（\(address)）"
    }
}

struct RoutePlan {
    let mode: TransportMode
    let gcj02Points: [Coordinate]
    let wgs84Points: [Coordinate]
    let duration: TimeInterval
    let distance: Double

    var distanceText: String {
        distance >= 1_000 ? String(format: "%.1f km", distance / 1_000) : "\(Int(distance)) m"
    }

    var durationText: String {
        let minutes = Int(duration) / 60
        return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分" : "\(max(minutes, 1)) 分"
    }

    static func merging(_ legs: [RoutePlan]) -> RoutePlan {
        precondition(!legs.isEmpty)
        var gcj02Points: [Coordinate] = []
        var wgs84Points: [Coordinate] = []

        for leg in legs {
            for point in leg.gcj02Points where gcj02Points.last != point {
                gcj02Points.append(point)
            }
            for point in leg.wgs84Points where wgs84Points.last != point {
                wgs84Points.append(point)
            }
        }

        return RoutePlan(
            mode: legs[0].mode,
            gcj02Points: gcj02Points,
            wgs84Points: wgs84Points,
            duration: legs.reduce(0) { $0 + $1.duration },
            distance: legs.reduce(0) { $0 + $1.distance }
        )
    }
}

enum RouteStopKind: Equatable {
    case start
    case waypoint
    case end

    var title: String {
        switch self {
        case .start: "起点"
        case .waypoint: "途经点"
        case .end: "终点"
        }
    }

    var symbolName: String {
        switch self {
        case .start: "circle.inset.filled"
        case .waypoint: "circle.fill"
        case .end: "mappin.circle.fill"
        }
    }
}

struct RouteStop: Identifiable {
    let id = UUID()
    let kind: RouteStopKind
    var query = ""
    var selectedQuery: String?
    var place: Place?
    var suggestions: [Place] = []
}

@MainActor
final class RoutePlannerModel: ObservableObject {
    @Published private(set) var stops: [RouteStop] = [
        RouteStop(kind: .start),
        RouteStop(kind: .end)
    ]
    @Published var transportMode: TransportMode = .driving {
        didSet { invalidateRoute() }
    }
    @Published var departureTime = Date()
    @Published private(set) var routePlan: RoutePlan?
    @Published private(set) var routeOptions: [RoutePlan] = []
    @Published private(set) var selectedRouteIndex = 0
    @Published private(set) var generatedDepartureTime: Date?
    @Published private(set) var isPlanning = false
    @Published private(set) var statusText = "输入起点和终点后即可生成路线。"
    @Published private(set) var errorMessage: String?
    @Published private(set) var mapFocusToken = 0
    @Published private(set) var apiKey: String
    @Published private(set) var securityKey: String

    private var searchTasks: [UUID: Task<Void, Never>] = [:]

    init() {
        apiKey = KeychainStore.value(for: "amap-api-key") ?? ""
        securityKey = KeychainStore.value(for: "amap-security-key") ?? ""
        if apiKey.isEmpty {
            statusText = "请先在右上角设置高德 Web 服务 API Key。"
        }
    }

    var hasCredentials: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canPlan: Bool {
        hasCredentials && stops.allSatisfy { $0.place != nil } && !isPlanning
    }

    var selectedPlaces: [Place] {
        stops.compactMap(\.place)
    }

    var waypointCount: Int {
        max(stops.count - 2, 0)
    }

    var exportDepartureTime: Date {
        generatedDepartureTime ?? departureTime
    }

    func queryBinding(for stopID: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.stops.first(where: { $0.id == stopID })?.query ?? ""
            },
            set: { [weak self] text in
                self?.updateQuery(text, for: stopID)
            }
        )
    }

    func updateQuery(_ text: String, for stopID: UUID) {
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return }
        stops[index].query = text
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stops[index].selectedQuery == normalized {
            stops[index].suggestions = []
            return
        }
        if stops[index].selectedQuery != normalized {
            stops[index].selectedQuery = nil
            stops[index].place = nil
            invalidateRoute()
        }
        searchPlaces(keyword: normalized, for: stopID)
    }

    func clearStop(_ stopID: UUID) {
        searchTasks[stopID]?.cancel()
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return }
        stops[index].query = ""
        stops[index].selectedQuery = nil
        stops[index].place = nil
        stops[index].suggestions = []
        invalidateRoute()
    }

    func select(_ place: Place, for stopID: UUID) {
        searchTasks[stopID]?.cancel()
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return }
        stops[index].place = place
        stops[index].query = place.displayName
        stops[index].selectedQuery = place.displayName
        stops[index].suggestions = []
        invalidateRoute()
        mapFocusToken += 1
    }

    func addWaypoint() {
        guard let endIndex = stops.firstIndex(where: { $0.kind == .end }) else { return }
        stops.insert(RouteStop(kind: .waypoint), at: endIndex)
        invalidateRoute()
    }

    func deleteWaypoint(_ stopID: UUID) {
        guard let index = stops.firstIndex(where: { $0.id == stopID }), stops[index].kind == .waypoint else { return }
        searchTasks[stopID]?.cancel()
        stops.remove(at: index)
        invalidateRoute()
    }

    func moveWaypoint(_ stopID: UUID, direction: Int) {
        guard let index = stops.firstIndex(where: { $0.id == stopID }), stops[index].kind == .waypoint else { return }
        let destination = index + direction
        guard stops.indices.contains(destination), stops[destination].kind == .waypoint else { return }
        stops.swapAt(index, destination)
        invalidateRoute()
    }

    func canMoveWaypoint(_ stopID: UUID, direction: Int) -> Bool {
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return false }
        let destination = index + direction
        return stops.indices.contains(destination) && stops[index].kind == .waypoint && stops[destination].kind == .waypoint
    }

    func saveCredentials(apiKey: String, securityKey: String) {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecurityKey = securityKey.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainStore.save(value: trimmedAPIKey, for: "amap-api-key")
        KeychainStore.save(value: trimmedSecurityKey, for: "amap-security-key")
        self.apiKey = trimmedAPIKey
        self.securityKey = trimmedSecurityKey
        statusText = trimmedAPIKey.isEmpty ? "尚未设置 API Key。" : "高德 API 设置已保存到本机钥匙串。"
    }

    func planRoute() {
        guard hasCredentials else {
            errorMessage = "请先在设置中填入高德 Web 服务 API Key。"
            return
        }
        guard stops.allSatisfy({ $0.place != nil }) else {
            errorMessage = "请为起点、终点和每个途经点选择一个地点。"
            return
        }
        let places = selectedPlaces
        guard places.count == stops.count, places.count >= 2 else { return }

        let mode = transportMode
        let key = apiKey
        let security = securityKey
        let plannedDeparture = departureTime
        isPlanning = true
        errorMessage = nil
        statusText = places.count > 2 ? "正在计算包含 \(places.count - 2) 个途经点的路线…" : "正在获取路线建议…"

        Task { [weak self] in
            do {
                let plans: [RoutePlan]
                if places.count == 2 {
                    plans = try await AMapClient.planRoutes(
                        start: places[0],
                        end: places[1],
                        mode: mode,
                        apiKey: key,
                        securityKey: security
                    )
                } else {
                    var legs: [RoutePlan] = []
                    for index in 0..<(places.count - 1) {
                        let leg = try await AMapClient.planRoute(
                            start: places[index],
                            end: places[index + 1],
                            mode: mode,
                            apiKey: key,
                            securityKey: security
                        )
                        legs.append(leg)
                    }
                    plans = [RoutePlan.merging(legs)]
                }
                guard !Task.isCancelled else { return }
                self?.apply(plans: plans, departure: plannedDeparture)
            } catch {
                guard !Task.isCancelled else { return }
                self?.isPlanning = false
                self?.routePlan = nil
                self?.routeOptions = []
                self?.generatedDepartureTime = nil
                self?.errorMessage = error.localizedDescription
                self?.statusText = "生成路线失败。请检查地点或 API 设置后重试。"
            }
        }
    }

    func selectRoute(at index: Int) {
        guard routeOptions.indices.contains(index) else { return }
        selectedRouteIndex = index
        routePlan = routeOptions[index]
        statusText = "已选择方案 \(index + 1)。"
        mapFocusToken += 1
    }

    func makeTemporaryGPXURL() throws -> URL {
        guard let routePlan, let start = stops.first?.place, let end = stops.last?.place else {
            throw AMapError.message("请先生成路线。")
        }
        guard let data = GPXWriter.makeData(
            plan: routePlan,
            departure: exportDepartureTime,
            startName: start.name,
            endName: end.name
        ) else {
            throw AMapError.message("无法生成 GPX 文件。")
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let name = safeFilename("\(formatter.string(from: exportDepartureTime))_\(start.name)_\(end.name)")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name.isEmpty ? "MyGPXStudio" : name)
            .appendingPathExtension("gpx")
        try data.write(to: url, options: .atomic)
        statusText = "GPX 文件已准备好，可通过系统分享面板保存或发送。"
        return url
    }

    func clearError() {
        errorMessage = nil
    }

    func present(error: Error) {
        errorMessage = error.localizedDescription
    }

    private func searchPlaces(keyword: String, for stopID: UUID) {
        searchTasks[stopID]?.cancel()
        guard keyword.count >= 2 else {
            setSuggestions([], for: stopID)
            return
        }
        guard hasCredentials else {
            setSuggestions([], for: stopID)
            return
        }
        let key = apiKey
        let security = securityKey
        searchTasks[stopID] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            do {
                let places = try await AMapClient.searchPlaces(keyword: keyword, apiKey: key, securityKey: security)
                guard !Task.isCancelled else { return }
                self?.setSuggestions(places, for: stopID, matching: keyword)
            } catch {
                guard !Task.isCancelled else { return }
                self?.setSuggestions([], for: stopID, matching: keyword)
            }
        }
    }

    private func setSuggestions(_ suggestions: [Place], for stopID: UUID, matching keyword: String? = nil) {
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return }
        if let keyword, stops[index].query.trimmingCharacters(in: .whitespacesAndNewlines) != keyword { return }
        stops[index].suggestions = suggestions
    }

    private func apply(plans: [RoutePlan], departure: Date) {
        guard let first = plans.first else { return }
        routeOptions = plans
        routePlan = first
        selectedRouteIndex = 0
        generatedDepartureTime = departure
        isPlanning = false
        statusText = plans.count > 1 ? "已找到 \(plans.count) 条路线建议。" : "路线已生成，可以导出 GPX。"
        mapFocusToken += 1
    }

    private func invalidateRoute() {
        routePlan = nil
        routeOptions = []
        selectedRouteIndex = 0
        generatedDepartureTime = nil
    }
}

enum AMapClient {
    static func searchPlaces(keyword: String, apiKey: String, securityKey: String) async throws -> [Place] {
        var parameters: [String: String] = [
            "key": apiKey,
            "keywords": keyword,
            "city": "全国",
            "citylimit": "false",
            "output": "json",
            "offset": "10",
            "page": "1",
            "extensions": "all"
        ]
        if !securityKey.isEmpty {
            parameters["sig"] = signature(for: parameters, securityKey: securityKey)
        }
        let data = try await request("https://restapi.amap.com/v3/place/text", parameters: parameters)
        let response = try dictionary(from: data)
        guard response.string("status") == "1" else {
            throw AMapError.message(response.string("info") ?? "高德地点检索未成功")
        }
        let pois = response["pois"] as? [[String: Any]] ?? []
        return pois.compactMap { poi in
            guard let location = poi.string("location") else { return nil }
            let components = location.split(separator: ",")
            guard components.count == 2,
                  let longitude = Double(components[0]),
                  let latitude = Double(components[1]) else { return nil }
            return Place(
                id: poi.string("id") ?? "\(longitude),\(latitude)",
                name: poi.string("name") ?? "未命名地点",
                address: poi.string("address")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                gcj02: Coordinate(latitude: latitude, longitude: longitude),
                category: poi.string("type") ?? ""
            )
        }
    }

    static func planRoutes(start: Place, end: Place, mode: TransportMode, apiKey: String, securityKey: String) async throws -> [RoutePlan] {
        var parameters: [String: String] = [
            "key": apiKey,
            "origin": "\(start.gcj02.longitude),\(start.gcj02.latitude)",
            "destination": "\(end.gcj02.longitude),\(end.gcj02.latitude)",
            "output": "json"
        ]
        let endpoint: String
        switch mode {
        case .driving:
            endpoint = "https://restapi.amap.com/v3/direction/driving"
            parameters["strategy"] = "11"
            parameters["extensions"] = "all"
        case .bicycling:
            endpoint = "https://restapi.amap.com/v4/direction/bicycling"
            parameters["strategy"] = "0"
        case .walking:
            endpoint = "https://restapi.amap.com/v3/direction/walking"
            parameters["strategy"] = "0"
        }
        if !securityKey.isEmpty {
            parameters["sig"] = signature(for: parameters, securityKey: securityKey)
        }

        let data = try await request(endpoint, parameters: parameters)
        let response = try dictionary(from: data)
        let paths: [[String: Any]]
        if mode == .bicycling {
            guard response.int("errcode") == 0 else {
                throw AMapError.message(response.string("errmsg") ?? "高德骑行算路未成功")
            }
            paths = ((response["data"] as? [String: Any])?["paths"] as? [[String: Any]]) ?? []
        } else {
            guard response.string("status") == "1" else {
                throw AMapError.message(response.string("info") ?? "高德算路未成功")
            }
            paths = ((response["route"] as? [String: Any])?["paths"] as? [[String: Any]]) ?? []
        }
        guard !paths.isEmpty else { throw AMapError.message("未返回可用路线") }

        let plans = paths.compactMap { path -> RoutePlan? in
            let steps = path["steps"] as? [[String: Any]] ?? []
            var points: [Coordinate] = []
            for step in steps {
                guard let polyline = step.string("polyline") else { continue }
                for pair in polyline.split(separator: ";") {
                    let values = pair.split(separator: ",")
                    guard values.count == 2,
                          let longitude = Double(values[0]),
                          let latitude = Double(values[1]) else { continue }
                    let point = Coordinate(latitude: latitude, longitude: longitude)
                    if points.last != point { points.append(point) }
                }
            }
            guard points.count > 1 else { return nil }
            return RoutePlan(
                mode: mode,
                gcj02Points: points,
                wgs84Points: points.map(CoordinateTransform.gcj02ToWGS84),
                duration: TimeInterval(path.double("duration") ?? 0),
                distance: path.double("distance") ?? 0
            )
        }
        guard !plans.isEmpty else { throw AMapError.message("路线没有返回可导出的轨迹点") }
        return plans
    }

    static func planRoute(start: Place, end: Place, mode: TransportMode, apiKey: String, securityKey: String) async throws -> RoutePlan {
        guard let plan = try await planRoutes(start: start, end: end, mode: mode, apiKey: apiKey, securityKey: securityKey).first else {
            throw AMapError.message("未返回可用路线")
        }
        return plan
    }

    private static func request(_ endpoint: String, parameters: [String: String]) async throws -> Data {
        guard var components = URLComponents(string: endpoint) else {
            throw AMapError.message("无效的高德服务地址")
        }
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw AMapError.message("无法创建高德请求") }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AMapError.message("高德服务网络请求失败")
        }
        return data
    }

    private static func dictionary(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AMapError.message("无法解析高德服务返回的数据")
        }
        return object
    }

    private static func signature(for parameters: [String: String], securityKey: String) -> String {
        let content = securityKey + parameters.sorted { $0.key < $1.key }.map { "\($0.key)\($0.value)" }.joined()
        return Insecure.MD5.hash(data: Data(content.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }
}

enum AMapError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? {
        if let value = self[key] as? String { return value }
        if let value = self[key] as? NSNumber { return value.stringValue }
        return nil
    }

    func double(_ key: String) -> Double? {
        if let value = self[key] as? Double { return value }
        if let value = self[key] as? NSNumber { return value.doubleValue }
        if let value = self[key] as? String { return Double(value) }
        return nil
    }

    func int(_ key: String) -> Int? {
        if let value = self[key] as? Int { return value }
        if let value = self[key] as? NSNumber { return value.intValue }
        if let value = self[key] as? String { return Int(value) }
        return nil
    }
}

enum CoordinateTransform {
    private static let pi = Double.pi
    private static let axis = 6_378_245.0
    private static let offset = 0.00669342162296594323

    static func gcj02ToWGS84(_ point: Coordinate) -> Coordinate {
        guard !isOutsideMainlandChina(point) else { return point }
        let delta = transformDelta(latitude: point.latitude, longitude: point.longitude)
        return Coordinate(latitude: point.latitude * 2 - delta.latitude, longitude: point.longitude * 2 - delta.longitude)
    }

    private static func transformDelta(latitude: Double, longitude: Double) -> Coordinate {
        var deltaLatitude = transformLatitude(longitude - 105, latitude - 35)
        var deltaLongitude = transformLongitude(longitude - 105, latitude - 35)
        let radians = latitude / 180 * pi
        var magic = sin(radians)
        magic = 1 - offset * magic * magic
        let sqrtMagic = sqrt(magic)
        deltaLatitude = (deltaLatitude * 180) / ((axis * (1 - offset)) / (magic * sqrtMagic) * pi)
        deltaLongitude = (deltaLongitude * 180) / (axis / sqrtMagic * cos(radians) * pi)
        return Coordinate(latitude: latitude + deltaLatitude, longitude: longitude + deltaLongitude)
    }

    private static func transformLatitude(_ x: Double, _ y: Double) -> Double {
        var result = -100 + 2 * x + 3 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        result += (20 * sin(6 * x * pi) + 20 * sin(2 * x * pi)) * 2 / 3
        result += (20 * sin(y * pi) + 40 * sin(y / 3 * pi)) * 2 / 3
        result += (160 * sin(y / 12 * pi) + 320 * sin(y * pi / 30)) * 2 / 3
        return result
    }

    private static func transformLongitude(_ x: Double, _ y: Double) -> Double {
        var result = 300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        result += (20 * sin(6 * x * pi) + 20 * sin(2 * x * pi)) * 2 / 3
        result += (20 * sin(x * pi) + 40 * sin(x / 3 * pi)) * 2 / 3
        result += (150 * sin(x / 12 * pi) + 300 * sin(x * pi / 30)) * 2 / 3
        return result
    }

    private static func isOutsideMainlandChina(_ point: Coordinate) -> Bool {
        if !(73.66 < point.longitude && point.longitude < 135.05 && 3.86 < point.latitude && point.latitude < 53.55) { return true }
        if 119.3 < point.longitude && point.longitude < 124.6 && 21.9 < point.latitude && point.latitude < 25.3 { return true }
        if 113.8 < point.longitude && point.longitude < 114.5 && 22.1 < point.latitude && point.latitude < 22.6 { return true }
        if 113.5 < point.longitude && point.longitude < 113.6 && 22.1 < point.latitude && point.latitude < 22.2 { return true }
        return false
    }
}

enum GPXWriter {
    static func makeData(plan: RoutePlan, departure: Date, startName: String, endName: String) -> Data? {
        let times = timestamps(for: plan.wgs84Points, departure: departure, duration: plan.duration)
        let title = "\(startName)_\(endName)"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"

        var pointsXML = ""
        for (index, point) in plan.wgs84Points.enumerated() {
            let timestamp = formatter.string(from: times[index])
            let latitude = String(format: "%.8f", point.latitude)
            let longitude = String(format: "%.8f", point.longitude)
            pointsXML += "    <trkpt lat=\"\(latitude)\" lon=\"\(longitude)\"><time>\(timestamp)</time></trkpt>\\n"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="MyGPXStudio iOS" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(title.xmlEscaped)</name>
            <desc>高德\(plan.mode.title)路线；坐标已由 GCJ-02 转为 WGS-84。</desc>
          </metadata>
          <trk>
            <name>\(title.xmlEscaped)</name>
            <type>\(plan.mode.rawValue)</type>
            <extensions><distanceMeters>\(Int(plan.distance))</distanceMeters><durationSeconds>\(Int(plan.duration))</durationSeconds></extensions>
            <trkseg>
        \(pointsXML)    </trkseg>
          </trk>
        </gpx>
        """
        return xml.data(using: .utf8)
    }

    private static func timestamps(for points: [Coordinate], departure: Date, duration: TimeInterval) -> [Date] {
        guard points.count > 1 else { return [departure] }
        let totalDuration = max(duration, TimeInterval(points.count - 1))
        var accumulated: [Double] = [0]
        for index in 1..<points.count {
            accumulated.append(accumulated[index - 1] + distance(from: points[index - 1], to: points[index]))
        }
        let totalDistance = max(accumulated.last ?? 0, 0.000001)
        return accumulated.map { departure.addingTimeInterval(totalDuration * ($0 / totalDistance)) }
    }

    private static func distance(from start: Coordinate, to end: Coordinate) -> Double {
        let radius = 6_371_000.0
        let deltaLatitude = (end.latitude - start.latitude) * .pi / 180
        let deltaLongitude = (end.longitude - start.longitude) * .pi / 180
        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(start.latitude * .pi / 180) * cos(end.latitude * .pi / 180)
            * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

enum KeychainStore {
    private static let service = "com.zongyue.MyGPXStudio.iOS"

    static func value(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(value: String, for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(value.utf8)
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private func safeFilename(_ text: String) -> String {
    text.replacingOccurrences(of: "[\\\\/:*?\\\"<>|]", with: "", options: .regularExpression)
}
