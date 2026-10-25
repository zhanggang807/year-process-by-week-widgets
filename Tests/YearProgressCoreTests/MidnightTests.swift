import Testing
import Foundation
@testable import YearProgressCore

@Suite("零点刷新")
struct MidnightTests {
    func date(_ s: String, _ tz: TimeZone) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    @Test("跨月 / 跨年 / DST 都落在下一个 0 点")
    func nextMidnightEdges() {
        let sh = TimeZone(identifier: "Asia/Shanghai")!
        var cal = WeekStartMode.monday.makeCalendar(timeZone: sh)

        let feb = YearWeekMath.nextMidnight(after: date("2026-01-31 23:59", sh), calendar: cal)
        #expect(cal.component(.month, from: feb) == 2)
        #expect(cal.component(.day, from: feb) == 1)
        #expect(cal.component(.hour, from: feb) == 0)

        let nextYear = YearWeekMath.nextMidnight(after: date("2026-12-31 23:59", sh), calendar: cal)
        #expect(cal.component(.year, from: nextYear) == 2027)

        // DST 结束的那天（25 小时）
        let ny = TimeZone(identifier: "America/New_York")!
        cal = WeekStartMode.monday.makeCalendar(timeZone: ny)
        let dst = YearWeekMath.nextMidnight(after: date("2026-10-31 23:59", ny), calendar: cal)
        #expect(cal.component(.month, from: dst) == 11)
        #expect(cal.component(.day, from: dst) == 1)
        #expect(cal.component(.hour, from: dst) == 0)
    }
}
