import Testing
@testable import YearProgressCore

@Suite("干支纪年")
struct GanzhiTests {
    @Test("六十甲子取样")
    func samples() {
        #expect(Ganzhi(year: 2026).yearName == "丙午年")
        #expect(Ganzhi(year: 2026).animal == "马")
        #expect(Ganzhi(year: 2025).yearName == "乙巳年")
        #expect(Ganzhi(year: 2020).yearName == "庚子年")
        #expect(Ganzhi(year: 1984).name == "甲子")   // 六十甲子起点
        #expect(Ganzhi(year: 2044).name == "甲子")
        #expect(Ganzhi(year: 1912).name == "壬子")
    }

    @Test("60 年一循环")
    func sixtyYearCycle() {
        for year in 1900...2100 {
            #expect(Ganzhi(year: year).name == Ganzhi(year: year + 60).name)
        }
    }
}
