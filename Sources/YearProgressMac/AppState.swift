import SwiftUI
import YearProgressCore
import YearProgressUI

/// 视图状态 + 刷新调度（跨零点、唤醒、时区变更）。
@MainActor
final class AppState: ObservableObject {

    @Published private(set) var progress: YearProgress
    @Published var theme: CardTheme { didSet { defaults.set(theme.rawValue, forKey: Self.themeKey) } }
    @Published var cardSize: CGSize { didSet { defaults.set(NSStringFromSize(cardSize), forKey: Self.sizeKey) } }

    var weekStartMode: WeekStartMode = .monday

    /// 调试用：把「今天」固定成某一天（`--date`）。
    private let dateOverride: Date?
    private let defaults = AppDefaults.store
    private static let themeKey = AppDefaults.Key.theme
    private static let sizeKey = AppDefaults.Key.cardSize
    private var timer: Timer?

    static let sizePresets: [(name: String, size: CGSize)] = [
        ("大（600×292）", CGSize(width: 600, height: 292)),
        ("中（450×219）", CGSize(width: 450, height: 219)),
        ("小（338×158 · 同系统中号小组件）", CGSize(width: 338, height: 158)),
    ]
    /// 桌面挂件默认尺寸 = macOS 中号小组件。
    static let defaultSize = CGSize(width: 338, height: 158)

    init(dateOverride: Date? = nil) {
        self.dateOverride = dateOverride
        Self.migratePreferencesIfNeeded()
        let savedTheme = AppDefaults.store.string(forKey: Self.themeKey).flatMap(CardTheme.init(rawValue:))
        self.theme = savedTheme ?? .graphite          // 默认石墨
        if let s = AppDefaults.store.string(forKey: Self.sizeKey) {
            let parsed = NSSizeFromString(s)
            self.cardSize = parsed.width > 100 ? parsed : Self.defaultSize
        } else {
            self.cardSize = Self.defaultSize          // 默认小尺寸
        }
        self.progress = Self.makeProgress(for: dateOverride ?? Date(), weekStartMode: .monday)
        observeEnvironment()
        scheduleMidnightRefresh()
    }

    /// 默认值变化时清掉旧偏好（旧版本写过 theme/size），只迁移一次。
    private static let settingsVersion = 3
    private static func migratePreferencesIfNeeded() {
        let defaults = AppDefaults.store
        guard defaults.integer(forKey: AppDefaults.Key.settingsVersion) < settingsVersion else { return }
        defaults.removeObject(forKey: themeKey)
        defaults.removeObject(forKey: sizeKey)
        defaults.set(settingsVersion, forKey: AppDefaults.Key.settingsVersion)
    }

    func refresh() {
        progress = Self.makeProgress(for: dateOverride ?? Date(), weekStartMode: weekStartMode)
        scheduleMidnightRefresh()
    }

    /// 统一走 HolidayStore（缓存 → 打包 → 内建 → 法定兜底）
    private static func makeProgress(for date: Date, weekStartMode: WeekStartMode) -> YearProgress {
        let tz = TimeZone.current
        let calendar = weekStartMode.makeCalendar(timeZone: tz)
        let year = calendar.component(.year, from: date)
        let holidays = HolidayStore.table(for: year, timeZone: tz)
        return YearProgressCalculator.progress(for: date,
                                               calendar: calendar,
                                               timeZone: tz,
                                               weekStartMode: weekStartMode,
                                               holidayTable: holidays)
    }

    /// 下一个零点自动刷新。
    private func scheduleMidnightRefresh() {
        timer?.invalidate()
        let calendar = weekStartMode.makeCalendar(timeZone: .current)
        let next = YearWeekMath.nextMidnight(after: Date(), calendar: calendar)
        let timer = Timer(timeInterval: max(5, next.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func observeEnvironment() {
        let center = NotificationCenter.default
        // 系统跨天（含睡眠后跨天）
        center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        center.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        center.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        center.addObserver(forName: .holidayDataUpdated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
}
