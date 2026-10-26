import Foundation
import YearProgressCore
import YearProgressUI

/// 极简命令行解析：`--snapshot out.png --date 2026-10-15 --theme violet --size 600x292`
struct CLIOptions {
    var snapshotPath: String?
    var date: Date?
    var theme: CardTheme = .violet
    var size = CGSize(width: CardMetrics.referenceWidth, height: CardMetrics.referenceHeight)
    /// 只有命令行显式传了 --theme / --size 才覆盖 App 里的设置（否则每次启动都会把用户偏好写回默认值）
    var themeOverride: CardTheme?
    var sizeOverride: CGSize?
    var scale: CGFloat = 2
    var margin: CGFloat = 36
    var weekStartMode: WeekStartMode = .monday
    var timeZone: TimeZone = .current
    /// 导出时的渲染档位：app（圆角卡片，无描边/阴影）/ widget（系统小组件，无外框）
    var chrome: CardChrome = .card
    /// 导出时强制列数（调试用，便于对比面板/小组件布局）
    var columns: Int?
    /// 导出时覆盖顶部字号（模拟 small 小组件）
    var headerFontOverride: CGFloat?
    /// 开发用：启动后自动弹出菜单栏 quick panel
    var showQuick = false
    /// 开发用：模拟点击菜单栏按钮，验证 action 绑定
    var testClick = false
    /// 导出菜单栏弹窗（带小三角）的预览
    var popoverPreview = false
    /// 节假日标记样式
    var holidayMarker: HolidayMarkerStyle = .triangle
    /// 开发用：模拟"挂菜单→摘菜单→重新绑定→左键点击"的完整序列
    var testMenuClick = false

    static func parse(_ argv: [String]) -> CLIOptions {
        var o = CLIOptions()
        var i = 1
        func next() -> String? { i + 1 < argv.count ? argv[i + 1] : nil }

        // 先扫时区（影响日期解析）
        if let tzIndex = argv.firstIndex(of: "--timezone"), tzIndex + 1 < argv.count,
           let tz = TimeZone(identifier: argv[tzIndex + 1]) {
            o.timeZone = tz
        }

        while i < argv.count {
            let arg = argv[i]
            switch arg {
            case "--snapshot":
                if let v = next() { o.snapshotPath = v; i += 1 }
            case "--date":
                if let v = next() { o.date = parseDate(v, timeZone: o.timeZone); i += 1 }
            case "--theme":
                if let v = next(), let t = CardTheme(rawValue: v) { o.theme = t; o.themeOverride = t; i += 1 }
            case "--size":
                if let v = next(), let s = parseSize(v) { o.size = s; o.sizeOverride = s; i += 1 }
            case "--scale":
                if let v = next(), let s = Double(v), s > 0 { o.scale = CGFloat(s); i += 1 }
            case "--margin":
                if let v = next(), let m = Double(v), m >= 0 { o.margin = CGFloat(m); i += 1 }
            case "--timezone":
                i += 1
            case "--show-quick":
                o.showQuick = true
            case "--test-click":
                o.testClick = true
            case "--popover":
                o.popoverPreview = true
            case "--marker":
                if let v = next(), let m = HolidayMarkerStyle(rawValue: v) { o.holidayMarker = m; i += 1 }
            case "--test-menu-click":
                o.testMenuClick = true
            case "--header-font":
                if let v = next(), let n = Double(v), n > 0 { o.headerFontOverride = CGFloat(n); i += 1 }
            case "--columns":
                if let v = next(), let n = Int(v), n > 0 { o.columns = n; i += 1 }
            case "--chrome":
                if let v = next() { o.chrome = (v == "widget") ? .widget : .card; i += 1 }
            case "--week-start":
                if let v = next(), let w = WeekStartMode(rawValue: v) { o.weekStartMode = w; i += 1 }
            case "--help", "-h":
                print(Self.usage); exit(0)
            default:
                break
            }
            i += 1
        }
        return o
    }

    static let usage = """
    年进度小组件（macOS）

    用法:
      YearProgressMac                                    # 启动桌面小组件（菜单栏图标）
      YearProgressMac --snapshot preview.png             # 离屏渲染成 PNG（用于自查/分享）
      YearProgressMac --date 2026-10-15 --snapshot p.png # 指定「今天」

    参数:
      --snapshot <path>     导出 PNG 后退出
      --date <yyyy-MM-dd>   把「今天」固定为某一天
      --theme violet|graphite|system|slate
      --size <W>x<H>        默认 600x292
      --scale <n>           导出倍率，默认 2
      --margin <pt>         导出留白，默认 36
      --timezone <id>       例如 Asia/Shanghai
      --week-start monday|sunday|locale
      --chrome card|widget   导出样式：card（App 大卡片）/ widget（系统小组件，无外框）
      --marker none|dot|bar|triangle|ring|stripe   节假日标记样式（预览用）
    """

    static func parseDate(_ s: String, timeZone: TimeZone) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: s) {
                return format == "yyyy-MM-dd" ? d.addingTimeInterval(12 * 3600) : d
            }
        }
        return nil
    }

    static func parseSize(_ s: String) -> CGSize? {
        let parts = s.lowercased().split(separator: "x")
        guard parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]), w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }
}
