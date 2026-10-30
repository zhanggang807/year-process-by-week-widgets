import Foundation

/// 网格月份 / 季度分隔线的显示模式。
///
/// 正式产品默认使用 `.coloredLines`：季度线青柠、月份线洋红，菜单里可关闭。
/// 其余 case 保留给 CLI / 快照调试，也兼容旧版本已经保存过的偏好值。
public enum GridDecoration: String, CaseIterable, Sendable {
    case none
    case months
    case quarters
    case both
    case coloredLines

    /// 没有保存过偏好时的产品默认值。宿主 App 与 Widget 扩展共用这个默认值。
    public static let productDefault: GridDecoration = .coloredLines

    public var isEnabled: Bool { self != .none }
    public var showsMonths: Bool { self == .months || self == .both || self == .coloredLines }
    public var showsQuarters: Bool { self == .quarters || self == .both || self == .coloredLines }

    public var displayName: String {
        switch self {
        case .none: return "不显示"
        case .months: return "仅月份分隔"
        case .quarters: return "仅季度分隔"
        case .both, .coloredLines: return "月份 + 季度分隔"
        }
    }
}
