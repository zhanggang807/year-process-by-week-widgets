# YearProgress · 交接文档

> 更新时间：2026-10-27  
> 仓库：https://github.com/zhanggang807/year-process-by-week-widgets  
> 分支：`main`  
> 交接基线：`0614b17 chore: 忽略构建产物`  
> 当前版本：`0.6.6 / build 55`  
> 当前开发机：macOS 27.0.1，Apple M5，16GB，只有 CommandLineTools（未安装 Xcode）

## 1. 先看这里

这是一个 macOS 菜单栏 + WidgetKit 小组件项目：把当前公历年的每周画成方块。

当前已实现：

- 菜单栏图标：左键快捷进度弹窗，右键原生设置菜单
- 可选的桌面浮窗（不是系统小组件，使用 AppKit `NSPanel`）
- 系统 WidgetKit 小组件：small / medium / large
- 节假日周折角标记（只看周一~周五，周六日不算）
- 当前周 ring
- 开机启动（`SMAppService`）
- 节假日数据：内置 JSON → 运行时更新 → 法定日期兜底
- 跨端真值表：`spec/year-weeks.json`

当前最低系统版本：**macOS 14.0（Sonoma）**。

## 2. 快速开始

在新电脑上：

```bash
git clone https://github.com/zhanggang807/year-process-by-week-widgets.git
cd year-process-by-week-widgets

# 编译与测试
swift build -c release
make test

# 打包宿主 App（不含系统小组件扩展）
make app

# 安装到 /Applications，注册 WidgetKit 扩展并重启系统小组件服务
make install

# 体检：注册状态、入口点、图标、最近崩溃、扩展调用
make diagnose
```

常用开发命令：

```bash
make run          # 前台启动，开发用
make preview      # 重新生成 docs/preview-*.png
make spec         # 重新生成 spec/year-weeks.json
make icon         # 重新生成 AppIcon.icns
make clean
```

## 3. 构建环境

### macOS / Widget 扩展

当前项目不需要完整 Xcode 也能构建 macOS App 和手写 `.appex`：

- Swift 6 toolchain
- macOS CommandLineTools
- Makefile 会在没有 Xcode 时给 Swift Testing 补 `Testing.framework` 链接参数
- Widget 扩展入口使用 `_NSExtensionMain`，见 `Makefile` 的 `widget` 目标

如果新机器安装了 Xcode，`make test` 通常会直接使用 Xcode 的 Testing 支持；Makefile 会自动判断。

### iOS

当前**没有** Xcode 工程，只有 SwiftPM package。要做 iOS 端还需要：

- Xcode（建议与 macOS 版本匹配的 Xcode 27）
- iOS SDK + Simulator runtime
- 新建真正的 Xcode App target + Widget Extension target

可复用：

- `Sources/YearProgressCore`：纯 Foundation，直接复用
- `Sources/YearProgressUI`：有条件编译的 AppKit/UIKit 分支，但尚未在 iOS 目标实际编译验证

iOS 最低建议 **iOS 17**，因为使用 `containerBackground` 等 WidgetKit API。

### Android

当前没有 Android 工程。需要：

- JDK 21（当前开发机已有）
- Android Studio 或 Android SDK command-line tools
- `platform-tools`、`build-tools`、platform SDK、emulator + system image
- Gradle wrapper（Android Studio 生成，不必单独全局安装 Gradle）

Android 端不能复用 SwiftUI，需要 Kotlin + Jetpack Compose + Glance；`spec/year-weeks.json` 和节假日 JSON 可共用。

**不要自动安装 Xcode/Android SDK**；先和用户确认环境和磁盘空间。

## 4. 关键业务口径（重要）

### 年 = 当前公历年

展示年份按当前公历年，不按 ISO 周年度。例如 2025-12-30 仍显示 2025 年。

### 周 = 公历年内重叠周（53/54 周）

从 `f74d709` 开始，生产口径改为：

> 公历年内所有与它相交的周一~周日；首周可能从上一年的 12 月开始，末周可能延到下一年的 1 月。

结果：

| 年份 | 周数 |
|---|---:|
| 2025 | 53 |
| 2026 | 53 |
| 2027 | 53 |
| 2012 | 54 |
| 2040 | 54 |

- 53/54 周都使用 **14 列 × 4 行**
- 末行分别 11/12 块，并自动居中
- 52 周的 13 列布局只作为数据源/兜底，不再由正常公历年份触发
- 跨年周边界按「落在展示年份内的天数」折算，避免 1 月 1 日显示成一周已过 6/7

`YearWeekMath.weeksInYear` 仍保留 ISO 52/53 规则，仅用于交叉校验；生产周数用 `YearWeekMath.weeksOverlapping` / `overlappingWeekStarts`。

### 节假日

- 数据来源：`Support/holidays/{year}.json`
- 运行时更新源：`NateScarlet/holiday-cn`（原始来源国务院通知）
- 只记录 `isOffDay=true`，只看周一~周五
- 缺失时用 `HolidayTable.statutory` 兜底

## 5. 代码结构

