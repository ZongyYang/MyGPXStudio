# MyGPXStudio 最新源码与开发记录

> 更新时间：2026-09-10
>
> 本文档是当前版本的交接与归档文件，包含 macOS 主源码快照、iOS Target 说明、功能记录和构建/分发说明。项目实际文件仍是后续编辑时的唯一准则。
>
> 安全提示：不要在本文档、源码或压缩包中写入真实的高德 API Key、安全密钥或用户地点数据。

## 1. 项目概况

MyGPXStudio 是原生 macOS 路线规划与 GPX 导出工具。它使用 SwiftUI + MapKit 构建界面和地图，通过高德 Web 服务 API 检索地点、规划驾车/骑行/步行路线，并在导出前将 GCJ-02 坐标转换为 WGS-84。

- Swift tools version：6.0
- 最低系统：macOS 14.0
- 当前构建：Apple Silicon `arm64`，不是 Universal Binary
- 应用标识：`com.zongyue.mygpxstudio`
- 应用产物：`dist/MyGPXStudio.app`
- 签名：本机临时 ad-hoc 签名，未使用 Developer ID，也未公证

### iOS Target（2026-09-10）

- 工程：`MyGPXStudio-iOS.xcodeproj`
- 源码：`iOS/MyGPXStudioiOS/MyGPXStudioiOSApp.swift`、`ContentView.swift`、`RoutePlannerModel.swift`
- 使用 MapKit 原生地图，支持双指缩放、拖移，以及可上下拖拽的系统底部路线规划抽屉。
- 支持起点、多个途经点、终点、驾车/骑行/步行、路线建议、GPX 生成与 iOS 系统分享。
- Bundle Identifier：`com.zongyue.mygpxstudio.ios`
- 2026-09-10 已完成 Debug 真机构建、签名、安装和启动验证；iOS API Key 仍由用户在 App 设置中输入并保存到本机钥匙串。

## 2. 已完成的功能记录

### 路线卡片与地点

- 地图全屏显示；规划路线卡片位于左侧，生成路线后路线信息卡片显示在其右侧并顶部对齐。
- 两张卡片根据内容增长、但不会超出窗口下边界；存在路线时两张卡片底部对齐。
- 起点、终点和多个途经点可搜索、确认、清除、上移、下移和删除；途经点以紧凑行显示，不再在每行下方重复展示绿色勾选地址。
- 搜索推荐仅在输入文本后出现，以顶层浮层展示，不遮挡卡片内的时间或按钮。
- 路线建议使用竖向列表；点击可以切换当前方案。

### 出行方式、出发时间和导出时间

- 顶部提供紧凑的驾车、骑行、步行图标。
- 日期支持图形化日历和键盘输入 `yyyy-MM-dd`；当输入成为完整有效日期时立即同步，按回车或离开输入框也会提交。时间使用 24 小时制。
- 点击“生成路线”时，应用会冻结该次路线的出发日期和时间。
- 后续即使编辑时间输入框，导出的 GPX 时间戳、文件名和导出文件夹仍使用这次路线生成时冻结的出发时间，不使用系统当前时间。
- 导出按钮默认打开 `下载/GPX Output/生成路线时的出发日期` 文件夹（如 `下载/GPX Output/2023-07-25`），不存在时自动创建；用户也可以在保存面板中改选其他位置，应用会在所选父目录下创建该出发日期文件夹。同名 GPX 自动添加 `-2`、`-3` 等序号，避免覆盖旧文件。

### 地图与路线

- MapKit 地图启用原生拖移、双指缩放、旋转和俯仰。背景视觉层关闭命中测试，避免遮挡地图手势。
- 起点显示绿色标记，终点显示橙色标记，已确认的每个途经点显示带顺序标签的蓝色标记。
- 地图右侧含样式、定位、缩放、恢复正北等工具；比例尺位于整组右侧控制的上方。
- 没有途经点时可选择高德返回的多条路线；有途经点时应用按当前顺序逐段规划，并在合并时去掉重复连接点。

### GPX、设置与本机数据

- GPX 导出按照路线距离比例分配轨迹点时间戳。
- “文件 → 合并文件夹中的 GPX…”（`⌘⌥M`）可合并某个文件夹内的 GPX，不修改原文件。
- 高德 API Key 与可选安全密钥保存于当前 Mac 的钥匙串；最近地点保存于 UserDefaults，最多 10 个。
- 复制 App 到另一台 Mac 后，需要重新填写 API Key；钥匙串和最近地点不会随 App 包转移。

## 3. 关键文件

```text
MyGPXStudio-source/
├── Sources/RouteToGPX/RouteToGPXApp.swift      # 主源码：界面、地图、API、GPX
├── Tests/RouteToGPXTests/RouteToGPXTests.swift  # XCTest 测试
├── Resources/Info.plist                         # App 信息、最低系统、定位权限说明
├── Resources/MyGPXStudio.icns                   # 应用图标
├── Resources/MyGPXStudio.svg                    # 图标源文件
├── Package.swift                                 # Swift Package 配置
├── build_macos.sh                                # 构建、打包和临时签名
├── MyGPXStudio-iOS.xcodeproj/                     # iOS Target 工程
├── iOS/MyGPXStudioiOS/                            # iOS 地图、路线和 GPX 源码
├── README.md                                     # 简版使用说明
├── MyGPXStudio-开发记录.md                       # 本归档文档
└── dist/MyGPXStudio.app                          # 当前可运行 App
```

关键类型：`ContentView`、`PaddedDatePicker`、`RouteMapView`、`MapToolbar`、`RoutePlannerViewModel`、`AMapClient`、`CoordinateTransform`、`GPXWriter`、`GPXExportDestination`、`GPXMerger` 与 `KeychainStore`。

## 4. 构建与验证

在项目根目录执行：

```bash
swift test
zsh build_macos.sh
codesign --verify --deep --strict dist/MyGPXStudio.app
open dist/MyGPXStudio.app
```

当前版本验证状态：11 项 XCTest 通过、Release 构建成功、App 签名验证成功。

## 5. 分发与后续更新

目标 Mac 需要 Apple Silicon 和 macOS 14 或更高版本。建议压缩 `dist/MyGPXStudio.app` 为 ZIP 后再传输；首次打开被 Gatekeeper 拦截时，可右键选择“打开”。

后续开发应始终在源码工程中进行：修改源码 → 测试和构建 → 退出旧 App → 用新版 `dist/MyGPXStudio.app` 替换“应用程序”文件夹中的旧 App。当前未实现自动更新。

如果未来要发布给其他用户，应增加 Developer ID 签名、公证、版本管理和自动更新方案；如果要支持 Intel Mac，应构建 Intel 或 Universal Binary。

## 6. 当前源码快照

以下内容是生成本文档时的完整源码快照。

### 6.1 `Sources/RouteToGPX/RouteToGPXApp.swift`

