import YearProgressUI
import AppKit
import SwiftUI
import os
import ServiceManagement
import WidgetKit
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
        case .desktop:
            // 关键：不要和壁纸用同一层（kCGDesktopWindowLevel）。
            // 同层会被 Finder 桌面判定为遮挡，AppKit 停止绘制 SwiftUI 内容，
            // 表现就是“关掉所有应用后只剩一块白板”。
            // 抬到桌面图标层之上、普通窗口（0）之下。
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let log = Logger(subsystem: "com.local.yearprogress", category: "statusbar")

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
    /// 左键弹出的独立小窗（不影响桌面挂件）。
    /// 复用同一个 NSPanel：每次点击只换 contentView，不重复建窗口。
    private lazy var quickPanel: NSPanel = makeQuickPanel()
    /// 点外部收起用的全局鼠标监听
    private var quickClickMonitor: Any?
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
        log.info("[app] launched \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?", privacy: .public)")
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        state = AppState(dateOverride: cli.date)
        // 只有命令行显式传了 --theme/--size 才覆盖，否则沿用（或迁移后的）默认设置
        if let theme = cli.themeOverride { state.theme = theme }
        if let size = cli.sizeOverride { state.cardSize = size }

        setUpStatusItem()
        setUpPanel()

        // 后台补全年份节假日数据（当前年 / 次年，缺失时才抓）
        HolidayUpdater.refreshIfNeeded()

        // 覆盖安装后系统小组件可能仍持有旧的归档/快照；主动请求一次重载，
        // 让桌面小组件尽快用上新版本里的背景与图标。
        WidgetCenter.shared.reloadAllTimelines()

        if cli.showQuick {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.toggleQuickPanel()
            }
        }
        if cli.testMenuClick {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                self.log.info("[status] test: attach/detach menu then click")
                self.statusItem.menu = self.statusMenu
                self.statusItem.menu = nil
                self.configureStatusButton()
                self.statusItem.button?.performClick(nil)
            }
        }
        if cli.testClick {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.log.info("[status] performClick test")
                self?.statusItem.button?.performClick(nil)
            }
        }

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

        // 应用切换 / 回到桌面时，桌面层窗口可能被判定为遮挡而不再重绘。
        // 这里主动 orderFront + 强制 display，保证内容立即出现。
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(desktopVisibilityChanged),
                                               name: NSApplication.didBecomeActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(desktopVisibilityChanged),
                                               name: NSApplication.didResignActiveNotification,
                                               object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didDeactivateApplicationNotification] {
            workspace.addObserver(self, selector: #selector(desktopVisibilityChanged),
                                  name: name, object: nil)
        }
    }

    @objc private func desktopVisibilityChanged() {
        guard isVisible else { return }
        panel.orderFrontRegardless()
        panel.contentView?.needsDisplay = true
        panel.displayIfNeeded()
    }

    /// 永远贴住主屏可视区域的右上角（窗口与卡片等大）。
    private func anchorTopRight() {
        // 看面板当前在哪个屏幕；首次创建时还没有 screen，再退回主屏
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
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
        configureStatusButton()

        statusMenu.delegate = self
        rebuildMenu()
    }

    /// 重新绑定按钮的 target/action（挂过菜单后保险起见再调一次）
    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        log.info("[status] button configured")
    }

    // MARK: 菜单栏点击

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        log.info("[status] click event=\(event.map { String($0.type.rawValue) } ?? "nil", privacy: .public) right=\(isRightClick ? "yes" : "no", privacy: .public)")
        if isRightClick {
            showSettingsMenu()
        } else {
            toggleQuickPanel()
        }
    }

    private func showSettingsMenu() {
        rebuildMenu()
        guard statusItem.button != nil else { return }
        // 交给系统定位（原生状态栏菜单位置：图标正下方、自动贴边）。
        // 临时挂上菜单 → performClick 弹出 → 立刻摘掉；随后重新绑定按钮 action，
        // 避免"挂过菜单后左键失效"的问题。
        log.info("[status] settings menu popup")
        statusItem.menu = statusMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
        configureStatusButton()
    }

    /// 左键：在菜单栏图标下方弹一个独立小窗，展示当前进度。
    /// 不碰桌面挂件的显隐和层级。位置会按屏幕可视区域夹边，避免出屏。
    private func makeQuickPanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        // NSPanel 默认 hidesOnDeactivate = true：点菜单栏不会激活 App，
        // 不关掉这个开关，窗口会在屏幕上立刻被系统藏起来。
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func toggleQuickPanel() {
        if quickPanel.isVisible {
            hideQuickPanel(reason: "toggle")
            return
        }
        log.info("[quick] show")

        let cardSize = AppState.defaultSize      // 338×158
        let windowSize = CGSize(width: cardSize.width,
                                height: cardSize.height + QuickPopoverMetrics.arrowHeight)
        guard let anchor = quickAnchor() else { return }
        let placement = QuickPopoverPlacement.compute(anchor: anchor.rect,
                                                      visibleFrame: anchor.screen.visibleFrame,
                                                      windowSize: windowSize)

        let popover = QuickPopoverView(progress: state.progress,
                                       theme: state.theme,           // 默认石墨
                                       cardSize: cardSize,
                                       tailCenterX: placement.tailX)
        quickPanel.contentView = NSHostingView(rootView: popover)
        quickPanel.setFrame(placement.frame, display: false)

        // 不要 makeKey：菜单栏点击不会激活 App，成为 key 会被立刻收回（窗口一闪就没）。
        quickPanel.orderFrontRegardless()

        // 点其它 App / 桌面时收起。鼠标事件的全局监听不需要辅助功能权限。
        quickClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hideQuickPanel(reason: "outside click")
        }
    }

    /// 状态栏按钮的屏幕坐标 + 所在屏幕（多屏时不要盲目用主屏）
    private func quickAnchor() -> (rect: CGRect, screen: NSScreen)? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return nil }
        return (rect, screen)
    }

    private func hideQuickPanel(reason: String) {
        log.info("[quick] hide reason=\(reason, privacy: .public)")
        if let m = quickClickMonitor {
            NSEvent.removeMonitor(m)
            quickClickMonitor = nil
        }
        quickPanel.orderOut(nil)
    }

    private func rebuildMenu() {
        let menu = statusMenu
        menu.removeAllItems()

        let guide = NSMenuItem(title: "添加系统小组件…", action: #selector(showWelcome), keyEquivalent: "?")
        guide.target = self
        menu.addItem(guide)

        let toggle = NSMenuItem(title: isVisible ? "关闭桌面挂件" : "打开桌面挂件",
                                action: #selector(togglePanel), keyEquivalent: "h")
        toggle.target = self
        menu.addItem(toggle)

        let login = NSMenuItem(title: launchAtLoginTitle,
                               action: #selector(toggleLaunchAtLogin),
                               keyEquivalent: "")
        login.target = self
        login.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(login)

        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let holidays = NSMenuItem(title: "更新节假日数据", action: #selector(updateHolidays), keyEquivalent: "")
        holidays.target = self
        menu.addItem(holidays)

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

    @objc private func updateHolidays() {
        HolidayUpdater.refreshIfNeeded(force: true)
        rebuildMenu()
    }

    /// 现代 macOS 推荐用 SMAppService 管理登录项：它会出现在
    /// 「系统设置 → 通用 → 登录项」里，用户仍可在系统层面禁用。
    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private var launchAtLoginTitle: String {
        SMAppService.mainApp.status == .requiresApproval
            ? "开机启动（需在系统设置允许）"
            : "开机启动"
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        switch service.status {
        case .enabled:
            do {
                try service.unregister()
            } catch {
                log.error("[login] \(error.localizedDescription, privacy: .private)")
                showLoginItemError(error)
            }
        case .requiresApproval:
            // 已经登记，但需要用户在系统设置里放行；再 register 不会有帮助。
            openLoginItemsSettings()
        case .notFound:
            showLoginItemMessage("请先把 App 安装到 /Applications，再开启开机启动。")
        default:
            do {
                try service.register()
                if service.status == .requiresApproval {
                    openLoginItemsSettings()
                }
            } catch {
                log.error("[login] \(error.localizedDescription, privacy: .private)")
                showLoginItemError(error)
            }
        }
        rebuildMenu()
    }

    private func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func showLoginItemError(_ error: Error) {
        showLoginItemMessage("""
        \(error.localizedDescription)

        请确认 App 已安装到 /Applications。
        """)
    }

    private func showLoginItemMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "无法设置开机启动"
        alert.informativeText = message + "\n\n可以到「系统设置 → 通用 → 登录项」手动检查。"
        alert.addButton(withTitle: "好")
        alert.runModal()
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

