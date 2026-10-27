import Foundation

/// 某一天的中国法定节假日（只记录放假日；调休上班日不参与标记）。
public struct HolidayDay: Hashable, Sendable, Codable {
    public let month: Int
    public let day: Int
    public let name: String

    public init(month: Int, day: Int, name: String) {
        self.month = month
        self.day = day
        self.name = name
    }
}

/// 节假日数据文件（与 holiday-cn 的 JSON 兼容；未知字段会被忽略）。
public struct HolidayFile: Codable, Sendable {
    public struct Day: Codable, Sendable {
        public let date: String      // yyyy-MM-dd
        public let name: String
        public let isOffDay: Bool
    }

    public let year: Int
    public let days: [Day]
    public let papers: [String]?

    public init(year: Int, days: [Day], papers: [String]? = nil) {
        self.year = year
        self.days = days
        self.papers = papers
    }
}

public enum HolidayValidationError: Error, Equatable {
    case yearMismatch(expected: Int, found: Int)
    case invalidDate(String)
    case duplicateDate(String)
    case tooFewOffDays(Int)
    case emptyName(String)
}

/// 一年的节假日表。
public struct HolidayTable: Sendable {
    public let year: Int
    public let days: [HolidayDay]

    public init(year: Int, days: [HolidayDay]) {
        self.year = year
        self.days = days
    }

    /// 某一天是否是放假日；返回节日名（不含调休补班日，年份必须匹配）。
    public func holidayName(on date: Date, calendar: Calendar) -> String? {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard c.year == year, let month = c.month, let day = c.day else { return nil }
        return days.first { $0.month == month && $0.day == day }?.name
    }
}

// MARK: - 解析 / 校验 / 序列化

public extension HolidayTable {

    /// 从官方安排文件解析（只保留 isOffDay=true 的放假日）。
    init(file: HolidayFile, expectedYear: Int) throws {
        guard file.year == expectedYear else {
            throw HolidayValidationError.yearMismatch(expected: expectedYear, found: file.year)
        }
        var seen = Set<String>()
        var out: [HolidayDay] = []
        // 只校验日期本身，时区用 UTC 即可；节假日 JSON 是“年月日”而不是瞬间时间。
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        for day in file.days where day.isOffDay {
            let parts = day.date.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
                  y == expectedYear, (1...12).contains(m), (1...31).contains(d),
                  let parsed = calendar.date(from: DateComponents(year: y, month: m, day: d)) else {
                throw HolidayValidationError.invalidDate(day.date)
            }
            // Calendar 会把 2/30 之类归一化到 3/2；回读 components 才能确认原日期合法。
            let normalized = calendar.dateComponents([.year, .month, .day], from: parsed)
            guard normalized.year == y, normalized.month == m, normalized.day == d else {
                throw HolidayValidationError.invalidDate(day.date)
            }
            guard !seen.contains(day.date) else { throw HolidayValidationError.duplicateDate(day.date) }
            seen.insert(day.date)
            guard !day.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HolidayValidationError.emptyName(day.date)
            }
            out.append(HolidayDay(month: m, day: d, name: day.name))
        }
        guard out.count >= 5 else { throw HolidayValidationError.tooFewOffDays(out.count) }
        self.init(year: expectedYear, days: out)
    }

    var fileRepresentation: HolidayFile {
        let days = days.map {
            HolidayFile.Day(date: String(format: "%04d-%02d-%02d", year, $0.month, $0.day),
                            name: $0.name, isOffDay: true)
        }
        return HolidayFile(year: year, days: days, papers: ["https://www.gov.cn/zhengce/zhengceku/"])
    }

    /// 没有官方数据时的兜底：只包含法定节假日（不含调休/延长）。
    /// 春节=正月初一~初三，端午=五月初五，中秋=八月十五，清明按节气近似公式。
    static func statutory(for year: Int, timeZone: TimeZone = .current) -> HolidayTable {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = timeZone

        var days: [HolidayDay] = []
        func add(_ month: Int, _ day: Int, _ name: String) {
            days.append(HolidayDay(month: month, day: day, name: name))
        }

        add(1, 1, "元旦")
        add(5, 1, "劳动节")
        add(10, 1, "国庆节"); add(10, 2, "国庆节"); add(10, 3, "国庆节")

        // 清明：21 世纪近似公式（2000–2099）
        let yy = year % 100
        let qingming = Int(floor(Double(yy) * 0.2422 + 4.81)) - yy / 4
        add(4, min(6, max(4, qingming)), "清明节")

        guard let start = gregorian.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return HolidayTable(year: year, days: days)
        }
        var cursor = start
        while gregorian.component(.year, from: cursor) == year {
            let c = chinese.dateComponents([.month, .day], from: cursor)
            if let m = c.month, let d = c.day {
                let g = gregorian.dateComponents([.month, .day], from: cursor)
                if let gm = g.month, let gd = g.day {
                    if m == 1 && d == 1 {          // 春节：正月初一 + 2 天
                        add(gm, gd, "春节")
                        for offset in 1...2 {
                            if let next = gregorian.date(byAdding: .day, value: offset, to: cursor),
                               let n = gregorian.dateComponents([.month, .day], from: next).day,
                               let nm = gregorian.dateComponents([.month, .day], from: next).month {
                                add(nm, n, "春节")
                            }
                        }
                    }
                    if m == 5 && d == 5 { add(gm, gd, "端午节") }
                    if m == 8 && d == 15 { add(gm, gd, "中秋节") }
                }
            }
            guard let next = gregorian.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return HolidayTable(year: year, days: days)
    }

    /// 内建 2026（官方安排）——用作没有 bundle 资源时的兜底（如 `swift run` 预览）。
    static func builtIn(for year: Int) -> HolidayTable? {
        year == 2026 ? .china2026 : nil
    }

    static let china2026: HolidayTable = {
        func span(_ name: String, _ from: (Int, Int), _ to: (Int, Int)) -> [HolidayDay] {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
            let start = cal.date(from: DateComponents(year: 2026, month: from.0, day: from.1))!
            let end = cal.date(from: DateComponents(year: 2026, month: to.0, day: to.1))!
            var out: [HolidayDay] = []
            var d = start
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
