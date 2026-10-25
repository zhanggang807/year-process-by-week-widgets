import Testing
import Foundation
@testable import YearProgressCore
import YearProgressUI

@Suite("气泡形状")
struct PopoverShapeTests {
    @Test("尾巴尖区域与身体在路径内，方角落在外")
    func geometry() {
        let rect = CGRect(x: 0, y: 0, width: 338, height: 172)
        let shape = PopoverShape(cornerRadius: 20,
                                 arrowHeight: 14,
                                 arrowHalfWidth: 12,
                                 arrowCenterX: 169)
        let path = shape.path(in: rect)

        #expect(path.contains(CGPoint(x: 169, y: 8)))      // 尾巴内部
        #expect(path.contains(CGPoint(x: 169, y: 100)))    // 身体内部
        #expect(!path.contains(CGPoint(x: 4, y: 4)))       // 左上圆角外侧
        #expect(!path.contains(CGPoint(x: 334, y: 4)))     // 右上圆角外侧
        #expect(!path.contains(CGPoint(x: 169, y: 0.5)))   // 尾巴尖之外（高于形状）
    }
}
