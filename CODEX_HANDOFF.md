# MyGPXStudio Codex Handoff

Last updated: 2026-09-10

## Current status

- Native SwiftUI + MapKit macOS application targeting macOS 14 or later.
- Supports driving, cycling and walking route planning. AMap remains the domestic provider; Apple MapKit search and directions are used as the overseas fallback.
- Apple MapKit results are tagged as WGS-84 so they are not incorrectly passed through GCJ-02 conversion; a route containing any Apple result uses MapKit for all legs.
- Supports ordered start, waypoint and destination rows; confirmed waypoints appear as blue map markers.
- When the Generate Route button is disabled, the planner shows the exact blocking reason below it, including the missing stop number or missing API configuration.
- If start and destination are the same, a waypoint is required so the app can plan a meaningful loop back to the start; with waypoints, each leg is planned in order.
- Route alternatives are displayed vertically in a route information card.
- Departure date accepts `yyyy-MM-dd` keyboard input or graphical calendar selection; time uses 24-hour format.
- The departure time is frozen when route generation succeeds. GPX timestamps, filenames and date folders use that generated-route time rather than the system clock.
- GPX export uses the departure time frozen when the route was generated. The save panel defaults to `~/Downloads/GPX Output/yyyy-MM-dd`, creates or reuses that folder, and avoids overwriting duplicate filenames. Choosing another location remains supported.
- Native map pan, pinch zoom, rotation and pitch are enabled; the map scale is above the right-side controls.
- The current test suite contains 13 passing XCTest cases, including overseas-provider eligibility and same-start/end validation.

## iOS target

- Project: `MyGPXStudio-iOS.xcodeproj`
- Sources: `iOS/MyGPXStudioiOS/ContentView.swift`, `RoutePlannerModel.swift`, `MyGPXStudioiOSApp.swift`
- Uses MapKit with native pan/zoom and a draggable bottom-sheet route planner.
- Supports ordered stops, AMap search/routing, GPX generation, and the native iOS share sheet.
- Bundle identifier: `com.zongyue.mygpxstudio.ios`
- The iOS Debug build was signed, installed, and launched on the connected iPhone on 2026-09-10. The Xcode metadata extraction and orientation messages are warnings only.

## Before editing

Read [MyGPXStudio-开发记录.md](MyGPXStudio-开发记录.md) for the complete feature history and source snapshot. The authoritative source is [Sources/RouteToGPX/RouteToGPXApp.swift](Sources/RouteToGPX/RouteToGPXApp.swift).

Never commit a real AMap API key or security key. Credentials are stored at runtime in the macOS Keychain.

## Verification

```bash
swift test
zsh build_macos.sh
codesign --verify --deep --strict dist/MyGPXStudio.app
```

The generated `dist/` directory is intentionally ignored by Git. Build a fresh app locally before testing or distributing a release.
