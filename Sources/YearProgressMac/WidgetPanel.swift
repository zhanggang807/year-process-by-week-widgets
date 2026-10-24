import YearProgressUI
import AppKit
import SwiftUI

/// 无边框、无标题栏、点它不抢焦点的「桌面小组件」窗口。
final class WidgetPanel: NSPanel {
    init(size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false            // 阴影由 SwiftUI 侧绘制，跟圆角一致
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none
    }

    /// 不抢键盘焦点：像桌面挂件而不是窗口。
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 面板里承载的 SwiftUI 根视图：观察 AppState，状态一变就重绘。
struct PanelRootView: View {
    @ObservedObject var state: AppState

    var body: some View {
        YearProgressCardView(progress: state.progress, theme: state.theme, size: state.cardSize)
            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)  // 卡片居中，四周留给阴影
    }
}
