import CoreGraphics

/// 菜单栏气泡弹窗的几何参数：App、预览、定位共用同一份，
/// 避免出现"预览里尾巴 11pt、实际 14pt"这类漂移。
enum QuickPopoverMetrics {
    static let arrowHeight: CGFloat = 14
    static let arrowHalfWidth: CGFloat = 12
    static let cornerRadius: CGFloat = 20
    static let edgeMargin: CGFloat = 8
    static let gap: CGFloat = 4
    static let tailInset: CGFloat = 4
}
