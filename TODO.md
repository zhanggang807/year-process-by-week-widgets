# TODO · iOS / Android 移植

> 状态（2026-10-27）：macOS 0.6.6 已完成。
> iOS App + WidgetKit 工程已使用 Xcode 27.1 / iOS SDK 27.1 编译通过；
> Android 工程构建、测试和 lint 已通过。两端都还缺真机桌面可视化验收。

---

## 0. 共享前置（两端都依赖）

- [ ] **CORE-1** 把 `Sources/YearProgressCore` 当作跨端唯一规则源：
  年份=当前公历年、公历年内重叠周 53/54、周起始、当前周按真实周长度折算（DST 安全）、节假日表结构。
- [ ] **CORE-2** 规则变更时先跑 `make spec`，`spec/year-weeks.json`（2012–2040 + 1421 个探针日期）
      是 iOS/Android 的**一致性真值表**，任何实现都必须通过它。
- [ ] **CORE-3** 节假日数据统一用 `Support/holidays/{year}.json`（holiday-cn 格式，原始来源国务院通知）；
      两端都只取 `isOffDay=true`、只看周一~周五、忽略调休补班日。
- [ ] **CORE-4** 视觉规则保持一致：14 列×4 行（53/54 周；末行 11/12 块居中）/13 列×4 行（52 周兜底）、
      当前周从顶部向下填充、周序号居中、节假日 ring 标记。

---

## 1. iOS（Swift / WidgetKit）

### 1.1 前置

- [x] **IOS-1** Xcode 27.1 + iOS SDK 27.1 已存在（Simulator runtime 尚未安装）
- [x] **IOS-2** 命令行使用无签名编译；真机仍需在 Xcode 选择同一个 Apple Developer 团队

### 1.2 代码复用

- [x] **IOS-3** `YearProgressCore` 编成 iOS Framework 并直接复用
- [x] **IOS-4** `YearProgressUI` 编成 iOS Framework；AppKit/UIKit 条件分支实际编译通过
- [x] **IOS-5** 不复用 `YearProgressMac/*`

### 1.3 小组件

- [x] **IOS-6** 建 Widget Extension 目标（`WidgetKit`），入口 `@main WidgetBundle`
- [x] **IOS-7** v1 用 `StaticConfiguration`；v2 的 `AppIntentConfiguration` 仍待后续
      周起始（周一/周日）、主题（跟随系统/暗岩灰）、是否显示节假日标记
- [x] **IOS-8** 支持 families：`.systemSmall / .systemMedium / .systemLarge`
      （`.systemMedium` 强制使用与桌面挂件同一套基准列数；small/large 自适应）
- [x] **IOS-9** 时间线：`[now, nextMidnight]` + `policy: .after(nextMidnight)`；
      必须使用 `.containerBackground(for: .widget)`；`contentMarginsDisabled()`
- [x] **IOS-10** 小号/大号的字号与 padding 用 `CardMetrics(profile: .widget)` 的 clamp 规则

### 1.4 节假日数据

- [x] **IOS-11** 把 `Support/holidays/2026.json` 打进 App 与 Widget Extension
- [ ] **IOS-12** 运行时更新：App 启动时用 `HolidayFetcher`（把 macOS 的实现挪到共享层）抓取缺失年份，
      校验后缓存；**Widget 只读本地**（bundle 或共享容器）
- [ ] **IOS-13** 若要 App→Widget 共享运行时新数据：启用 App Group（需真实团队签名），
      用 `UserDefaults(suiteName:)` 或共享文件；否则每年重新打包即可

### 1.5 宿主 App

- [x] **IOS-14** SwiftUI 宿主 App：预览卡片、主题预览、说明如何在桌面/锁屏添加
- [x] **IOS-15** 锁屏附件组件（`accessoryCircular/Rectangular`）

### 1.6 构建与验收

- [x] **IOS-16** Simulator SDK Debug/Release + Device SDK Debug 无签名编译通过
- [ ] **IOS-17** 在模拟器上添加 small/medium/large，跨零点刷新、时区变更、跨年周（12/29–1/3）验证
- [x] **IOS-18** 共享 Core 的 2026/53 周、2012/2040/54 周、10 个节假日周及 DST 测试通过

---

## 2. Android（Kotlin / 标准 AppWidgetProvider）

### 2.1 前置

- [x] **AND-1** 使用本机 Android SDK 36 + Gradle Wrapper 8.14.3
- [x] **AND-2** 建 Gradle 工程：`:app`（原生 View 宿主）+ `:core`（纯 Kotlin），`minSdk 26`、`compileSdk 36`

### 2.2 核心逻辑移植

