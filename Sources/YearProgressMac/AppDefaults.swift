import Foundation

/// 桌面挂件的偏好域（`.app` 与 `swift run` 共用）。
///
/// 放在 Mac 壳而不是 Core：这里存的是"这台机器上的 UI 配置"，
/// Core 要能被 iOS/其它平台复用，不能依赖 UserDefaults / NSSize 这类平台概念。
/// 系统小组件（沙盒）也不读这里，它固定用暗岩灰主题。
public enum AppDefaults {
    public static let suiteName = "com.local.yearprogress"
    public static let store: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    public enum Key {
        public static let theme = "theme"
        public static let cardSize = "cardSize"
        public static let settingsVersion = "settingsVersion"
        public static let panelLevel = "panelLevel"
        public static let panelVisible = "panelVisible"
        public static let didShowWelcome = "didShowWelcome"
    }

}
