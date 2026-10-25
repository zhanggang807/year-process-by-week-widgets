import YearProgressUI
import AppKit
import SwiftUI
import YearProgressCore
import YearProgressUI

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
        hasShadow = false            // 不要系统窗口阴影
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
        YearProgressCardView(progress: state.progress,
                            theme: state.theme,
                            size: state.cardSize,
                            fixedColumns: WidgetGridReference.columns(weekCount: state.progress.totalWeeks))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}


/// 菜单栏弹窗：顶部带圆角小三角气泡尾巴的卡片
struct QuickPopoverView: View {
    let progress: YearProgress
    let theme: CardTheme
    let cardSize: CGSize
    let arrowHeight: CGFloat
    let cornerRadius: CGFloat
    /// 尾巴尖在窗口内的 x（正常居中；被屏幕边缘夹住时会偏移，仍指向图标）
    let tailCenterX: CGFloat

    var body: some View {
        let total = CGSize(width: cardSize.width, height: cardSize.height + arrowHeight)
        let shape = PopoverShape(cornerRadius: cornerRadius,
                                 arrowHeight: arrowHeight,
                                 arrowHalfWidth: 14,
                                 arrowCenterX: tailCenterX)
        return ZStack(alignment: .top) {
            shape.fill(LinearGradient(colors: theme.backgroundColors,
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing))
            YearProgressCardView(progress: progress,
                                 theme: theme,
                                 size: cardSize,
                                 chrome: .widget,
                                 showsTooltips: false,
                                 drawsBackground: false)
                .frame(width: cardSize.width, height: cardSize.height)
                .offset(y: arrowHeight)
        }
        .frame(width: total.width, height: total.height)
        .clipShape(shape)
    }
}
