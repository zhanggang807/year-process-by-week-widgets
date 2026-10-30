import Testing
import YearProgressUI

@Suite("月份/季度分隔线")
struct GridDecorationTests {
    @Test("产品默认开启，并同时显示月份与季度线")
    func defaultShowsBoth() {
        #expect(GridDecoration.productDefault == .coloredLines)
        #expect(GridDecoration.productDefault.isEnabled)
        #expect(GridDecoration.productDefault.showsMonths)
        #expect(GridDecoration.productDefault.showsQuarters)
    }

    @Test("关闭时两条线都不显示")
    func noneHidesBoth() {
        #expect(!GridDecoration.none.isEnabled)
        #expect(!GridDecoration.none.showsMonths)
        #expect(!GridDecoration.none.showsQuarters)
    }

    @Test("旧模式的语义保持不变")
    func legacyModes() {
        #expect(GridDecoration.months.showsMonths)
        #expect(!GridDecoration.months.showsQuarters)
        #expect(GridDecoration.quarters.showsQuarters)
        #expect(!GridDecoration.quarters.showsMonths)
        #expect(GridDecoration.both.showsMonths)
        #expect(GridDecoration.both.showsQuarters)
    }
}
