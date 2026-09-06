import XCTest
@testable import RouteToGPX

final class RouteToGPXTests: XCTestCase {
    @MainActor
    func testTypedDepartureDateAcceptsISODateOnly() {
        let parsed = PaddedDatePicker.parsedDate(from: "2026-09-03")
        XCTAssertNotNil(parsed)
        XCTAssertNil(PaddedDatePicker.parsedDate(from: "2026-9-3"))
        XCTAssertNil(PaddedDatePicker.parsedDate(from: "2026-02-30"))
    }

    func testGCJ02ConversionChangesMainlandCoordinate() {
        let gaodePoint = Coordinate(latitude: 23.1291, longitude: 113.2644)
        let wgs84Point = CoordinateTransform.gcj02ToWGS84(gaodePoint)

        XCTAssertNotEqual(gaodePoint, wgs84Point)
        XCTAssertLessThan(abs(gaodePoint.latitude - wgs84Point.latitude), 0.02)
        XCTAssertLessThan(abs(gaodePoint.longitude - wgs84Point.longitude), 0.02)
    }

    func testGPXContainsTrackPointsAndTimes() throws {
        let points = [
            Coordinate(latitude: 23.1201, longitude: 113.2301),
            Coordinate(latitude: 23.1301, longitude: 113.2401),
            Coordinate(latitude: 23.1401, longitude: 113.2501)
        ]
        let plan = RoutePlan(
            mode: .walking,
            gcj02Points: points,
            wgs84Points: points,
            duration: 900,
            distance: 2_000
        )
        let data = try XCTUnwrap(GPXWriter.makeData(plan: plan, departure: Date(timeIntervalSince1970: 0), startName: "起点", endName: "终点"))
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(xml.components(separatedBy: "<trkpt ").count - 1, 3)
        XCTAssertEqual(xml.components(separatedBy: "<time>").count - 1, 3)
        XCTAssertTrue(xml.contains("坐标已由 GCJ-02 转为 WGS-84"))
    }

    func testGPXExportDestinationCreatesAndReusesDepartureFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2023
        components.month = 7
        components.day = 6
        components.hour = 10
        components.minute = 57
        let departure = try XCTUnwrap(components.date)

        let first = try GPXExportDestination.destinationURL(
            in: root,
            departure: departure,
            filename: "route.gpx"
        )
        XCTAssertEqual(first.deletingLastPathComponent().lastPathComponent, GPXExportDestination.folderName(for: departure))
        XCTAssertEqual(first.lastPathComponent, "route.gpx")

