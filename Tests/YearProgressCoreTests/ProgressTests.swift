import Testing
import Foundation
@testable import YearProgressCore

@Suite("周进度计算")
struct ProgressTests {
    let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    func date(_ string: String, _ timeZone: TimeZone) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: string)!
    }

    @Test("2026-10-15 应为第 42 周 / 共 53 周")
    func midOctober2026() {
        let p = YearProgressCalculator.progress(for: date("2026-10-15 12:00", shanghai),
                                                timeZone: shanghai, weekStartMode: .monday)
        #expect(p.year == 2026)
        #expect(p.totalWeeks == 53)
        #expect(p.currentWeek?.index == 42)
        #expect(p.pastCount == 41)
        #expect(p.remainingWeeks == 11)
        #expect(p.percent > 77 && p.percent < 79)
        #expect(p.yearTitle == "2026年")
        #expect(p.subtitle == "丙午年 · 第 42/53 周")
        #expect(p.footerText == "已过 78% · 剩余 11 周")
    }

    @Test("网格连续、无空洞，且覆盖整年")
    func cellsAreContiguous() {
        let p = YearProgressCalculator.progress(for: date("2026-06-01 12:00", shanghai),
                                                timeZone: shanghai, weekStartMode: .monday)
        #expect(p.weeks.count == 53)
        #expect(p.weeks.first?.index == 1)
        #expect(p.weeks.last?.index == 53)
        for (a, b) in zip(p.weeks, p.weeks.dropFirst()) {
            #expect(a.endExclusive == b.start)
        }
        // 第 1 周包含 1 月 1 日，最后一周包含 12 月 31 日
        let jan1 = date("2026-01-01 12:00", shanghai)
        let dec31 = date("2026-12-31 12:00", shanghai)
        #expect(p.weeks.first!.start <= jan1 && jan1 < p.weeks.first!.endExclusive)
        #expect(p.weeks.last!.start <= dec31 && dec31 < p.weeks.last!.endExclusive)
    }

    @Test("任何一天都能在自己那一年的网格里找到「本周」")
    func currentWeekAlwaysPresent() {
        for tzName in ["Asia/Shanghai", "UTC", "America/New_York", "Australia/Sydney"] {
            let tz = TimeZone(identifier: tzName)!
            let cal = WeekStartMode.monday.makeCalendar(timeZone: tz)
            var day = DateComponents(year: 2019, month: 1, day: 1, hour: 12)
            var cursor = cal.date(from: day)!
            let end = cal.date(from: DateComponents(year: 2031, month: 1, day: 1, hour: 12))!
            while cursor < end {
                let p = YearProgressCalculator.progress(for: cursor, calendar: cal, timeZone: tz, weekStartMode: .monday)
                #expect(p.currentWeek != nil, "\(tzName) \(cursor) 没有当前周")
                #expect(p.weeks.count == p.totalWeeks)
                if let c = p.currentWeek {
                    #expect(c.start <= cursor && cursor < c.endExclusive)
                }
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
                day.day = 1
            }
        }
    }

    @Test("12 月底：ISO 周年度会提前进入下一年（标准 ISO 行为）")
    func isoYearFlipsInLateDecember() {
        let p = YearProgressCalculator.progress(for: date("2025-12-30 12:00", shanghai),
                                                timeZone: shanghai, weekStartMode: .monday)
        #expect(p.year == 2026)              // 2025-12-30 属于 ISO 2026 年第 1 周
        #expect(p.currentWeek?.index == 1)
        #expect(p.pastCount == 0)
        #expect(p.totalWeeks == 53)

        let q = YearProgressCalculator.progress(for: date("2025-12-28 12:00", shanghai),
                                                timeZone: shanghai, weekStartMode: .monday)
        #expect(q.year == 2025)
        #expect(q.currentWeek?.index == 52)  // 2025 年第 52 周（最后一周）
        #expect(q.remainingWeeks == 0)
    }

    @Test("周日模式也能自洽（今天的周一定在网格里，且计数为 52/53）")
    func sundayModeIsSelfConsistent() {
        for string in ["2026-01-01 12:00", "2026-10-15 12:00", "2025-12-30 12:00", "2028-02-29 12:00"] {
            let p = YearProgressCalculator.progress(for: date(string, shanghai),
                                                    timeZone: shanghai, weekStartMode: .sunday)
            #expect([52, 53].contains(p.totalWeeks), "\(string) -> \(p.totalWeeks)")
            #expect(p.currentWeek != nil, "\(string)")
        }
    }
}
