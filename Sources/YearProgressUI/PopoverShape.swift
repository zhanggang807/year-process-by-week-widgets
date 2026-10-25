import SwiftUI

/// 菜单栏弹窗的外形：圆角矩形 + 顶部居中的「圆角小三角」气泡尾巴。
public struct PopoverShape: Shape {
    public var cornerRadius: CGFloat
    public var arrowHeight: CGFloat
    public var arrowHalfWidth: CGFloat
    public var arrowCenterX: CGFloat

    public init(cornerRadius: CGFloat = 20,
                arrowHeight: CGFloat = 11,
                arrowHalfWidth: CGFloat = 14,
                arrowCenterX: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
        self.arrowHeight = arrowHeight
        self.arrowHalfWidth = arrowHalfWidth
        self.arrowCenterX = arrowCenterX ?? 0
    }

    public func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.height / 2, rect.width / 2)
        let a = arrowHeight
        let half = arrowHalfWidth
        // 尾巴尖始终在顶部（y=0），左右夹住，避免出圆角
        let cx = min(max(arrowCenterX == 0 ? rect.midX : arrowCenterX, r + half + 2), rect.width - r - half - 2)
        let left = cx - half
        let right = cx + half
        let w = rect.width
        let h = rect.height

        var p = Path()
        p.move(to: CGPoint(x: r, y: a))                       // 左上角之后
        p.addLine(to: CGPoint(x: left, y: a))

        // 左肩 → 圆润的尖
        p.addCurve(to: CGPoint(x: cx, y: 0),
                   control1: CGPoint(x: left + half * 0.42, y: a * 0.62),
                   control2: CGPoint(x: cx - half * 0.22, y: 0))
        // 尖 → 右肩
        p.addCurve(to: CGPoint(x: right, y: a),
                   control1: CGPoint(x: cx + half * 0.22, y: 0),
                   control2: CGPoint(x: right - half * 0.42, y: a * 0.62))

        p.addLine(to: CGPoint(x: w - r, y: a))
        p.addQuadCurve(to: CGPoint(x: w, y: a + r), control: CGPoint(x: w, y: a))
        p.addLine(to: CGPoint(x: w, y: h - r))
        p.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: r, y: h))
        p.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: a + r))
        p.addQuadCurve(to: CGPoint(x: r, y: a), control: CGPoint(x: 0, y: a))
        p.closeSubpath()
        return p
    }
}
