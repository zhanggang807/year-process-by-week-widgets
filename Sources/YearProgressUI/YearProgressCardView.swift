import SwiftUI
import YearProgressCore

/// 卡片的「外框」处理方式：
/// - `.card`：App 自己的圆角卡片（描边 + 阴影）
/// - `.widget`：系统小组件，圆角与背板由系统提供，不要再画一层
public enum CardChrome: Sendable {
    case card
    case widget
}

/// 卡片本体：顶部一行居中「2026年 · 丙午年 · 第 42/53 周 · 已过 78%」，下面是方块网格。
/// App 与系统小组件共用同一份实现。
public struct YearProgressCardView: View {
    public let progress: YearProgress
    public let theme: CardTheme
    public let size: CGSize
    public var profile: CardProfile
    public var chrome: CardChrome
    public var showsTooltips: Bool
    public var preferredColumns: Int
    /// 非 nil 时使用固定列数（桌面挂件用它对齐小组件的行列）
    public var fixedColumns: Int?

    public init(progress: YearProgress,
                theme: CardTheme,
                size: CGSize,
                profile: CardProfile = .app,
                chrome: CardChrome = .card,
                showsTooltips: Bool = true,
                preferredColumns: Int = 13,
                fixedColumns: Int? = nil) {
        self.progress = progress
        self.theme = theme
        self.size = size
        self.profile = profile
        self.chrome = chrome
        self.showsTooltips = showsTooltips
        self.preferredColumns = preferredColumns
        self.fixedColumns = fixedColumns
    }

    public var body: some View {
        let m = CardMetrics(size: size, profile: profile)
        let note = progress.boundaryNote
        let layout = GridLayoutCalculator.compute(weekCount: progress.totalWeeks,
                                                 available: m.gridArea(noteVisible: note != nil),
                                                 preferredColumns: preferredColumns,
                                                 forcedColumns: fixedColumns)

        content(m: m, layout: layout, note: note)
            .padding(m.padding)
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(
                LinearGradient(colors: theme.backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .modifier(CardChromeModifier(chrome: chrome, cornerRadius: m.cornerRadius, theme: theme))
    }

    private func content(m: CardMetrics, layout: WeekGridLayout, note: String?) -> some View {
        VStack(spacing: 0) {
            // 年份 + 干支 + 周计数 + 百分比，合并成顶部一行居中
            Text(progress.headerText(compact: m.usesCompactHeader))
                .font(.system(size: m.headerFont, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .center)

            // 只有年初/年末那 1–3 天（跨年周）才补一行小字
            if let note {
                Text(note)
                    .font(.system(size: m.noteFont, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, m.noteGap)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // 网格在「头部以下的剩余空间」里垂直居中（不随尺寸变化而偏上/偏下）
            grid(layout, metrics: m)
                .padding(.top, m.headerGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
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
                                          timeZone: progress.timeZone,
                                          showsTooltip: showsTooltips)
                        }
                    }
                }
            }
        }
        .frame(width: CGFloat(layout.gridWidth), height: CGFloat(layout.gridHeight), alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)   // 网格整体居中，左右留白对称
    }
}

/// 圆角 / 描边 / 阴影：App 卡片需要，系统小组件不需要（系统已给）。
private struct CardChromeModifier: ViewModifier {
    let chrome: CardChrome
    let cornerRadius: CGFloat
    let theme: CardTheme

    func body(content: Content) -> some View {
        switch chrome {
        case .widget:
            return AnyView(content)
        case .card:
            return AnyView(
                content
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(theme.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
            )
        }
    }
}

/// 一个方块 = 一周。已过 = 黑块，未来 = 白块，本周 = 白底 + 从底部升起的黑色进度条。
private struct WeekBlockView: View {
    let cell: WeekCell
    let side: CGFloat
    let radius: CGFloat
    let theme: CardTheme
    let timeZone: TimeZone
    let showsTooltip: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            if cell.state == .current {
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
            if let stroke {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke.color, lineWidth: stroke.width)
            }
        }
        .modifier(TooltipModifier(text: tooltip, enabled: showsTooltip))
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
        let width = max(0.8, side * 0.030)
        switch cell.state {
        case .past: return theme.pastStroke.map { ($0, width) }
        case .future: return theme.futureStroke.map { ($0, width) }
        case .current: return nil
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

/// `.help()` 只在 App 里有意义，小组件里不允许用。
private struct TooltipModifier: ViewModifier {
    let text: String
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            return AnyView(content.help(text))
        } else {
            return AnyView(content)
        }
    }
}

/// 年度进度环（首页说明窗口还在用）。
public struct ProgressRing: View {
    public let percent: Double
    public let size: CGFloat
    public let theme: CardTheme

    public init(percent: Double, size: CGFloat, theme: CardTheme) {
        self.percent = percent
        self.size = size
        self.theme = theme
    }

    public var body: some View {
        ZStack {
            Circle().stroke(theme.ringTrack, lineWidth: max(1.5, size * 0.11))
            Circle()
                .trim(from: 0, to: max(0.001, min(1, percent / 100)))
                .stroke(theme.ringProgress, style: StrokeStyle(lineWidth: max(1.5, size * 0.11), lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("年度进度 \(Int(percent.rounded()))%")
    }
}