```swift
import SwiftUI
import Foundation
import Security
import CryptoKit
import UniformTypeIdentifiers
import MapKit
import AppKit

@main
struct RouteToGPXApp: App {
    @StateObject private var model = RoutePlannerViewModel()

    var body: some Scene {
        WindowGroup("MyGPXStudio") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 700)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .importExport) {
                Button("合并文件夹中的 GPX…") {
                    model.mergeGPXFolder()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

/// 将搜索框的位置传递到路线面板的最外层。推荐列表在这里绘制，避免被卡片内后续控件遮挡。
private struct RouteStopSearchFieldAnchorKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: RoutePlannerViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExporting = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapTapCoordinate: Coordinate?
    @State private var mapAppearance: MapAppearance = .standard
    @StateObject private var locationController = UserLocationController()
    @Namespace private var mapScope
    private let panelInset: CGFloat = 16
    private let formCardChromeHeight: CGFloat = 280
    private let compactStopRowHeight: CGFloat = 54
    private let stopSeparatorHeight: CGFloat = 13
    private let primaryActionHeight: CGFloat = 40

    var body: some View {
        ZStack {
            RouteMapView(
                cameraPosition: $cameraPosition,
                start: model.startPlace,
                end: model.endPlace,
                waypoints: model.waypointPlaces,
                route: model.routePlan,
                mapAppearance: mapAppearance,
                mapScope: mapScope,
                onMapTap: { coordinate in
                    mapTapCoordinate = coordinate
                }
            )
            .ignoresSafeArea()

            MapScaleView(scope: mapScope)
                .mapControlVisibility(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 6)
                .padding(.trailing, 24)
                .allowsHitTesting(false)

            MapToolbar(
                mapAppearance: $mapAppearance,
                onLocate: {
                    locationController.requestLocation()
                },
                onZoomIn: { zoomMap(by: 0.55) },
                onZoomOut: { zoomMap(by: 1.8) },
                onResetNorth: resetMapNorth
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 24)
            .padding(.trailing, 24)
            .zIndex(5)

            LinearGradient(
                colors: colorScheme == .dark
                    ? [.black.opacity(0.18), Color(red: 0.02, green: 0.10, blue: 0.15).opacity(0.28)]
                    : [.white.opacity(0.10), .white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { layout in
                let maximumCardHeight = max(0, layout.size.height - panelInset * 2)
                let stopListHeight = compactStopListHeight(for: maximumCardHeight)
                let plannerContentHeight = min(
                    formCardChromeHeight + stopListHeight,
                    maximumCardHeight
                )
                let alignedCardHeight = commonCardHeight(
                    plannerContentHeight: plannerContentHeight,
                    maximumCardHeight: maximumCardHeight
                )

                HStack(alignment: .top, spacing: panelInset) {
                    formCard(height: alignedCardHeight, stopListHeight: stopListHeight)
                        .frame(width: 360, height: alignedCardHeight)

                    if model.routePlan != nil {
                        routeSummaryCard
                            .frame(width: 360, height: alignedCardHeight)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(panelInset)
                .overlayPreferenceValue(RouteStopSearchFieldAnchorKey.self) { anchors in
                    GeometryReader { proxy in
                        if let stop = model.activeSuggestionStop,
                           let anchor = anchors[stop.id] {
                            let searchFieldFrame = proxy[anchor]
                            let availableHeight = max(120, proxy.size.height - searchFieldFrame.maxY - panelInset - 8)
                            let dropdownHeight = min(
                                MapStyleDropdown.height(for: stop.suggestions.count),
                                availableHeight
                            )

                            MapStyleDropdown(
                                suggestions: stop.suggestions,
                                maximumHeight: availableHeight,
                                onSelect: { model.select($0, for: stop.id) }
                            )
                            .frame(width: searchFieldFrame.width)
                            .position(
                                x: searchFieldFrame.midX,
                                y: searchFieldFrame.maxY + 8 + dropdownHeight / 2
                            )
                            .zIndex(100)
                        }
                    }
                }
                .zIndex(model.activeSuggestionStop == nil ? 0 : 30)
            }

            if let mapTapCoordinate {
                MapPointActionMenu(
                    coordinate: mapTapCoordinate,
                    onStart: {
                        model.selectMapCoordinate(mapTapCoordinate, for: .start)
                        self.mapTapCoordinate = nil
                    },
                    onEnd: {
                        model.selectMapCoordinate(mapTapCoordinate, for: .end)
                        self.mapTapCoordinate = nil
                    },
                    onCancel: {
                        self.mapTapCoordinate = nil
                    }
                )
                .zIndex(20)
            }

            if isExporting {
                exportProgressNotice
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
            }

            if model.isMergingGPX {
                progressNotice(title: "正在合并 GPX", message: "正在读取并合并文件夹中的轨迹…")
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(11)
            }
        }
        .onChange(of: model.selectedPlaces) { _, _ in focusMapOnSelectedPlaces() }
        .onChange(of: locationController.location) { _, location in
            guard let location else { return }
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            ))
        }
        .onChange(of: locationController.lastError) { _, message in
            if let message {
                model.setStatus(message, error: true)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExporting)
    }

    private func zoomMap(by factor: Double) {
        guard let region = cameraPosition.region else {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 34.18, longitude: 108.70),
                span: MKCoordinateSpan(latitudeDelta: 0.08 * factor, longitudeDelta: 0.08 * factor)
            ))
            return
        }
        let latitudeDelta = min(max(region.span.latitudeDelta * factor, 0.0005), 180)
        let longitudeDelta = min(max(region.span.longitudeDelta * factor, 0.0005), 360)
        cameraPosition = .region(MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        ))
    }

    private func resetMapNorth() {
        guard let camera = cameraPosition.camera else { return }
        cameraPosition = .camera(MapCamera(
            centerCoordinate: camera.centerCoordinate,
            distance: camera.distance,
            heading: 0,
            pitch: camera.pitch
        ))
    }

    private func focusMapOnSelectedPlaces() {
        let places = model.selectedPlaces
        guard !places.isEmpty else { return }
        let coordinates = places.map { CoordinateTransform.gcj02ToWGS84($0.gcj02) }
        if coordinates.count == 1, let coordinate = coordinates.first {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            ))
            return
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let latitudeDelta = max((latitudes.max()! - latitudes.min()!) * 1.7, 0.03)
        let longitudeDelta = max((longitudes.max()! - longitudes.min()!) * 1.7, 0.03)
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (latitudes.max()! + latitudes.min()!) / 2,
                longitude: (longitudes.max()! + longitudes.min()!) / 2
            ),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        ))
    }

    private var exportProgressNotice: some View {
        progressNotice(title: "正在导出 GPX", message: "正在写入所选位置…")
    }

    /// 节点区按内容增加高度，超过窗口可用高度时才需要滚动。
    private func compactStopListHeight(for maximumCardHeight: CGFloat) -> CGFloat {
        let count = model.routeStops.count
        let naturalHeight = CGFloat(count) * compactStopRowHeight
            + CGFloat(max(count - 1, 0)) * stopSeparatorHeight
        let maximumListHeight = max(120, maximumCardHeight - formCardChromeHeight)
        return min(naturalHeight, maximumListHeight)
    }

    /// 有路线时两张卡片共用高度，以保证底边对齐；但始终不越过窗口下沿。
    private func commonCardHeight(plannerContentHeight: CGFloat, maximumCardHeight: CGFloat) -> CGFloat {
        guard model.routePlan != nil else { return plannerContentHeight }

        let routeChoicesHeight: CGFloat
        if model.routeOptions.count > 1 {
            routeChoicesHeight = 32
                + CGFloat(model.routeOptions.count) * 47
                + CGFloat(model.routeOptions.count - 1) * 7
        } else {
            routeChoicesHeight = 0
        }
        let summaryContentHeight: CGFloat = 360 + routeChoicesHeight
        return min(max(plannerContentHeight, summaryContentHeight), maximumCardHeight)
    }

    private func progressNotice(title: String, message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .tint(colorScheme == .dark ? .white : .accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(FrostedSurface(cornerRadius: 16, tintOpacity: 0.62))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 20, y: 10)
        .foregroundStyle(primaryTextColor)
    }

    private func chooseExportLocation() {
        guard let data = model.gpxData else {
            model.setStatus("没有可导出的路线。", error: true)
            return
        }

        let panel = NSSavePanel()
        let exportDepartureTime = model.exportDepartureTime
        let departureFolderName = GPXExportDestination.folderName(for: exportDepartureTime)
        panel.title = "选择 GPX 输出位置"
        panel.message = "将在所选位置创建或复用“\(departureFolderName)”文件夹。"
        panel.prompt = "保存"
        panel.allowedContentTypes = [.gpx]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = model.suggestedFilename

        let defaultFolderURL: URL
        do {
            defaultFolderURL = try GPXExportDestination.defaultFolderURL(for: exportDepartureTime)
            panel.directoryURL = defaultFolderURL
        } catch {
            model.setStatus("无法创建默认 GPX 输出文件夹：\(error.localizedDescription)", error: true)
            return
        }
        panel.message = "默认保存到“下载/GPX Output/\(departureFolderName)”；如需更改可在此窗口选择其他位置。"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let selectedDirectory = url.deletingLastPathComponent().standardizedFileURL
                let destination: URL
                if selectedDirectory == defaultFolderURL.standardizedFileURL {
                    destination = try GPXExportDestination.destinationFileURL(
                        in: selectedDirectory,
                        filename: url.lastPathComponent
                    )
                } else {
                    destination = try GPXExportDestination.destinationURL(
                        in: selectedDirectory,
                        departure: exportDepartureTime,
                        filename: url.lastPathComponent
                    )
                }
                export(data, to: destination, folderName: departureFolderName)
            } catch {
                model.setStatus("无法创建 GPX 输出文件夹：\(error.localizedDescription)", error: true)
            }
        }
    }

    private func export(_ data: Data, to url: URL, folderName: String) {
        Task { @MainActor in
            isExporting = true
            model.setStatus("正在导出 GPX…", error: false)
            await Task.yield()

            let failureMessage: String? = await Task.detached(priority: .userInitiated) {
                do {
                    try data.write(to: url, options: .atomic)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value

            // 路线文件通常很小；短暂保留提示，让保存完成状态能够被看见。
            try? await Task.sleep(for: .milliseconds(420))
            isExporting = false
            if let failureMessage {
                model.setStatus("导出失败：\(failureMessage)", error: true)
            } else {
                model.setStatus("已导出 GPX 文件至“\(folderName)”文件夹。", error: false)
            }
        }
    }

    private func formCard(height: CGFloat, stopListHeight: CGFloat) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("规划路线")
                    .font(.title3.weight(.semibold))

                TransportModePicker(selection: $model.transportMode)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(model.routeStops.enumerated()), id: \.element.id) { index, stop in
                            RouteStopInput(
                                stopID: stop.id,
                                title: model.stopTitle(at: index),
                                marker: model.stopMarker(at: index),
                                placeholder: "输入地点、地标或完整地址",
                                query: model.queryBinding(for: stop.id),
                                isLoading: model.searchingStopID == stop.id,
                                canMoveUp: index > 0,
                                canMoveDown: index < model.routeStops.count - 1,
                                canRemove: model.canRemoveStop(stop.id),
                                onSearch: { model.searchPlaces($0, for: stop.id) },
                                onConfirm: { model.confirmSearch(for: stop.id) },
                                onMoveUp: { model.moveStop(stop.id, direction: .up) },
                                onMoveDown: { model.moveStop(stop.id, direction: .down) },
                                onRemove: { model.removeStop(stop.id) }
                            )

                            if index < model.routeStops.count - 1 {
                                Divider().overlay(dividerColor)
                            }
                        }
                    }
                }
                .frame(height: stopListHeight)
                .scrollIndicators(.visible, axes: .vertical)

                Spacer(minLength: 0)

                Button {
                    model.addWaypoint()
                } label: {
                    Label("添加途经点", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Divider().overlay(dividerColor)

                VStack(alignment: .leading, spacing: 9) {
                    Text("出发时间")
                        .font(.subheadline.weight(.medium))
                    PaddedDatePicker(date: $model.departureTime)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    model.planRoute()
                } label: {
                    HStack {
                        if model.isPlanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                        Text(model.isPlanning ? "正在生成路线…" : "生成路线")
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: primaryActionHeight)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canPlan || model.isPlanning)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: height)
    }

    private var routeSummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("路线信息")
                            .font(.title3.weight(.semibold))
                        Text("地图显示已定位至起终点")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let plan = model.routePlan {
                        Text(plan.mode.title)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(plan.mode.tint.opacity(0.18), in: Capsule())
                            .foregroundStyle(plan.mode.tint)
                    }
                }

                if model.routeOptions.count > 1 {
                    RouteSuggestionsView(
                        routes: model.routeOptions,
                        selectedIndex: model.selectedRouteIndex,
                        onSelect: model.selectRouteOption
                    )
                }

                if let plan = model.routePlan {
                    HStack(spacing: 0) {
                        MetricView(title: "距离", value: plan.distanceText, icon: "ruler")
                        Divider().overlay(dividerColor)
                        MetricView(title: "预计时长", value: plan.durationText, icon: "clock")
                        Divider().overlay(dividerColor)
                        MetricView(title: "轨迹点", value: "\(plan.wgs84Points.count)", icon: "point.3.connected.trianglepath.dotted")
                    }
                    .frame(height: 82)

                    VStack(alignment: .leading, spacing: 5) {
                        Label(model.startPlace?.displayName ?? "", systemImage: "circle.inset.filled")
                            .foregroundStyle(.green)
                        Label(model.endPlace?.displayName ?? "", systemImage: "mappin.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.footnote)
                    .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(model.statusText)
                        .font(.caption)
                        .foregroundStyle(model.hasError ? .red : secondaryTextColor)
                        .lineLimit(2)

                    Button {
                        chooseExportLocation()
                    } label: {
                        Label("导出 GPX", systemImage: "square.and.arrow.down")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: primaryActionHeight)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.18, green: 0.67, blue: 0.45))
                    .disabled(model.isPlanning || isExporting)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.62) : .secondary
    }

    private var dividerColor: Color {
        colorScheme == .dark ? .white.opacity(0.16) : .black.opacity(0.12)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.10)
    }
}

struct TransportModePicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: TransportMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TransportMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Image(systemName: mode.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == mode ? selectedForeground : primaryTextColor)
                .background {
                    if selection == mode {
                        Capsule()
                            .fill(selectedBackground)
                            .padding(2)
                    }
                }
                .accessibilityLabel(mode.title)
                .help(mode.title)
            }
        }
        .background(trackBackground, in: Capsule())
        .overlay {
            Capsule()
                .stroke(colorScheme == .dark ? .white.opacity(0.15) : .black.opacity(0.08), lineWidth: 1)
        }
    }

    private var selectedForeground: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.72) : .secondary
    }

    private var selectedBackground: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.88)
    }

    private var trackBackground: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.06)
    }
}

struct PaddedDatePicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var date: Date
    @State private var isShowingCalendar = false
    @State private var dateInput: String
    @FocusState private var isDateFieldFocused: Bool

    init(date: Binding<Date>) {
        _date = date
        _dateInput = State(initialValue: Self.dateText(from: date.wrappedValue))
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                TextField("yyyy-MM-dd", text: $dateInput)
                    .textFieldStyle(.plain)
                    .font(.body.monospacedDigit())
                    .focused($isDateFieldFocused)
                    .onChange(of: dateInput) { _, value in
                        updateDateIfComplete(value)
                    }
                    .onSubmit(commitDateInput)
                    .onChange(of: isDateFieldFocused) { _, isFocused in
                        if !isFocused {
                            commitDateInput()
                        }
                    }

                Button {
                    isShowingCalendar.toggle()
                } label: {
                    Image(systemName: "calendar")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("从日历选择日期")
            }
            .padding(.leading, 10)
            .padding(.trailing, 5)
            .frame(height: 34)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isDateFieldFocused ? Color.accentColor.opacity(0.78) : fieldBorder, lineWidth: 1)
            }
            .popover(isPresented: $isShowingCalendar, arrowEdge: .bottom) {
                VStack(alignment: .trailing, spacing: 8) {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    Button("完成") {
                        isShowingCalendar = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(14)
            }
            .onChange(of: date) { _, newDate in
                if !isDateFieldFocused {
                    dateInput = Self.dateText(from: newDate)
                }
            }

            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
                .environment(\.locale, Locale(identifier: "en_GB"))
                .frame(width: 104)
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(fieldBorder, lineWidth: 1)
                }
        }
    }

    private func commitDateInput() {
        let normalizedInput = dateInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedDate = Self.parsedDate(from: normalizedInput) else {
            dateInput = Self.dateText(from: date)
            return
        }

        applyDate(parsedDate)
        dateInput = Self.dateText(from: date)
    }

    /// 输入达到完整且有效的 yyyy-MM-dd 时立即同步，避免点击“生成路线”时仍保留旧日期。
    private func updateDateIfComplete(_ input: String) {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedDate = Self.parsedDate(from: normalizedInput) else { return }
        applyDate(parsedDate)
    }

    private func applyDate(_ parsedDate: Date) {
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = calendar.dateComponents([.year, .month, .day], from: parsedDate)
        let existingTime = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        var merged = DateComponents()
        merged.calendar = calendar
        merged.timeZone = .current
        merged.year = selectedDay.year
        merged.month = selectedDay.month
        merged.day = selectedDay.day
        merged.hour = existingTime.hour
        merged.minute = existingTime.minute
        merged.second = existingTime.second
        merged.nanosecond = existingTime.nanosecond

        if let updatedDate = calendar.date(from: merged) {
            date = updatedDate
        }
    }

    static func parsedDate(from input: String) -> Date? {
        guard input.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.isLenient = false
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: input)
    }

    static func dateText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private var fieldBackground: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.05)
    }

    private var fieldBorder: Color {
        colorScheme == .dark ? .white.opacity(0.16) : .black.opacity(0.12)
    }
}

struct RouteMapView: View {
    @Binding var cameraPosition: MapCameraPosition
    let start: Place?
    let end: Place?
    let waypoints: [Place]
    let route: RoutePlan?
    let mapAppearance: MapAppearance
    let mapScope: Namespace.ID
    let onMapTap: (Coordinate) -> Void

    var body: some View {
        MapReader { proxy in
            // 显式保留 macOS 地图原生手势：触控板双指平移、双指捏合缩放，以及旋转/俯仰。
            Map(position: $cameraPosition, interactionModes: .all, scope: mapScope) {
                UserAnnotation()
                if let start {
                    Marker("起点：\(start.name)", coordinate: coordinate(for: start))
                        .tint(.green)
                }
                ForEach(Array(waypoints.enumerated()), id: \.offset) { index, waypoint in
                    Marker("途经点 \(index + 1)：\(waypoint.name)", coordinate: coordinate(for: waypoint))
                        .tint(.blue)
                }
                if let end {
                    Marker("终点：\(end.name)", coordinate: coordinate(for: end))
                        .tint(.orange)
                }
                if let route, route.wgs84Points.count > 1 {
                    MapPolyline(coordinates: route.wgs84Points.map { point in
                        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                    })
                    .stroke(.cyan, lineWidth: 5)
                }
            }
            .mapStyle(mapAppearance.mapStyle)
            .mapControls {
                MapCompass()
                MapPitchToggle()
            }
            .simultaneousGesture(
                SpatialTapGesture().onEnded { event in
                    guard let coordinate = proxy.convert(event.location, from: .local) else { return }
                    onMapTap(Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            )
        }
    }

    private func coordinate(for place: Place) -> CLLocationCoordinate2D {
        let wgs84 = CoordinateTransform.gcj02ToWGS84(place.gcj02)
        return CLLocationCoordinate2D(latitude: wgs84.latitude, longitude: wgs84.longitude)
    }
}

enum MapAppearance: String {
    case standard
    case imagery

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard
        case .imagery:
            return .imagery(elevation: .realistic)
        }
    }

    var iconName: String {
        switch self {
        case .standard: "map.fill"
        case .imagery: "globe.americas.fill"
        }
    }
}

struct MapToolbar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var mapAppearance: MapAppearance
    let onLocate: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onResetNorth: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                toolbarButton(systemImage: mapAppearance.iconName, action: toggleMapAppearance)
                toolbarDivider
                toolbarButton(systemImage: "location.fill", action: onLocate)
            }
            .background(toolbarSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 0) {
                toolbarButton(systemImage: "plus", action: onZoomIn)
                toolbarDivider
                toolbarButton(systemImage: "minus", action: onZoomOut)
            }
            .background(toolbarSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Button(action: onResetNorth) {
                ZStack {
                    Circle()
                        .fill(toolbarFill)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.red)
                    Text("北")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .offset(y: 13)
                }
                .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .background(toolbarSurface)
            .clipShape(Circle())
            .overlay { Circle().stroke(toolbarBorder, lineWidth: 1) }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.14), radius: 10, y: 5)
            .help("恢复正北方向")
        }
    }

    private func toggleMapAppearance() {
        mapAppearance = mapAppearance == .standard ? .imagery : .standard
    }

    private func toolbarButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(primaryTextColor)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(systemImage == "plus" ? "放大地图" : systemImage == "minus" ? "缩小地图" : systemImage == "location.fill" ? "定位到当前位置" : "切换地图样式")
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(toolbarBorder)
            .frame(width: 28, height: 1)
    }

    private var toolbarSurface: some View {
        FrostedSurface(cornerRadius: 24, tintOpacity: 0.68)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(toolbarBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.14), radius: 12, y: 6)
    }

    private var toolbarFill: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.04)
    }

    private var toolbarBorder: Color {
        colorScheme == .dark ? .white.opacity(0.20) : .black.opacity(0.10)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }
}

@MainActor
final class UserLocationController: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var lastError: String?

    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            lastError = "无法获取当前位置，请在系统设置中允许 MyGPXStudio 使用定位。"
        @unknown default:
            lastError = "当前设备暂时无法获取位置。"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastError = nil
        self.location = location
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = "当前位置获取失败：\(error.localizedDescription)"
    }
}

struct MapPointActionMenu: View {
    @Environment(\.colorScheme) private var colorScheme
    let coordinate: Coordinate
    let onStart: () -> Void
    let onEnd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("地图选点")
                        .font(.headline)
                    Text("纬度 \(String(format: "%.6f", coordinate.latitude))，经度 \(String(format: "%.6f", coordinate.longitude))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button("设为起点", action: onStart)
                    .buttonStyle(.borderedProminent)
                Button("设为终点", action: onEnd)
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 290)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.11), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 18, y: 8)
    }
}

struct RouteSuggestionsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let routes: [RoutePlan]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("路线建议")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(routes.count) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 7) {
                ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                    Button {
                        onSelect(index)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: index == selectedIndex ? "checkmark.circle.fill" : "circle")
                                .font(.subheadline)

                            Text("方案 \(index + 1)")
                                .font(.subheadline.weight(.semibold))

                            Spacer(minLength: 0)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(route.distanceText)
                                    .font(.subheadline.weight(.semibold))
                                Text(route.durationText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == selectedIndex ? Color.accentColor : primaryTextColor)
                    .background(
                        index == selectedIndex ? Color.accentColor.opacity(0.15) : primaryTextColor.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(index == selectedIndex ? Color.accentColor.opacity(0.50) : dividerColor, lineWidth: 1)
                    }
                }
            }
        }
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var dividerColor: Color {
        colorScheme == .dark ? .white.opacity(0.16) : .black.opacity(0.12)
    }
}

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FrostedSurface(cornerRadius: 20, tintOpacity: 0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme == .dark ? .white.opacity(0.20) : .black.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 18, y: 8)
            .foregroundStyle(colorScheme == .dark ? .white : .primary)
    }
}

struct FrostedSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let tintOpacity: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thickMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(surfaceTint)
        }
    }

    private var surfaceTint: Color {
        if colorScheme == .dark {
            return Color(red: 0.03, green: 0.10, blue: 0.16).opacity(tintOpacity)
        }
        return .white.opacity(min(max(tintOpacity * 0.32, 0.18), 0.34))
    }
}

struct RouteStopInput: View {
    @Environment(\.colorScheme) private var colorScheme
    let stopID: UUID
    let title: String
    let marker: String
    let placeholder: String
    @Binding var query: String
    let isLoading: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canRemove: Bool
    let onSearch: (String) -> Void
    let onConfirm: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Label(title, systemImage: marker)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(markerColor)
                Spacer(minLength: 0)
                HStack(spacing: 1) {
                    orderButton(systemImage: "chevron.up", action: onMoveUp)
                        .disabled(!canMoveUp)
                        .help("上移")
                    orderButton(systemImage: "chevron.down", action: onMoveDown)
                        .disabled(!canMoveDown)
                        .help("下移")
                    if canRemove {
                        orderButton(systemImage: "trash", action: onRemove)
                            .help("删除途经点")
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(secondaryTextColor)
                TextField(placeholder, text: $query)
                    .textFieldStyle(.plain)
                    .foregroundStyle(primaryTextColor)
                    .onChange(of: query) { _, value in onSearch(value) }
                    .onSubmit { onConfirm() }
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        onSearch("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(secondaryTextColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(FrostedSurface(cornerRadius: 12, tintOpacity: 0.78))
            .anchorPreference(key: RouteStopSearchFieldAnchorKey.self, value: .bounds) { [stopID: $0] }
        }
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.62) : .secondary
    }

    private var markerColor: Color {
        switch marker {
        case "circle.inset.filled": .green
        case "mappin.circle.fill": .orange
        default: .blue
        }
    }

    private func orderButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MapStyleDropdown: View {
    @Environment(\.colorScheme) private var colorScheme
    let suggestions: [Place]
    var maximumHeight: CGFloat? = nil
    let onSelect: (Place) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, place in
                        Button { onSelect(place) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle().fill(place.searchTint)
                                    Image(systemName: place.searchIcon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(place.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(primaryTextColor)
                                        .lineLimit(1)
                                    Text(place.fullAddress)
                                        .font(.caption)
                                        .foregroundStyle(secondaryTextColor)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(index == 0 ? selectionFillColor : .clear)

                        if place.id != suggestions.last?.id {
                            Divider().overlay(dividerColor)
                        }
                    }
                }
            }
            .frame(height: resultListHeight)
            .scrollIndicators(.visible, axes: .vertical)
        }
        .background(FrostedSurface(cornerRadius: 18, tintOpacity: 0.58))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(colorScheme == .dark ? .white.opacity(0.24) : .black.opacity(0.11), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.42 : 0.17), radius: 20, y: 10)
        .foregroundStyle(primaryTextColor)
    }

    static func height(for suggestionCount: Int) -> CGFloat {
        min(max(CGFloat(suggestionCount) * 72, 154), 456)
    }

    private var resultListHeight: CGFloat {
        min(Self.height(for: suggestions.count), maximumHeight ?? .greatestFiniteMagnitude)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.66) : .secondary
    }

    private var dividerColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.10)
    }

    private var selectionFillColor: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .white.opacity(0.52)
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundStyle(.mint)
                .font(.footnote)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RouteSketch: View {
    let points: [Coordinate]

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            let minLat = points.map(\.latitude).min() ?? 0
            let maxLat = points.map(\.latitude).max() ?? 0
            let minLon = points.map(\.longitude).min() ?? 0
            let maxLon = points.map(\.longitude).max() ?? 0
            let latRange = max(maxLat - minLat, 0.0001)
            let lonRange = max(maxLon - minLon, 0.0001)
            let inset: CGFloat = 18
            func screenPoint(_ coordinate: Coordinate) -> CGPoint {
                let x = inset + CGFloat((coordinate.longitude - minLon) / lonRange) * (size.width - inset * 2)
                let y = size.height - inset - CGFloat((coordinate.latitude - minLat) / latRange) * (size.height - inset * 2)
                return CGPoint(x: x, y: y)
            }

            var route = Path()
            route.move(to: screenPoint(points[0]))
            for point in points.dropFirst() {
                route.addLine(to: screenPoint(point))
            }
            context.stroke(route, with: .color(Color.mint), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

            let start = screenPoint(points[0])
            let end = screenPoint(points[points.count - 1])
            context.fill(Path(ellipseIn: CGRect(x: start.x - 7, y: start.y - 7, width: 14, height: 14)), with: .color(.green))
            context.fill(Path(ellipseIn: CGRect(x: end.x - 7, y: end.y - 7, width: 14, height: 14)), with: .color(.orange))
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: RoutePlannerViewModel
    @State private var key = ""
    @State private var securityKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("高德 Web 服务设置")
                .font(.title2.weight(.bold))
            Text("填写“Web 服务”类型的 Key。密钥只保存在此 Mac 的系统钥匙串中。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SecureField("Web 服务 API Key", text: $key)
                .textFieldStyle(.roundedBorder)
            SecureField("安全密钥（可选）", text: $securityKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Link("高德开放平台", destination: URL(string: "https://lbs.amap.com/")!)
                Spacer()
                Button("保存") {
                    model.saveCredentials(apiKey: key, securityKey: securityKey)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            key = model.apiKey
            securityKey = model.securityKey
        }
    }
}

struct RouteStop: Identifiable, Hashable {
    let id: UUID
    var query: String
    var place: Place?
    var suggestions: [Place]
    var selectedQuery: String?

    init(id: UUID = UUID(), query: String = "", place: Place? = nil, suggestions: [Place] = [], selectedQuery: String? = nil) {
        self.id = id
        self.query = query
        self.place = place
        self.suggestions = suggestions
        self.selectedQuery = selectedQuery
    }
}

@MainActor
final class RoutePlannerViewModel: ObservableObject {
    enum SearchField {
        case start, end
    }

    enum MoveDirection {
        case up, down
    }

    @Published var apiKey: String
    @Published var securityKey: String
    @Published private(set) var routeStops: [RouteStop] = [RouteStop(), RouteStop()]
    @Published private(set) var searchingStopID: UUID?
    @Published var startQuery = ""
    @Published var endQuery = ""
    @Published var startPlace: Place?
    @Published var endPlace: Place?
    @Published var startSuggestions: [Place] = []
    @Published var endSuggestions: [Place] = []
    @Published private(set) var recentPlaces: [Place]
    @Published var searchingField: SearchField?
    @Published var transportMode: TransportMode = .driving
    @Published var departureTime = Date()
    @Published var routePlan: RoutePlan?
    /// 路线生成成功时冻结的出发时间；导出的 GPX、文件名和日期文件夹始终使用它。
    @Published private(set) var routeDepartureTime: Date?
    @Published private(set) var routeOptions: [RoutePlan] = []
    @Published private(set) var selectedRouteIndex = 0
    @Published var isPlanning = false
    @Published private(set) var isMergingGPX = false
    @Published var statusText = "请先在“高德设置”中配置 Web 服务 API Key。"
    @Published var hasError = false

    private var searchTask: Task<Void, Never>?
    private var selectedStartQuery: String?
    private var selectedEndQuery: String?
    private let recentPlacesKey = "recentPlaces"

    init() {
        apiKey = KeychainStore.value(for: "amap.webServiceKey") ?? ""
        securityKey = KeychainStore.value(for: "amap.securityKey") ?? ""
        if let data = UserDefaults.standard.data(forKey: recentPlacesKey),
           let places = try? JSONDecoder().decode([Place].self, from: data) {
            recentPlaces = places
        } else {
            recentPlaces = []
        }
        if !apiKey.isEmpty {
            statusText = "输入起点和终点，点选详细地址后即可生成路线。"
        }
    }

    func stopTitle(at index: Int) -> String {
        guard routeStops.indices.contains(index) else { return "" }
        if index == 0 { return "起点" }
        if index == routeStops.count - 1 { return "终点" }
        return "途经点 \(index)"
    }

    func stopMarker(at index: Int) -> String {
        guard routeStops.indices.contains(index) else { return "mappin.circle.fill" }
        if index == 0 { return "circle.inset.filled" }
        if index == routeStops.count - 1 { return "mappin.circle.fill" }
        return "plus.circle.fill"
    }

    func queryBinding(for stopID: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.routeStops.first(where: { $0.id == stopID })?.query ?? ""
            },
            set: { [weak self] value in
                guard let self, let index = self.routeStops.firstIndex(where: { $0.id == stopID }) else { return }
                self.routeStops[index].query = value
            }
        )
    }

    func canRemoveStop(_ stopID: UUID) -> Bool {
        guard let index = routeStops.firstIndex(where: { $0.id == stopID }) else { return false }
        return index > 0 && index < routeStops.count - 1
    }

    func addWaypoint() {
        let insertionIndex = max(routeStops.count - 1, 0)
        routeStops.insert(RouteStop(), at: insertionIndex)
        invalidateRoute()
        setStatus("已添加途经点。", error: false)
    }

    func removeStop(_ stopID: UUID) {
        guard canRemoveStop(stopID), let index = routeStops.firstIndex(where: { $0.id == stopID }) else { return }
        searchTask?.cancel()
        if searchingStopID == stopID { searchingStopID = nil }
        routeStops.remove(at: index)
        synchronizeLegacyEndpoints()
        invalidateRoute()
        setStatus("已删除途经点。", error: false)
    }

    func moveStop(_ stopID: UUID, direction: MoveDirection) {
        guard let index = routeStops.firstIndex(where: { $0.id == stopID }) else { return }
        let destination = direction == .up ? index - 1 : index + 1
        guard routeStops.indices.contains(destination) else { return }
        routeStops.swapAt(index, destination)
        synchronizeLegacyEndpoints()
        invalidateRoute()
        setStatus("已调整路线节点顺序。", error: false)
    }

    func showRecent(for stopID: UUID) {
        searchTask?.cancel()
        searchingStopID = nil
        guard !recentPlaces.isEmpty, let index = routeStops.firstIndex(where: { $0.id == stopID }) else { return }
        dismissSuggestions(except: stopID)
        routeStops[index].suggestions = recentPlaces
        synchronizeLegacyEndpoints()
    }

    func searchPlaces(_ text: String, for stopID: UUID, selectFirstResult: Bool = false) {
        guard let index = routeStops.firstIndex(where: { $0.id == stopID }) else { return }
        dismissSuggestions(except: stopID)
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if routeStops[index].selectedQuery == keyword {
            routeStops[index].selectedQuery = nil
            routeStops[index].suggestions = []
            synchronizeLegacyEndpoints()
            return
        }

        routeStops[index].place = nil
        routeStops[index].suggestions = []
        synchronizeLegacyEndpoints()
        invalidateRoute()
        searchTask?.cancel()
        searchingStopID = nil
        guard keyword.count >= 2 else { return }
        guard !apiKey.isEmpty else {
            setStatus("请先配置高德 Web 服务 API Key。", error: true)
            return
        }

        searchTask = Task { [weak self] in
            if !selectFirstResult {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled, let self else { return }
            self.searchingStopID = stopID
            do {
                let places = try await AMapClient.searchPlaces(keyword: keyword, apiKey: self.apiKey, securityKey: self.securityKey)
                guard !Task.isCancelled, let index = self.routeStops.firstIndex(where: { $0.id == stopID }) else { return }
                self.routeStops[index].suggestions = places
                self.synchronizeLegacyEndpoints()
                if selectFirstResult, let place = places.first {
                    self.select(place, for: stopID)
                } else {
                    self.setStatus(places.isEmpty ? "没有找到匹配地点，请换一个关键词。" : "请在搜索结果中点击一个包含详细地址的地点。", error: places.isEmpty)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.setStatus("地点检索失败：\(error.localizedDescription)", error: true)
            }
            if self.searchingStopID == stopID { self.searchingStopID = nil }
        }
    }

    func confirmSearch(for stopID: UUID) {
        guard let stop = routeStops.first(where: { $0.id == stopID }) else { return }
        if let first = stop.suggestions.first {
            select(first, for: stopID)
            return
        }
        searchPlaces(stop.query, for: stopID, selectFirstResult: true)
    }

    func select(_ place: Place, for stopID: UUID) {
        guard let index = routeStops.firstIndex(where: { $0.id == stopID }) else { return }
        rememberRecent(place)
        routeStops[index].place = place
        routeStops[index].selectedQuery = place.displayName
        routeStops[index].query = place.displayName
        routeStops[index].suggestions = []
        synchronizeLegacyEndpoints()
        invalidateRoute()
        setStatus("已选择\(stopTitle(at: index))：\(place.fullAddress)", error: false)
    }

    private func stopID(for field: SearchField) -> UUID? {
        switch field {
        case .start: routeStops.first?.id
        case .end: routeStops.last?.id
        }
    }

    private func synchronizeLegacyEndpoints() {
        guard let start = routeStops.first, let end = routeStops.last else { return }
        startQuery = start.query
        endQuery = end.query
        startPlace = start.place
        endPlace = end.place
        startSuggestions = start.suggestions
        endSuggestions = end.suggestions
        selectedStartQuery = start.selectedQuery
        selectedEndQuery = end.selectedQuery
    }

    private func dismissSuggestions(except stopID: UUID? = nil) {
        for index in routeStops.indices where routeStops[index].id != stopID {
            routeStops[index].suggestions = []
        }
    }

    private func invalidateRoute() {
        routePlan = nil
        routeDepartureTime = nil
        routeOptions = []
        selectedRouteIndex = 0
    }

    var selectedPlaces: [Place] {
        routeStops.compactMap(\.place)
    }

    var waypointPlaces: [Place] {
        guard routeStops.count > 2 else { return [] }
        return routeStops.dropFirst().dropLast().compactMap(\.place)
    }

    var activeSuggestionStop: RouteStop? {
        routeStops.first(where: { !$0.suggestions.isEmpty })
    }

    var canPlan: Bool {
        !apiKey.isEmpty && routeStops.count >= 2 && routeStops.allSatisfy { $0.place != nil }
    }

    var exportDepartureTime: Date {
        routeDepartureTime ?? departureTime
    }

    var gpxData: Data? {
        guard let routePlan, let startPlace, let endPlace else { return nil }
        return GPXWriter.makeData(
            plan: routePlan,
            departure: exportDepartureTime,
            startName: startPlace.displayName,
            endName: endPlace.displayName
        )
    }

    var suggestedFilename: String {
        guard let startPlace, let endPlace else { return "route.gpx" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return "\(safeFilename(startPlace.name))_\(safeFilename(endPlace.name))_\(formatter.string(from: exportDepartureTime)).gpx"
    }

    func saveCredentials(apiKey: String, securityKey: String) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.securityKey = securityKey.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainStore.save(value: self.apiKey, for: "amap.webServiceKey")
        KeychainStore.save(value: self.securityKey, for: "amap.securityKey")
        setStatus(self.apiKey.isEmpty ? "尚未配置 API Key。" : "高德设置已保存。", error: self.apiKey.isEmpty)
    }

    func showRecent(for field: SearchField) {
        guard let stopID = stopID(for: field) else { return }
        showRecent(for: stopID)
    }

    func swapStartEnd() {
        guard routeStops.count >= 2 else { return }
        routeStops.swapAt(0, routeStops.count - 1)
        synchronizeLegacyEndpoints()
        invalidateRoute()
        setStatus("已交换起点和终点。", error: false)
    }

    func selectMapCoordinate(_ coordinate: Coordinate, for field: SearchField) {
        let latitude = String(format: "%.6f", coordinate.latitude)
        let longitude = String(format: "%.6f", coordinate.longitude)
        let place = Place(
            id: "map-\(latitude)-\(longitude)",
            name: "地图选点",
            address: "纬度 \(latitude)，经度 \(longitude)",
            gcj02: CoordinateTransform.wgs84ToGCJ02(coordinate),
            category: "地图选点"
        )
        select(place, for: field)
    }

    func searchPlaces(_ text: String, for field: SearchField, selectFirstResult: Bool = false) {
        guard let stopID = stopID(for: field) else { return }
        searchPlaces(text, for: stopID, selectFirstResult: selectFirstResult)
    }

    func confirmSearch(for field: SearchField) {
        guard let stopID = stopID(for: field) else { return }
        let legacySuggestions = field == .start ? startSuggestions : endSuggestions
        if let first = legacySuggestions.first {
            select(first, for: stopID)
            return
        }
        confirmSearch(for: stopID)
    }

    func select(_ place: Place, for field: SearchField) {
        guard let stopID = stopID(for: field) else { return }
        select(place, for: stopID)
    }

    private func rememberRecent(_ place: Place) {
        recentPlaces.removeAll { $0.id == place.id }
        recentPlaces.insert(place, at: 0)
        if recentPlaces.count > 10 {
            recentPlaces.removeLast(recentPlaces.count - 10)
        }
        if let data = try? JSONEncoder().encode(recentPlaces) {
            UserDefaults.standard.set(data, forKey: recentPlacesKey)
        }
    }

    func planRoute() {
        let places = routeStops.compactMap(\.place)
        guard places.count == routeStops.count, places.count >= 2 else { return }
        guard !apiKey.isEmpty else {
            setStatus("请先配置高德 Web 服务 API Key。", error: true)
            return
        }
        let mode = transportMode
        let key = apiKey
        let keySecurity = securityKey
        let plannedDepartureTime = departureTime
        let waypointCount = max(places.count - 2, 0)
        isPlanning = true
        invalidateRoute()
        setStatus("正在请求高德路线…", error: false)
        Task {
            do {
                let plans: [RoutePlan]
                if waypointCount == 0 {
                    plans = try await AMapClient.planRoutes(
                        start: places[0],
                        end: places[1],
                        mode: mode,
                        apiKey: key,
                        securityKey: keySecurity
                    )
                } else {
                    var legs: [RoutePlan] = []
                    for (start, end) in zip(places, places.dropFirst()) {
                        let leg = try await AMapClient.planRoute(
                            start: start,
                            end: end,
                            mode: mode,
                            apiKey: key,
                            securityKey: keySecurity
                        )
                        legs.append(leg)
                    }
                    plans = [RoutePlan.merging(legs)]
                }
                applyPlannedRoutes(plans, departureTime: plannedDepartureTime)
                let countText: String
                if waypointCount > 0 {
                    countText = "已按 \(waypointCount) 个途经点生成 \(waypointCount + 1) 段路线。"
                } else {
                    countText = plans.count > 1 ? "已生成 \(plans.count) 条路线建议，可在路线信息中切换。" : "路线已生成。"
                }
                setStatus("\(countText) 导出将使用生成路线时设定的出发时间。", error: false)
            } catch {
                setStatus("生成路线失败：\(error.localizedDescription)", error: true)
            }
            isPlanning = false
        }
    }

    func selectRouteOption(_ index: Int) {
        guard routeOptions.indices.contains(index) else { return }
        selectedRouteIndex = index
        routePlan = routeOptions[index]
        setStatus("已选择第 \(index + 1) 条路线建议。导出将使用生成路线时固定的出发时间。", error: false)
    }

    func applyPlannedRoutes(_ plans: [RoutePlan], departureTime: Date) {
        guard let firstPlan = plans.first else { return }
        routeOptions = plans
        selectedRouteIndex = 0
        routePlan = firstPlan
        routeDepartureTime = departureTime
    }

    func mergeGPXFolder() {
        let folderPanel = NSOpenPanel()
        folderPanel.title = "选择包含 GPX 文件的文件夹"
        folderPanel.message = "MyGPXStudio 会合并此文件夹中的所有 GPX 文件。"
        folderPanel.canChooseFiles = false
        folderPanel.canChooseDirectories = true
        folderPanel.allowsMultipleSelection = false

        folderPanel.begin { response in
            guard response == .OK, let folderURL = folderPanel.url else { return }
            self.performGPXMerge(in: folderURL)
        }
    }

    private func performGPXMerge(in folderURL: URL) {
        isMergingGPX = true
        setStatus("正在读取 GPX 文件…", error: false)

        Task { @MainActor in
            let outcome: (data: Data?, fileCount: Int, trackCount: Int, error: String?) = await Task.detached(priority: .userInitiated) {
                do {
                    let result = try GPXMerger.merge(folder: folderURL)
                    return (result.data, result.fileCount, result.trackCount, nil)
                } catch {
                    return (nil, 0, 0, error.localizedDescription)
                }
            }.value

            isMergingGPX = false
            guard let data = outcome.data else {
                setStatus("GPX 合并失败：\(outcome.error ?? "未知错误")", error: true)
                return
            }

            let savePanel = NSSavePanel()
            savePanel.title = "保存合并后的 GPX"
            savePanel.allowedContentTypes = [.gpx]
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.nameFieldStringValue = "\(safeFilename(folderURL.lastPathComponent))_合并.gpx"
            savePanel.begin { response in
                guard response == .OK, let url = savePanel.url else {
                    self.setStatus("已取消保存合并后的 GPX。", error: false)
                    return
                }
                do {
                    try data.write(to: url, options: .atomic)
                    self.setStatus("已合并 \(outcome.fileCount) 个 GPX 文件（\(outcome.trackCount) 条轨迹）。", error: false)
                } catch {
                    self.setStatus("合并后的 GPX 保存失败：\(error.localizedDescription)", error: true)
                }
            }
        }
    }

    func setStatus(_ text: String, error: Bool) {
        statusText = text
        hasError = error
    }
}

enum TransportMode: String, CaseIterable, Identifiable {
    case driving, bicycling, walking

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
    var tint: Color {
        switch self {
        case .driving: .blue
        case .bicycling: .orange
        case .walking: .mint
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
    var fullAddress: String {
        address.isEmpty || address == "[]" ? name : address
    }
    var searchIcon: String {
        if category.contains("地铁") || category.contains("公交") { return "tram.fill" }
        if category.contains("停车") || category.contains("汽车") { return "car.fill" }
        if category.contains("学校") || category.contains("教育") { return "building.columns.fill" }
        if category.contains("医院") || category.contains("医疗") { return "cross.case.fill" }
        if category.contains("商场") || category.contains("购物") { return "bag.fill" }
        return "mappin"
    }
    var searchTint: Color {
        if category.contains("地铁") || category.contains("公交") { return .blue }
        if category.contains("停车") || category.contains("汽车") { return .orange }
        if category.contains("医院") || category.contains("医疗") { return .red }
        if category.contains("学校") || category.contains("教育") { return .purple }
        return .pink
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

enum AMapClient {
    static func searchPlaces(keyword: String, apiKey: String, securityKey: String) async throws -> [Place] {
        var params: [String: String] = [
            "key": apiKey,
            "keywords": keyword,
            "city": "全国",
            "citylimit": "false",
            "output": "json",
            "offset": "10",
            "page": "1",
            "extensions": "all"
        ]
        if !securityKey.isEmpty { params["sig"] = signature(for: params, securityKey: securityKey) }
        let data = try await request("https://restapi.amap.com/v3/place/text", params: params)
        let response = try dictionary(from: data)
        guard response.string("status") == "1" else { throw AMapError.message(response.string("info") ?? "高德地点检索未成功") }
        let pois = response["pois"] as? [[String: Any]] ?? []
        return pois.compactMap { poi -> Place? in
            guard let location = poi.string("location") else { return nil }
            let parts = location.split(separator: ",")
            guard parts.count == 2, let longitude = Double(parts[0]), let latitude = Double(parts[1]) else { return nil }
            let address = poi.string("address")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return Place(
                id: poi.string("id") ?? "\(longitude),\(latitude)",
                name: poi.string("name") ?? "未命名地点",
                address: address,
                gcj02: Coordinate(latitude: latitude, longitude: longitude),
                category: poi.string("type") ?? ""
            )
        }
    }

    static func planRoutes(start: Place, end: Place, mode: TransportMode, apiKey: String, securityKey: String) async throws -> [RoutePlan] {
        var params: [String: String] = [
            "key": apiKey,
            "origin": "\(start.gcj02.longitude),\(start.gcj02.latitude)",
            "destination": "\(end.gcj02.longitude),\(end.gcj02.latitude)",
            "output": "json"
        ]
        let url: String
        switch mode {
        case .driving:
            url = "https://restapi.amap.com/v3/direction/driving"
            params["strategy"] = "11"
            params["extensions"] = "all"
        case .bicycling:
            url = "https://restapi.amap.com/v4/direction/bicycling"
            params["strategy"] = "0"
        case .walking:
            url = "https://restapi.amap.com/v3/direction/walking"
            params["strategy"] = "0"
        }
        if !securityKey.isEmpty { params["sig"] = signature(for: params, securityKey: securityKey) }

        let data = try await request(url, params: params)
        let response = try dictionary(from: data)
        let paths: [[String: Any]]
        if mode == .bicycling {
            let errorCode = response.int("errcode")
            guard errorCode == 0 else { throw AMapError.message(response.string("errmsg") ?? "高德骑行算路未成功") }
            paths = ((response["data"] as? [String: Any])?["paths"] as? [[String: Any]]) ?? []
        } else {
            guard response.string("status") == "1" else { throw AMapError.message(response.string("info") ?? "高德算路未成功") }
            paths = ((response["route"] as? [String: Any])?["paths"] as? [[String: Any]]) ?? []
        }
        guard !paths.isEmpty else { throw AMapError.message("未返回可用路线") }

        let plans = paths.compactMap { path -> RoutePlan? in
            let steps = path["steps"] as? [[String: Any]] ?? []
            var points: [Coordinate] = []
            for step in steps {
                guard let polyline = step.string("polyline") else { continue }
                for pair in polyline.split(separator: ";") {
                    let parts = pair.split(separator: ",")
                    guard parts.count == 2, let longitude = Double(parts[0]), let latitude = Double(parts[1]) else { continue }
                    let point = Coordinate(latitude: latitude, longitude: longitude)
                    if points.last != point { points.append(point) }
                }
            }
            guard points.count > 1 else { return nil }
            let wgs84 = points.map { CoordinateTransform.gcj02ToWGS84($0) }
            return RoutePlan(
                mode: mode,
                gcj02Points: points,
                wgs84Points: wgs84,
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

    private static func request(_ endpoint: String, params: [String: String]) async throws -> Data {
        guard var components = URLComponents(string: endpoint) else { throw AMapError.message("无效的高德服务地址") }
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw AMapError.message("无法创建高德请求") }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw AMapError.message("高德服务网络请求失败") }
        return data
    }

    private static func dictionary(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AMapError.message("无法解析高德服务返回的数据") }
        return object
    }

    private static func signature(for params: [String: String], securityKey: String) -> String {
        let content = securityKey + params.sorted { $0.key < $1.key }.map { "\($0.key)\($0.value)" }.joined()
        return Insecure.MD5.hash(data: Data(content.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }
}

enum AMapError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): message }
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

    static func wgs84ToGCJ02(_ point: Coordinate) -> Coordinate {
        guard !isOutsideMainlandChina(point) else { return point }
        let delta = transformDelta(latitude: point.latitude, longitude: point.longitude)
        return Coordinate(latitude: point.latitude + delta.latitude, longitude: point.longitude + delta.longitude)
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
            pointsXML += "    <trkpt lat=\"\(latitude)\" lon=\"\(longitude)\"><time>\(timestamp)</time></trkpt>\n"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="MyGPXStudio macOS" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
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
        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2) + cos(start.latitude * .pi / 180) * cos(end.latitude * .pi / 180) * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

enum GPXExportDestination {
    static func folderName(for departure: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: departure)
    }

    /// 默认将路线 GPX 保存到“下载/GPX Output/出发日期”文件夹。
    static func defaultFolderURL(for departure: Date, fileManager: FileManager = .default) throws -> URL {
        guard let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "找不到下载文件夹。"])
        }
        let outputURL = downloadsURL.appendingPathComponent("GPX Output", isDirectory: true)
        return try departureFolderURL(in: outputURL, departure: departure, fileManager: fileManager)
    }

    static func departureFolderURL(in parentDirectory: URL, departure: Date, fileManager: FileManager = .default) throws -> URL {
        let folderURL = parentDirectory.appendingPathComponent(folderName(for: departure), isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }

    /// 在用户选择的父目录中创建或复用出发日期文件夹，并为重复文件名追加序号。
    static func destinationURL(in parentDirectory: URL, departure: Date, filename: String, fileManager: FileManager = .default) throws -> URL {
        let folderURL = try departureFolderURL(in: parentDirectory, departure: departure, fileManager: fileManager)
        return try destinationFileURL(in: folderURL, filename: filename, fileManager: fileManager)
    }

    /// 在已经确定的出发日期文件夹中选择不覆盖已有文件的文件名。
    static func destinationFileURL(in folderURL: URL, filename: String, fileManager: FileManager = .default) throws -> URL {
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let initialURL = folderURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: initialURL.path) else { return initialURL }

        let fileExtension = initialURL.pathExtension
        let baseName = initialURL.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let alternateName = fileExtension.isEmpty
                ? "\(baseName)-\(index)"
                : "\(baseName)-\(index).\(fileExtension)"
            let alternateURL = folderURL.appendingPathComponent(alternateName)
            if !fileManager.fileExists(atPath: alternateURL.path) {
                return alternateURL
            }
            index += 1
        }
    }
}

enum GPXMergeError: LocalizedError {
    case noFiles
    case noGPXContent
    case invalidFile(String)

    var errorDescription: String? {
        switch self {
        case .noFiles:
            return "所选文件夹中没有 GPX 文件。"
        case .noGPXContent:
            return "GPX 文件中没有可合并的轨迹、路线或航点。"
        case .invalidFile(let name):
            return "无法读取 GPX 文件：\(name)"
        }
    }
}

enum GPXMerger {
    struct Result {
        let data: Data
        let fileCount: Int
        let trackCount: Int
    }

    static func merge(folder: URL) throws -> Result {
        let files = try FileManager.default
            .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { $0.pathExtension.lowercased() == "gpx" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return try merge(files: files)
    }

    static func merge(files: [URL]) throws -> Result {
        guard !files.isEmpty else { throw GPXMergeError.noFiles }

        var content: [String] = []
        var trackCount = 0
        for file in files {
            do {
                let document = try XMLDocument(data: Data(contentsOf: file), options: [])
                let nodes = try document.nodes(forXPath: "/*[local-name()='gpx']/*[local-name()='trk' or local-name()='rte' or local-name()='wpt']")
                for node in nodes {
                    content.append(node.xmlString)
                    if node.localName == "trk" || node.name == "trk" {
                        trackCount += 1
                    }
                }
            } catch {
                throw GPXMergeError.invalidFile(file.lastPathComponent)
            }
        }

        guard !content.isEmpty else { throw GPXMergeError.noGPXContent }
        let folderName = files.first?.deletingLastPathComponent().lastPathComponent ?? "文件夹"
        let title = "\(folderName) 合并 GPX"
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="MyGPXStudio macOS" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(title.xmlEscaped)</name>
            <desc>由 MyGPXStudio 合并 \(files.count) 个 GPX 文件。</desc>
          </metadata>
        \(content.joined(separator: "\n"))
        </gpx>
        """
        guard let data = xml.data(using: .utf8) else { throw GPXMergeError.noGPXContent }
        return Result(data: data, fileCount: files.count, trackCount: trackCount)
    }
}

extension UTType {
    static let gpx = UTType(exportedAs: "com.topografix.gpx", conformingTo: .xml)
}

enum KeychainStore {
    private static let service = "com.zongyue.RouteToGPX"

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
    text.replacingOccurrences(of: "[\\/:*?\"<>|]", with: "", options: .regularExpression)
}

```

