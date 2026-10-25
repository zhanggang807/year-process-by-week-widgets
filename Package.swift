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
        // 注意：Widget 的入口点（_NSExtensionMain）在 Makefile 的 widget 目标里用
        // `-Xlinker -e` 传入，而不是放在这里：unsafeFlags 会让整个包无法作为依赖被复用。
        .executableTarget(name: "YearProgressWidget", dependencies: ["YearProgressCore", "YearProgressUI"]),
        .executableTarget(name: "YearWeekSpecDump", dependencies: ["YearProgressCore"]),
        .testTarget(name: "YearProgressCoreTests", dependencies: ["YearProgressCore", "YearProgressUI"]),
    ],
    swiftLanguageModes: [.v5]
)
