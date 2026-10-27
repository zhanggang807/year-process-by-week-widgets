import Testing
import Foundation
@testable import YearProgressCore
import YearProgressUI

@Suite("桌面挂件与小组件网格一致")
struct PanelGridTests {

    @Test("基准列数：52 周 = 13 列，53 周 = 14 列")
    func referenceColumns() {
        #expect(WidgetGridReference.columns(weekCount: 52) == 13)
        #expect(WidgetGridReference.columns(weekCount: 53) == 14)
    }

    @Test("桌面挂件（330×161）强制基准列数后，与中号小组件同为 14×4、末行 11 块")
    func panelMatchesWidget() {
        let panel = CardMetrics(size: CGSize(width: 330, height: 161), profile: .app)
        let layout = GridLayoutCalculator.compute(weekCount: 53,
                                                 available: panel.gridArea(noteVisible: false),
                                                 forcedColumns: WidgetGridReference.columns(weekCount: 53))
        #expect(layout.columns == 14)
        #expect(layout.rows == 4)
        #expect(layout.lastRowCount(weekCount: 53) == 11)
    }

    @Test("中号小组件自身算出来也是 14×4")
    func widgetMatchesReference() {
        let widget = CardMetrics(size: WidgetGridReference.referenceSize, profile: .widget)
        let layout = GridLayoutCalculator.compute(weekCount: 53,
                                                  available: widget.gridArea(noteVisible: false))
        #expect(layout.columns == 14)
        #expect(layout.rows == 4)
    }

    @Test("54 周（公历年重叠周模型）也能得到完整布局")
    func fiftyFourWeeksLayout() {
        let columns = WidgetGridReference.columns(weekCount: 54)
        let widget = CardMetrics(size: WidgetGridReference.referenceSize, profile: .widget)
        let layout = GridLayoutCalculator.compute(weekCount: 54,
                                                  available: widget.gridArea(noteVisible: false),
                                                  forcedColumns: columns)
        print("54 weeks: columns=\(columns), rows=\(layout.rows), lastRow=\(layout.lastRowCount(weekCount: 54))")
        #expect(layout.rows * layout.columns >= 54)
        #expect(layout.lastRowCount(weekCount: 54) > 0)
    }
}
