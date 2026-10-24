import Foundation

/// 桌面挂件的偏好域（`.app` 与 `swift run` 共用）。
/// 注意：系统小组件**不读这里**——它用 macOS 自带配色，与面板设置无关。
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
