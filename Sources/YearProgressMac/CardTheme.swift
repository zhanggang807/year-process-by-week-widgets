import SwiftUI

/// 卡片配色。默认紫色（与参考图同一气质），黑白方块在其上都清晰可辨。
enum CardTheme: String, CaseIterable, Identifiable {
    case violet
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .violet: return "紫色"
        case .graphite: return "石墨"
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .violet: return [Color(red: 0.478, green: 0.263, blue: 0.937),
                              Color(red: 0.663, green: 0.333, blue: 0.949)]
        case .graphite: return [Color(red: 0.208, green: 0.208, blue: 0.227),
                                Color(red: 0.118, green: 0.118, blue: 0.133)]
        }
    }

    var primaryText: Color { .white }
    var secondaryText: Color { Color.white.opacity(0.72) }
    var cardBorder: Color { Color.white.opacity(0.16) }
    var ringTrack: Color { Color.white.opacity(0.24) }
    var ringProgress: Color { .white }

    /// 已过周：白块。
    var pastFill: Color { .white }
    /// 未来周：黑块。
    var futureFill: Color { .black }
    /// 未来周在深色卡片上需要一层细描边，否则会糊进背景。
    var futureStroke: Color? {
        switch self {
        case .violet: return nil
        case .graphite: return Color.white.opacity(0.22)
        }
    }
    /// 本周：白底 + 黑描边 + 从底部升起的黑色进度条。
    var currentFill: Color { .white }
    var currentStroke: Color { .black }
    var currentProgressFill: Color { .black }
}
