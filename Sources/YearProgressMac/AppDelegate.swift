import YearProgressUI
import AppKit
import SwiftUI
import YearProgressCore

enum PanelLevel: String, CaseIterable {
    case normal, floating, desktop

    var displayName: String {
        switch self {
        case .normal: return "普通（会被其他窗口盖住）"
        case .floating: return "置顶显示（总在最前）"
        case .desktop: return "贴到桌面（在窗口下方）"
        }
    }

    var nsLevel: NSWindow.Level {
        switch self {
        case .normal: return .normal
        case .floating: return .floating
        case .desktop: return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 与系统桌面小组件对齐（实测 2x 截图：距右 30–34px、距菜单栏底边 37px）
    /// → 16pt / 18pt
    private static let cardMarginRight: CGFloat = 16
    private static let cardMarginTop: CGFloat = 18
    private static let levelKey = AppDefaults.Key.panelLevel
    private static let panelVisibleKey = AppDefaults.Key.panelVisible
    private static let didWelcomeKey = AppDefaults.Key.didShowWelcome

    private let cli: CLIOptions
    private var state: AppState!
    private var panel: WidgetPanel!
    private var statusItem: NSStatusItem!
    /// 右键弹出的设置菜单（左键不弹菜单，用来显示桌面挂件）
    private let statusMenu = NSMenu()

    private var level: PanelLevel {
        get { PanelLevel(rawValue: AppDefaults.store.string(forKey: Self.levelKey) ?? "") ?? .desktop }
        set { AppDefaults.store.set(newValue.rawValue, forKey: Self.levelKey) }
    }

    private let welcome = WelcomeWindowController()

    /// 桌面浮窗是可选项：默认关闭，使用说明才是主入口。
    private var isVisible: Bool {
        get { AppDefaults.store.bool(forKey: Self.panelVisibleKey) }
        set { AppDefaults.store.set(newValue, forKey: Self.panelVisibleKey) }
    }

    init(cli: CLIOptions) {
        self.cli = cli
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = NSImage(named: "AppIcon") { NSApp.applicationIconImage = icon }
        state = AppState(dateOverride: cli.date)
        // 只有命令行显式传了 --theme/--size 才覆盖，否则沿用（或迁移后的）默认设置
        if let theme = cli.themeOverride { state.theme = theme }
        if let size = cli.sizeOverride { state.cardSize = size }

        setUpStatusItem()
        setUpPanel()

        if !AppDefaults.store.bool(forKey: Self.didWelcomeKey) {
            AppDefaults.store.set(true, forKey: Self.didWelcomeKey)
            welcome.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: 面板

    private func setUpPanel() {
        panel = WidgetPanel(size: state.cardSize)
        panel.level = level.nsLevel
        panel.contentView = NSHostingView(rootView: PanelRootView(state: state))
        anchorTopRight()
        if isVisible { panel.orderFrontRegardless() }

        // 换屏幕 / 改分辨率后也要回到右上角
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screenParametersChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    /// 永远贴住主屏可视区域的右上角（窗口与卡片等大）。
    private func anchorTopRight() {
        guard let screen = NSScreen.screens.first ?? NSScreen.main else { return }
        let f = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: f.maxX - size.width - Self.cardMarginRight,
                                     y: f.maxY - size.height - Self.cardMarginTop))
    }

    @objc private func screenParametersChanged() {
        anchorTopRight()
    }

    private func applyCardSize(_ size: CGSize) {
        state.cardSize = size
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true, animate: false)
        anchorTopRight()        // 改尺寸后重新贴回右上角，而不是按旧坐标漂移
    }

    // MARK: 菜单栏

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = Self.makeStatusIcon()
        button.imagePosition = .imageOnly
        button.toolTip = "左键显示桌面挂件 · 右键设置"

        // 不用 statusItem.menu：那会让左右键都弹菜单。
        // 自己处理点击，左键显示挂件，右键临时挂上菜单再弹。
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusMenu.delegate = self
        rebuildMenu()
    }

    // MARK: 菜单栏点击

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        let isRightClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isRightClick {
            showSettingsMenu()
        } else {
            showPanelFromMenuBar()
        }
    }