### 6.2 `Tests/RouteToGPXTests/RouteToGPXTests.swift`

```swift
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

```


### 6.3 `Package.swift`

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RouteToGPX",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RouteToGPX", targets: ["RouteToGPX"])
    ],
    targets: [
        .executableTarget(name: "RouteToGPX"),
        .testTarget(name: "RouteToGPXTests", dependencies: ["RouteToGPX"])
    ]
)

```


### 6.4 `Resources/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>RouteToGPX</string>
    <key>CFBundleIdentifier</key>
    <string>com.zongyue.mygpxstudio</string>
    <key>CFBundleName</key>
    <string>MyGPXStudio</string>
    <key>CFBundleDisplayName</key>
    <string>MyGPXStudio</string>
    <key>CFBundleIconFile</key>
    <string>MyGPXStudio.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>MyGPXStudio 使用当前位置帮助你快速定位地图。</string>
</dict>
</plist>

```


### 6.5 `build_macos.sh`

```bash
#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
app_dir="$project_dir/dist/MyGPXStudio.app"
binary_dir="$project_dir/.build/release"

cd "$project_dir"
swift build -c release

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/RouteToGPX" "$app_dir/Contents/MacOS/RouteToGPX"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/MyGPXStudio.icns" "$app_dir/Contents/Resources/MyGPXStudio.icns"

codesign --force --deep --sign - "$app_dir"
echo "已生成：$app_dir"

```
