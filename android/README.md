# 年进度 · HyperOS 3 小组件

这是“年度周进度”的 Android 原生实现，使用标准 `AppWidgetProvider` +
`RemoteViews`，因此会被 HyperOS 3 的小组件选择器识别为普通桌面小部件。
工程针对 Android 16（API 36）构建，最低支持 API 26。

## 已实现

- `2×2` 与 `4×2` 两个独立入口，适合 HyperOS 小组件库直接选择。
- 公历年内重叠周口径：通常 53 周，闰年边界可为 54 周。
- 已过深色、未来浅色、本周从顶部向下增长并带高饱和蓝环。
- 工作日法定节假日周右上角红色折角。
- `onAppWidgetOptionsChanged` 自适应尺寸；调整大小后重新计算行列和像素密度。
- 本地零点 `AlarmManager` 刷新，`updatePeriodMillis` 与开机广播作兜底。
- 点击小部件打开宿主 App，可看完整预览和添加说明。
- 直接复用仓库的 `spec/year-weeks.json` 和 `Support/holidays/2026.json`。

## 构建

需要 JDK 17+、Android SDK Platform 36 和 Build Tools 36。工程自带 Gradle Wrapper。

```bash
cd android
ANDROID_HOME="$HOME/Library/Android/sdk" ./gradlew test assembleDebug lintDebug
```

APK：

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

安装到已连接的设备：

```bash
"$ANDROID_HOME/platform-tools/adb" install -r app/build/outputs/apk/debug/app-debug.apk
```

也可以在仓库根目录执行：

```bash
make android-build
make android-install
```

安装后先打开“年进度” App：

1. 查看“系统已识别 N 个年进度组件”状态。
2. 点击“添加 2×2”或“添加 4×2”，按桌面提示确认。
3. 如果桌面不支持一键添加，再长按桌面空白处 → 添加小部件 → 搜索“年进度”。

HyperOS 的小组件搜索可能把所有第三方组件混在同一个长列表里，因此 App 内直达入口
比搜索更可靠。若状态显示“系统暂未识别组件”，重启手机后再打开 App 检查。

## 技术取舍

macOS 计划中曾建议 Jetpack Glance。这里的周网格包含准确的折角、双色数字和
进度裁切，最终选择先用 `Canvas` 预渲染整张卡片，再通过单个 `RemoteViews`
`ImageView` 显示。这样：

- HyperOS 与 AOSP 启动器使用完全相同的几何结果；
- 每次刷新只有一次 bitmap 更新，不需要为 53 个格子下发大量 RemoteViews action；
- 同一张渲染结果也供宿主 App 预览，不维护两套视觉实现。

整卡 bitmap 的代价是格子无法逐格点击或读取单个语义节点；当前交互只需要整卡
打开宿主 App，因此以视觉稳定和兼容性优先。

## 当前验证边界

已验证：

- `./gradlew clean test assembleDebug lintDebug` 通过；
- Swift 共享真值表 2012–2040、1421 个探针全部通过；
- 2026 年 10 个节假日周与 macOS 一致；
- APK 的 Manifest 暴露两个 app-widget receiver，2026 节假日资源已打包。

尚未在真实 HyperOS 3 桌面或模拟器上做视觉验收；当前机器没有连接 Android
设备，也没有安装 Android 模拟器镜像。真机验收时重点检查 2×2 / 4×2 首屏、
调整大小、跨零点、跨时区和长按添加页。
