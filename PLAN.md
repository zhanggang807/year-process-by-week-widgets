# 年度周进度小组件 · 技术方案

> 目标：用「一年的周」构成小方块网格，已过的周为白块，未来为黑块。跨 macOS / iOS / Android。
> 本机环境实测于 2026-10-15，见 §3。**按你的要求，全程不安装任何环境。**

---

## 1. 需求还原

| 项 | 你的描述 | 本方案默认取值 |
|---|---|---|
| 主体 | 一年内的周，一格一周 | ISO 8601 周（周一起始，第 1 周含 1/4） |
| 网格规模 | 「几个周展示几具小方块」 | 52 或 53 格，自动判定 |
| 已过 | 白块 | 白 `#FFFFFF` 实心块 |
| 未来 | 黑块 | 黑 `#000000` 实心块 |
| 当前周 | 未指定 | **白底 + 黑描边 + 细进度条**（三态，一眼看到「我在哪」） |
| 平台 | mac / iOS / Android，各自编译 | 一套纯逻辑核心 + 三个平台薄壳 |
| 顺序 | 先 mac（Swift），再试 iOS | M1 先交可跑可看的 mac 版 |

网格意象（终端示意，实际为圆角方块）：

```
  2026 · 第 42 / 53 周 · 已过 78%
  ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣
  ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣
  ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣ ▣
  ▣ ▣ ▣ ▣ ◪ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢
  ▣
  ▣ = 已过周(白)   ▢ = 未来周(黑)   ◪ = 当前周(白底黑边)
```

---

## 2. 方案总览：一个核心 + 三个薄壳

```
                ┌──────────────────────────────────────────┐
                │  YearProgressCore  (纯 Swift, 无 UI 依赖) │
                │  · WeeksInYear(52/53)    · currentWeek    │
                │  · [WeekCell] 状态机      · 网格布局算法   │
                │  · 只依赖 Foundation，可被 macOS/iOS 复用  │
                └───────────────┬──────────────────────────┘
                                │ 100% 复用
        ┌───────────────────────┼───────────────────────────┐
        ▼                       ▼                           ▼
  ┌───────────────┐     ┌──────────────────┐        ┌──────────────────┐
  │ macOS 壳      │     │ iOS 壳（需 Xcode)│        │ Android 壳       │
  │ SwiftPM 可执行│     │ WidgetKit 扩展   │        │ Kotlin + Glance  │
  │ +手工 .app    │     │ +宿主 App        │        │ AppWidget        │
  │ A:菜单栏+浮窗 │     │ +App Intents 配置│        │ (逻辑手写移植)   │
  │ B:.appex 实验 │     │                  │        │                  │
  └───────────────┘     └──────────────────┘        └──────────────────┘
        Swift                 Swift                     Kotlin
```

要点：**所有日期逻辑只写一遍**，平台代码只负责「把格子画出来 + 怎么触发刷新」。Android 语言不同，靠共享真值表 `spec/year-weeks.json` 做一致性校验。

---

## 3. 本机环境实测（决定方案形态）

| 能力 | 实测结果 | 影响 |
|---|---|---|
| macOS | 27.0.1 (26A434), arm64 | ✅ |
| Swift 工具链 | 6.3.2，`swift`/`swiftc` 可用 | ✅ |
| `swift build` | 实测通过（约 21s 首次） | ✅ 可建可跑 |
| AppKit + SwiftUI 链接 | 实测编译链接并运行通过 | ✅ 能出 GUI 程序 |
| SDK | 仅有 CLT `MacOSX.sdk 26.5`（+15.x） | ⚠️ 老于系统，需设 deployment target |
| `import WidgetKit` | CLT SDK 内**成功编译**（模块存在） | ✅ 逻辑上可写 widget 代码 |
| Xcode.app | **未安装**，`xcode-select -p` = CommandLineTools | ❌ 无 `xcodebuild`、无 Preview |
| iOS SDK / 模拟器 | **不存在**（无 CoreSimulator、无 iOS SDK） | ❌ 本机无法编译 iOS |
| Android SDK / Gradle | 无 SDK、无 gradle（有 JDK 21） | ❌ 本机无法编译 Android |
| 单元测试 | XCTest 模块**缺失**；Swift Testing 可用，但需补 link/rpath 参数（实测已跑通 ✔ 1 test passed） | ⚠️ 用 Makefile 封装参数 |
| `codesign` / `pluginkit` | 均存在 | ⚠️ 具备手工签 .app/.appex 的可能 |

