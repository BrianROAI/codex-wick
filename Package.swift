// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CodexCreditMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CodexPulseCore", targets: ["CodexPulseCore"]),
        .executable(name: "CodexWick", targets: ["CodexWick"]),
        .executable(name: "CodexPulseCoreChecks", targets: ["CodexPulseCoreChecks"])
    ],
    targets: [
        .target(name: "CodexPulseCore"),
        .executableTarget(
            name: "CodexWick",
            dependencies: ["CodexPulseCore"],
            path: "Sources/CodexPulse"
        ),
        .executableTarget(
            name: "CodexPulseCoreChecks",
            dependencies: ["CodexPulseCore"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
