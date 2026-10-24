import CoreGraphics

/// 同一套视图要同时服务两种场合：桌面大卡片（App）与系统小组件（Widget）。
/// 小组件的容器尺寸由系统给（small/medium/large），字号必须收口才读得清。
public enum CardProfile: Sendable {
    case app
    case widget

    /// 顶部单行（年份 · 干支 · 周计数 · 百分比）
    var headerRatio: Double { self == .app ? 0.0235 : 0.031 }
    var headerRange: ClosedRange<CGFloat> { self == .app ? 11...26 : 9.5...14 }
    /// 跨年周才出现的第二行小字
    var noteRatio: Double { self == .app ? 0.0180 : 0.023 }
    var noteRange: ClosedRange<CGFloat> { self == .app ? 8...17 : 7.5...10.5 }

    var paddingRatio: Double { self == .app ? 0.036 : 0.050 }
    var paddingRange: ClosedRange<CGFloat> { self == .app ? 12...40 : 8...20 }
    var headerGapRatio: Double { self == .app ? 0.022 : 0.028 }
    var noteGapRatio: Double { self == .app ? 0.006 : 0.008 }
    var cornerRatio: Double { self == .app ? 0.033 : 0.0 }

    /// 小于这个宽度就用紧凑文案（small 小组件）
    var compactWidthThreshold: CGFloat { self == .app ? 300 : 250 }
}

/// 所有尺寸由卡片宽度按比例推导，配合上下限，因此在 158pt 的小组件与 600pt 的大卡片上都成立。
public struct CardMetrics {
    public static let referenceWidth: CGFloat = 600
    public static let referenceHeight: CGFloat = 292

    public let size: CGSize
    public let profile: CardProfile
    /// 非 nil 时覆盖顶部字号（small 小组件要跟面板一样的 13pt）
    public let headerFontOverride: CGFloat?

    public init(size: CGSize, profile: CardProfile = .app, headerFontOverride: CGFloat? = nil) {
        self.size = size
        self.profile = profile
        self.headerFontOverride = headerFontOverride
    }

    private func clamp(_ value: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    public var scale: CGFloat { size.width / Self.referenceWidth }

    public var padding: CGFloat { clamp(size.width * profile.paddingRatio, profile.paddingRange) }
    public var cornerRadius: CGFloat { size.width * profile.cornerRatio }
    public var headerGap: CGFloat { max(6, size.width * profile.headerGapRatio) }
    public var noteGap: CGFloat { max(2, size.width * profile.noteGapRatio) }

    public var headerFont: CGFloat { headerFontOverride ?? (clamp(size.width * profile.headerRatio, profile.headerRange) + 2) }
    public var noteFont: CGFloat { clamp(size.width * profile.noteRatio, profile.noteRange) }

    public var headerHeight: CGFloat { headerFont * 1.35 }
    public var noteHeight: CGFloat { noteFont * 1.32 }

    public var usesCompactHeader: Bool { size.width < profile.compactWidthThreshold }

    /// 留给方块网格的空间（不再是固定高度，底部/环去掉后网格能变大）。
    public func gridArea(noteVisible: Bool) -> (width: Double, height: Double) {
        var height = size.height - padding * 2 - headerHeight - headerGap
        if noteVisible { height -= noteHeight + noteGap }
        let width = size.width - padding * 2
        return (Double(max(24, width)), Double(max(24, height)))
    }
}
