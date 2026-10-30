import Foundation

/// 网格分隔线装饰。默认关闭；用于探索“月份/季度”在周网格里的视觉分隔。
public enum GridDecoration: String, CaseIterable, Sendable {
    case none
    case months
    case quarters
    case both
    case coloredLines

    public var showsMonths: Bool { self == .months || self == .both }
    public var showsQuarters: Bool { self == .quarters || self == .both || self == .coloredLines }

    public var displayName: String {
        switch self {
        case .none: return "不显示"
        case .months: return "月份分隔"
        case .quarters: return "季度分隔"
        case .both: return "月份 + 季度"
        case .coloredLines: return "季度黄线 + 月份青线"
        }
    }
}
