// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YearProgress",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "YearProgressCore", targets: ["YearProgressCore"]),
        .library(name: "YearProgressUI", targets: ["YearProgressUI"]),
        .executable(name: "YearProgressMac", targets: ["YearProgressMac"]),
        .executable(name: "YearProgressWidget", targets: ["YearProgressWidget"]),
        .executable(name: "year-weeks-dump", targets: ["YearWeekSpecDump"]),
    ],
    targets: [
        .target(name: "YearProgressCore"),
        .target(name: "YearProgressUI", dependencies: ["YearProgressCore"]),
        .executableTarget(name: "YearProgressMac", dependencies: ["YearProgressCore", "YearProgressUI"]),
        .executableTarget(name: "YearProgressWidget", dependencies: ["YearProgressCore", "YearProgressUI"]),
        .executableTarget(name: "YearWeekSpecDump", dependencies: ["YearProgressCore"]),
        .testTarget(name: "YearProgressCoreTests", dependencies: ["YearProgressCore"]),
    ],
    swiftLanguageModes: [.v5]
)
