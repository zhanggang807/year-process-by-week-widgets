import AppKit
import SwiftUI
import YearProgressUI

/// 宿主 App 的说明窗口：告诉用户去哪儿添加系统小组件。
struct WelcomeView: View {
    var onClose: () -> Void

    private let steps: [(String, String)] = [
        ("1", "点击菜单栏最右侧的「日期与时间」"),
        ("2", "在展开的通知中心底部点「编辑小组件…」"),
        ("3", "搜索「年进度」→ 选尺寸 → 添加"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("年进度小组件")
                        .font(.system(size: 20, weight: .semibold))
                    Text("在通知中心 / 桌面小组件库里添加")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressRing(percent: 78, size: 34, theme: .violet)
            }
            .padding(.bottom, 18)

            ForEach(steps, id: \.0) { step in
                HStack(alignment: .top, spacing: 10) {
                    Text(step.0)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.accentColor))
                    Text(step.1)
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.bottom, 10)
            }

            Divider().padding(.vertical, 4)

            Text("另外：菜单栏图标里可以打开「桌面挂件」（贴桌面的浮窗版，可选），以及切换主题、尺寸和立即刷新。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("好", action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 460, height: 330)
    }
}

@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 460, height: 330),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "年进度"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeView { [weak self] in
            self?.window?.close()
        })
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
