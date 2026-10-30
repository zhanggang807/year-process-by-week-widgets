import Testing
import CoreGraphics
@testable import YearProgressUI

@Suite("月份/季度分隔线位置")
struct GridSeparatorTests {
    private let jan = GridPeriod(month: 1, quarter: 1)
    private let feb = GridPeriod(month: 2, quarter: 1)
    private let apr = GridPeriod(month: 4, quarter: 2)

    @Test("月份边界归属于边界前的方块右侧")
    func monthBelongsToPreviousBlock() {
        let periods = [jan, jan, feb]
        #expect(GridSeparatorRules.separator(after: 1, periods: periods, decoration: .coloredLines) == .month)
    }

    @Test("月份和季度同时落在同一方块右侧时只画季度")
    func quarterWinsOverMonth() {
        let periods = [jan, apr]
        #expect(GridSeparatorRules.separator(after: 0, periods: periods, decoration: .coloredLines) == .quarter)
    }

    @Test("关闭或只显示单一类型时规则正确")
    func decorationModes() {
        let periods = [jan, feb, apr]
        #expect(GridSeparatorRules.separator(after: 0, periods: periods, decoration: .none) == .none)
        #expect(GridSeparatorRules.separator(after: 0, periods: periods, decoration: .months) == .month)
        #expect(GridSeparatorRules.separator(after: 0, periods: periods, decoration: .quarters) == .none)
        #expect(GridSeparatorRules.separator(after: 1, periods: periods, decoration: .quarters) == .quarter)
    }

    @Test("最后一个方块没有右侧边界")
    func lastBlockHasNoSeparator() {
        #expect(GridSeparatorRules.separator(after: 1, periods: [jan, feb], decoration: .coloredLines) == .none)
    }

    @Test("行内线中心严格落在方块右侧间隙中心")
    func interiorGeometry() {
        let side: CGFloat = 18.6
        let gap: CGFloat = 3.348
        let center = GridSeparatorMetrics.centerX(cellSide: side, gap: gap, isRowEnd: false)
        #expect(abs(center - (side + gap / 2)) < 0.0001)

        // trailing overlay 的初始中心在 side - width/2，偏移后应回到间隙中心。
        let overlayCenter = side - GridSeparatorMetrics.width / 2
            + GridSeparatorMetrics.trailingOffset(gap: gap, isRowEnd: false)
        #expect(abs(overlayCenter - center) < 0.0001)
    }

    @Test("行末线贴方块右边缘，不悬空到网格外")
    func rowEndGeometry() {
        let side: CGFloat = 18.6
        let gap: CGFloat = 3.348
        let center = GridSeparatorMetrics.centerX(cellSide: side, gap: gap, isRowEnd: true)
        #expect(abs(center - (side - GridSeparatorMetrics.width / 2)) < 0.0001)

        let overlayCenter = side - GridSeparatorMetrics.width / 2
            + GridSeparatorMetrics.trailingOffset(gap: gap, isRowEnd: true)
        #expect(abs(overlayCenter - center) < 0.0001)
    }
}
