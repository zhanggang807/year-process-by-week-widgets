# TODO · iOS / Android 移植

> 状态（2026-10-25）：macOS 0.5.2 已完成（commit `1abf1bd`）。
> iOS / Android 暂缓：本机没有 Xcode（无 iOS SDK / 模拟器）与 Android SDK / Gradle。
> **按约定不自动安装任何工具链**；开工前先由你确认环境。

---

## 0. 共享前置（两端都依赖）

- [ ] **CORE-1** 把 `Sources/YearProgressCore` 当作跨端唯一规则源：
  年份=当前公历年、ISO 52/53 周、周起始、当前周按真实周长度折算（DST 安全）、节假日表结构。
- [ ] **CORE-2** 规则变更时先跑 `make spec`，`spec/year-weeks.json`（2015–2035 + 1029 个探针日期）
      是 iOS/Android 的**一致性真值表**，任何实现都必须通过它。
- [ ] **CORE-3** 节假日数据统一用 `Support/holidays/{year}.json`（holiday-cn 格式，原始来源国务院通知）；
      两端都只取 `isOffDay=true`、只看周一~周五、忽略调休补班日。
- [ ] **CORE-4** 视觉规则保持一致：14 列×4 行（53 周）/13 列×4 行（52 周）、
      当前周从顶部向下填充、周序号居中、节假日 ring 标记。

---

## 1. iOS（Swift / WidgetKit）

### 1.1 前置

- [ ] **IOS-1** 安装 Xcode（含 iOS SDK + Simulator）——需要你的确认，不自动安装
- [ ] **IOS-2** 选择签名方式：模拟器可无团队；真机/App Group 需要 Apple ID 团队

### 1.2 代码复用

- [ ] **IOS-3** `YearProgressCore` **100% 复用**（纯 Foundation）
- [ ] **IOS-4** `YearProgressUI` 复用前做编译验证：`CardTheme` 已按 AppKit/UIKit 条件编译、
      `.help` 已仅 macOS 分支；仍需在 iOS 目标里实际编译一次（这是当前唯一未验证的部分）
- [ ] **IOS-5** 不复用 `YearProgressMac/*`（菜单栏、桌面浮窗、quick popover 均为 AppKit）

### 1.3 小组件

- [ ] **IOS-6** 建 Widget Extension 目标（`WidgetKit`），入口 `@main WidgetBundle`
- [ ] **IOS-7** v1 用 `StaticConfiguration`；v2 换 `AppIntentConfiguration`，暴露配置：
      周起始（周一/周日）、主题（跟随系统/暗岩灰）、是否显示节假日标记
- [ ] **IOS-8** 支持 families：`.systemSmall / .systemMedium / .systemLarge`
      （`.systemMedium` 强制使用与桌面挂件同一套基准列数；small/large 自适应）
- [ ] **IOS-9** 时间线：`[now, nextMidnight]` + `policy: .after(nextMidnight)`；
      必须使用 `.containerBackground(for: .widget)`；`contentMarginsDisabled()`
- [ ] **IOS-10** 小号/大号的字号与 padding 用 `CardMetrics(profile: .widget)` 的 clamp 规则

### 1.4 节假日数据

- [ ] **IOS-11** 把 `Support/holidays/*.json` 打进 App 与 Widget Extension（widget 是独立沙盒）
- [ ] **IOS-12** 运行时更新：App 启动时用 `HolidayFetcher`（把 macOS 的实现挪到共享层）抓取缺失年份，
      校验后缓存；**Widget 只读本地**（bundle 或共享容器）
- [ ] **IOS-13** 若要 App→Widget 共享运行时新数据：启用 App Group（需真实团队签名），
      用 `UserDefaults(suiteName:)` 或共享文件；否则每年重新打包即可

### 1.5 宿主 App

- [ ] **IOS-14** 一个 SwiftUI 宿主 App：预览卡片、说明如何在桌面/锁屏添加、设置默认主题
- [ ] **IOS-15** 可选：锁屏附件组件（`accessoryCircular/Rectangular`），用同一套 Core

### 1.6 构建与验收

