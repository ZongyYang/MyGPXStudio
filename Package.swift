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