    private func showSettingsMenu() {
        rebuildMenu()
        // 临时把菜单挂到 status item 上，performClick 会按系统样式弹出菜单，
        // 弹完立刻摘掉，下一次左键仍然走「显示挂件」。
        statusItem.menu = statusMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// 左键：显示桌面挂件（贴右上角、当前主题/尺寸；默认小尺寸 + 石墨）
    private func showPanelFromMenuBar() {
        isVisible = true
        anchorTopRight()
        panel.orderFrontRegardless()
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = statusMenu
        menu.removeAllItems()

        let progress = state.progress
        let title = NSMenuItem(title: "\(progress.yearTitle) \(progress.ganzhi.yearName) · \(progress.footerText)",
                               action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let guide = NSMenuItem(title: "添加系统小组件…", action: #selector(showWelcome), keyEquivalent: "?")
        guide.target = self
        menu.addItem(guide)

        let toggle = NSMenuItem(title: isVisible ? "关闭桌面挂件" : "打开桌面挂件",
                                action: #selector(togglePanel), keyEquivalent: "h")
        toggle.target = self
        menu.addItem(toggle)

        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(.separator())

        let levelHeader = NSMenuItem(title: "窗口层级", action: nil, keyEquivalent: "")
        levelHeader.isEnabled = false
        menu.addItem(levelHeader)
        for l in PanelLevel.allCases {
            let item = NSMenuItem(title: l.displayName, action: #selector(changeLevel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = l.rawValue
            item.state = (l == level) ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let themeHeader = NSMenuItem(title: "主题", action: nil, keyEquivalent: "")
        themeHeader.isEnabled = false
        menu.addItem(themeHeader)
        for t in CardTheme.allCases {
            let item = NSMenuItem(title: t.displayName, action: #selector(changeTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = t.rawValue
            item.state = (t == state.theme) ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }

        let sizeHeader = NSMenuItem(title: "尺寸", action: nil, keyEquivalent: "")
        sizeHeader.isEnabled = false
        menu.addItem(sizeHeader)
        for preset in AppState.sizePresets {
            let item = NSMenuItem(title: preset.name, action: #selector(changeSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSStringFromSize(preset.size)
            item.state = (preset.size == state.cardSize) ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func showWelcome() {
        welcome.show()
    }

    @objc private func togglePanel() {
        isVisible.toggle()
        if isVisible {
            anchorTopRight()    // 每次打开都重新贴右上角
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
        rebuildMenu()
    }

    @objc private func refresh() {
        state.refresh()
        rebuildMenu()
    }

    @objc private func changeLevel(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let l = PanelLevel(rawValue: raw) else { return }
        level = l
        panel.level = l.nsLevel
        rebuildMenu()
    }

    @objc private func changeTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let t = CardTheme(rawValue: raw) else { return }
        state.theme = t
        rebuildMenu()
    }

    @objc private func changeSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        applyCardSize(NSSizeFromString(raw))
        rebuildMenu()
    }

    /// 菜单栏小图标：4×4 迷你方块，已过部分更实。
    private static func makeStatusIcon() -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let cols = 4, rows = 4
        let block: CGFloat = 2.9, gap: CGFloat = 1.35
        let total = CGFloat(cols) * block + CGFloat(cols - 1) * gap
        let origin = (side - total) / 2
        let filled = 11
        for index in 0..<(cols * rows) {
            let c = index % cols, r = index / cols
            let rect = NSRect(x: origin + CGFloat(c) * (block + gap),
                              y: origin + CGFloat(rows - 1 - r) * (block + gap),
                              width: block, height: block)
            let path = NSBezierPath(roundedRect: rect, xRadius: 0.7, yRadius: 0.7)
            NSColor.black.withAlphaComponent(index < filled ? 1.0 : 0.32).setFill()
            path.fill()
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu() }
}
