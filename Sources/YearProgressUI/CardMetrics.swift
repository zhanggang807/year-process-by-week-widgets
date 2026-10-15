import CoreGraphics

/// 同一套视图要同时服务两种场合：桌面大卡片（App）与系统小组件（Widget）。
/// 小组件的容器尺寸由系统给（small/medium/large），字号必须收口才读得清。
public enum CardProfile: Sendable {
    case app
    case widget

    var titleRatio: Double { self == .app ? 0.045 : 0.055 }
    var subtitleRatio: Double { self == .app ? 0.020 : 0.029 }
    var footerRatio: Double { self == .app ? 0.0192 : 0.026 }

    var titleRange: ClosedRange<CGFloat> { self == .app ? 15...48 : 11...26 }
    var subtitleRange: ClosedRange<CGFloat> { self == .app ? 7...22 : 8...13 }
    var footerRange: ClosedRange<CGFloat> { self == .app ? 7...20 : 7.5...12 }

    var paddingRatio: Double { self == .app ? 0.040 : 0.055 }
    var paddingRange: ClosedRange<CGFloat> { self == .app ? 14...44 : 9...22 }
    var headerGapRatio: Double { self == .app ? 0.027 : 0.035 }
    var footerGapRatio: Double { self == .app ? 0.020 : 0.022 }
    var ringRatio: Double { self == .app ? 0.043 : 0.070 }
    var cornerRatio: Double { self == .app ? 0.033 : 0.0 }
}

/// 所有尺寸由卡片宽度按比例推导，配合上下限，因此在 158pt 的小组件与 600pt 的大卡片上都成立。
public struct CardMetrics {
    public static let referenceWidth: CGFloat = 600
    public static let referenceHeight: CGFloat = 292

    public let size: CGSize
    public let profile: CardProfile

    public init(size: CGSize, profile: CardProfile = .app) {
        self.size = size
        self.profile = profile
    }

    private func clamp(_ value: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    public var scale: CGFloat { size.width / Self.referenceWidth }

    public var padding: CGFloat { clamp(size.width * profile.paddingRatio, profile.paddingRange) }
    public var cornerRadius: CGFloat { size.width * profile.cornerRatio }
    public var headerGap: CGFloat { max(6, size.width * profile.headerGapRatio) }
    public var footerGap: CGFloat { max(4, size.width * profile.footerGapRatio) }

    public var titleFont: CGFloat { clamp(size.width * profile.titleRatio, profile.titleRange) }
    public var subtitleFont: CGFloat { clamp(size.width * profile.subtitleRatio, profile.subtitleRange) }
    public var footerFont: CGFloat { clamp(size.width * profile.footerRatio, profile.footerRange) }
    public var ringSize: CGFloat { max(12, size.width * profile.ringRatio) }

    public var headerHeight: CGFloat { titleFont * 1.16 + max(2, scale * 3) + subtitleFont * 1.30 }
    public var footerHeight: CGFloat { footerFont * 1.32 }

    /// 留给方块网格的空间。
    public var gridArea: (width: Double, height: Double) {
        let width = size.width - padding * 2
        let height = size.height - padding * 2 - headerHeight - headerGap - footerGap - footerHeight
        return (Double(max(24, width)), Double(max(24, height)))
    }
}
