import Testing
import Foundation
@testable import YearProgressCore

@Suite("一年有几个周")
struct WeeksInYearTests {
    let calendar = WeekStartMode.monday.makeCalendar(timeZone: TimeZone(identifier: "Asia/Shanghai")!)

    @Test("已知年份：52 / 53 的经典取值")
    func knownValues() {
        #expect(YearWeekMath.weeksInYear(2015, calendar: calendar) == 53)
        #expect(YearWeekMath.weeksInYear(2020, calendar: calendar) == 53)
        #expect(YearWeekMath.weeksInYear(2024, calendar: calendar) == 52)
        #expect(YearWeekMath.weeksInYear(2025, calendar: calendar) == 52)
        #expect(YearWeekMath.weeksInYear(2026, calendar: calendar) == 53)
        #expect(YearWeekMath.weeksInYear(2027, calendar: calendar) == 52)
        #expect(YearWeekMath.weeksInYear(2032, calendar: calendar) == 53)
    }

    @Test("与独立 ISO 规则交叉校验（1990...2060）")
    func crossCheckAgainstIndependentRule() {
        for year in 1990...2060 {
            let byCalendar = YearWeekMath.weeksInYear(year, calendar: calendar)
            let byRule = YearWeekMath.isoWeeksInYearByRule(year)
            #expect(byCalendar == byRule, "\(year) 年：日历算 \(byCalendar)，规则算 \(byRule)")
        }
    }

    @Test("时区不影响周数判定")
    func timeZoneIndependent() {
        for tzName in ["UTC", "Asia/Shanghai", "America/New_York", "Pacific/Kiritimati"] {
            let cal = WeekStartMode.monday.makeCalendar(timeZone: TimeZone(identifier: tzName)!)
            #expect(YearWeekMath.weeksInYear(2026, calendar: cal) == 53, "\(tzName)")
            #expect(YearWeekMath.weeksInYear(2025, calendar: cal) == 52, "\(tzName)")
        }
    }

    @Test("公历年重叠周：53/54 周，且 2012/2040 为 54")
    func overlappingWeeks() {
        #expect(YearWeekMath.weeksOverlapping(year: 2025, calendar: calendar) == 53)
        #expect(YearWeekMath.weeksOverlapping(year: 2026, calendar: calendar) == 53)
        #expect(YearWeekMath.weeksOverlapping(year: 2027, calendar: calendar) == 53)
        #expect(YearWeekMath.weeksOverlapping(year: 2012, calendar: calendar) == 54)
        #expect(YearWeekMath.weeksOverlapping(year: 2040, calendar: calendar) == 54)
    }

    @Test("公历年重叠周：YearProgress 实际产生 54 周")
    func yearProgressCanProduce54Weeks() {
        let cal = WeekStartMode.monday.makeCalendar(timeZone: TimeZone(identifier: "UTC")!)
        let mid = cal.date(from: DateComponents(year: 2012, month: 6, day: 1, hour: 12))!
        let p = YearProgressCalculator.progress(for: mid, calendar: cal,
                                                timeZone: TimeZone(identifier: "UTC")!,
                                                weekStartMode: .monday)
        #expect(p.totalWeeks == 54)
        #expect(p.currentWeek != nil)
        #expect(p.weeks.first?.index == 1)
        #expect(p.weeks.last?.index == 54)
    }
}
