import CoreGraphics

/// 菜单栏气泡弹窗的几何参数：App、预览、定位共用同一份，
/// 避免出现"预览里尾巴 11pt、实际 14pt"这类漂移。
public enum QuickPopoverMetrics {
    public static let arrowHeight: CGFloat = 14
    public static let arrowHalfWidth: CGFloat = 12
    public static let cornerRadius: CGFloat = 20
    /// 弹窗与屏幕可视区域的最小边距
    public static let edgeMargin: CGFloat = 8
    /// 尾巴尖与菜单栏底边的间隙
    public static let gap: CGFloat = 4
    /// 尾巴尖与圆角之间的安全距离
    public static let tailInset: CGFloat = 4
}
