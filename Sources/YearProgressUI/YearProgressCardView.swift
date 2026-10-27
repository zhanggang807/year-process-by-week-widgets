import SwiftUI
import YearProgressCore

/// 卡片的「外框」处理方式：
/// - `.card`：App 自己的圆角卡片（无描边、无阴影）
/// - `.widget`：系统小组件，圆角与背板由系统提供，不要再画一层
public enum CardChrome: Sendable {
    case card
    case widget
}

/// 卡片本体：顶部一行居中（年份 · 干支 · 第 N 周 · 剩 M 周 · 已过 X%），下面是方块网格。
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
    /// 系统强制 accented 渲染时（例如 macOS 开启「降低透明度」），
    /// 自定义颜色会被压成同一个 tint；这里改用不同透明度保留已过/未来层级。
    public var accented: Bool

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
                holidayMarker: HolidayMarkerStyle = .triangle,
                accented: Bool = false) {
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
        self.accented = accented
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
                                          holidayMarker: holidayMarker,
                                          accented: accented)
                        }
                    }
                }
                // 53 周时最后一行只有 11 块；在整行宽度内居中，避免右侧留空不对称。
                // 满行居中和左对齐等价，不会改变正常行的列对齐。
                .frame(width: CGFloat(layout.gridWidth), alignment: .center)
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

/// 一个方块 = 一周。已过=深色、未来=浅色；本周的深色部分从顶部向下增长；
/// 节假日周按 `holidayMarker` 叠加标记；数字用 `.monospacedDigit` 保证列对齐。
private struct WeekBlockView: View {
    let cell: WeekCell
    let side: CGFloat
    let radius: CGFloat
    let theme: CardTheme
    let showsTooltip: Bool
    let holidayMarker: HolidayMarkerStyle
    let accented: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            if cell.state == .current {
                // 本周：已过部分从顶部向下增长，剩余部分留在底部
                ZStack(alignment: .top) {
                    Color.clear
                    Rectangle()
                        .fill(accented ? Color.white.opacity(0.95) : theme.currentProgressFill)
                        .frame(height: max(0, min(1, cell.fraction)) * side)
                }
            }
            if cell.holiday != nil {
                HolidayMarker(style: holidayMarker, side: side, radius: radius,
                              color: accented ? Color.white.opacity(0.95) : theme.holidayAccent)
            }
            // 第几周：水平 + 垂直居中
            number
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            if cell.state == .current {
                // 本周：金黄色 ring（节假日是红色折角，用颜色区分）。
                // 线宽与 HolidayMarkerStyle.ring 保持一致（1.2pt 起）。
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(accented ? Color.white : theme.currentRing,
                                  lineWidth: max(1.2, side * 0.065))
                    .shadow(color: accented ? Color.white.opacity(0.35) : theme.currentRing.opacity(0.35),
                            radius: 1.5)
            } else if let stroke {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke.color, lineWidth: stroke.width)
            }
        }
        .modifier(TooltipModifier(text: tooltip, enabled: showsTooltip))
        .accessibilityLabel(tooltip)
    }

    private var fill: Color {
        // accented 模式下不要再用 theme 的彩色 fill：WidgetKit 会把它们统一 tint，
        // 导致所有方块看起来一样亮。用不同透明度制造层级；系统把高透明度映射成强调色，
        // 所以视觉上是“已过亮、未来暗”，和彩色模式的深浅方向相反，但信息仍然可读。
        if accented {
            switch cell.state {
            case .past: return Color.white.opacity(0.86)
            case .future, .current: return Color.white.opacity(0.10)
            }
        }
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
            base.foregroundStyle(accented ? Color.black.opacity(0.78) : theme.pastLabel)
        case .future:
            base.foregroundStyle(accented ? Color.white.opacity(0.96) : theme.futureLabel)
        case .current:
            let f = CGFloat(min(1, max(0, cell.fraction)))
            ZStack {
                base.foregroundStyle(accented ? Color.black.opacity(0.78) : theme.pastLabel)
                    .mask(alignment: .top) { Rectangle().frame(height: f * side) }
                base.foregroundStyle(accented ? Color.white.opacity(0.96) : theme.futureLabel)
                    .mask(alignment: .bottom) { Rectangle().frame(height: (1 - f) * side) }
            }
        }
    }

    private var stroke: (color: Color, width: CGFloat)? {
        if accented {
            // 未来块几乎是透明的，用淡描边把「还没到的周」画出来；
            // 已过块保持实心，两者形成实心/空心对比，比单纯明暗更清楚。
            return cell.state == .future
                ? (Color.white.opacity(0.30), max(0.8, side * 0.035))
                : nil
        }
        let width = max(0.8, side * 0.030)
        switch cell.state {
        case .past: return theme.pastStroke.map { ($0, width) }
        case .future: return theme.futureStroke.map { ($0, width) }
        case .current: return nil   // 本周由上面的红色 ring 处理
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
        // .help 是 macOS-only；小组件传 enabled=false，但 iOS 编译时也不能出现该调用
        #if canImport(AppKit)
        if enabled {
            return AnyView(content.help(text))
        }
        #endif
        return AnyView(content)
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
