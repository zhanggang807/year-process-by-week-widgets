import SwiftUI
import YearProgressCore

/// 卡片本体：左上「2026年 / 丙午年 · 第 42/53 周」，右上进度环，中间方块网格，底部一行统计。
struct YearProgressCardView: View {
    let progress: YearProgress
    let theme: CardTheme
    let size: CGSize
    var preferredColumns: Int = 13

    var body: some View {
        let m = CardMetrics(size: size)
        let layout = GridLayoutCalculator.compute(weekCount: progress.totalWeeks,
                                                 available: m.gridArea,
                                                 preferredColumns: preferredColumns)

        VStack(alignment: .leading, spacing: 0) {
            header(m)
            Spacer().frame(height: m.headerGap)
            grid(layout, metrics: m)
            Spacer(minLength: 0)
            Text(progress.footerText)
                .font(.system(size: m.footerFont, weight: .medium))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(m.padding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(
            LinearGradient(colors: theme.backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: m.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: m.cornerRadius, style: .continuous)
                .strokeBorder(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: 顶部

    private func header(_ m: CardMetrics) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 3 * m.scale) {
                Text(progress.yearTitle)
                    .font(.system(size: m.titleFont, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                Text(progress.subtitle)
                    .font(.system(size: m.subtitleFont, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
            ProgressRing(percent: progress.percent, size: m.ringSize, theme: theme)
        }
        .frame(height: m.headerHeight, alignment: .top)
    }

    // MARK: 网格

    private func grid(_ layout: WeekGridLayout, metrics m: CardMetrics) -> some View {
        let cells = progress.weeks
        let radius = CGFloat(layout.cellSize) * 0.22
        return VStack(alignment: .leading, spacing: CGFloat(layout.gap)) {
            ForEach(0..<layout.rows, id: \.self) { row in
                HStack(spacing: CGFloat(layout.gap)) {
                    ForEach(layout.rowRange(row, weekCount: progress.totalWeeks), id: \.self) { index in
                        if index < cells.count {
                            WeekBlockView(cell: cells[index],
                                          side: CGFloat(layout.cellSize),
                                          radius: radius,
                                          theme: theme,
                                          timeZone: progress.timeZone)
                        }
                    }
                }
            }
        }
        .frame(width: CGFloat(layout.gridWidth), height: CGFloat(layout.gridHeight), alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)   // 网格整体居中，左右留白对称
    }
}

/// 一个方块 = 一周。
private struct WeekBlockView: View {
    let cell: WeekCell
    let side: CGFloat
    let radius: CGFloat
    let theme: CardTheme
    let timeZone: TimeZone

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            if cell.state == .current {
                // 本周：白色部分是「还没过完的」，从底部升起的黑色部分 = 本周已过的比例。
                ZStack(alignment: .bottom) {
                    Color.clear
                    Rectangle()
                        .fill(theme.currentProgressFill)
                        .frame(height: max(0, min(1, cell.fraction)) * side)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            if let stroke = stroke {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke.color, lineWidth: stroke.width)
            }
        }
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }

    private var fill: Color {
        switch cell.state {
        case .past: return theme.pastFill
        case .future: return theme.futureFill
        case .current: return theme.currentFill
        }
    }

    private var stroke: (color: Color, width: CGFloat)? {
        switch cell.state {
        case .past: return nil
        case .future: return theme.futureStroke.map { ($0, 1) }
        case .current: return (theme.currentStroke, max(1, side * 0.045))
        }
    }

    private var tooltip: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        fmt.timeZone = timeZone
        let range = "\(fmt.string(from: cell.start))–\(fmt.string(from: cell.end))"
        switch cell.state {
        case .past: return "第 \(cell.index) 周 · \(range) · 已过"
        case .current: return "第 \(cell.index) 周 · \(range) · 本周（已过 \(Int((cell.fraction * 100).rounded()))%）"
        case .future: return "第 \(cell.index) 周 · \(range) · 未来"
        }
    }
}

/// 右上角的年度进度环。
struct ProgressRing: View {
    let percent: Double
    let size: CGFloat
    let theme: CardTheme

    var body: some View {
        ZStack {
            Circle().stroke(theme.ringTrack, lineWidth: max(2, size * 0.11))
            Circle()
                .trim(from: 0, to: max(0.001, min(1, percent / 100)))
                .stroke(theme.ringProgress, style: StrokeStyle(lineWidth: max(2, size * 0.11), lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("年度进度 \(Int(percent.rounded()))%")
    }
}
