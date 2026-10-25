import Foundation
import WidgetKit
import YearProgressCore

extension Notification.Name {
    static let holidayDataUpdated = Notification.Name("com.local.yearprogress.holidayDataUpdated")
}

/// 从公开发布源抓取节假日安排（holiday-cn 镜像，原始来源是国务院通知）。
enum HolidayFetcher {
    static func fetch(year: Int) async throws -> HolidayTable {
        let url = URL(string: "https://api.github.com/repos/NateScarlet/holiday-cn/contents/\(year).json?ref=master")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github.raw", forHTTPHeaderField: "Accept")
        request.setValue("YearProgress/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let file = try JSONDecoder().decode(HolidayFile.self, from: data)
        return try HolidayTable(file: file, expectedYear: year)
    }
}

/// 年度节假日数据的后台更新：当前年 + 次年，缺失或过期时抓取；
/// 成功后写缓存、刷新桌面挂件、通知 UI。
@MainActor
enum HolidayUpdater {
    private static let attemptKeyPrefix = "holidayFetchAttempt."

    static func refreshIfNeeded(force: Bool = false, now: Date = Date()) {
        let calendar = WeekStartMode.monday.makeCalendar(timeZone: .current)
        let current = calendar.component(.year, from: now)
        for year in [current, current + 1] {
            // 缓存或打包数据已存在就不抓（避免每年/每次启动重复请求）
            if !force, (HolidayStore.cachedTable(for: year) ?? HolidayStore.bundledTable(for: year)) != nil { continue }
            if !force, let last = lastAttempt(year), now.timeIntervalSince(last) < 12 * 3600 { continue }
            setLastAttempt(year, now)

            Task { @MainActor in
                do {
                    let table = try await HolidayFetcher.fetch(year: year)
                    try HolidayStore.save(table)
                    WidgetCenter.shared.reloadAllTimelines()
                    NotificationCenter.default.post(name: .holidayDataUpdated, object: nil)
                } catch {
                    // 保持现有数据（bundle / 内建 / 法定兜底），下次再试
                }
            }
        }
    }

    private static func lastAttempt(_ year: Int) -> Date? {
        let t = AppDefaults.store.double(forKey: attemptKeyPrefix + "\(year)")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    private static func setLastAttempt(_ year: Int, _ date: Date) {
        AppDefaults.store.set(date.timeIntervalSince1970, forKey: attemptKeyPrefix + "\(year)")
    }
}
