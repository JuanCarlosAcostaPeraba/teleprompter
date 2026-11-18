// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Teleprompter",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ScriptTracking"),
        .executableTarget(name: "Teleprompter", dependencies: ["ScriptTracking"]),
        .testTarget(name: "ScriptTrackingTests", dependencies: ["ScriptTracking"])
    ],
    swiftLanguageModes: [.v5]
)