**结论**
1. **macOS 走「原生 App 形态」是 100% 可行的，今天就能跑起来看效果。**
2. **真正的 WidgetKit 小组件（.appex）可以做实验，但没有 Xcode 时签名/宿主注册不保证成功** → 定位为实验项 M3，不阻塞主线。
3. **iOS / Android 在本机无法编译**（按你要求不装环境）。这两条我按「代码先写到位 + 标清未验证」交付，你装上 Xcode / Android Studio 后即可编译。

---

## 4. 核心算法与数据模型

### 4.1 一年有几周（52 / 53）
不自己推公式，直接问系统日历，避免边界错误：

```swift
var cal = Calendar(identifier: .iso8601)          // 周一为首日, minimumDaysInFirstWeek = 4
cal.timeZone = timeZone                            // 跟随系统时区
let weeks = cal.range(of: .weekOfYear, in: .yearForWeekOfYear,
                      for: midYearDate)!.count      // 52 或 53
```
> 已实测：2025 → 52，2026 → **53**，断言通过。
> 同时写一份**基于 ISO 规则的独立推导**（1/1 为周四，或闰年且 1/1 为周三 → 53 周）做交叉校验，避免「用日历测日历」的自证。

### 4.2 数据模型
```swift
public struct WeekCell: Identifiable, Hashable {   // 一格 = 一周
    public let index: Int        // 1...53
    public let start: Date       // 周一
    public let end: Date         // 周日
    public let state: State      // .past / .current / .future
    public var fraction: Double  // 当前周内已过比例 0...1（非当前周为 0/1）
}
public struct YearProgress {
    public let year: Int
    public let weeks: [WeekCell]
    public var pastCount: Int    // 已过周数
    public var percent: Double   // 已过 / 总周数
}
```
纯值类型、无状态、无持久化：**任何时刻都能由「当前时间 + 时区」重算出全部内容** —— 这让 WidgetKit 实现极简（无需 App Group、无需共享数据库）。

### 4.3 边界规则（全都要有测试）
- 12/31 可能属于**下一年的第 1 周**；1/1 可能属于**上一年的第 52/53 周**。
- 跨零点刷新：`Calendar.nextDate(after: .now, matching: DateComponents(hour:0,minute:0,second:1))`。
- 时区变更 / 系统时间被改 / 睡眠唤醒 → 都要重算。
- `fraction` 用「周一 00:00 → 下周一 00:00」线性比例（可切换为按天粒度）。

### 4.4 布局算法（自动适配尺寸）
- 输入：总周数 `n`、容器可用宽高；输出：列数 `c`、行数 `r = ceil(n/c)`、格子边长 `s`、间距 `g = s * 0.18`。
- 默认 `c = 13`（52 周 = 4×13 方阵，最紧凑好看）。
- 53 周年份：允许「自动列数」候选 `{13, 14, 18, 9, 8, 7}`，取渲染后宽高比最接近容器宽高比者，避免出现孤零零 1 格。
- 提供固定 `cellSize` 模式（大屏展示用）。
- 空位不绘制（不是灰块）。

---

## 5. UI 方案（macOS 优先）

### 5.1 三种形态对比

| 形态 | 是否像「桌面小组件」 | 无 Xcode 可行性 | 说明 |
|---|---|---|---|
| **A. 菜单栏 App**（NSStatusItem + 弹出面板） | 一般 | ✅ 确定可行 | 点图标看整年进度，最稳的第一步 |
| **B. 桌面常驻浮窗**（无边框窗口，桌面层级） | ✅ 很像 | ✅ 确定可行 | 贴在桌面、不抢焦点；就是你说的"桌面小组件"效果 |
| **C. 真 WidgetKit 小组件**（.appex） | ✅ 系统原生 | ⚠️ 实验性 | 可加入通知中心/桌面，但签名与宿主注册无 Xcode 时不保证 |

