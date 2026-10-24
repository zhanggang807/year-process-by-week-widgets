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
/// 「今天」落在网格之外时的信息（年初/年末那几个跨年周）。
public struct OutOfGridWeek: Hashable, Sendable {
    public let year: Int        // 它真正属于哪一年（周年度）
    public let index: Int       // 第几周
}

public struct YearProgress: Sendable {
    public let year: Int                 // 展示年份 = 当前公历年
    public let ganzhi: Ganzhi
    public let weeks: [WeekCell]
    public let referenceDate: Date
    public let timeZone: TimeZone
    public let weekStartMode: WeekStartMode
    /// 非 nil 表示「今天」所在的周不属于展示年份（只会出现在 1 月 1–3 日或 12 月 29–31 日）。
    public let outOfGridWeek: OutOfGridWeek?

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
    /// "丙午年 · 第 42/53 周"；跨年周时退化为 "丙午年 · 共 52 周"
    public var subtitle: String {
        if currentWeek == nil {
            return "\(ganzhi.yearName) · 共 \(totalWeeks) 周"
        }
        return "\(ganzhi.yearName) · 第 \(currentWeek?.index ?? totalWeeks)/\(totalWeeks) 周"
    }

    /// 顶部单行（完整版）："2026年 · 丙午年 · 第 42/53 周 · 已过 78%"
    public func headerText(compact: Bool = false) -> String {
        let p = Int(percent.rounded())
        if compact {
            if outOfGridWeek != nil { return "\(year) · \(ganzhi.name) · \(totalWeeks) 周 · \(p)%" }
            return "\(year) · \(ganzhi.name) · \(currentWeek?.index ?? totalWeeks)/\(totalWeeks) · \(p)%"
        }
        if outOfGridWeek != nil {
            return "\(yearTitle) · \(ganzhi.yearName) · 共 \(totalWeeks) 周 · 已过 \(p)%"
        }
        return "\(yearTitle) · \(ganzhi.yearName) · 第 \(currentWeek?.index ?? totalWeeks)/\(totalWeeks) 周 · 已过 \(p)%"
    }

    /// 只有「跨年周」那 1–3 天才出现的第二行小字。
    public var boundaryNote: String? {
        guard let outside = outOfGridWeek else { return nil }
        return "本周属于 \(outside.year) 年第 \(outside.index) 周"
    }

    /// "已过 78% · 剩余 11 周"；跨年周时说明本周到底属于哪一年。
    public var footerText: String {
        let p = Int(percent.rounded())
        if let outside = outOfGridWeek {
            return "已过 \(p)% · 本周属于 \(outside.year) 年第 \(outside.index) 周"
        }
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
        // 展示年份 = 当前公历年（不是 ISO 周年度）
        let year = calendar.component(.year, from: date)
        let count = YearWeekMath.weeksInYear(year, calendar: calendar)
        let dayLength: TimeInterval = 7 * 24 * 3600

        var cells: [WeekCell] = []
        cells.reserveCapacity(count)
        for index in 1...count {
            guard let range = YearWeekMath.weekRange(index: index, weekYear: year, calendar: calendar) else { continue }
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

        // 今天的这一周不在网格里时（跨年周），记下它真正属于哪一年第几周，用于文案说明。
        let outside: OutOfGridWeek? = cells.contains { date >= $0.start && date < $0.endExclusive }
            ? nil
            : OutOfGridWeek(year: calendar.component(.yearForWeekOfYear, from: date),
                            index: calendar.component(.weekOfYear, from: date))

        return YearProgress(year: year,
                            ganzhi: Ganzhi(year: year),
                            weeks: cells,
                            referenceDate: date,
                            timeZone: timeZone,
                            weekStartMode: weekStartMode,
                            outOfGridWeek: outside)
    }
}
