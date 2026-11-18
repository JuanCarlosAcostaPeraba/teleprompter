// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Teleprompter",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ScriptTracking"),
        .executableTarget(name: "Teleprompter", dependencies: ["ScriptTracking"], resources: [.process("Resources")]),
        .testTarget(name: "ScriptTrackingTests", dependencies: ["ScriptTracking"])
    ],
    swiftLanguageModes: [.v5]
)
