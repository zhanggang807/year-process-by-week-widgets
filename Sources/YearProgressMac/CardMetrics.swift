import CoreGraphics

/// 所有尺寸都从基准尺寸 600×292 按比例推导，因此换任何窗口大小都不会失衡。
struct CardMetrics {
    static let referenceWidth: CGFloat = 600
    static let referenceHeight: CGFloat = 292

    let size: CGSize

    var scale: CGFloat { size.width / Self.referenceWidth }

    var padding: CGFloat { 24 * scale }
    var cornerRadius: CGFloat { 20 * scale }
    var headerGap: CGFloat { 16 * scale }
    var footerGap: CGFloat { 12 * scale }

    var titleFont: CGFloat { 27 * scale }
    var subtitleFont: CGFloat { 12 * scale }
    var footerFont: CGFloat { 11.5 * scale }
    var ringSize: CGFloat { 26 * scale }

    var headerHeight: CGFloat { titleFont * 1.16 + 3 * scale + subtitleFont * 1.28 }
    var footerHeight: CGFloat { footerFont * 1.3 }

    /// 留给方块网格的空间。
    var gridArea: (width: Double, height: Double) {
        let width = size.width - padding * 2
        let height = size.height - padding * 2 - headerHeight - headerGap - footerGap - footerHeight
        return (Double(max(40, width)), Double(max(40, height)))
    }
}
