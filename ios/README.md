# 年进度 · iOS / iPadOS 小组件

原生 SwiftUI App + WidgetKit Extension，最低系统版本 iOS / iPadOS 17。
宿主 App 与小组件直接复用仓库现有的 `YearProgressCore`、`YearProgressUI`。

## 已实现

- 主屏幕 `.systemSmall / .systemMedium / .systemLarge`
- 锁屏 `.accessoryCircular / .accessoryRectangular`
- 53/54 周自动网格、已过深色、未来浅色
- 本周顶部向下进度 + 蓝色描边
- 工作日法定节假日红色折角
- 当前 + 下一个本地零点的时间线刷新
- 点击小组件打开宿主 App
- 2026 官方节假日 JSON 同时打进 App 与 Extension
- 宿主预览页、三种主题预览和添加说明

## 打开与构建

```bash
open ios/YearProgress.xcodeproj
```

命令行无签名编译：

```bash
xcodebuild -project ios/YearProgress.xcodeproj \
  -scheme YearProgressIOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/build/simulator \
  CODE_SIGNING_ALLOWED=NO build
```

真机 SDK 编译：

```bash
xcodebuild -project ios/YearProgress.xcodeproj \
  -scheme YearProgressIOS \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ios/build/device \
  CODE_SIGNING_ALLOWED=NO build
```

在 Xcode 中真机运行前，把 `YearProgressIOS` 与
`YearProgressWidgetExtension` 的 Signing Team 设为同一个 Apple Developer 团队。
两个 Bundle ID 必须保持从属关系：

- App：`com.local.yearprogress.ios`
- Widget：`com.local.yearprogress.ios.widget`

## 添加小组件

1. 运行宿主 App 一次。
2. 长按 iOS 主屏幕空白处。
3. 点击左上角“编辑” → “添加小组件” → 搜索“年进度”。
4. 选择小号、中号或大号；锁屏编辑模式下也可添加圆形/矩形版本。

## 工程结构

- `YearProgressCore`：iOS Framework，直接编译共享 Core。
- `YearProgressUI`：iOS Framework，直接编译共享卡片视图。
- `YearProgressIOS`：SwiftUI 宿主 App。
- `YearProgressWidgetExtension`：WidgetKit Extension。

## 验证状态

已通过：

- Xcode 27.1 / iOS 27.1 Simulator SDK Debug build
- Xcode 27.1 / iOS 27.1 Device SDK Debug build
- iOS Simulator SDK Release build
- 共享 Swift Testing 44 tests / 11 suites
- `.appex`、两个动态 Framework、2026 节假日 JSON 的最终包结构检查

当前机器没有安装 iOS Simulator 运行时，也没有连接 iPhone，因此尚未完成桌面添加、
锁屏样式和跨零点的可视化验收。安装 Simulator runtime 后可直接用 Xcode 运行；
真机需要设置签名团队。
