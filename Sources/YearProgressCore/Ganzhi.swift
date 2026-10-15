import Foundation

/// 干支纪年（天干 + 地支 + 生肖）。
///
/// 说明：这里按**公历年**换算（2026 → 丙午年）。农历意义上的换年发生在春节/立春，
/// 若需要精确到节气，可在 `year(for:)` 里接入农历换算，其余逻辑不变。
public struct Ganzhi: Hashable, Sendable {
    public let stem: String      // 天干：甲乙丙丁戊己庚辛壬癸
    public let branch: String    // 地支：子丑寅卯辰巳午未申酉戌亥
    public let animal: String    // 生肖：鼠牛虎兔龙蛇马羊猴鸡狗猪

    public init(year: Int) {
        let stems = Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
        let branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
        let animals = Array("鼠牛虎兔龙蛇马羊猴鸡狗猪").map(String.init)
        let s = ((year - 4) % 10 + 10) % 10
        let b = ((year - 4) % 12 + 12) % 12
        self.stem = stems[s]
        self.branch = branches[b]
        self.animal = animals[b]
    }

    /// 例如 "丙午"
    public var name: String { stem + branch }
    /// 例如 "丙午年"
    public var yearName: String { name + "年" }
    /// 例如 "丙午马年"
    public var yearNameWithAnimal: String { stem + branch + animal + "年" }
}
