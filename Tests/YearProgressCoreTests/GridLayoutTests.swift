import Testing
import Foundation
@testable import YearProgressCore

@Suite("网格布局")
struct GridLayoutTests {
    let area = (width: 552.0, height: 146.0)   // 600×292 卡片里留给网格的空间

    @Test("52 周：默认 13 列 × 4 行方阵")
    func fiftyTwoWeeks() {
        let l = GridLayoutCalculator.compute(weekCount: 52, available: area)
        #expect(l.columns == 13)
        #expect(l.rows == 4)
        #expect(l.autoSelectedColumns == false)
        #expect(l.lastRowCount(weekCount: 52) == 13)
        #expect(l.cellSize > 0)
        #expect(l.gridWidth <= area.width + 0.001)
        #expect(l.gridHeight <= area.height + 0.001)
    }

    @Test("53 周：自动换列，避免最后一行只剩 1 个方块")
    func fiftyThreeWeeks() {
        let l = GridLayoutCalculator.compute(weekCount: 53, available: area)
        #expect(l.columns != 13, "53 周年份应自动选列，而不是留 1 个孤块")
        #expect(l.autoSelectedColumns)
        #expect(l.rows * l.columns >= 53)
        #expect(l.rows * l.columns - 53 <= l.columns, "空位不应超过一整行")
        #expect(l.cellSize > 0)
        #expect(l.gridWidth <= area.width + 0.001)
        #expect(l.gridHeight <= area.height + 0.001)
    }

    @Test("方块始终是正方形且放得下（多种容器）")
    func fitsEveryContainer() {
        for size in [(200.0, 90.0), (552.0, 146.0), (900.0, 700.0), (80.0, 80.0)] {
            for n in [52, 53] {
                let l = GridLayoutCalculator.compute(weekCount: n, available: size)
                #expect(l.cellSize >= 1)
                #expect(l.gridWidth <= size.0 + 0.001)
                #expect(l.gridHeight <= size.1 + 0.001)
                #expect(l.rows == Int(ceil(Double(n) / Double(l.columns))))
            }
        }
    }

    @Test("每行方块数之和等于总周数")
    func rowsCoverAllWeeks() {
        for n in [52, 53] {
            let l = GridLayoutCalculator.compute(weekCount: n, available: area)
            let covered = (0..<l.rows).reduce(0) { $0 + l.cellsInRow($1, weekCount: n) }
            #expect(covered == n)
            #expect(l.lastRowCount(weekCount: n) == l.cellsInRow(l.rows - 1, weekCount: n))
            #expect(l.rowRange(0, weekCount: n).lowerBound == 0)
        }
    }
}
