import Foundation

/// 一个方块 = 一年里的一周。
public struct WeekCell: Identifiable, Hashable, Sendable {
    public enum State: String, Hashable, Sendable {
        case past      // 已过（白块）
        case current   // 本周（白底 + 黑描边 + 进度条）
        case future    // 未来（黑块）
    }

    public let index: Int          // 第几周，1...53
    public let start: Date         // 周一 00:00
    public let endExclusive: Date  // 下周一 00:00
    public let state: State
    /// 本周已过的比例 0...1（非本周：past 为 1、future 为 0）。
    public let fraction: Double

    public var id: Int { index }
    /// 该周最后一天（周日）。用于展示区间。
    public var end: Date { endExclusive.addingTimeInterval(-1) }
}

/// 某一年的周进度快照：纯值对象，任何时刻都能由「当前时间 + 时区」重算。
public struct YearProgress: Sendable {
    public let year: Int                 // 展示年份（周年度）
    public let ganzhi: Ganzhi
    public let weeks: [WeekCell]
    public let referenceDate: Date
    public let timeZone: TimeZone
    public let weekStartMode: WeekStartMode

    public var totalWeeks: Int { weeks.count }
    public var pastCount: Int { weeks.filter { $0.state == .past }.count }
    public var currentWeek: WeekCell? { weeks.first { $0.state == .current } }
    public var remainingWeeks: Int { weeks.filter { $0.state == .future }.count }

    /// 已完成比例 0...100（按「周」计，本周按已过的天数比例折算）。
    public var percent: Double {
        guard totalWeeks > 0 else { return 0 }
        let done = Double(pastCount) + (currentWeek?.fraction ?? 0)
        return min(100, max(0, done / Double(totalWeeks) * 100))
    }

    // MARK: 展示文案（集中放这里，UI 层只负责摆位置）

    /// "2026年"
    public var yearTitle: String { "\(year)年" }
    /// "丙午年 · 第 42/53 周"
    public var subtitle: String {
        "\(ganzhi.yearName) · 第 \(currentWeek?.index ?? totalWeeks)/\(totalWeeks) 周"
    }
    /// "已过 78% · 剩余 11 周"
    public var footerText: String {
        let p = Int(percent.rounded())
        return "已过 \(p)% · 剩余 \(remainingWeeks) 周"
    }
}

public enum YearProgressCalculator {

    /// 计算某一天所属周年的完整周进度。
    public static func progress(for date: Date = Date(),
                                timeZone: TimeZone = .current,
                                weekStartMode: WeekStartMode = .monday) -> YearProgress {
        let calendar = weekStartMode.makeCalendar(timeZone: timeZone)
        return progress(for: date, calendar: calendar, timeZone: timeZone, weekStartMode: weekStartMode)
    }

    public static func progress(for date: Date,
                                calendar: Calendar,
                                timeZone: TimeZone,
                                weekStartMode: WeekStartMode = .monday) -> YearProgress {
        let weekYear = YearWeekMath.weekYear(of: date, calendar: calendar)
        let count = YearWeekMath.weeksInYear(weekYear, calendar: calendar)
        let dayLength: TimeInterval = 7 * 24 * 3600

        var cells: [WeekCell] = []
        cells.reserveCapacity(count)
        for index in 1...count {
            guard let range = YearWeekMath.weekRange(index: index, weekYear: weekYear, calendar: calendar) else { continue }
            let state: WeekCell.State
            let fraction: Double
            if date >= range.endExclusive {
                state = .past; fraction = 1
            } else if date < range.start {
                state = .future; fraction = 0
            } else {
                state = .current
                fraction = min(1, max(0, date.timeIntervalSince(range.start) / dayLength))
            }
            cells.append(WeekCell(index: index, start: range.start, endExclusive: range.endExclusive,
                                  state: state, fraction: fraction))
        }

        return YearProgress(year: weekYear,
                            ganzhi: Ganzhi(year: weekYear),
                            weeks: cells,
                            referenceDate: date,
                            timeZone: timeZone,
                            weekStartMode: weekStartMode)
    }
}
