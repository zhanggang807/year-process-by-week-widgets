import SwiftUI
import WidgetKit
import YearProgressCore
import YearProgressUI

struct YearProgressEntry: TimelineEntry {
    let date: Date
    let progress: YearProgress
}

struct YearProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> YearProgressEntry {
        YearProgressEntry(date: .now, progress: IOSProgressFactory.make())
    }

    func getSnapshot(in context: Context, completion: @escaping (YearProgressEntry) -> Void) {
        completion(YearProgressEntry(date: .now, progress: IOSProgressFactory.make()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<YearProgressEntry>) -> Void) {
        let now = Date()
        let timeZone = TimeZone.current
        let calendar = WeekStartMode.monday.makeCalendar(timeZone: timeZone)
        let nextMidnight = YearWeekMath.nextMidnight(after: now, calendar: calendar)
        let entries = [
            YearProgressEntry(date: now, progress: IOSProgressFactory.make(at: now)),
            YearProgressEntry(date: nextMidnight, progress: IOSProgressFactory.make(at: nextMidnight)),
        ]
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }
}

struct YearProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: YearProgressEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularAccessory
        case .accessoryRectangular:
            rectangularAccessory
        default:
            homeScreenCard
        }
    }

    private var homeScreenCard: some View {
        GeometryReader { geometry in
            YearProgressCardView(
                progress: entry.progress,
                theme: .slate,
                size: geometry.size,
                profile: .widget,
                chrome: .widget,
                showsTooltips: false,
                fixedColumns: family == .systemMedium
                    ? WidgetGridReference.columns(weekCount: entry.progress.totalWeeks)
                    : nil,
                headerFontOverride: family == .systemSmall ? 13 : nil,
                drawsBackground: false
            )
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: CardTheme.slate.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var circularAccessory: some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .stroke(.primary.opacity(0.16), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.002, entry.progress.percent / 100))
                .stroke(.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(entry.progress.percent.rounded()))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("\(entry.progress.year)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
            }
        }
        .padding(5)
    }

    private var rectangularAccessory: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(entry.progress.year)年 · \(entry.progress.ganzhi.name)年")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text(
                "第 \(entry.progress.currentWeek?.index ?? entry.progress.totalWeeks) 周 · " +
                "剩 \(entry.progress.remainingWeeks) 周 · 已过 \(Int(entry.progress.percent.rounded()))%"
            )
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct YearProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YearProgressIOSWidget", provider: YearProgressProvider()) { entry in
            YearProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("年进度")
        .description("一年里的每一周：已过为深色、未来为浅色，本周与节假日周有独立标记。")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular,
        ])
        .contentMarginsDisabled()
    }
}

@main
struct YearProgressWidgetBundle: WidgetBundle {
    var body: some Widget {
        YearProgressWidget()
    }
}
