import Foundation

/// 方块网格的尺寸计算：给定容器大小，算出列数 / 行数 / 方块边长 / 间距。
public struct WeekGridLayout: Hashable, Sendable {
    public let columns: Int
    public let rows: Int
    public let cellSize: Double
    public let gap: Double
    /// 是否由「自动选列」得出（53 周年份等），而非固定列数。
    public let autoSelectedColumns: Bool

    public var gridWidth: Double { Double(columns) * cellSize + Double(columns - 1) * gap }
    public var gridHeight: Double { Double(rows) * cellSize + Double(rows - 1) * gap }
    /// 第 row 行实际有几个方块（最后一行常常不满）。
    public func cellsInRow(_ row: Int, weekCount: Int) -> Int {
        guard row >= 0, row < rows else { return 0 }
        return min(columns, max(0, weekCount - row * columns))
    }

    /// 第 row 行对应的周下标区间。
    public func rowRange(_ row: Int, weekCount: Int) -> Range<Int> {
        let start = row * columns
        return start..<(start + cellsInRow(row, weekCount: weekCount))
    }

    /// 最后一行实际有几个方块。
    public func lastRowCount(weekCount: Int) -> Int {
        cellsInRow(rows - 1, weekCount: weekCount)
    }
}

public enum GridLayoutCalculator {

    /// 间距 = 边长 * gapRatio（方块之间的视觉呼吸感随尺寸缩放）。
    public static let gapRatio: Double = 0.18

    /// - Parameters:
    ///   - weekCount: 总周数（52 / 53）
    ///   - available: 可放置网格的矩形大小
    ///   - preferredColumns: 首选列数，默认 13（52 周 = 4×13 方阵）
    ///   - autoColumns: 首选列数无法整除时，是否自动挑一个更协调的列数（53 周年份用）
    public static func compute(weekCount: Int,
                               available: (width: Double, height: Double),
                               preferredColumns: Int = 13,
                               autoColumns: Bool = true,
                               forcedColumns: Int? = nil,
                               candidates: [Int] = [7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 26]) -> WeekGridLayout {
        let n = max(1, weekCount)
        let targetAspect = available.height > 0 ? available.width / available.height : 1

        var columns = max(1, forcedColumns ?? preferredColumns)
        var auto = false
        if forcedColumns == nil, autoColumns && n % columns != 0 {
            columns = bestColumns(weekCount: n, targetAspect: targetAspect, candidates: candidates) ?? columns
            auto = columns != preferredColumns
        }

        let rows = Int(ceil(Double(n) / Double(columns)))
        let cell = bestCellSize(columns: columns, rows: rows, available: available)
        return WeekGridLayout(columns: columns, rows: rows,
                          cellSize: cell, gap: cell * gapRatio,
                          autoSelectedColumns: auto)
    }

    /// 让方块尽量大：宽高两个方向都放得下。
    public static func bestCellSize(columns: Int, rows: Int, available: (width: Double, height: Double)) -> Double {
        let byWidth = available.width / (Double(columns) + gapRatio * Double(columns - 1))
        let byHeight = available.height / (Double(rows) + gapRatio * Double(rows - 1))
        // 下界 1pt：极端小容器里宁可溢出一点，也不要算出 0/负数导致布局崩溃
        return max(1, min(byWidth, byHeight))
    }

    /// 在候选列数里挑一个「空格少、整体比例接近容器」的方案。
    static func bestColumns(weekCount n: Int, targetAspect: Double, candidates: [Int]) -> Int? {
        var best: (columns: Int, score: Double)?
        for c in candidates where c > 0 && c <= n {
            let r = Int(ceil(Double(n) / Double(c)))
            let waste = (Double(c * r) - Double(n)) / Double(c * r)          // 空位占比
            let aspect = (Double(c) + gapRatio * Double(c - 1)) / (Double(r) + gapRatio * Double(r - 1))
            let aspectPenalty = abs(log(aspect / max(0.01, targetAspect)))   // 比例偏差
            // 末行只剩寥寥几块很难看（例：53 周用 13 列 → 最后一行只有 1 块），重罚
            let lastRow = n - (r - 1) * c
            let fill = Double(lastRow) / Double(c)
            let sparsePenalty = fill < 0.5 ? 1.2 * (0.5 - fill) / 0.5 : 0
            let score = waste + 1.2 * aspectPenalty + sparsePenalty
            if best == nil || score < best!.score - 1e-9 { best = (c, score) }
        }
        return best?.columns
    }
}
