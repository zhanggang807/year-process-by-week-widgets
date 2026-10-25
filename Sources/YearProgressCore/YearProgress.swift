import Foundation

/// 一个方块 = 一年里的一周。
public struct WeekCell: Identifiable, Hashable, Sendable {
    public enum State: String, Hashable, Sendable {
        case past      // 已过（主题的深色块）
        case current   // 本周（上半深色/下半浅色，随进度推进）
        case future    // 未来（主题的浅色块）
    }

    public let index: Int          // 第几周，1...53
    public let start: Date         // 周一 00:00
    public let endExclusive: Date  // 下周一 00:00
    public let state: State
    /// 本周已过的比例 0...1（非本周：past 为 1、future 为 0）。
    public let fraction: Double
    /// 本周内的节假日名（只看周一~周五；周末不算），nil 表示无。
    public let holiday: String?
    /// 展示用区间，如 "10/12–10/18"（每次进度计算时生成一次，避免每格重复建 DateFormatter）
    public let rangeText: String

    public var id: Int { index }
    /// 该周最后一天（周日）。用于展示区间。
    public var end: Date { endExclusive.addingTimeInterval(-1) }
}

/// 「今天」落在网格之外时的信息（年初/年末那几个跨年周）。
public struct OutOfGridWeek: Hashable, Sendable {
    public let year: Int        // 它真正属于哪一年（周年度）
    public let index: Int       // 第几周
}

/// 某一年的周进度快照：纯值对象，任何时刻都能由「当前时间 + 时区」重算。
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
    /// 注意这是"周进度"，不是"天进度"：最后一周走到一半时百分比会明显跳一格。
    public var percent: Double {
        guard totalWeeks > 0 else { return 0 }
        let done = Double(pastCount) + (currentWeek?.fraction ?? 0)
        return min(100, max(0, done / Double(totalWeeks) * 100))
    }

    // MARK: 展示文案（集中放这里，UI 层只负责摆位置）

    /// "2026年"
    public var yearTitle: String { "\(year)年" }
    /// "丙午年 · 第 42 周 · 剩 11 周"；跨年周时退化为 "丙午年 · 共 52 周"
    public var subtitle: String {
        if currentWeek == nil {
            return "\(ganzhi.yearName) · 共 \(totalWeeks) 周"
        }
        return "\(ganzhi.yearName) · 第 \(currentWeek?.index ?? totalWeeks) 周 · 剩 \(remainingWeeks) 周"
    }

    /// 顶部单行（完整版）："2026年 · 丙午年 · 第 42 周 · 剩 11 周 · 已过 78%"
    public func headerText(compact: Bool = false) -> String {
        let p = Int(percent.rounded())
        if compact {
            if outOfGridWeek != nil { return "\(year) · \(ganzhi.name) · \(totalWeeks) 周 · \(p)%" }
            return "\(year) · \(ganzhi.name) · \(currentWeek?.index ?? totalWeeks) 周 · 剩 \(remainingWeeks) 周 · \(p)%"
        }
        if outOfGridWeek != nil {
            return "\(yearTitle) · \(ganzhi.yearName) · 共 \(totalWeeks) 周 · 已过 \(p)%"
        }
        return "\(yearTitle) · \(ganzhi.yearName) · 第 \(currentWeek?.index ?? totalWeeks) 周 · 剩 \(remainingWeeks) 周 · 已过 \(p)%"
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
                                weekStartMode: WeekStartMode = .monday,
                                holidayTable: HolidayTable? = nil) -> YearProgress {
        // 展示年份 = 当前公历年（不是 ISO 周年度）
        let year = calendar.component(.year, from: date)
        let count = YearWeekMath.weeksInYear(year, calendar: calendar)
        let holidays = holidayTable ?? HolidayTable.builtIn(for: year)

        // 每次计算只建一个 formatter，rangeText 预计算好（原来每个方块每次渲染都要建）
        let dayFormat = DateFormatter()
        dayFormat.locale = Locale(identifier: "en_US_POSIX")
        dayFormat.timeZone = timeZone
        dayFormat.dateFormat = "M/d"

        var cells: [WeekCell] = []
        cells.reserveCapacity(count)

        // 第 1 周只算一次，其余按 7 个自然日推进；任何一步失败都显式断言，
        // 不再 `continue` 静默少一格（那会让 totalWeeks/percent 悄悄算错）。
        guard count > 0,
              let first = YearWeekMath.weekRange(index: 1, weekYear: year, calendar: calendar) else {
            assertionFailure("无法计算 \(year) 年第 1 周")
            return YearProgress(year: year, ganzhi: Ganzhi(year: year), weeks: [],
                                referenceDate: date, timeZone: timeZone,
                                weekStartMode: weekStartMode, outOfGridWeek: nil)
        }

        var weekStart = first.start
        for index in 1...count {
            let endExclusive: Date
            if let next = calendar.date(byAdding: .day, value: 7, to: weekStart) {
                endExclusive = next
            } else {
                assertionFailure("无法计算第 \(index) 周的结束")
                endExclusive = weekStart.addingTimeInterval(7 * 24 * 3600)
            }

            let state: WeekCell.State
            let fraction: Double
            if date >= endExclusive {
                state = .past; fraction = 1
            } else if date < weekStart {
                state = .future; fraction = 0
            } else {
                state = .current
                // 用这一周的真实长度（DST 周可能是 167/169 小时），而不是固定 168 小时
                let span = endExclusive.timeIntervalSince(weekStart)
                fraction = min(1, max(0, date.timeIntervalSince(weekStart) / span))
            }
            // 周内是否有工作日假期（周六日不算）
            var holidayName: String?
            if let holidays {
                var day = weekStart
                while day < endExclusive {
                    let weekday = calendar.component(.weekday, from: day)   // 1=Sun ... 7=Sat
                    if weekday != 1, weekday != 7, let name = holidays.holidayName(on: day, calendar: calendar) {
                        holidayName = name
                        break
                    }
                    day = calendar.date(byAdding: .day, value: 1, to: day) ?? endExclusive
                }
            }

            let rangeText = "\(dayFormat.string(from: weekStart))–\(dayFormat.string(from: endExclusive.addingTimeInterval(-1)))"
            cells.append(WeekCell(index: index, start: weekStart, endExclusive: endExclusive,
                                  state: state, fraction: fraction, holiday: holidayName,
                                  rangeText: rangeText))
            weekStart = endExclusive
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
