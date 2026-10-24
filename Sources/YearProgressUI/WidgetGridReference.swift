import Foundation
import YearProgressCore

/// 桌面挂件复用「系统中号小组件」的网格列数，保证两边行列一致。
/// 基准尺寸取 macOS 中号小组件的典型大小（338×158）。
public enum WidgetGridReference {
    public static let referenceSize = CGSize(width: 338, height: 158)

    public static func columns(weekCount: Int) -> Int {
        let metrics = CardMetrics(size: referenceSize, profile: .widget)
        let layout = GridLayoutCalculator.compute(weekCount: weekCount,
                                                  available: metrics.gridArea(noteVisible: false),
                                                  preferredColumns: 13)
        return layout.columns
    }
}
