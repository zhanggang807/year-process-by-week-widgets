import Foundation
import YearProgressCore

/// 极简命令行解析：`--snapshot out.png --date 2026-10-15 --theme violet --size 600x292`
struct CLIOptions {
    var snapshotPath: String?
    var date: Date?
    var theme: CardTheme = .violet
    var size = CGSize(width: CardMetrics.referenceWidth, height: CardMetrics.referenceHeight)
    var scale: CGFloat = 2
    var margin: CGFloat = 36
    var weekStartMode: WeekStartMode = .monday
    var timeZone: TimeZone = .current

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
                if let v = next(), let t = CardTheme(rawValue: v) { o.theme = t; i += 1 }
            case "--size":
                if let v = next(), let s = parseSize(v) { o.size = s; i += 1 }
            case "--scale":
                if let v = next(), let s = Double(v) { o.scale = CGFloat(s); i += 1 }
            case "--margin":
                if let v = next(), let m = Double(v) { o.margin = CGFloat(m); i += 1 }
            case "--timezone":
                i += 1
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
      --theme violet|graphite
      --size <W>x<H>        默认 600x292
      --scale <n>           导出倍率，默认 2
      --margin <pt>         导出留白（露出阴影），默认 36
      --timezone <id>       例如 Asia/Shanghai
      --week-start monday|sunday|locale
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
