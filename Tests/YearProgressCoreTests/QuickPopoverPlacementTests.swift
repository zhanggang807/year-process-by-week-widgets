import Testing
import Foundation
@testable import YearProgressCore
import YearProgressUI

@Suite("菜单栏弹窗定位")
struct QuickPopoverPlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1470, height: 887)
    let window = CGSize(width: 338, height: 172)

    @Test("正常情况：居中于图标，尾巴在窗口中间")
    func centered() {
        let anchor = CGRect(x: 615, y: 892, width: 34, height: 22)
        let r = QuickPopoverPlacement.compute(anchor: anchor, visibleFrame: screen, windowSize: window)
        #expect(abs(r.frame.midX - anchor.midX) < 0.001)
        #expect(abs(r.tailX - window.width / 2) < 0.001)
        #expect(r.frame.maxY <= screen.maxY + 0.001)
        #expect(r.frame.minY >= screen.minY)
    }

    @Test("靠左夹边，尾巴跟着图标偏左（仍在圆角内）")
    func clampLeft() {
        let anchor = CGRect(x: 5, y: 892, width: 34, height: 22)
        let r = QuickPopoverPlacement.compute(anchor: anchor, visibleFrame: screen, windowSize: window)
        #expect(abs(r.frame.minX - (screen.minX + QuickPopoverMetrics.edgeMargin)) < 0.001)
        #expect(r.tailX < window.width / 2)
        #expect(r.tailX >= QuickPopoverMetrics.cornerRadius + QuickPopoverMetrics.arrowHalfWidth)
    }

    @Test("靠右夹边，尾巴跟着图标偏右（仍在圆角内）")
    func clampRight() {
        let anchor = CGRect(x: 1430, y: 892, width: 34, height: 22)
        let r = QuickPopoverPlacement.compute(anchor: anchor, visibleFrame: screen, windowSize: window)
        #expect(abs(r.frame.maxX - (screen.maxX - QuickPopoverMetrics.edgeMargin)) < 0.001)
        #expect(r.tailX > window.width / 2)
        #expect(r.tailX <= window.width - QuickPopoverMetrics.cornerRadius - QuickPopoverMetrics.arrowHalfWidth)
    }

    @Test("窗口比屏幕还窄时也不会产生非法坐标")
    func tinyScreen() {
        let tiny = CGRect(x: 0, y: 0, width: 200, height: 200)
        let r = QuickPopoverPlacement.compute(anchor: CGRect(x: 90, y: 210, width: 20, height: 20),
                                              visibleFrame: tiny, windowSize: window)
        #expect(r.frame.width == window.width)
        #expect(r.frame.minX >= tiny.minX)
        #expect(r.tailX.isFinite)
    }
}
