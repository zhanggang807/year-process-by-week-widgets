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
        .executableTarget(
            name: "YearProgressWidget",
            dependencies: ["YearProgressCore", "YearProgressUI"],
            linkerSettings: [
                // App Extension 的入口必须是扩展运行时（Xcode 里是 LD_ENTRY_POINT = _NSExtensionMain）。
                // 少了它，WidgetKit 会在 ExtensionFoundation 初始化时 SIGTRAP，小组件库就看不到我们。
                .linkedFramework("Foundation"),
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"]),
            ]
        ),
        .executableTarget(name: "YearWeekSpecDump", dependencies: ["YearProgressCore"]),
        .testTarget(name: "YearProgressCoreTests", dependencies: ["YearProgressCore", "YearProgressUI"]),
    ],
    swiftLanguageModes: [.v5]
)
