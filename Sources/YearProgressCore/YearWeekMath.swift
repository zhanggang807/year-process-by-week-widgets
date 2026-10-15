import Foundation

/// 与「一年的周」有关的纯计算。不依赖任何 UI 框架。
public enum YearWeekMath {

    // MARK: 一年有几个周

    /// 用系统日历求某个「周年度」包含多少个周：ISO 下为 52 或 53。
    public static func weeksInYear(_ weekYear: Int, calendar: Calendar) -> Int {
        guard let mid = calendar.date(from: DateComponents(year: weekYear, month: 6, day: 15)),
              let range = calendar.range(of: .weekOfYear, in: .yearForWeekOfYear, for: mid)
        else { return 52 }
        return range.count
    }

    /// 独立于 `Calendar` 的 ISO 8601 规则推导，仅用于交叉校验（勿用于生产取值）：
    /// 1 月 1 日是周四 → 53 周；闰年且 1 月 1 日是周三 → 53 周；否则 52 周。
    public static func isoWeeksInYearByRule(_ year: Int) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return 52 }
        // Calendar 的 weekday 固定为 1 = 周日 … 7 = 周六，与 firstWeekday 设置无关。
        let weekday = cal.component(.weekday, from: jan1)
        let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        if weekday == 5 { return 53 }                       // 周四
        if isLeap && weekday == 4 { return 53 }             // 闰年 + 周三
        return 52
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    // MARK: 单个日期落在哪一周

    /// 该日期所在周的第一天（00:00）。
    public static func weekStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    /// 显示用的「周年度」：保证今天的这一周一定落在这一年里。
    public static func weekYear(of date: Date, calendar: Calendar) -> Int {
        calendar.component(.yearForWeekOfYear, from: date)
    }

    /// 指定周年的第 index 周（index 从 1 开始）的起止时刻。
    public static func weekRange(index: Int, weekYear: Int, calendar: Calendar) -> (start: Date, endExclusive: Date)? {
        var comps = DateComponents()
        comps.yearForWeekOfYear = weekYear
        comps.weekOfYear = index
        comps.weekday = calendar.firstWeekday
        guard let start = calendar.date(from: comps) else { return nil }
        guard let endExclusive = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
        return (start, endExclusive)
    }

    /// 下一个零点的时刻（用于零点自动刷新）。
    public static func nextMidnight(after date: Date, calendar: Calendar) -> Date {
        calendar.nextDate(after: date,
                          matching: DateComponents(hour: 0, minute: 0, second: 5),
                          matchingPolicy: .nextTime) ?? date.addingTimeInterval(6 * 3600)
    }
}
