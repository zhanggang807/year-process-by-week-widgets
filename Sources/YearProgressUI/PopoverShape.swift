import SwiftUI

/// 菜单栏弹窗的外形：圆角矩形 + 顶部居中的「圆角小三角」气泡尾巴。
public struct PopoverShape: Shape {
    public var cornerRadius: CGFloat
    public var arrowHeight: CGFloat
    public var arrowHalfWidth: CGFloat
    /// nil 表示水平居中；有值时是尾巴尖在窗口内的 x
    public var arrowCenterX: CGFloat?

    public init(cornerRadius: CGFloat = 20,
                arrowHeight: CGFloat = 11,
                arrowHalfWidth: CGFloat = 14,
                arrowCenterX: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
        self.arrowHeight = arrowHeight
        self.arrowHalfWidth = arrowHalfWidth
        self.arrowCenterX = arrowCenterX
    }

    public func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.height / 2, rect.width / 2)
        let a = arrowHeight
        // 窗口过窄时缩小尾巴宽度并退化为居中，避免左右边越过窗口。
        let half = min(arrowHalfWidth, max(1, (rect.width - 2 * (r + 2)) / 2))
        // 尾巴尖始终在顶部（y=0）；限制在圆角内侧，窗口过窄时退化为居中
        let desired = arrowCenterX ?? rect.midX
        let lower = r + half + 2
        let upper = rect.width - r - half - 2
        let cx = upper >= lower ? min(max(desired, lower), upper) : rect.midX
        let left = cx - half
        let right = cx + half
        let w = rect.width
        let h = rect.height

        var p = Path()
        p.move(to: CGPoint(x: r, y: a))                       // 左上角之后
        p.addLine(to: CGPoint(x: left, y: a))

        // 三角形尾巴：两条直边 + 顶点倒圆角（小半径，整体仍是三角）
        let tipRadius: CGFloat = 4
        let tanHalf = half / max(1, a)                 // tan(顶点半角)
        let tangent = tipRadius / tanHalf               // 圆角切点到顶点的距离
        let sideLength = hypot(half, a)
        let u = min(tangent / sideLength, 0.85)         // 沿边方向的比例
        let leftTip = CGPoint(x: cx - half * u, y: a * u)
        let rightTip = CGPoint(x: cx + half * u, y: a * u)

        p.addLine(to: leftTip)                          // 左直边上行
        p.addQuadCurve(to: rightTip,                    // 顶点圆角（切线连续）
                       control: CGPoint(x: cx, y: 0))
        p.addLine(to: CGPoint(x: right, y: a))          // 右直边下行

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
