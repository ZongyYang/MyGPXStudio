import MapKit
import SwiftUI
import UIKit

struct ContentView: View {
    private static let compactDetent = PresentationDetent.height(178)
    private static let mediumDetent = PresentationDetent.fraction(0.52)

    @StateObject private var model = RoutePlannerModel()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )
    )
    @State private var isShowingSettings = false
    @State private var isShowingShareSheet = false
    @State private var sharedGPXURL: URL?
    @State private var isShowingPlanner = true
    @State private var plannerDetent = ContentView.compactDetent

    var body: some View {
        routeMap
            .ignoresSafeArea()
        .navigationTitle("MyGPXStudio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("高德 API 设置")
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(model: model)
        }
        .sheet(isPresented: $isShowingPlanner) {
            plannerSheet
                .presentationDetents(
                    [Self.compactDetent, Self.mediumDetent, .large],
                    selection: $plannerDetent
                )
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(.thinMaterial)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let sharedGPXURL {
                ActivityView(activityItems: [sharedGPXURL])
                    .ignoresSafeArea()
            }
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button("好", role: .cancel) {
                model.clearError()
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onChange(of: model.mapFocusToken) { _, _ in
            focusMap(on: model.routePlan?.wgs84Points ?? model.selectedPlaces.map { CoordinateTransform.gcj02ToWGS84($0.gcj02) })
        }
        .onChange(of: model.routePlan?.wgs84Points.count) { _, pointCount in
            if pointCount != nil {
                plannerDetent = Self.mediumDetent
            }
        }
    }

    private var plannerSheet: some View {
        Group {
            if plannerDetent == Self.compactDetent {
                compactPlannerSummary
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        plannerCard
                        if model.routePlan != nil {
                            Divider()
                            routeInformationCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private var compactPlannerSummary: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.routePlan == nil ? "规划路线" : "路线已生成")
                        .font(.title3.bold())
                    Text(compactSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.semibold))
                        .padding(8)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("高德 API 设置")
            }

            Button {
                plannerDetent = Self.mediumDetent
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.routePlan == nil ? "magnifyingglass" : "arrow.triangle.turn.up.right.diamond.fill")
                    Text(model.routePlan == nil ? "上滑或点此设置起点、终点和途经点" : "查看路线信息与导出 GPX")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var compactSummaryText: String {
        if let plan = model.routePlan {
            return "\(plan.distanceText) · \(plan.durationText) · \(model.waypointCount) 个途经点"
        }
        if !model.hasCredentials {
            return "请先设置高德 API Key"
        }
        return "起点、终点与 \(model.waypointCount) 个途经点"
    }

    private var routeMap: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            if let plan = model.routePlan {
                MapPolyline(coordinates: plan.wgs84Points.map(clLocationCoordinate))
                    .stroke(.blue, lineWidth: 6)
            }
            ForEach(Array(model.stops.enumerated()), id: \.element.id) { index, stop in
                if let place = stop.place {
                    Annotation(markerTitle(for: stop, index: index), coordinate: clLocationCoordinate(CoordinateTransform.gcj02ToWGS84(place.gcj02))) {
                        marker(for: stop.kind, index: index)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    private var plannerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("规划路线")
                        .font(.title3.bold())
                    Text(model.hasCredentials ? "原生地图支持双指缩放和拖移。" : "请先设置高德 API Key 后搜索地点。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isPlanning {
                    ProgressView()
                }
            }

            Picker("出行方式", selection: $model.transportMode) {
                ForEach(TransportMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.iconName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            ForEach(Array(model.stops.enumerated()), id: \.element.id) { index, stop in
                RouteStopEditor(
                    stop: stop,
                    waypointNumber: waypointNumber(for: index),
                    query: model.queryBinding(for: stop.id),
                    canMoveUp: model.canMoveWaypoint(stop.id, direction: -1),
                    canMoveDown: model.canMoveWaypoint(stop.id, direction: 1),
                    onClear: { model.clearStop(stop.id) },
                    onSelect: { model.select($0, for: stop.id) },
                    onMove: { model.moveWaypoint(stop.id, direction: $0) },
                    onDelete: { model.deleteWaypoint(stop.id) }
                )
            }

            Button {
                model.addWaypoint()
            } label: {
                Label("添加途经点", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("出发时间")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 10) {
                    DatePicker("日期", selection: $model.departureTime, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    DatePicker("时间", selection: $model.departureTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
                if let generated = model.generatedDepartureTime {
                    Text("当前路线按 \(generated.formatted(.dateTime.year().month().day().hour().minute())) 写入 GPX 时间戳。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                model.planRoute()
            } label: {
                Label(model.isPlanning ? "正在生成路线" : "生成路线", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canPlan)

            Text(model.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private var routeInformationCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("路线信息")
                        .font(.title3.bold())
                    Text("路线生成时锁定的出发时间会写入 GPX。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.transportMode.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.14), in: Capsule())
                    .foregroundStyle(.blue)
            }

            if model.routeOptions.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("路线建议")
                        .font(.headline)
                    ForEach(model.routeOptions.indices, id: \.self) { index in
                        RouteOptionRow(
                            plan: model.routeOptions[index],
                            index: index,
                            isSelected: model.selectedRouteIndex == index
                        ) {
                            model.selectRoute(at: index)
                        }
                    }
                }
            }

            if let plan = model.routePlan {
                HStack(spacing: 0) {
                    MetricView(title: "距离", value: plan.distanceText, systemImage: "ruler")
                    Divider().frame(height: 48)
                    MetricView(title: "预计时长", value: plan.durationText, systemImage: "clock")
                    Divider().frame(height: 48)
                    MetricView(title: "轨迹点", value: "\(plan.wgs84Points.count)", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 7) {
                if let start = model.stops.first?.place {
                    Label(start.displayName, systemImage: "circle.inset.filled")
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
                if let end = model.stops.last?.place {
                    Label(end.displayName, systemImage: "mappin.circle.fill")
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
            .font(.footnote.weight(.medium))

            Button {
                do {
                    sharedGPXURL = try model.makeTemporaryGPXURL()
                    isShowingShareSheet = true
                } catch {
                    model.present(error: error)
                }
            } label: {
                Label("导出 / 分享 GPX", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    private func waypointNumber(for index: Int) -> Int? {
        guard model.stops[index].kind == .waypoint else { return nil }
        return model.stops[..<index].filter { $0.kind == .waypoint }.count + 1
    }

    private func markerTitle(for stop: RouteStop, index: Int) -> String {
        switch stop.kind {
        case .start: "起点"
        case .end: "终点"
        case .waypoint: "途经点 \(waypointNumber(for: index) ?? 1)"
        }
    }

    @ViewBuilder
    private func marker(for kind: RouteStopKind, index: Int) -> some View {
        let color: Color = switch kind {
        case .start: .green
        case .waypoint: .blue
        case .end: .orange
        }
        ZStack {
            Circle().fill(.background).frame(width: 38, height: 38)
            Image(systemName: kind == .waypoint ? "\(waypointNumber(for: index) ?? 1).circle.fill" : kind.symbolName)
                .font(.title2)
                .foregroundStyle(color)
        }
        .shadow(radius: 3)
    }

    private func clLocationCoordinate(_ coordinate: Coordinate) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func focusMap(on points: [Coordinate]) {
        guard !points.isEmpty else { return }
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard let minimumLatitude = latitudes.min(),
              let maximumLatitude = latitudes.max(),
              let minimumLongitude = longitudes.min(),
              let maximumLongitude = longitudes.max() else { return }
        let latitudeDelta = max((maximumLatitude - minimumLatitude) * 1.45, 0.025)
        let longitudeDelta = max((maximumLongitude - minimumLongitude) * 1.45, 0.025)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minimumLatitude + maximumLatitude) / 2,
                longitude: (minimumLongitude + maximumLongitude) / 2
            ),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
        withAnimation {
            cameraPosition = .region(region)
        }
    }
}

private struct RouteStopEditor: View {
    let stop: RouteStop
    let waypointNumber: Int?
    @Binding var query: String
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onClear: () -> Void
    let onSelect: (Place) -> Void
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: stop.kind.symbolName)
                    .foregroundStyle(markerColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(markerColor)
                Spacer()
                if stop.kind == .waypoint {
                    Button { onMove(-1) } label: { Image(systemName: "chevron.up") }
                        .disabled(!canMoveUp)
                    Button { onMove(1) } label: { Image(systemName: "chevron.down") }
                        .disabled(!canMoveDown)
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                }
            }
            .font(.caption.weight(.semibold))

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索地点或地址", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("清除\(title)")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            if !stop.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(stop.suggestions) { place in
                        Button {
                            onSelect(place)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if !place.address.isEmpty && place.address != "[]" {
                                    Text(place.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        if place.id != stop.suggestions.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        stop.kind == .waypoint ? "途经点 \(waypointNumber ?? 1)" : stop.kind.title
    }

    private var markerColor: Color {
        switch stop.kind {
        case .start: .green
        case .waypoint: .blue
        case .end: .orange
        }
    }
}

private struct RouteOptionRow: View {
    let plan: RoutePlan
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                Text("方案 \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.distanceText)
                        .font(.subheadline.weight(.semibold))
                    Text(plan.durationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MetricView: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.teal)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: RoutePlannerModel
    @State private var apiKey = ""
    @State private var securityKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("高德 Web 服务") {
                    TextField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("数字签名安全密钥（可选）", text: $securityKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("密钥仅存储在本机钥匙串，不会写入项目代码或 GPX 文件。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("使用说明") {
                    Text("输入至少两个汉字后显示地点建议；点击建议后才会在地图上放置起点、途经点或终点。路线生成后，使用系统分享面板存储到“文件”或发送给其他 App。")
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        model.saveCredentials(apiKey: apiKey, securityKey: securityKey)
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKey = model.apiKey
                securityKey = model.securityKey
            }
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
