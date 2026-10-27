import AppKit
import ServiceManagement

// 年进度小组件（macOS）
//   YearProgressMac                                  启动桌面小组件
//   YearProgressMac --snapshot preview.png           离屏渲染 PNG
//   YearProgressMac --help                           查看参数
//
// main.swift 的顶层代码由主线程执行，这里显式声明主 actor 隔离。

let options = CLIOptions.parse(CommandLine.arguments)

MainActor.assumeIsolated {
    if let action = options.loginItemAction {
        let service = SMAppService.mainApp
        do {
            switch action {
            case .status:
                break
            case .register:
                try service.register()
            case .unregister:
                try service.unregister()
            }
            print("loginItem status=\(service.status.rawValue)")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("loginItem error=\(error)\n".utf8))
            exit(1)
        }
    }
    if let path = options.snapshotPath {
        SnapshotRunner.run(options: options, outputPath: path)
    } else {
        let app = NSApplication.shared
        let delegate = AppDelegate(cli: options)
        app.delegate = delegate
        app.setActivationPolicy(.accessory)      // 不占 Dock 图标
        app.run()
    }
}
