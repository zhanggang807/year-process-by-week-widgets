import Foundation
import YearProgressCore

// 生成 spec/year-weeks.json：Swift 与未来 Kotlin 实现共用的「一年有几周」真值表。
// 用法: swift run year-weeks-dump [输出路径]

struct YearEntry: Codable {
    let year: Int
    let weeks: Int
    let firstWeekStart: String
    let lastWeekStart: String
    let lastWeekEnd: String
}

struct ProbeEntry: Codable {
    let date: String
    let year: Int              // 展示年份 = 当前公历年
    let weekIndex: Int         // 第几周；0 表示本周不在该网格内（跨年周）
    let totalWeeks: Int
    let state: String          // current / none（跨年周）
    let isoWeekYear: Int       // 真正所属的周年度
    let isoWeekIndex: Int      // 真正属于第几周
}

struct Fixture: Codable {
    let generatedAt: String
    let rule: String
    let timeZone: String
    let weekStart: String
    let years: [YearEntry]
    let probes: [ProbeEntry]
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "spec/year-weeks.json"

let tz = TimeZone(identifier: "UTC")!
let calendar = WeekStartMode.monday.makeCalendar(timeZone: tz)
let dayFormat = DateFormatter()
dayFormat.locale = Locale(identifier: "en_US_POSIX")
dayFormat.timeZone = tz
dayFormat.dateFormat = "yyyy-MM-dd"
let stampFormat = ISO8601DateFormatter()

let yearRange = 2015...2035
var years: [YearEntry] = []
var probes: [ProbeEntry] = []

for year in yearRange {
    let count = YearWeekMath.weeksInYear(year, calendar: calendar)
    guard let first = YearWeekMath.weekRange(index: 1, weekYear: year, calendar: calendar),
          let last = YearWeekMath.weekRange(index: count, weekYear: year, calendar: calendar) else { continue }
    years.append(YearEntry(year: year,
                           weeks: count,
                           firstWeekStart: dayFormat.string(from: first.start),
                           lastWeekStart: dayFormat.string(from: last.start),
                           lastWeekEnd: dayFormat.string(from: last.endExclusive.addingTimeInterval(-1))))

    // 探针：每月 1/8/15/22 日 + 12/31，用于跨端一致性校验
    var comps = DateComponents()
    for month in 1...12 {
        for day in [1, 8, 15, 22] {
            comps.year = year; comps.month = month; comps.day = day; comps.hour = 12
            guard let d = calendar.date(from: comps) else { continue }
            let p = YearProgressCalculator.progress(for: d, calendar: calendar, timeZone: tz, weekStartMode: .monday)
            probes.append(ProbeEntry(date: dayFormat.string(from: d),
                                     year: p.year,
                                     weekIndex: p.currentWeek?.index ?? 0,
                                     totalWeeks: p.totalWeeks,
                                     state: p.currentWeek?.state.rawValue ?? "none",
                                     isoWeekYear: calendar.component(.yearForWeekOfYear, from: d),
                                     isoWeekIndex: calendar.component(.weekOfYear, from: d)))
        }
    }
    comps.year = year; comps.month = 12; comps.day = 31; comps.hour = 12
    if let d = calendar.date(from: comps) {
        let p = YearProgressCalculator.progress(for: d, calendar: calendar, timeZone: tz, weekStartMode: .monday)
            probes.append(ProbeEntry(date: dayFormat.string(from: d),
                                     year: p.year,
                                     weekIndex: p.currentWeek?.index ?? 0,
                                     totalWeeks: p.totalWeeks,
                                     state: p.currentWeek?.state.rawValue ?? "none",
                                     isoWeekYear: calendar.component(.yearForWeekOfYear, from: d),
                                     isoWeekIndex: calendar.component(.weekOfYear, from: d)))
    }
}

let fixture = Fixture(generatedAt: stampFormat.string(from: Date()),
                      rule: "ISO 8601 (Monday first, minimumDaysInFirstWeek = 4)",
                      timeZone: "UTC",
                      weekStart: "monday",
                      years: years,
                      probes: probes)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let data = try encoder.encode(fixture)
let url = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: url)
print("已写出 \(outputPath)：\(years.count) 个年份、\(probes.count) 个探针日期")
print(years.map { "\($0.year):\($0.weeks)" }.joined(separator: "  "))
