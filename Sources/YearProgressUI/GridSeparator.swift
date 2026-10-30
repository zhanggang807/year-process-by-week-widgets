import Foundation

/// 一个周方块所属的日历周期，用来判断方块右侧是否需要分隔线。
struct GridPeriod: Equatable, Sendable {
    let month: Int
    let quarter: Int
}

/// 方块右侧要画的分隔线类型。同一位置季度优先，保证不会重叠两条线。
enum GridSeparatorKind: Equatable, Sendable {
    case none
    case month
    case quarter
}

enum GridSeparatorRules {
    /// 分隔线归属于「边界之前的周方块」。
    ///
    /// 例如第 14 周从 3 月跨到 4 月，线画在第 14 周右侧，而不是第 15 周左侧。
    /// 这样即使第 14 周正好是行末，也不会因为“没有前一个方块”而漏画。
    static func separator(after index: Int,
                          periods: [GridPeriod],
                          decoration: GridDecoration) -> GridSeparatorKind {
        guard decoration.isEnabled,
              index >= 0,
              index + 1 < periods.count else { return .none }

        let current = periods[index]
        let next = periods[index + 1]
        if decoration.showsQuarters, current.quarter != next.quarter { return .quarter }
        if decoration.showsMonths, current.month != next.month { return .month }
        return .none
    }
}

/// 分隔线几何：宽 1.8pt，中心位于方块右侧间隙的正中。
enum GridSeparatorMetrics {
    static let width: CGFloat = 1.8

    /// 以方块左边缘为 0 时，分隔线中心的 x 坐标。
    ///
    /// 行内和行末使用同一条规则：都落在方块右侧 `gap / 2`。
    /// 行末没有下一块时，线会自然悬在右侧留白里，但距离与行内完全一致。
    static func centerX(cellSide: CGFloat, gap: CGFloat) -> CGFloat {
        cellSide + gap / 2
    }

    /// `.overlay(alignment: .trailing)` 下，从方块右边缘到线中心的偏移。
    static func trailingOffset(gap: CGFloat) -> CGFloat {
        gap / 2 + width / 2
    }
}
