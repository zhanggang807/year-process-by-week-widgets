import Foundation

/// 某一天的中国法定节假日（只记录放假日；调休上班日与周末不参与标记）。
public struct HolidayDay: Hashable, Sendable {
    public let month: Int
    public let day: Int
    public let name: String

    public init(month: Int, day: Int, name: String) {
        self.month = month
        self.day = day
        self.name = name
    }
}

/// 一年的节假日表。2026 来自国务院办公厅通知：
/// https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm
/// （数据经 holiday-cn 整理，包含全部放假日期）
public struct HolidayTable: Sendable {
    public let year: Int
    public let days: [HolidayDay]

    public init(year: Int, days: [HolidayDay]) {
        self.year = year
        self.days = days
    }

    /// 某一天是否是放假日；返回节日名（不含调休补班日）。
    public func holidayName(on date: Date, calendar: Calendar) -> String? {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard c.year == year, let month = c.month, let day = c.day else { return nil }
        return days.first { $0.month == month && $0.day == day }?.name
    }

    public static func builtIn(for year: Int) -> HolidayTable? {
        year == 2026 ? .china2026 : nil
    }

    /// 2026：元旦 1/1–1/3，春节 2/15–2/23，清明 4/4–4/6，劳动节 5/1–5/5，
    /// 端午 6/19–6/21，中秋 9/25–9/27，国庆 10/1–10/7。
    public static let china2026: HolidayTable = {
        func span(_ name: String, _ from: (Int, Int), _ to: (Int, Int)) -> [HolidayDay] {
            let start = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: from.0, day: from.1))!
            let end = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: to.0, day: to.1))!
            var out: [HolidayDay] = []
            var d = start
            let cal = Calendar(identifier: .gregorian)
            while d <= end {
                let c = cal.dateComponents([.month, .day], from: d)
                out.append(HolidayDay(month: c.month!, day: c.day!, name: name))
                d = cal.date(byAdding: .day, value: 1, to: d)!
            }
            return out
        }
        return HolidayTable(year: 2026, days:
            span("元旦", (1, 1), (1, 3)) +
            span("春节", (2, 15), (2, 23)) +
            span("清明节", (4, 4), (4, 6)) +
            span("劳动节", (5, 1), (5, 5)) +
            span("端午节", (6, 19), (6, 21)) +
            span("中秋节", (9, 25), (9, 27)) +
            span("国庆节", (10, 1), (10, 7))
        )
    }()
}
