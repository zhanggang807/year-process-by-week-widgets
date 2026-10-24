import SwiftUI
import AppKit

/// 卡片配色。默认紫色（与参考图同一气质），黑白方块在其上都清晰可辨。
public enum CardTheme: String, CaseIterable, Identifiable, Sendable {
    case violet
    case graphite
    /// macOS 系统小组件配色：跟随浅色/深色与系统背景
    case system
    /// 暗岩灰：固定深色底，系统小组件用
    case slate

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .violet: return "紫色"
        case .graphite: return "石墨"
        case .system: return "跟随系统"
        case .slate: return "暗岩灰"
        }
    }

    public var backgroundColors: [Color] {
        switch self {
        case .violet: return [Color(red: 0.478, green: 0.263, blue: 0.937),
                              Color(red: 0.663, green: 0.333, blue: 0.949)]
        case .graphite: return [Color(red: 0.208, green: 0.208, blue: 0.227),
                                Color(red: 0.118, green: 0.118, blue: 0.133)]
        case .system: return [Color(nsColor: .windowBackgroundColor)]
        case .slate: return [Color(red: 0.200, green: 0.212, blue: 0.231),   // #33363B
                             Color(red: 0.125, green: 0.137, blue: 0.153)]   // #202327
        }
    }

    public var primaryText: Color { self == .system ? .primary : .white }
    public var secondaryText: Color { self == .system ? .secondary : Color.white.opacity(0.72) }
    public var ringTrack: Color { self == .system ? Color.primary.opacity(0.14) : Color.white.opacity(0.24) }
    public var ringProgress: Color { self == .system ? .primary : .white }

    // 两种状态都用「和底色同色系」的中明度色，不再用纯黑/纯白：
    // 纯白在深底上会视觉膨胀、纯黑会收缩（Helmholtz 错觉）。让两边的明度差接近，
    // 方块看起来就一样大了。紫色主题：深梅子 vs 浅薰衣草；石墨主题：深灰 vs 浅灰。

    /// 已过周：深色。
    public var pastFill: Color {
        switch self {
        case .violet: return Color(red: 0.184, green: 0.118, blue: 0.341)   // #2F1E57 深梅子
        case .graphite: return Color(red: 0.200, green: 0.275, blue: 0.361) // #33465C 深石板蓝
        case .system: return .primary                                        // 深色模式下自动变白
        case .slate: return Color(red: 0.200, green: 0.275, blue: 0.361)     // #33465C 深石板蓝（同面板）
        }
    }

    /// 未来周：浅色。
    public var futureFill: Color {
        switch self {
        case .violet: return Color(red: 0.812, green: 0.749, blue: 0.973)   // #CFBFF8 浅薰衣草
        case .graphite: return Color(red: 0.686, green: 0.784, blue: 0.871) // #AFC8DE 浅冰蓝
        case .system: return Color.primary.opacity(0.12)                     // 系统填充色
        case .slate: return Color(red: 0.686, green: 0.784, blue: 0.871)     // #AFC8DE 浅冰蓝（同面板）
        }
    }

    /// 只在深色（石墨）卡片上给深块留一圈极淡描边，避免和底色贴在一起。
    public var pastStroke: Color? {
        switch self {
        case .violet: return nil
        case .graphite, .slate: return Color.white.opacity(0.16)
        case .system: return nil
        }
    }
    /// 浅色块不需要描边（同色系之后不再「发胀」）。
    public var futureStroke: Color? {
        switch self {
        case .system: return Color.primary.opacity(0.14)
        default: return nil        // graphite / slate：浅色块本身够亮，不需要描边
        }
    }

    /// 本周：浅色底（还没过）+ 从底部升起的深色进度条（已过）。
    public var currentFill: Color { futureFill }
    public var currentProgressFill: Color { pastFill }
}