        try Data("first".utf8).write(to: first)
        let second = try GPXExportDestination.destinationURL(
            in: root,
            departure: departure,
            filename: "route.gpx"
        )
        XCTAssertEqual(second.deletingLastPathComponent(), first.deletingLastPathComponent())
        XCTAssertEqual(second.lastPathComponent, "route-2.gpx")
    }

    @MainActor
    func testGeneratedRouteKeepsItsDepartureTimeForExport() {
        let route = RoutePlan(
            mode: .driving,
            gcj02Points: [Coordinate(latitude: 34.1, longitude: 108.7)],
            wgs84Points: [Coordinate(latitude: 34.1, longitude: 108.7)],
            duration: 60,
            distance: 1_000
        )
        let generatedDeparture = Date(timeIntervalSince1970: 1_690_243_020)
        let laterEditedDate = Date(timeIntervalSince1970: 1_725_110_400)
        let model = RoutePlannerViewModel()

        model.departureTime = generatedDeparture
        model.applyPlannedRoutes([route], departureTime: model.departureTime)
        model.departureTime = laterEditedDate

        XCTAssertEqual(model.exportDepartureTime, generatedDeparture)
        XCTAssertEqual(model.routeDepartureTime, generatedDeparture)
    }

    func testGPXMergerCombinesTracksFromFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let template = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><name>测试轨迹</name><trkseg><trkpt lat="34.1" lon="108.7" /></trkseg></trk>
        </gpx>
        """
        try Data(template.utf8).write(to: folder.appendingPathComponent("01.gpx"))
        try Data(template.utf8).write(to: folder.appendingPathComponent("02.gpx"))

        let result = try GPXMerger.merge(folder: folder)
        let xml = try XCTUnwrap(String(data: result.data, encoding: .utf8))

        XCTAssertEqual(result.fileCount, 2)
        XCTAssertEqual(result.trackCount, 2)
        XCTAssertEqual(xml.components(separatedBy: "<trk>").count - 1, 2)
    }

    @MainActor
    func testSelectingSuggestionRetainsChosenPlaceAfterTextFieldUpdate() {
        let place = Place(
            id: "poi-1",
            name: "创新港（地铁站）",
            address: "西咸新区沣西新城沣西大道2399号",
            gcj02: Coordinate(latitude: 34.18, longitude: 108.70)
        )
        let model = RoutePlannerViewModel()
        model.startSuggestions = [place]
        model.confirmSearch(for: .start)

        XCTAssertEqual(model.startPlace, place)
        XCTAssertEqual(model.startQuery, place.displayName)
        XCTAssertTrue(model.startSuggestions.isEmpty)

        // SwiftUI 会在 select() 修改输入框后触发 onChange；这一步不应清空已选地点。
        model.searchPlaces(model.startQuery, for: .start)
        XCTAssertEqual(model.startPlace, place)
        XCTAssertTrue(model.startSuggestions.isEmpty)

        let endPlace = Place(
            id: "poi-2",
            name: "昆明池·七夕公园",
            address: "西安市长安区",
            gcj02: Coordinate(latitude: 34.15, longitude: 108.73)
        )
        model.select(endPlace, for: .end)
        model.searchPlaces(model.endQuery, for: .end)
        XCTAssertEqual(model.endPlace, endPlace)
        XCTAssertTrue(model.canPlan)
    }

    @MainActor
    func testSwapStartAndEndPreservesSelections() {
        let start = Place(
            id: "swap-start",
            name: "起点",
            address: "起点地址",
            gcj02: Coordinate(latitude: 34.1, longitude: 108.7)
        )
        let end = Place(
            id: "swap-end",
            name: "终点",
            address: "终点地址",
            gcj02: Coordinate(latitude: 34.2, longitude: 108.8)
        )
        let model = RoutePlannerViewModel()
        model.select(start, for: .start)
        model.select(end, for: .end)

        model.swapStartEnd()

        XCTAssertEqual(model.startPlace, end)
        XCTAssertEqual(model.endPlace, start)
        XCTAssertEqual(model.startQuery, end.displayName)
        XCTAssertEqual(model.endQuery, start.displayName)
    }

    @MainActor
    func testSelectingPlaceMakesItAvailableAsRecentSearch() {
        let place = Place(
            id: "recent-place",
            name: "最近地点",
            address: "最近地点地址",
            gcj02: Coordinate(latitude: 34.1, longitude: 108.7)
        )
        let model = RoutePlannerViewModel()
        model.select(place, for: .start)
        model.startQuery = ""

        model.showRecent(for: .start)

        XCTAssertEqual(model.startSuggestions.first, place)
    }

    @MainActor
    func testWaypointCanBeAddedReorderedAndRemoved() {
        let start = Place(id: "start", name: "起点", address: "起点地址", gcj02: Coordinate(latitude: 34.1, longitude: 108.7))
        let waypoint = Place(id: "waypoint", name: "途经点", address: "途经点地址", gcj02: Coordinate(latitude: 34.2, longitude: 108.8))
        let end = Place(id: "end", name: "终点", address: "终点地址", gcj02: Coordinate(latitude: 34.3, longitude: 108.9))
        let model = RoutePlannerViewModel()
        model.apiKey = "test-key"
        model.select(start, for: .start)
        model.select(end, for: .end)

        model.addWaypoint()
        let waypointID = model.routeStops[1].id
        model.select(waypoint, for: waypointID)

        XCTAssertEqual(model.routeStops.count, 3)
        XCTAssertTrue(model.canPlan)
        XCTAssertEqual(model.stopTitle(at: 1), "途经点 1")
        XCTAssertEqual(model.waypointPlaces.map(\.id), ["waypoint"])

        model.moveStop(waypointID, direction: .up)

        XCTAssertEqual(model.routeStops.compactMap(\.place).map(\.id), ["waypoint", "start", "end"])
        XCTAssertEqual(model.startPlace, waypoint)
        XCTAssertEqual(model.waypointPlaces.map(\.id), ["start"])

        let removableStopID = model.routeStops[1].id
        model.removeStop(removableStopID)

        XCTAssertEqual(model.routeStops.compactMap(\.place).map(\.id), ["waypoint", "end"])
        XCTAssertTrue(model.waypointPlaces.isEmpty)
        XCTAssertTrue(model.canPlan)
    }

    func testMergingRouteLegsKeepsOnlyOneSharedConnectionPoint() {
        let first = Coordinate(latitude: 34.1, longitude: 108.7)
        let shared = Coordinate(latitude: 34.2, longitude: 108.8)
        let last = Coordinate(latitude: 34.3, longitude: 108.9)
        let firstLeg = RoutePlan(mode: .driving, gcj02Points: [first, shared], wgs84Points: [first, shared], duration: 60, distance: 1_000)
        let secondLeg = RoutePlan(mode: .driving, gcj02Points: [shared, last], wgs84Points: [shared, last], duration: 90, distance: 1_500)

        let merged = RoutePlan.merging([firstLeg, secondLeg])

        XCTAssertEqual(merged.gcj02Points, [first, shared, last])
        XCTAssertEqual(merged.wgs84Points, [first, shared, last])
        XCTAssertEqual(merged.duration, 150)
        XCTAssertEqual(merged.distance, 2_500)
    }
}
