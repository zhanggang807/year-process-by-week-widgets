import Foundation
import YearProgressCore

/// Builds the same snapshot for the host app and widget extension. Keeping this
/// in one file prevents the two processes from drifting on week-start or holiday
/// behavior.
enum IOSProgressFactory {
    static func make(at date: Date = Date(), timeZone: TimeZone = .current) -> YearProgress {
        let calendar = WeekStartMode.monday.makeCalendar(timeZone: timeZone)
        let year = calendar.component(.year, from: date)
        let holidays = HolidayStore.table(for: year, timeZone: timeZone)
        return YearProgressCalculator.progress(
            for: date,
            calendar: calendar,
            timeZone: timeZone,
            weekStartMode: .monday,
            holidayTable: holidays
        )
    }
}