**路线：A + B 一起做（同一份 Core 与视图），M3 再尝试 C。** 因为 A/B 共用同一个 SwiftUI 视图，成本只多一个窗口壳。

### 5.2 视觉与配色
- 已过周：白实心；未来周：黑实心；当前周：白底 + 黑描边 + 底部细进度条。
- **深色模式**：黑白字面保留（尊重你的要求），但深色背景下给**黑块加 1px 半透明白描边**，否则黑块会糊在背景里看不见；窗口底色用材质/浅灰，保证对比。可用设置项切到「随系统自适应」。
- 圆角：`s * 0.22`；间距随尺寸缩放，整体气质偏克制、无阴影堆叠。
- 信息层（可开关）：年份、`第 42 / 53 周`、`已过 78%`。
- 交互：悬停某格显示 tooltip「第 42 周 · 10/12–10/18 ✅」。
- 可访问性：每格 `accessibilityLabel`，整体合并为一句摘要；黑白两态天然色盲友好，不靠颜色单独承载信息。

### 5.3 刷新策略
| 场景 | 手段 |
|---|---|
| macOS App（A/B） | 定时到下一个零点 + `NSCalendarDayChanged` + 唤醒通知 + 时区变更 |
| WidgetKit | `Timeline` 每次给「今天/明天零点」两个 entry，`policy: .after(次日零点)` |
| Android Glance | `updatePeriodMillis` 最短 30 分钟，故用 AlarmManager/WorkManager 卡零点 |

### 5.4 我的自检方式（无 GUI 也能验收）
`swift run YearProgressSnapshot --out preview.png`：用 `NSHostingView` **离屏渲染**成 PNG。
→ 我不需要鼠标/屏幕权限就能出图自查，也能直接把图发给你看，你无需先跑起来就能review视觉。

---

## 6. macOS 构建与运行（无 Xcode 的具体做法）

```
swift build                     # 编译
swift run YearProgressApp       # 直接跑（菜单栏出现图标）
make app                        # 产出 build/YearProgress.app（含 Info.plist + ad-hoc 签名）
open build/YearProgress.app      # 双击式启动
make test                       # 已封装 CLT 下 Testing.framework 的 -F/-framework/-rpath 参数
make snapshot                   # 出 preview.png 自查
```

`.app` 手工组装细节（无 Xcode 的替代方案）：
```
YearProgress.app/Contents/
├── Info.plist          # CFBundleIdentifier / CFBundleExecutable / LSUIElement=true(仅菜单栏,无 Dock 图标)
│                       # NSHighResolutionCapable=true / LSMinimumSystemVersion=14.0
├── MacOS/YearProgress  # swift build 产物
└── Resources/          # 图标、可选资源
```
签名：`codesign --force --sign - build/YearProgress.app`（ad-hoc，仅本机自用）。

**M3 的 .appex 实验路径**（成功则可真·加进桌面小组件）：
`PlugIns/YearProgressWidget.appex`（`NSExtensionPointIdentifier = com.apple.widgetkit-extension`）+ `pluginkit -a` 注册 + ad-hoc 签名 → 加入桌面。**若系统拒绝注册，则回退到形态 B（视觉等价），不阻塞交付。**

---

## 7. iOS 落地路径（需要 Xcode）

| 项目 | 说明 |
|---|---|
| 前置 | Xcode（含 iOS SDK + 模拟器/真机）。当前机器缺失，无法编译或验证 |
| 复用 | `YearProgressCore` 100% 复用（纯 Foundation，不含 AppKit） |
| 新写 | ① Home Screen 小组件（`systemSmall/Medium/Large`，布局按 family 自适应）② Lock Screen 附件组件（`accessoryCircular/Rectangular`，可选）③ 宿主 App（一屏，用于安装/预览/设置）④ `AppIntentConfiguration`：周起始日、主题、是否显示百分比 |
| 平台差异 | iOS 无「桌面常驻浮窗」，只有系统小组件（桌面/锁屏/待机）；尺寸由系统给，必须 GeometryReader 自适应 |
| 交付 | `ios/` 下源码 + 工程文件 + 一份「装好 Xcode 后怎么编译」的说明，**并明确标注：未在本机编译验证过** |
| 后续一条命令 | `xcodebuild -scheme YearProgressWidget -destination 'platform=iOS Simulator,name=iPhone 17' build` |

