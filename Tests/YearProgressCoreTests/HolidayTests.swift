import Testing
import Foundation
@testable import YearProgressCore

@Suite("2026 节假日标记")
struct HolidayTests {
    let tz = TimeZone(identifier: "Asia/Shanghai")!

    func date(_ string: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: string)!
    }

    func progress(_ string: String, table: HolidayTable? = nil) -> YearProgress {
        let calendar = WeekStartMode.monday.makeCalendar(timeZone: tz)
        return YearProgressCalculator.progress(for: date(string), calendar: calendar,
                                               timeZone: tz, weekStartMode: .monday,
                                               holidayTable: table)
    }

    @Test("2026 年有工作日假期的 10 个周")
    func holidayWeeks2026() {
        let p = progress("2026-06-01 12:00")
        let weeks = p.weeks.filter { $0.holiday != nil }.map(\.index)
        #expect(weeks == [1, 8, 9, 15, 18, 19, 25, 39, 40, 41])
        // 第 53 周跨到 2027-01-01，不能被 2026 的表误标
        #expect(p.weeks.last?.holiday == nil)
    }

    @Test("只有周末的假期不算")
    func weekendHolidayIgnored() {
        // 2026-01-03 是周六
        let table = HolidayTable(year: 2026, days: [HolidayDay(month: 1, day: 3, name: "测试")])
        let p = progress("2026-06-01 12:00", table: table)
        #expect(p.weeks.allSatisfy { $0.holiday == nil })
    }

    @Test("工作日假期会标记，且年份必须匹配")
    func weekdayHolidayAndYearScope() {
        // 2026-06-03 是周三，属于第 23 周
        let table = HolidayTable(year: 2026, days: [HolidayDay(month: 6, day: 3, name: "测试")])
        let p = progress("2026-06-01 12:00", table: table)
        #expect(p.weeks.first { $0.index == 23 }?.holiday == "测试")

        let calendar = WeekStartMode.monday.makeCalendar(timeZone: tz)
        #expect(HolidayTable.china2026.holidayName(on: date("2027-01-01 12:00"), calendar: calendar) == nil)
    }
}
