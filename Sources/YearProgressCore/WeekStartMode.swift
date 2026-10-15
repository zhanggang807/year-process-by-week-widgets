import Foundation

/// 一周从哪天开始。
public enum WeekStartMode: String, CaseIterable, Codable, Sendable, Identifiable {
    /// ISO 8601：周一为首日，第 1 周含 1 月 4 日。等价于「一年 52 或 53 周」的标准答案。
    case monday
    /// 周日为首日，第 1 周含 1 月 1 日。
    case sunday
    /// 跟随系统区域设置。
    case locale

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .monday: return "周一（ISO 8601）"
        case .sunday: return "周日"
        case .locale: return "跟随系统"
        }
    }

    public func makeCalendar(timeZone: TimeZone) -> Calendar {
        switch self {
        case .monday:
            var c = Calendar(identifier: .iso8601)
            c.timeZone = timeZone
            return c
        case .sunday:
            var c = Calendar(identifier: .gregorian)
            c.timeZone = timeZone
            c.firstWeekday = 1
            c.minimumDaysInFirstWeek = 1
            return c
        case .locale:
            var c = Calendar(identifier: .gregorian)
            c.timeZone = timeZone
            c.firstWeekday = Calendar.current.firstWeekday
            c.minimumDaysInFirstWeek = Calendar.current.minimumDaysInFirstWeek
            return c
        }
    }
}
