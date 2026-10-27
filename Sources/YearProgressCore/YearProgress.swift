import Foundation

/// 一个方块 = 一年里的一周。
public struct WeekCell: Identifiable, Hashable, Sendable {
    public enum State: String, Hashable, Sendable {
        case past      // 已过（主题的深色块）
        case current   // 本周（上半深色/下半浅色，随进度推进）
        case future    // 未来（主题的浅色块）
    }

    public let index: Int          // 该公历年内的第几周，1...54
    public let start: Date         // 周首日 00:00
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

/// 仅用于异常/空网格的兜底；正常公历年重叠周模型下不会出现。
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
    /// 重叠周模型下正常不会出现；保留给计算异常/未来数据源的兜底。
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
    /// "丙午年 · 第 42 周 · 剩 11 周"；异常/空网格时退化为 "丙午年 · 共 N 周"
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

    /// 保留给异常/未来数据源；正常重叠周模型中为 nil。
    public var boundaryNote: String? {
        guard let outside = outOfGridWeek else { return nil }
        return "本周属于 \(outside.year) 年第 \(outside.index) 周"
    }

    /// "已过 78% · 剩余 11 周"；异常跨年信息只在有 outOfGridWeek 时出现。
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
        // 展示年份 = 当前公历年；网格包含所有与这个公历年相交的周。
        // 首周可能从上一年的 12 月开始，末周可能延到下一年的 1 月；
        // 因此总周数是 53 或 54，而不是 ISO 周年度的 52/53。
        let year = calendar.component(.year, from: date)
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let nextYearStart = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            assertionFailure("无法计算 \(year) 年的起止")
            return YearProgress(year: year, ganzhi: Ganzhi(year: year), weeks: [],
                                referenceDate: date, timeZone: timeZone,
                                weekStartMode: weekStartMode, outOfGridWeek: nil)
        }
        let weekStarts = YearWeekMath.overlappingWeekStarts(year: year, calendar: calendar)
        let holidays = holidayTable ?? HolidayTable.builtIn(for: year)

        // 每次计算只建一个 formatter，rangeText 预计算好（原来每个方块每次渲染都要建）
        let dayFormat = DateFormatter()
        dayFormat.locale = Locale(identifier: "en_US_POSIX")
        dayFormat.timeZone = timeZone
        dayFormat.dateFormat = "M/d"

        var cells: [WeekCell] = []
        cells.reserveCapacity(weekStarts.count)

        for (offset, weekStart) in weekStarts.enumerated() {
            let index = offset + 1
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
                // 本周刚好跨年时，只按「落在展示年份内那几天」计算比例。
                // 否则 1 月 1 日会因为所在周从去年 12 月开始，被显示成“本周已过 6/7”。
                let portionStart = max(weekStart, yearStart)
                let portionEnd = min(endExclusive, nextYearStart)
                let span = portionEnd.timeIntervalSince(portionStart)
                fraction = span > 0
                    ? min(1, max(0, date.timeIntervalSince(portionStart) / span))
                    : 0
            }

            // 周内是否有工作日假期（周六日不算）；只检查落在展示年份内的日期。
            var holidayName: String?
            if let holidays {
                var day = max(weekStart, yearStart)
                let scanEnd = min(endExclusive, nextYearStart)
                while day < scanEnd {
                    let weekday = calendar.component(.weekday, from: day)   // 1=Sun ... 7=Sat
                    if weekday != 1, weekday != 7, let name = holidays.holidayName(on: day, calendar: calendar) {
                        holidayName = name
                        break
                    }
                    day = calendar.date(byAdding: .day, value: 1, to: day) ?? scanEnd
                }
            }

            let rangeText = "\(dayFormat.string(from: weekStart))–\(dayFormat.string(from: endExclusive.addingTimeInterval(-1)))"
            cells.append(WeekCell(index: index, start: weekStart, endExclusive: endExclusive,
                                  state: state, fraction: fraction, holiday: holidayName,
                                  rangeText: rangeText))
        }

        // 重叠周模型下，公历年内每一天都在网格里；保留兜底以防计算异常。
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
