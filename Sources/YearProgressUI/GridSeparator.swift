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
    /// - 行内：落在本方块与下一方块之间间隙的正中。
    /// - 行末：没有下一块，线贴在本方块右边缘内侧，避免悬空到网格外的留白里。
    static func centerX(cellSide: CGFloat, gap: CGFloat, isRowEnd: Bool) -> CGFloat {
        isRowEnd ? cellSide - width / 2 : cellSide + gap / 2
    }

    /// `.overlay(alignment: .trailing)` 下，从方块右边缘到线中心的偏移。
    static func trailingOffset(gap: CGFloat, isRowEnd: Bool) -> CGFloat {
        isRowEnd ? 0 : gap / 2 + width / 2
    }
}
