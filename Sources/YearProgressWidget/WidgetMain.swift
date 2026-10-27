import SwiftUI
import AppKit
import WidgetKit
import YearProgressCore
import YearProgressUI

// 系统小组件（通知中心 / 桌面小组件的「编辑小组件」里添加的那种）。
// 由手工组装的 .appex 承载，见 Makefile 的 widget 目标。

struct YearProgressEntry: TimelineEntry {
    let date: Date
    let progress: YearProgress
}

/// 诊断用：系统只要调用过我们（画预览 / 取时间线），就往沙盒容器里记一行。
/// 位置：~/Library/Containers/com.local.yearprogress.widget/Data/Library/Application Support/widget-activity.log
enum WidgetActivityLog {
    static func touch(_ what: String) {
        #if DEBUG
        guard let dir = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true) else { return }
        let url = dir.appendingPathComponent("widget-activity.log")
        let line = "\(ISO8601DateFormatter().string(from: Date()))  \(what)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
    }
}

struct YearProgressProvider: TimelineProvider {

    private func makeEntry(for date: Date) -> YearProgressEntry {
        let tz = TimeZone.current
        let calendar = WeekStartMode.monday.makeCalendar(timeZone: tz)
        let year = calendar.component(.year, from: date)
        let holidays = HolidayStore.table(for: year, timeZone: tz)
        return YearProgressEntry(date: date,
                                 progress: YearProgressCalculator.progress(for: date,
                                                                          calendar: calendar,
                                                                          timeZone: tz,
                                                                          weekStartMode: .monday,
                                                                          holidayTable: holidays))
    }

    func placeholder(in context: Context) -> YearProgressEntry {
        WidgetActivityLog.touch("placeholder")
        return makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (YearProgressEntry) -> Void) {
        WidgetActivityLog.touch("snapshot")
        completion(makeEntry(for: Date()))
    }

    /// 只排两个 entry：现在 + 下一个零点，之后由系统在零点后重新要时间线。
    func getTimeline(in context: Context, completion: @escaping (Timeline<YearProgressEntry>) -> Void) {
        WidgetActivityLog.touch("timeline")
        let now = Date()
        let calendar = WeekStartMode.monday.makeCalendar(timeZone: .current)
        let next = YearWeekMath.nextMidnight(after: now, calendar: calendar)
        let entries = [makeEntry(for: now), makeEntry(for: next)]
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

struct YearProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: YearProgressEntry

    var body: some View {
        GeometryReader { geo in
            // 菜单栏里的主题/尺寸只作用于桌面挂件；小组件固定用「暗岩灰」底。
            // small 的标题字号与桌面挂件对齐（13pt）。
            // 中号组件与桌面挂件同宽高比：强制使用同一套基准列数，
            // 避免系统尺寸/字体微调后两边行列悄悄分叉；小/大号保持自适应。
            YearProgressCardView(progress: entry.progress,
                                 theme: .slate,
                                 size: geo.size,
                                 profile: .widget,
                                 chrome: .widget,
                                 showsTooltips: false,
                                 fixedColumns: family == .systemMedium
                                     ? WidgetGridReference.columns(weekCount: entry.progress.totalWeeks)
                                     : nil,
                                 headerFontOverride: family == .systemSmall ? 13 : nil,
                                 drawsBackground: false)
        }
        // macOS 14 / iOS 17 起，小组件必须用 containerBackground 声明背板，否则系统显示占位提示。
        // 背景交给系统容器，卡面本身保持透明：桌面小组件宿主的某些渲染方案会
        // 移除开发者背景（或保留透明），卡面再画一层不透明底会减少可匹配的方案。
        .containerBackground(for: .widget) {
            LinearGradient(colors: CardTheme.slate.backgroundColors,
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
    }
}

struct YearProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YearProgressWidget", provider: YearProgressProvider()) { entry in
            YearProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("年进度")
        .description("一年里的每一周：已过为深色、未来为浅色；含节假日的周带描边标记。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct YearProgressWidgetBundle: WidgetBundle {
    var body: some Widget {
        YearProgressWidget()
    }
}