- [x] **AND-3** `YearWeeks.kt`：用 `java.time` 的周一为首日规则实现与 Swift 完全一致的重叠周：
      公历年、53/54 重叠周、周起止、当前周 fraction 用真实周长度（`Duration`，DST 安全）；ISO 52/53 仅做交叉校验
- [x] **AND-4** 直接读取共享 `spec/year-weeks.json`，JUnit parity 测试逐条比对
      （年份/周序/总周数/边界周，1421 个探针）
- [x] **AND-5** 节假日：`HolidayRepository.kt` 解析同一份 JSON（bundled in assets），
      周标记只看周一~周五；2026 断言 10 个周：1,8,9,15,18,19,25,39,40,41

### 2.3 小组件

- [x] **AND-6** 标准 `AppWidgetProvider`：2×2 / 4×2 两个入口，列数规则与 macOS 对齐
- [x] **AND-7** 整卡预渲染 Bitmap，用单个 `RemoteViews` ImageView 显示（跨启动器视觉稳定）
- [x] **AND-8** 刷新：`updatePeriodMillis`（系统下限 30 分钟）只作兜底；
      用 **AlarmManager** 在本地零点触发 `update()`；监听 `ACTION_TIMEZONE_CHANGED` 与开机广播
- [x] **AND-9** 交互：点击组件打开宿主 App；固定暗岩灰主题，暂不需要配置 Activity

### 2.4 宿主 App 与数据更新

- [x] **AND-10** 原生 View 宿主 App：预览、立即刷新、说明如何添加组件
- [ ] **AND-11** 节假日更新：WorkManager 每月检查一次缺失年份，抓取→校验→写入 `filesDir`；
      Glance 与 App 同进程，直接读同一份文件（不需要跨沙盒共享）
- [x] **AND-12** 离线兜底：打包 2026 JSON + 固定日期/清明算法；后续官方 JSON 放入共享目录即可

### 2.5 构建与验收

- [x] **AND-13** `./gradlew clean test assembleDebug lintDebug` 通过
- [ ] **AND-14** 在 HyperOS 3 真机添加 2×2 / 4×2，验证跨零点、时区、跨年周
- [ ] **AND-15** 验收：与 macOS 同一套周数/节假日周/当前周方向/ring 标记

---

## 3. 跨端一致性检查表（每次发版）

- [x] 2026：53 周；节假日周 = `1, 8, 9, 15, 18, 19, 25, 39, 40, 41`
- [x] 2025 / 2027：53 周
- [x] 2012 / 2040：54 周
- [x] 2025-12-30 → 年份显示 2025、第 53 周
- [x] 2027-01-01 → 年份显示 2027、第 1 周
- [x] DST 周（纽约 2026-03）：167h 真实时长断言通过
- [x] `spec/year-weeks.json` 与 Android 测试全部通过

---

## 4. 已知限制 / 决策记录

- iOS 小组件刷新由系统节流，无法做到分钟级；Android `updatePeriodMillis` 下限 30 分钟 → 用 AlarmManager 卡零点。
- iOS 工程已编译通过，但当前机器没有 Simulator runtime；桌面添加、锁屏视觉和跨零点仍需运行验收。
- iOS 跨 App/Widget 的运行时数据共享需要 App Group（真实团队签名）；v1 先走"打包 JSON"。
- Android 采用标准 AppWidgetProvider + 整卡 Canvas Bitmap，而不是 Glance；
  视觉跨启动器稳定，但单个周格不是独立可访问节点。
- 两端都需要对应工具链才能编译验证；**未安装前不产出"已编译"的承诺**。
- **macOS 27 桌面小组件白板（待工具链对齐）**：macOS 27.0.1 的桌面 WidgetKit 宿主会请求
  `fullColor + backgroundViewPolicy=Include(transparent)` 这一新渲染方案；本机只有 macOS 26.5 SDK，
  扩展侧只能生成 `fullColor+Include / fullColor+Remove / accented+Remove`，宿主找不到完全匹配的归档时
  会显示白板。通知中心里的小组件正常。彻底修复需要用 macOS 27 SDK（Xcode 27）重新编译扩展，
  本仓库按约定不会自动安装该工具链。
- **App 图标与扩展注册**：WidgetKit 搜索界面读的是扩展/宿主 App 的图标资源；扩展 Info.plist 必须带
  `CFBundleIconFile`，且 `Contents/Resources/AppIcon.icns` 要随 appex 一起打包。
  `make install` 会清掉 `build/` 下的重复 LaunchServices 记录，避免同一 bundle id 出现两条记录后
  chronod 继续使用旧图标或报告 “LS doesn't have a containing bundle”。
