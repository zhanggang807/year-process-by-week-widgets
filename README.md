# 年进度小组件 · YearProgress

把「一年里的每一周」画成一格小方块：**已过的周是白块，未来的周是黑块，本周是白底黑边并从底部升起黑色进度条**。
左上角是年份与干支纪年，右上角是年度进度环，底部一行统计。

![2026 年（53 周，自动选 14 列）](docs/preview-2026.png)

| 52 周的年份（13×4 方阵） | 年初（第 1 周） | 石墨主题 |
|---|---|---|
| ![2027](docs/preview-2027.png) | ![week1](docs/preview-week1.png) | ![graphite](docs/preview-graphite.png) |

- 默认尺寸 **600×292**（比例 2.06，与参考图实测的 442×215 一致）。
- 默认 **13 列**：52 周的年份正好 4×13 方阵；**53 周的年份自动换列**，避免最后一行只剩一个孤块。
- 2026 年是 **53 周**（ISO 8601），2025 / 2027 是 52 周。

---

## 快速开始

```bash
make run        # 直接跑：菜单栏出现小图标 + 桌面出现卡片
make test       # 单元测试（14 个）
make preview    # 导出几个典型日期的 PNG 到 docs/
make app        # 打包 build/YearProgress.app（含 Info.plist + ad-hoc 签名）
make open       # 打包并启动
```

启动后：桌面右上角出现卡片，菜单栏出现 4×4 小方块图标（**不占 Dock**）。
菜单里可以切窗口层级（普通 / 置顶 / 贴到桌面）、主题（紫色 / 石墨）、尺寸（大 / 中 / 小），以及退出。
卡片可以直接拖动，位置会被记住。

### 命令行参数

```bash
.build/debug/YearProgressMac --help
.build/debug/YearProgressMac --date 2026-12-31 --snapshot out.png --theme graphite --size 450x219 --scale 2
```

| 参数 | 说明 |
|---|---|
| `--snapshot <path>` | 离屏渲染成 PNG 后退出（无需窗口，用于自查/分享） |
| `--date <yyyy-MM-dd>` | 把「今天」固定成某一天，方便验证任意日期 |
| `--theme violet\|graphite` | 卡片配色，默认紫色 |
| `--size <W>x<H>` | 卡片尺寸，默认 600x292 |
| `--scale <n>` / `--margin <pt>` | 导出倍率（默认 2）与留白（默认 36，用于露出阴影） |
| `--timezone <id>` | 例如 `Asia/Shanghai` |
| `--week-start monday\|sunday\|locale` | 一周从哪天开始，默认周一（ISO 8601） |

---

## 规则约定（都写进了测试）

| 主题 | 约定 |
|---|---|
| 一年几周 | **ISO 8601**：周一为首日、第 1 周含 1 月 4 日 → 52 或 53 周。不自己推公式，用系统日历取值；同时用「1 月 1 日是周四，或闰年且 1 月 1 日是周三 → 53 周」的独立规则做**交叉校验**（1990–2060 逐年比对）。 |
| 跨年归属 | 按 ISO 标准：**2025-12-30 属于 2026 年第 1 周**，此时卡片显示 2026 年、第 1 周、已过 0%。这样做的好处是「本周」永远在网格里（测试覆盖 2019–2030 每天 × 4 个时区）。 |
| 干支纪年 | 按公历年换算：2026 → **丙午年（马）**，2025 → 乙巳年。农历意义上的换年（春节/立春）未接入，如需精确到节气，改 `Ganzhi(year:)` 一处即可。 |
| 本周进度 | 从周一 00:00 起按 7 天线性折算，体现在方块从底部升起的黑色比例上。 |
| 自动刷新 | 定时到下一个零点 + 系统跨天通知 + 睡眠唤醒 + 时区变更，都会重算。 |
| 深色卡片 | 黑块在深色卡片上会糊进背景，因此石墨主题给黑块加了 1px 半透明白描边；紫色主题不需要。 |

## 项目结构

```
Package.swift
Sources/
  YearProgressCore/          纯逻辑，不依赖任何 UI 框架（macOS/iOS 都能用）
    WeekStartMode.swift      一周从哪天开始
    YearWeekMath.swift       52/53 周、周区间、下一个零点
    YearProgress.swift       WeekCell / YearProgress / YearProgressCalculator
    Ganzhi.swift             天干地支生肖
    GridLayout.swift         列数、行数、方块边长、间距、每行几个
  YearProgressMac/           macOS 外壳（AppKit + SwiftUI）
    YearProgressCardView.swift 卡片视图（网格、进度环、方块）
    CardTheme.swift / CardMetrics.swift   配色与尺寸推导
    AppState.swift            状态 + 零点刷新调度
    AppDelegate.swift         菜单栏图标与菜单、窗口层级
    WidgetPanel.swift         无边框、不抢焦点的面板
    Snapshot.swift            离屏渲染 PNG
    CLIOptions.swift / main.swift
  YearWeekSpecDump/          生成跨平台真值表
Tests/YearProgressCoreTests/ 14 个测试
spec/year-weeks.json         Swift 与 Kotlin 共用的真值表（2015–2035 + 1029 个探针日期）
PLAN.md                      完整技术方案（含 iOS / Android 路线与里程碑）
```

---

## 本机环境说明（为什么不装 Xcode）

这台机器只有 CommandLineTools（macOS 27.0.1 / SDK 26.5），**没有 Xcode**，所以：

| 事项 | 结论 |
|---|---|
| 编译运行 macOS 版本 | ✅ 可以，`swift build` / `make app` 都走通（AppKit + SwiftUI 链接正常） |
| 离屏渲染 PNG 自查 | ✅ 可以，用 `ImageRenderer`，不需要窗口 |
| 单元测试 | ⚠️ XCTest 模块缺失，用 **Swift Testing**；CLT 里带了 `Testing.framework` 但不参与默认链接，Makefile 已封装 `-F / -framework / -rpath` 参数（有 Xcode 时会自动去掉这些参数） |
| 真·WidgetKit 小组件（.appex） | ⚠️ `import WidgetKit` 在 CLT SDK 下能编译，但没有 Xcode 时签名与宿主注册不保证成功 → 见 M3 |
| iOS | ❌ 本机没有 iOS SDK / 模拟器，无法编译，代码先就位（见 PLAN.md §7） |
| Android | ❌ 本机没有 Android SDK / Gradle，无法编译（见 PLAN.md §8） |

## 下一步（PLAN.md 里的里程碑）

- **M2** 打磨：把卡片放进「钉在桌面」的默认层级、更多主题、可选显示当前周百分比、锁屏/待机样式。
- **M3** 试真 WidgetKit 小组件：手工打 `.appex` + `pluginkit -a` 注册，成功即可加入系统小组件库；失败就保留当前形态（视觉一致）。
- **M4** iOS：`YearProgressCore` 直接复用，补 WidgetKit 扩展 + App Intents 配置 + 宿主 App（需要 Xcode 才能编译验证）。
- **M5** Android：Kotlin + Jetpack Glance，用 `spec/year-weeks.json` 做跨端一致性校验。
