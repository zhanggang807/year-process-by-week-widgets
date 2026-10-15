import YearProgressUI
import AppKit
import SwiftUI

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

    /// 窗口比卡片大一圈，好让 SwiftUI 画的阴影不被裁掉。
    private static let shadowInset: CGFloat = 22
    private static let levelKey = "panelLevel"
    private static let frameKey = "panelFrame"
    private static let panelVisibleKey = "panelVisible"
    private static let didWelcomeKey = "didShowWelcome"

    private let cli: CLIOptions
    private var state: AppState!
    private var panel: WidgetPanel!
    private var statusItem: NSStatusItem!

    private var level: PanelLevel {
        get { PanelLevel(rawValue: UserDefaults.standard.string(forKey: Self.levelKey) ?? "") ?? .desktop }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.levelKey) }
    }

    private let welcome = WelcomeWindowController()

    /// 桌面浮窗是可选项：默认关闭，使用说明才是主入口。
    private var isVisible: Bool {
        get { UserDefaults.standard.bool(forKey: Self.panelVisibleKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.panelVisibleKey) }
    }

    init(cli: CLIOptions) {
        self.cli = cli
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = AppState(dateOverride: cli.date)
        state.theme = cli.theme
        state.cardSize = cli.size

        setUpStatusItem()
        setUpPanel()

        if !UserDefaults.standard.bool(forKey: Self.didWelcomeKey) {
            UserDefaults.standard.set(true, forKey: Self.didWelcomeKey)
            welcome.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: 面板

    private func setUpPanel() {
        panel = WidgetPanel(size: windowSize(for: state.cardSize))
        panel.level = level.nsLevel
        panel.contentView = NSHostingView(rootView: PanelRootView(state: state))
        panel.setFrameOrigin(restoredOrigin() ?? defaultOrigin())
        if isVisible { panel.orderFrontRegardless() }
        panel.delegate = self
    }

    private func windowSize(for card: CGSize) -> CGSize {
        CGSize(width: card.width + Self.shadowInset * 2, height: card.height + Self.shadowInset * 2)
    }

    private func defaultOrigin() -> CGPoint {
        guard let screen = NSScreen.main else { return .zero }
        let f = screen.visibleFrame
        let size = panel.frame.size
        return CGPoint(x: f.maxX - size.width - 24, y: f.maxY - size.height - 24)
    }

    private func restoredOrigin() -> CGPoint? {
        guard let s = UserDefaults.standard.string(forKey: Self.frameKey) else { return nil }
        let origin = NSPointFromString(s)
        guard origin.x.isFinite, origin.y.isFinite else { return nil }
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(CGRect(origin: origin, size: panel.frame.size)) }
        return onScreen ? origin : nil
    }

    private func applyCardSize(_ size: CGSize) {
        state.cardSize = size
        let window = windowSize(for: size)
        var frame = panel.frame
        frame.origin.y += frame.height - window.height     // 保持顶部不动
        frame.size = window
        panel.setFrame(frame, display: true, animate: false)
    }

    // MARK: 菜单栏

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.makeStatusIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "年进度小组件"

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
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
        if isVisible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
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

extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        UserDefaults.standard.set(NSStringFromPoint(window.frame.origin), forKey: Self.frameKey)
    }
}