```text
Sources/
  YearProgressCore/
    YearProgress.swift       周进度、百分比、header/footer 文案
    YearWeekMath.swift       重叠周、ISO 交叉校验、下一零点
    GridLayout.swift         列/行/方块尺寸
    HolidayStore.swift       缓存/打包/兜底/Widget 镜像
    HolidayTable.swift       节假日解析、校验、法定兜底
    Ganzhi.swift             干支纪年
  YearProgressUI/
    YearProgressCardView.swift   App 与 Widget 共用卡片
    CardTheme.swift              配色
    CardMetrics.swift            尺寸/字号推导
    HolidayMarker.swift          节假日标记
    PopoverShape.swift           菜单栏气泡形状
    QuickPopoverPlacement.swift  弹窗定位纯函数
  YearProgressMac/
    AppDelegate.swift        菜单栏、桌面浮窗、快捷弹窗、登录项
    AppState.swift           状态、跨零点/唤醒/时区刷新
    WidgetPanel.swift        桌面浮窗
    HolidayUpdater.swift     GitHub 节假日更新
    Snapshot.swift           离屏 PNG 预览
  YearProgressWidget/
    WidgetMain.swift         WidgetKit Timeline + 视图
Tests/YearProgressCoreTests/ 44 个测试
Support/                     Info.plist、entitlements、图标、节假日 JSON
spec/year-weeks.json         跨端一致性真值表（2012–2040，1421 个探针）
docs/                        README 预览图
```

## 6. 当前验证状态

在交接基线上：

- `swift build -c release`：通过
- `make test`：**44 tests / 11 suites 全部通过**
- `make diagnose`：注册、`_NSExtensionMain`、图标、无崩溃均正常
- `/Applications/YearProgress.app` 已安装，版本 `0.6.6 / build 55`
- Git 工作区在生成本文件前是干净的

## 7. 已知限制 / 不要再踩的坑

### macOS 27 + Reduce Transparency

当前开发机是 macOS 27.0.1，但 SDK 是 26.5。开启「降低透明度」时，macOS 27 的桌面 WidgetKit 宿主会走 accented/glass 渲染，可能把方块压成同一种浅色，正常桌面的 placeholder/snapshot/live 路径也可能显示旧样式。

此前尝试过 accented 回退、未来周空心描边、`accessibilityReduceTransparency` 分支，已经在 `faddfaa` 回退；当前版本恢复原有深色已过/浅色未来方案。

**用户当前决定：这个问题先不解决。** 不要在没有确认的情况下重新引入 accented/空心描边实验。

后续如果要做，建议：

1. 先用 macOS 27 SDK 重新构建 Widget 扩展，确认新渲染方案；
2. 同时测试正常桌面、Mission Control、通知中心三条路径；
3. 不要只改主视图，placeholder/snapshot 和 timeline 归档都要验证。

### iOS/Android

- iOS 没有 Xcode 工程，需新建 Widget Extension target
- Android 没有 Gradle 工程，需要 Kotlin/Glance 重写 UI
- 不要声称 iOS/Android 已编译，除非对应工具链真实跑过

### 分发

- 当前 App/Extension 使用 ad-hoc 签名（`codesign --sign -`）
- 正式分发需要 Developer ID / notarization；Mac App Store 还需要沙盒和 App Store 配置
- 宿主机 App 目前未启用 App Sandbox；Widget 扩展有 App Sandbox
- 宿主机通过硬编码路径把节假日 JSON 镜像到 Widget 容器；正式分发建议改成 App Group + 沙箱

## 8. 隐私与网络

代码层面未发现用户数据外传：

- 没有剪贴板/屏幕/麦克风/摄像头/位置/通讯录/日历 API
- 没有第三方分析或崩溃 SDK
- 唯一网络请求是 GitHub 公开节假日 JSON
- 请求只带年份、`User-Agent`，不带用户标识
- 全局鼠标监听只在菜单栏快捷弹窗打开时启用，handler 丢弃事件，不记录坐标/内容

注意：

- 联网会暴露 IP 和请求时间（GitHub 侧）
- 登录项/开机启动使用 `SMAppService`
- **不要把 `~/.config/gh/hosts.yml`、token、`.env`、签名证书或私人路径提交到仓库**

## 9. 构建产物与提交规则

`.gitignore` 已忽略：

```text
.build/
build/
DerivedData/
*.xcuserstate
xcuserdata/
*.app
*.appex
*.dSYM
*.xcarchive
.DS_Store
```

`docs/preview-*.png`、`spec/year-weeks.json`、`Support/AppIcon.icns` 是**有意跟踪的文档/真值/资源**，不是编译产物。

如果改了周口径，必须同步：

```bash
make spec
make preview
make test
```

## 10. 建议的下一步

### 当前 macOS 维护

- 如用户重新决定处理 Reduce Transparency，再按上面 macOS 27 的验证流程做
- 可补 LICENSE（MIT/Apache-2.0）
- 正式分发前做 Developer ID、notarization、App Sandbox/App Group

### iOS

按 `TODO.md` 开工；先确认 Xcode 版本和签名方式，再创建 Xcode App + Widget Extension target。

### Android

按 `TODO.md` 开工；先安装 Android Studio/SDK，再以 `spec/year-weeks.json` 做 Kotlin parity test。

---

交接时如果只能先做一件事：先跑 `make test`，再根据用户是否要继续 macOS 27 Widget 问题决定下一步。
