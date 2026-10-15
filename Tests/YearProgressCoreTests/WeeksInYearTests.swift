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
}
