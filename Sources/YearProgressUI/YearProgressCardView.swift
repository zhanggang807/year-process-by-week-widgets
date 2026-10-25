import SwiftUI
import YearProgressCore

/// 卡片的「外框」处理方式：
/// - `.card`：App 自己的圆角卡片（无描边、无阴影）
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
    /// 非 nil 时覆盖顶部字号
    public var headerFontOverride: CGFloat?
    /// false 时不画自己的背景（菜单栏弹窗由 PopoverShape 统一填色）
    public var drawsBackground: Bool
    /// 节假日方块上的小标记样式
    public var holidayMarker: HolidayMarkerStyle

    public init(progress: YearProgress,
                theme: CardTheme,
                size: CGSize,
                profile: CardProfile = .app,
                chrome: CardChrome = .card,
                showsTooltips: Bool = true,
                preferredColumns: Int = 13,
                fixedColumns: Int? = nil,
                headerFontOverride: CGFloat? = nil,
                drawsBackground: Bool = true,
                holidayMarker: HolidayMarkerStyle = .ring) {
        self.progress = progress
        self.theme = theme
        self.size = size
        self.profile = profile
        self.chrome = chrome
        self.showsTooltips = showsTooltips
        self.preferredColumns = preferredColumns
        self.fixedColumns = fixedColumns
        self.headerFontOverride = headerFontOverride
        self.drawsBackground = drawsBackground
        self.holidayMarker = holidayMarker
    }

    public var body: some View {
        let m = CardMetrics(size: size, profile: profile, headerFontOverride: headerFontOverride)
        let note = progress.boundaryNote
        let layout = GridLayoutCalculator.compute(weekCount: progress.totalWeeks,
                                                 available: m.gridArea(noteVisible: note != nil),
                                                 preferredColumns: preferredColumns,
                                                 forcedColumns: fixedColumns)

        content(m: m, layout: layout, note: note)
            .padding(.horizontal, m.padding)
            .frame(width: size.width, height: size.height, alignment: .top)
            .background {
                if drawsBackground {
                    LinearGradient(colors: theme.backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .modifier(CardChromeModifier(chrome: chrome, cornerRadius: m.cornerRadius))
    }

    private func content(m: CardMetrics, layout: WeekGridLayout, note: String?) -> some View {
        // 网格在剩余空间里居中后，上方会留出 slack/2 的余量；
        // 顶部文字要在这段「卡片上边缘 → 网格顶部」的区域里垂直居中。
        let area = m.gridArea(noteVisible: note != nil)
        let slack = max(0, CGFloat(area.height) - CGFloat(layout.gridHeight))
        let headerBlock = m.headerHeight + (note == nil ? 0 : m.noteGap + m.noteHeight)
        let topRegion = m.padding + headerBlock + m.headerGap + slack / 2

        return VStack(spacing: 0) {
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
            }
            .frame(maxWidth: .infinity)
            .frame(height: topRegion, alignment: .center)   // 在顶边与网格之间垂直居中

            grid(layout, metrics: m)
                .frame(height: CGFloat(layout.gridHeight), alignment: .top)

            Spacer(minLength: 0)
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
                                          showsTooltip: showsTooltips,
                                          holidayMarker: holidayMarker)
                        }
                    }
                }
            }
        }
        .frame(width: CGFloat(layout.gridWidth), height: CGFloat(layout.gridHeight), alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)   // 网格整体居中，左右留白对称
    }
}

/// 圆角：App 卡片只在本地裁圆角，系统小组件由系统裁。
private struct CardChromeModifier: ViewModifier {
    let chrome: CardChrome
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        switch chrome {
        case .widget:
            return AnyView(content)
        case .card:
            return AnyView(
                content
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
    let showsTooltip: Bool
    let holidayMarker: HolidayMarkerStyle

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            if cell.state == .current {
                // 本周：已过部分从顶部向下增长，剩余部分留在底部
                ZStack(alignment: .top) {
                    Color.clear
                    Rectangle()
                        .fill(theme.currentProgressFill)
                        .frame(height: max(0, min(1, cell.fraction)) * side)
                }
            }
            if cell.holiday != nil {
                HolidayMarker(style: holidayMarker, side: side, radius: radius, color: theme.holidayAccent)
            }
            // 第几周：水平 + 垂直居中
            number
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

    /// 本周方块跨在「已过 / 未过」分界线上时，数字按分界线切成两种颜色，
    /// 保证压在深色段和浅色段的部分都清楚。
    @ViewBuilder
    private var number: some View {
        let base = Text("\(cell.index)")
            .font(.system(size: max(6, side * 0.46), weight: .semibold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(false)

        switch cell.state {
        case .past:
            base.foregroundStyle(theme.pastLabel)
        case .future:
            base.foregroundStyle(theme.futureLabel)
        case .current:
            let f = CGFloat(min(1, max(0, cell.fraction)))
            ZStack {
                base.foregroundStyle(theme.pastLabel)
                    .mask(alignment: .top) { Rectangle().frame(height: f * side) }
                base.foregroundStyle(theme.futureLabel)
                    .mask(alignment: .bottom) { Rectangle().frame(height: (1 - f) * side) }
            }
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
        let range = cell.rangeText
        switch cell.state {
        case .past: return "第 \(cell.index) 周 · \(range) · 已过\(holidaySuffix)"
        case .current: return "第 \(cell.index) 周 · \(range) · 本周（已过 \(Int((cell.fraction * 100).rounded()))%）\(holidaySuffix)"
        case .future: return "第 \(cell.index) 周 · \(range) · 未来\(holidaySuffix)"
        }
    }

    private var holidaySuffix: String {
        guard let holiday = cell.holiday else { return "" }
        return " · \(holiday)"
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
