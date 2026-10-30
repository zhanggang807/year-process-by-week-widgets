import Foundation

/// 宿主 App 与 Widget 扩展之间的轻量偏好桥。
///
/// 宿主 App 未沙盒，可以把设置写到 Widget 的容器；Widget 在自己的沙盒里
/// 通过 Application Support 读取同一份 JSON。正式分发改成 App Group 后，
/// 只需替换这里的路径实现。
public enum WidgetPreferences {
    public static let gridDecorationKey = "gridDecoration"

    public static func readGridDecoration() -> String? {
        guard let data = try? Data(contentsOf: widgetFileURL()),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object[gridDecorationKey] as? String
    }

    public static func writeGridDecoration(_ rawValue: String) {
        let url = widgetFileURL()
        let dir = url.deletingLastPathComponent()
        var object: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = existing
        }
        object[gridDecorationKey] = rawValue
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static func widgetFileURL() -> URL {
        #if os(macOS)
        // 宿主 App（非沙盒）写 Widget 容器；Widget 在自己的沙盒里用
        // Application Support 也会映射到同一个 Data/Library/Application Support。
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.local.yearprogress.widget/Data/Library/Application Support/YearProgress/preferences.json")
        #else
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("YearProgress/preferences.json")
        #endif
    }
}