---

## 8. Android 落地路径（需要 Android Studio/SDK）

- 技术：Kotlin + **Jetpack Glance**（`glance-appwidget`），宿主 App 用 Compose；minSdk 23。
- 逻辑移植：`YearWeeks.kt` 用 `java.time`（`WeekFields.ISO`）+ `java.time.temporal.WeekFields`，与 Swift 同规则。
- **一致性保障**：两端都读同一份 `spec/year-weeks.json`（2015–2035 年 周数/边界/当前周 真值表）跑测试，防止两端算法漂移。
- 刷新：Glance 最小周期 30 分钟，用 AlarmManager 卡零点。
- 前置：需要 Android SDK + Gradle（本机均无，按你要求不安装）。

---

## 9. 里程碑与交付物

| 阶段 | 内容 | 前置 | 可验证产物 |
|---|---|---|---|
| **M0 骨架** | 目录结构、Core 包、测试真值表、Makefile、README | 无 | `make test` 全绿 |
| **M1 mac 可用** | 菜单栏 App + 网格渲染 + 跨零点刷新 | 无 | `swift run` 可见；`preview.png` |
| **M2 打磨** | 桌面浮窗形态、设置（列数/主题/信息层）、深色模式、tooltip、可访问性 | 无 | 截图 + 设置项 |
| **M3 Widget 实验** | 手工打包 .appex + pluginkit 注册 | 无 | 成功 → 桌面真小组件；失败 → 记录原因 |
| **M4 iOS** | WidgetKit 扩展 + App Intent 配置 + 宿主 App | 需 Xcode | 源码/工程 + 编译说明（未本机验证） |
| **M5 Android** | Glance AppWidget + 宿主 App + parity 测试 | 需 Android SDK | 工程 + parity 测试通过 |

---

## 10. 风险与对策

| # | 风险 | 对策 |
|---|---|---|
| R1 | 无 Xcode → 真 Widget、iOS 无法验证 | 主线走独立 App，Widget 隔离为实验；iOS 代码交付时明确标注未验证 |
| R2 | CLT SDK 26.5 老于系统 27.0.1 | 固定 deployment target `macOS 14`，只用该版本 API；避免最新 API |
| R3 | 53 周年份网格出现孤格 | 自动列数算法 + 默认 13 列 |
| R4 | 深色模式下黑块不可见 | 黑块细描边 + 底材质；提供自适应主题开关 |
| R5 | CLT 下 XCTest 缺失、Swift Testing 需特殊链接参数 | Makefile 封装（实测可用），不让使用者记参数 |
| R6 | 我无法点鼠标看窗口效果 | 离屏渲染出 PNG 自检 + 交付截图给你 review |
| R7 | 时区/跨年边界算错 | 独立规则实现交叉校验 + 2015–2035 真值表 + 多时区测试 |

---

## 11. 验收标准
1. `make test` 全绿，且覆盖：52/53 周判定、跨年归属、多时区、当前周 fraction。
2. 2026 年运行时显示 **53 格**，已过白、未来黑、当前周有独立样式。
3. 跨零点（或手动改系统时间/时区）无需重启即自动刷新。
4. 深色/浅色模式下都能清楚区分三种状态。
5. 不依赖 Xcode 即可 `make app && open` 跑起来。
6. M4/M5 交付的代码有清晰「未在无环境机器上编译」的标注。

---

## 12. 待你确认（3 项，已给默认值，不回复我就按默认做）

1. **当前周怎么显示？**
   默认：白底 + 黑描边 + 底部细进度条（推荐，能看出"本周过了百分之几"）。
   其他：算作未来（黑）／算作已过（白）。
2. **macOS 形态优先做哪个？**
   默认：**菜单栏 App + 桌面常驻浮窗（都做，共用视图）**。
   其他：只做菜单栏／只做浮窗／直接赌 WidgetKit 实验。
3. **网格默认布局？**
   默认：**13 列（52 周 = 4×13 方阵）**，53 周年份自动选列。
   其他：GitHub 风格 7 行／完全自适应容器比例。

> 附：目录是否 `git init`？默认我会在 M0 顺手初始化（纯本地，不推远端）。