- [ ] **IOS-16** `xcodebuild -scheme YearProgressWidget -destination 'platform=iOS Simulator,name=...' build`
- [ ] **IOS-17** 在模拟器上添加 small/medium/large，跨零点刷新、时区变更、跨年周（12/29–1/3）验证
- [ ] **IOS-18** 验收：2026 年 53 周、10 个节假日周、ring 标记、当前周顶部向下、与 macOS 同款配色逻辑

---

## 2. Android（Kotlin / Jetpack Glance）

### 2.1 前置

- [ ] **AND-1** 安装 Android Studio 或 Android SDK + Gradle（本机已有 JDK 21，缺 SDK/Gradle）
- [ ] **AND-2** 建 Gradle 工程：`app`（Compose 宿主）+ `widget`（Glance AppWidget），`minSdk 23`、`compileSdk 34+`

### 2.2 核心逻辑移植

- [ ] **AND-3** `YearWeeks.kt`：用 `java.time` + `WeekFields.ISO` 实现与 Swift 完全一致的规则：
      公历年、52/53 周、周起止、当前周 fraction 用真实周长度（`Duration`，DST 安全）
- [ ] **AND-4** 导入 `spec/year-weeks.json` 到 `test/resources`，写 JUnit parity 测试逐条比对
      （年份/周序/总周数/跨年周，1029 个探针）
- [ ] **AND-5** 节假日：`HolidayTable.kt` 解析同一份 JSON（bundled in assets），
      周标记只看周一~周五；2026 断言 10 个周：1,8,9,15,18,19,25,39,40,41

### 2.3 小组件

- [ ] **AND-6** Glance AppWidget：`SizeMode.Responsive`（小/中/大），列数规则与 macOS 对齐
- [ ] **AND-7** 方块渲染：优先用行×列的 `Box` 组合；若 RemoteViews 性能不足，改为**预渲染 Bitmap** 用 `Image` 显示
- [ ] **AND-8** 刷新：`updatePeriodMillis`（系统下限 30 分钟）只作兜底；
      用 **AlarmManager** 在本地零点触发 `update()`；监听 `ACTION_TIMEZONE_CHANGED` 与开机广播
- [ ] **AND-9** 交互：点击组件打开宿主 App；可选配置 Activity（主题/周起始/标记开关）

### 2.4 宿主 App 与数据更新

- [ ] **AND-10** Compose 宿主 App：预览、设置、说明如何添加组件
- [ ] **AND-11** 节假日更新：WorkManager 每月检查一次缺失年份，抓取→校验→写入 `filesDir`；
      Glance 与 App 同进程，直接读同一份文件（不需要跨沙盒共享）
- [ ] **AND-12** 离线兜底：打包当年 JSON + 法定节日算法兜底（与 iOS 相同规则）

### 2.5 构建与验收

- [ ] **AND-13** `./gradlew test`（Core/parity）+ `./gradlew assembleDebug`
- [ ] **AND-14** 在 Pixel 模拟器/真机添加三种尺寸，验证跨零点、时区、跨年周
- [ ] **AND-15** 验收：与 macOS 同一套周数/节假日周/当前周方向/ring 标记

---

## 3. 跨端一致性检查表（每次发版）

- [ ] 2026：53 周；节假日周 = `1, 8, 9, 15, 18, 19, 25, 39, 40, 41`
- [ ] 2025 / 2027：52 周
- [ ] 2025-12-30 → 年份显示 2025、`共 52 周`、`本周属于 2026 年第 1 周`
- [ ] 2027-01-01 → 年份显示 2027、`本周属于 2026 年第 53 周`
- [ ] DST 周（纽约 2026-03/11）：当前周比例按 167h/169h
- [ ] `spec/year-weeks.json` 与两端测试全部通过

---

## 4. 已知限制 / 决策记录

- iOS 小组件刷新由系统节流，无法做到分钟级；Android `updatePeriodMillis` 下限 30 分钟 → 用 AlarmManager 卡零点。
- iOS 跨 App/Widget 的运行时数据共享需要 App Group（真实团队签名）；v1 先走"打包 JSON"。
- Android 的 Glance 没有任意 Canvas，复杂网格可能需要预渲染 Bitmap。
- 两端都需要对应工具链才能编译验证；**未安装前不产出"已编译"的承诺**。
