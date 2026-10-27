import Testing
import Foundation
@testable import YearProgressCore

@Suite("节假日数据管线")
struct HolidayDataTests {

    /// 仓库里的 2026 官方安排
    func fixtureURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YearProgressCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Support/holidays/2026.json")
    }

    @Test("打包的 2026 JSON 可解析（33 个放假日）")
    func bundled2026() throws {
        let data = try Data(contentsOf: fixtureURL())
        let file = try JSONDecoder().decode(HolidayFile.self, from: data)
        let table = try HolidayTable(file: file, expectedYear: 2026)
        #expect(table.days.count == 33)
        #expect(Set(table.days.map(\.name)).count == 7)
        #expect(table.days.contains { $0.name == "春节" })
        #expect(table.fileRepresentation.year == 2026)
        #expect(table.fileRepresentation.days.count == 33)
    }

    @Test("校验拒绝错误年份")
    func rejectsWrongYear() throws {
        let file = HolidayFile(year: 2027, days: [
            .init(date: "2027-01-01", name: "元旦", isOffDay: true)
        ])
        #expect(throws: HolidayValidationError.self) {
            try HolidayTable(file: file, expectedYear: 2026)
        }
    }

    @Test("校验拒绝过少放假日与重复日期")
    func rejectsBadContent() throws {
        let tooFew = HolidayFile(year: 2026, days: [
            .init(date: "2026-01-01", name: "元旦", isOffDay: true)
        ])
        #expect(throws: HolidayValidationError.self) {
            try HolidayTable(file: tooFew, expectedYear: 2026)
        }

        let duplicate = HolidayFile(year: 2026, days: (0..<6).map { i in
            .init(date: "2026-01-01", name: "元旦", isOffDay: true)
        })
        #expect(throws: HolidayValidationError.self) {
            try HolidayTable(file: duplicate, expectedYear: 2026)
        }
    }

    @Test("2027 法定兜底：固定节日 + 农历节日都在")
    func statutoryFallback2027() {
        let tz = TimeZone(identifier: "Asia/Shanghai")!
        let table = HolidayTable.statutory(for: 2027, timeZone: tz)
        let names = Set(table.days.map(\.name))
        for required in ["元旦", "春节", "清明节", "劳动节", "端午节", "中秋节", "国庆节"] {
            #expect(names.contains(required), "缺少 \(required)")
        }
        #expect(table.days.contains { $0.month == 1 && $0.day == 1 })
        #expect(table.days.contains { $0.month == 5 && $0.day == 1 })
        #expect(table.days.filter { $0.name == "国庆节" }.count == 3)

        // 用 Chinese 日历独立求 2027 正月初一，验证兜底里确实有这一天
        var gregorian = Calendar(identifier: .gregorian); gregorian.timeZone = tz
        var chinese = Calendar(identifier: .chinese); chinese.timeZone = tz
        var cursor = gregorian.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        var cny: (month: Int, day: Int)?
        while gregorian.component(.year, from: cursor) == 2027 {
            let c = chinese.dateComponents([.month, .day], from: cursor)
            if c.month == 1, c.day == 1 {
                let g = gregorian.dateComponents([.month, .day], from: cursor)
                cny = (g.month!, g.day!)
                break
            }
            cursor = gregorian.date(byAdding: .day, value: 1, to: cursor)!
        }
        #expect(cny != nil)
        if let cny {
            #expect(table.days.contains { $0.month == cny.month && $0.day == cny.day && $0.name == "春节" })
        }
    }

    @Test("校验拒绝不存在的日历日期")
    func rejectsInvalidCalendarDate() {
        let file = HolidayFile(year: 2026, days: [
            .init(date: "2026-02-30", name: "测试", isOffDay: true),
            .init(date: "2026-01-01", name: "元旦", isOffDay: true),
            .init(date: "2026-05-01", name: "劳动节", isOffDay: true),
            .init(date: "2026-10-01", name: "国庆节", isOffDay: true),
            .init(date: "2026-10-02", name: "国庆节", isOffDay: true),
            .init(date: "2026-10-03", name: "国庆节", isOffDay: true)
        ])
        #expect(throws: HolidayValidationError.self) {
            try HolidayTable(file: file, expectedYear: 2026)
        }
    }
}
