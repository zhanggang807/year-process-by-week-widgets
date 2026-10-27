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

    func progress(_ string: String, _ timeZone: TimeZone? = nil) -> YearProgress {
        YearProgressCalculator.progress(for: date(string, timeZone ?? shanghai),
                                        timeZone: timeZone ?? shanghai,
                                        weekStartMode: .monday)
    }

    @Test("2026-10-15 应为第 42 周 / 共 53 周")
    func midOctober2026() {
        let p = progress("2026-10-15 12:00")
        #expect(p.year == 2026)
        #expect(p.totalWeeks == 53)
        #expect(p.currentWeek?.index == 42)
        #expect(p.pastCount == 41)
        #expect(p.remainingWeeks == 11)
        #expect(p.percent > 77 && p.percent < 79)
        #expect(p.yearTitle == "2026年")
        #expect(p.subtitle == "丙午年 · 第 42 周 · 剩 11 周")
        #expect(p.footerText == "已过 78% · 剩余 11 周")
        #expect(p.outOfGridWeek == nil)
    }

    @Test("顶部单行：年份 · 干支 · 周计数 · 百分比（含紧凑版）")
    func headerTextFormat() {
        let p = progress("2026-10-15 12:00")
        #expect(p.headerText() == "2026年 · 丙午年 · 第 42 周 · 剩 11 周 · 已过 78%")
        #expect(p.headerText(compact: true) == "2026 · 丙午 · 42 周 · 剩 11 周 · 78%")
        #expect(p.boundaryNote == nil)

        let q = progress("2025-12-30 12:00")
        #expect(q.headerText() == "2025年 · 乙巳年 · 第 53 周 · 剩 0 周 · 已过 99%")
        #expect(q.boundaryNote == nil)

        let r = progress("2027-01-01 12:00")
        #expect(r.headerText() == "2027年 · 丁未年 · 第 1 周 · 剩 52 周 · 已过 0%")
        #expect(r.boundaryNote == nil)
    }

    @Test("年末最后一周的紧凑 header")
    func compactHeaderAtBoundary() {
        let p = progress("2025-12-30 12:00")
        #expect(p.headerText() == "2025年 · 乙巳年 · 第 53 周 · 剩 0 周 · 已过 99%")
        #expect(p.headerText(compact: true) == "2025 · 乙巳 · 53 周 · 剩 0 周 · 99%")
    }

    @Test("网格连续、无空洞，且覆盖整年")
    func cellsAreContiguous() {
        let p = progress("2026-06-01 12:00")
        #expect(p.weeks.count == 53)
        #expect(p.weeks.first?.index == 1)
        #expect(p.weeks.last?.index == 53)
        for (a, b) in zip(p.weeks, p.weeks.dropFirst()) {
            #expect(a.endExclusive == b.start)
        }
        let jan1 = date("2026-01-01 12:00", shanghai)
        let dec31 = date("2026-12-31 12:00", shanghai)
        #expect(p.weeks.first!.start <= jan1 && jan1 < p.weeks.first!.endExclusive)
        #expect(p.weeks.last!.start <= dec31 && dec31 < p.weeks.last!.endExclusive)
    }

    // MARK: 年份按「当前公历年」算（本次修改的主规则）

    @Test("展示年份 = 公历年：2025-12-30 是 2025 年第 53 周")
    func yearFollowsGregorianYearInLateDecember() {
        let p = progress("2025-12-30 12:00")
        #expect(p.year == 2025)
        #expect(p.yearTitle == "2025年")
        #expect(p.ganzhi.yearName == "乙巳年")
        #expect(p.totalWeeks == 53)
        #expect(p.currentWeek?.index == 53)
        #expect(p.pastCount == 52)
        #expect(p.remainingWeeks == 0)
        #expect(abs(p.percent - 99.0566) < 0.01)
        #expect(p.outOfGridWeek == nil)
        #expect(p.subtitle == "乙巳年 · 第 53 周 · 剩 0 周")
        #expect(p.footerText == "已过 99% · 剩余 0 周")
    }

    @Test("年初同理：2027-01-01 是 2027 年第 1 周")
    func yearFollowsGregorianYearInEarlyJanuary() {
        let p = progress("2027-01-01 12:00")
        #expect(p.year == 2027)
        #expect(p.yearTitle == "2027年")
        #expect(p.ganzhi.yearName == "丁未年")
        #expect(p.totalWeeks == 53)
        #expect(p.currentWeek?.index == 1)
        #expect(p.pastCount == 0)
        #expect(abs(p.percent - 0.3145) < 0.01)
        #expect(p.outOfGridWeek == nil)
        #expect(p.footerText == "已过 0% · 剩余 52 周")
    }

    @Test("常规日期不会出现跨年周")
    func noOutOfGridWeekInNormalDays() {
        for s in ["2026-01-05 12:00", "2026-06-01 12:00", "2026-10-15 12:00", "2025-12-28 12:00", "2027-06-01 12:00"] {
            let p = progress(s)
            #expect(p.outOfGridWeek == nil, "\(s)")
            #expect(p.currentWeek != nil, "\(s)")
        }
    }

    @Test("DST 周用真实长度算比例（169h / 167h）")
    func dstWeekFraction() {
        let ny = TimeZone(identifier: "America/New_York")!

        // 2026-11-01 02:00 回拨：所在周 169 小时
        let fall = YearProgressCalculator.progress(for: date("2026-11-01 12:00", ny),
                                                  timeZone: ny, weekStartMode: .monday)
        let fallCell = fall.currentWeek!
        #expect(abs(fallCell.endExclusive.timeIntervalSince(fallCell.start) - 169 * 3600) < 60)
        #expect(abs(fallCell.fraction - 157.0 / 169.0) < 1e-6)

        // 2026-03-08 02:00 前拨：所在周 167 小时
        let spring = YearProgressCalculator.progress(for: date("2026-03-05 12:00", ny),
                                                    timeZone: ny, weekStartMode: .monday)
        let springCell = spring.currentWeek!
        #expect(abs(springCell.endExclusive.timeIntervalSince(springCell.start) - 167 * 3600) < 60)
        #expect(abs(springCell.fraction - 84.0 / 167.0) < 1e-6)
    }

    @Test("rangeText 在计算时预生成")
    func weekRangeText() {
        let p = progress("2026-10-15 12:00")
        #expect(p.weeks[41].rangeText == "10/12–10/18")
    }

    @Test("逐日全量校验：年份跟着公历年、本周唯一、状态自洽（2019–2031 × 4 时区）")
    func dailyInvariants() {
        for tzName in ["Asia/Shanghai", "UTC", "America/New_York", "Australia/Sydney"] {
            let tz = TimeZone(identifier: tzName)!
            let cal = WeekStartMode.monday.makeCalendar(timeZone: tz)
            var cursor = cal.date(from: DateComponents(year: 2019, month: 1, day: 1, hour: 12))!
            let end = cal.date(from: DateComponents(year: 2031, month: 1, day: 1, hour: 12))!
            while cursor < end {
                let p = YearProgressCalculator.progress(for: cursor, calendar: cal, timeZone: tz, weekStartMode: .monday)
                #expect(p.year == cal.component(.year, from: cursor), "\(tzName) \(cursor) 年份不符")
                #expect([53, 54].contains(p.totalWeeks))
                #expect(p.weeks.count == p.totalWeeks)
                #expect(p.weeks.filter { $0.state == .current }.count == 1)
                #expect(p.pastCount + p.remainingWeeks + 1 == p.totalWeeks)
                for (a, b) in zip(p.weeks, p.weeks.dropFirst()) { #expect(a.endExclusive == b.start) }
                let c = try! #require(p.currentWeek)
                #expect(c.start <= cursor && cursor < c.endExclusive)
                #expect(p.outOfGridWeek == nil)
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
        }
    }

    @Test("周日模式同样自洽（53/54 周，且每天都有本周）")
    func sundayModeIsSelfConsistent() {
        for string in ["2026-01-01 12:00", "2026-10-15 12:00", "2025-12-30 12:00", "2028-02-29 12:00"] {
            let p = YearProgressCalculator.progress(for: date(string, shanghai),
                                                    timeZone: shanghai, weekStartMode: .sunday)
            #expect([53, 54].contains(p.totalWeeks), "\(string) -> \(p.totalWeeks)")
            #expect(p.currentWeek != nil, "\(string)")
            #expect(p.outOfGridWeek == nil, "\(string)")
            #expect(p.year == 2025 || p.year == 2026 || p.year == 2028)
        }
    }
}
