import CoreGraphics

/// 气泡弹窗的定位算法（纯函数，便于测试）。
///
/// 规则：
/// - 水平居中于状态栏图标
/// - 垂直贴在图标下方（gap），但不越过菜单栏/屏幕
/// - 被屏幕边缘夹住时，尾巴尖跟着图标偏移，保证仍然"指向"图标
public enum QuickPopoverPlacement {

    public struct Result: Equatable {
        public let frame: CGRect
        public let tailX: CGFloat
    }

    public static func compute(anchor: CGRect,
                               visibleFrame: CGRect,
                               windowSize: CGSize) -> Result {
        let m = QuickPopoverMetrics.self

        // 注意：下界用 max(...) 再取 min，避免窗口比屏幕还宽时 min > max 产生非法坐标
        let minX = visibleFrame.minX + m.edgeMargin
        let maxX = max(minX, visibleFrame.maxX - windowSize.width - m.edgeMargin)
        var x = anchor.midX - windowSize.width / 2
        x = min(max(x, minX), maxX)

        let minY = visibleFrame.minY + m.edgeMargin
        let maxY = max(minY, visibleFrame.maxY - windowSize.height)
        var y = anchor.minY - windowSize.height - m.gap
        y = min(max(y, minY), maxY)

        // 尾巴尖限制在圆角内侧，避免画到圆角外
        let half = m.arrowHalfWidth
        let minTail = m.cornerRadius + half + m.tailInset
        let maxTail = max(minTail, windowSize.width - m.cornerRadius - half - m.tailInset)
        let tailX = min(max(anchor.midX - x, minTail), maxTail)

        return Result(frame: CGRect(x: x, y: y, width: windowSize.width, height: windowSize.height),
                      tailX: tailX)
    }
}
