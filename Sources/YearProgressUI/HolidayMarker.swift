import SwiftUI

/// 有节假日的那一周，方块上的小标记样式。
public enum HolidayMarkerStyle: String, CaseIterable, Sendable {
    case none       // 不显示（待选型）
    case dot        // 右上角小圆点
    case bar        // 底部短横条
    case triangle   // 右上角折角三角
    case ring       // 一圈描边
    case stripe     // 顶部细条

    public var displayName: String {
        switch self {
        case .none: return "不显示"
        case .dot: return "圆点"
        case .bar: return "底条"
        case .triangle: return "折角"
        case .ring: return "描边"
        case .stripe: return "顶条"
        }
    }
}

/// 方块内的假期标记。颜色用暖红，和冷色方块区分开。
struct HolidayMarker: View {
    let style: HolidayMarkerStyle
    let side: CGFloat
    let radius: CGFloat
    let color: Color

    var body: some View {
        switch style {
        case .none:
            EmptyView()

        case .dot:
            Circle()
                .fill(color)
                .frame(width: max(2.6, side * 0.17), height: max(2.6, side * 0.17))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(max(2, side * 0.12))

        case .bar:
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(color)
                .frame(width: side * 0.56, height: max(1.8, side * 0.095))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, max(2, side * 0.12))

        case .triangle:
            CornerTriangle()
                .fill(color)
                .frame(width: side * 0.36, height: side * 0.36)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

        case .ring:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: max(1.2, side * 0.065))

        case .stripe:
            Rectangle()
                .fill(color)
                .frame(height: max(1.8, side * 0.095))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, side * 0.14)
        }
    }
}

/// 右上角的小三角（会被方块自己的圆角裁成折角效果）
struct CornerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
