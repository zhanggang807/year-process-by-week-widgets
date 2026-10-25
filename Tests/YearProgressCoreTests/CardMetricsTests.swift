import Testing
import Foundation
@testable import YearProgressCore
import YearProgressUI

@Suite("字号码尺")
struct CardMetricsTests {
    @Test("面板字号有下界（窄卡片不会缩到看不清）")
    func appFloor() {
        let m = CardMetrics(size: CGSize(width: 300, height: 158), profile: .app)
        #expect(m.headerFont == 13)   // clamp(7.05, 11...26) + 2
    }

    @Test("小组件字号有下界")
    func widgetFloor() {
        let m = CardMetrics(size: CGSize(width: 158, height: 158), profile: .widget)
        #expect(m.headerFont == 11.5) // clamp(4.9, 9.5...14) + 2
    }

    @Test("small 小组件可以覆盖成 13pt")
    func override() {
        let m = CardMetrics(size: CGSize(width: 158, height: 158), profile: .widget, headerFontOverride: 13)
        #expect(m.headerFont == 13)
    }
}
