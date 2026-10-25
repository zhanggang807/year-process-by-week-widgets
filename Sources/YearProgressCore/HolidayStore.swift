import Foundation

/// 节假日数据的三级来源：缓存 → App 内打包 → 内建/法定兜底。
///
/// - App 和 Widget 共用这套读取逻辑（各自沙盒里的 Application Support 不同）
/// - 宿主 App 抓取到新数据后，会额外镜像到 Widget 的容器目录（best effort）
public enum HolidayStore {

    private static let lock = NSLock()
    private static var memory: [Int: HolidayTable] = [:]

    // MARK: 读取

    public static func table(for year: Int, timeZone: TimeZone = .current) -> HolidayTable {
        lock.lock()
        if let cached = memory[year] { lock.unlock(); return cached }
        lock.unlock()

        if let t = cachedTable(for: year) ?? bundledTable(for: year) ?? HolidayTable.builtIn(for: year) {
            remember(t)
            return t
        }
        let fallback = HolidayTable.statutory(for: year, timeZone: timeZone)
        remember(fallback)
        return fallback
    }

    public static func cachedTable(for year: Int) -> HolidayTable? {
        guard let dir = cacheDirectory(create: false) else { return nil }
        return decode(url: dir.appendingPathComponent("\(year).json"))
    }

    public static func bundledTable(for year: Int) -> HolidayTable? {
        let bundle = Bundle.main
        let url = bundle.url(forResource: "\(year)", withExtension: "json", subdirectory: "holidays")
            ?? bundle.url(forResource: "\(year)", withExtension: "json")
        guard let url else { return nil }
        return decode(url: url)
    }

    // MARK: 保存

    /// 写入 App 自己的缓存，并尽力镜像一份到 Widget 的沙盒容器。
    public static func save(_ table: HolidayTable) throws {
        guard let dir = cacheDirectory(create: true) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try encoder.encode(table.fileRepresentation)
        try data.write(to: dir.appendingPathComponent("\(table.year).json"), options: .atomic)
        remember(table)
        mirrorToWidget(table, data: data)
    }

    public static func remember(_ table: HolidayTable) {
        lock.lock()
        memory[table.year] = table
        lock.unlock()
    }

    // MARK: 路径

    public static func cacheDirectory(create: Bool) -> URL? {
        guard let base = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: create) else { return nil }
        let dir = base.appendingPathComponent("YearProgress/holidays", isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Widget 扩展是独立沙盒，读不到 App 的 Application Support；
    /// 宿主 App（未沙盒）把同一份 JSON 镜像到它的容器里，下一次刷新就能读到。
    public static func widgetContainerCacheDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.local.yearprogress.widget/Data/Library/Application Support/YearProgress/holidays",
                                    isDirectory: true)
    }

    // MARK: 私有

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    private static func decode(url: URL) -> HolidayTable? {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(HolidayFile.self, from: data) else { return nil }
        return try? HolidayTable(file: file, expectedYear: file.year)
    }

    private static func mirrorToWidget(_ table: HolidayTable, data: Data) {
        let dir = widgetContainerCacheDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent("\(table.year).json"), options: .atomic)
    }
}
