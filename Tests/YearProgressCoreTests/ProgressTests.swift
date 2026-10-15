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
        #expect(p.subtitle == "丙午年 · 第 42/53 周")
        #expect(p.footerText == "已过 78% · 剩余 11 周")
        #expect(p.outOfGridWeek == nil)
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

    @Test("展示年份 = 当前公历年：2025-12-30 属于 ISO 2026 年第 1 周，但卡片必须是 2025 年")
    func yearFollowsGregorianYearInLateDecember() {
        let p = progress("2025-12-30 12:00")
        #expect(p.year == 2025)
        #expect(p.yearTitle == "2025年")
        #expect(p.ganzhi.yearName == "乙巳年")
        #expect(p.totalWeeks == 52)
        #expect(p.currentWeek == nil)
        #expect(p.pastCount == 52)
        #expect(p.remainingWeeks == 0)
        #expect(p.percent == 100)
        #expect(p.outOfGridWeek == OutOfGridWeek(year: 2026, index: 1))
        #expect(p.subtitle == "乙巳年 · 共 52 周")
        #expect(p.footerText == "已过 100% · 本周属于 2026 年第 1 周")
    }

    @Test("年初同理：2027-01-01 属于 2026 年第 53 周，卡片显示 2027 年")
    func yearFollowsGregorianYearInEarlyJanuary() {
        let p = progress("2027-01-01 12:00")
        #expect(p.year == 2027)
        #expect(p.yearTitle == "2027年")
        #expect(p.ganzhi.yearName == "丁未年")
        #expect(p.currentWeek == nil)
        #expect(p.pastCount == 0)
        #expect(p.percent == 0)
        #expect(p.outOfGridWeek == OutOfGridWeek(year: 2026, index: 53))
        #expect(p.footerText == "已过 0% · 本周属于 2026 年第 53 周")
    }

    @Test("常规日期不会出现跨年周")
    func noOutOfGridWeekInNormalDays() {
        for s in ["2026-01-05 12:00", "2026-06-01 12:00", "2026-10-15 12:00", "2025-12-28 12:00", "2027-06-01 12:00"] {
            let p = progress(s)
            #expect(p.outOfGridWeek == nil, "\(s)")
            #expect(p.currentWeek != nil, "\(s)")
        }
    }

    @Test("跨年周只会落在 1 月 1–3 日 / 12 月 29–31 日，且每年最多一出现")
    func boundaryWindowIsNarrow() {
        let calendar = WeekStartMode.monday.makeCalendar(timeZone: shanghai)
        for tzName in ["Asia/Shanghai", "UTC"] {
            let tz = TimeZone(identifier: tzName)!
            let cal = WeekStartMode.monday.makeCalendar(timeZone: tz)
            var cursor = cal.date(from: DateComponents(year: 2019, month: 1, day: 1, hour: 12))!
            let end = cal.date(from: DateComponents(year: 2032, month: 1, day: 1, hour: 12))!
            var gapsByYear: [Int: Int] = [:]
            while cursor < end {
                let p = YearProgressCalculator.progress(for: cursor, calendar: cal, timeZone: tz, weekStartMode: .monday)
                if p.currentWeek == nil {
                    let comps = cal.dateComponents([.year, .month, .day], from: cursor)
                    let month = comps.month!, day = comps.day!
                    let allowed = (month == 1 && day <= 3) || (month == 12 && day >= 29)
                    #expect(allowed, "\(tzName) \(comps) 意外落在网格外")
                    gapsByYear[comps.year!, default: 0] += 1
                    #expect(p.percent == 0 || p.percent == 100)
                }
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
            #expect(gapsByYear.values.allSatisfy { $0 <= 3 }, "\(tzName) 跨年周最多 3 天：\(gapsByYear)")
        }
        _ = calendar
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
                #expect(p.weeks.count == p.totalWeeks)
                #expect(p.weeks.filter { $0.state == .current }.count <= 1)
                #expect(p.pastCount + p.remainingWeeks + (p.currentWeek == nil ? 0 : 1) == p.totalWeeks)
                for (a, b) in zip(p.weeks, p.weeks.dropFirst()) { #expect(a.endExclusive == b.start) }
                if let c = p.currentWeek {
                    #expect(c.start <= cursor && cursor < c.endExclusive)
                    #expect(p.outOfGridWeek == nil)
                } else {
                    #expect(p.outOfGridWeek != nil)
                }
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
        }
    }

    @Test("周日模式同样自洽（52/53 周；跨年周也有兜底）")
    func sundayModeIsSelfConsistent() {
        for string in ["2026-01-01 12:00", "2026-10-15 12:00", "2025-12-30 12:00", "2028-02-29 12:00"] {
            let p = YearProgressCalculator.progress(for: date(string, shanghai),
                                                    timeZone: shanghai, weekStartMode: .sunday)
            #expect([52, 53].contains(p.totalWeeks), "\(string) -> \(p.totalWeeks)")
            #expect(p.currentWeek != nil || p.outOfGridWeek != nil, "\(string)")
            #expect(p.year == 2025 || p.year == 2026 || p.year == 2028)
        }
    }
}
