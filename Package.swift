// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YearProgress",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "YearProgressCore", targets: ["YearProgressCore"]),
        .executable(name: "YearProgressMac", targets: ["YearProgressMac"]),
        .executable(name: "year-weeks-dump", targets: ["YearWeekSpecDump"]),
    ],
    targets: [
        .target(name: "YearProgressCore"),
        .executableTarget(name: "YearProgressMac", dependencies: ["YearProgressCore"]),
        .executableTarget(name: "YearWeekSpecDump", dependencies: ["YearProgressCore"]),
        .testTarget(name: "YearProgressCoreTests", dependencies: ["YearProgressCore"]),
    ],
    swiftLanguageModes: [.v5]
)
