# 年进度小组件（macOS）— 无 Xcode 也能构建
#
#   make run        直接跑（菜单栏出现小图标 + 桌面卡片）
#   make app        打包成 build/YearProgress.app（含 Info.plist + ad-hoc 签名）
#   make open       打包并启动
#   make test       跑单元测试
#   make preview    用几个典型日期导出 PNG 到 docs/
#   make spec       重新生成 spec/year-weeks.json（跨平台真值表）
#   make widget     打包 + 组装 + 签名 .appex 并注册到系统（通知中心「编辑小组件」里可见）
#   make install    安装到 /Applications（先退出旧实例，装完自动重开）
#   make uninstall  卸载 /Applications 里的 App
#   make diagnose   注册状态 / 入口点 / 最近崩溃 / 扩展调用
#   make icon       重新生成 App 图标
#   make holidays YEAR=2027   拉取某年的官方节假日安排
#   make clean

SWIFT      ?= swift
CONFIG     ?= release
BUILD_DIR  := build
APP        := $(BUILD_DIR)/YearProgress.app
BIN        := .build/$(CONFIG)/YearProgressMac
BIN_WIDGET := .build/$(CONFIG)/YearProgressWidget
BUNDLE_ID  := com.local.yearprogress
WIDGET_ID  := com.local.yearprogress.widget
APPEX      := $(APP)/Contents/PlugIns/YearProgressWidget.appex
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# 有 Xcode 时 swift test 直接可用；只有 CommandLineTools 时需要显式挂上
# Testing.framework（CLT 里带了 Swift Testing 的模块和 dylib，但不参与默认链接）。
XCODE_AVAILABLE := $(shell xcodebuild -version >/dev/null 2>&1 && echo yes || echo no)

ifeq ($(XCODE_AVAILABLE),yes)
  TEST_FLAGS :=
else
  CLT_FW  := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
  CLT_LIB := /Library/Developer/CommandLineTools/Library/Developer/usr/lib
  TEST_FLAGS := \
    -Xswiftc -F -Xswiftc $(CLT_FW) \
    -Xswiftc -I -Xswiftc $(CLT_FW)/Testing.framework/Versions/A/Modules \
    -Xlinker -F -Xlinker $(CLT_FW) \
    -Xlinker -framework -Xlinker Testing \
    -Xlinker -rpath -Xlinker $(CLT_FW) \
    -Xlinker -rpath -Xlinker $(CLT_LIB)
endif

.PHONY: all build test run preview spec app open widget widget-uninstall register install uninstall diagnose icon holidays reset-widget-cache clean help

all: build

help:
	@sed -n '1,22p' Makefile

build:
	$(SWIFT) build -c $(CONFIG)

test:
	$(SWIFT) test $(TEST_FLAGS)

run:
	$(SWIFT) run YearProgressMac

preview:
	@mkdir -p docs
	$(SWIFT) run YearProgressMac --snapshot docs/preview-2026.png --date 2026-10-15
	$(SWIFT) run YearProgressMac --snapshot docs/preview-2027.png --date 2027-06-01
	$(SWIFT) run YearProgressMac --snapshot docs/preview-week1.png --date 2026-01-02
	$(SWIFT) run YearProgressMac --snapshot docs/preview-graphite.png --date 2026-10-15 --theme graphite
	$(SWIFT) run YearProgressMac --snapshot docs/preview-year-end.png --date 2025-12-30
	$(SWIFT) run YearProgressMac --snapshot docs/preview-panel-small.png --date 2026-10-15 --theme graphite --size 338x158 --margin 0 --scale 3
	$(SWIFT) run YearProgressMac --snapshot docs/preview-widget-small.png --date 2026-10-15 --theme slate --size 158x158 --chrome widget --margin 0 --scale 4 --header-font 13
	$(SWIFT) run YearProgressMac --snapshot docs/preview-widget-slate.png --date 2026-10-15 --theme slate --size 338x158 --chrome widget --margin 0 --scale 3
	$(SWIFT) run YearProgressMac --snapshot docs/preview-quick-popover.png --date 2026-10-25 --theme graphite --popover --margin 24 --scale 3

spec:
	$(SWIFT) run year-weeks-dump spec/year-weeks.json

app: build
	@rm -rf $(APP)
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	@cp $(BIN) $(APP)/Contents/MacOS/YearProgress
	@cp Support/App-Info.plist $(APP)/Contents/Info.plist
	@cp Support/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	@cp -R Support/holidays $(APP)/Contents/Resources/holidays
	@codesign --force --sign - $(APP)
	@echo "已生成 $(APP)"

# 组装宿主 App + WidgetKit 扩展（.appex），再注册到 LaunchServices / pluginkit。
# 没有 Xcode 时也能做：swiftc 能编 WidgetKit 代码，剩下的就是手工摆包结构 + 签名。
widget: app
	@# App Extension 的入口必须是扩展运行时（Xcode 里的 LD_ENTRY_POINT = _NSExtensionMain）。
	@# 少了它会直接跑 WidgetBundle.main()，ExtensionFoundation 初始化即 SIGTRAP。
	@$(SWIFT) build -c $(CONFIG) --product YearProgressWidget -Xlinker -e -Xlinker _NSExtensionMain
	@rm -rf $(APPEX)
	@mkdir -p $(APPEX)/Contents/MacOS $(APPEX)/Contents/Resources
	@cp $(BIN_WIDGET) $(APPEX)/Contents/MacOS/YearProgressWidget
	@cp Support/Widget-Info.plist $(APPEX)/Contents/Info.plist
	@cp Support/AppIcon.icns $(APPEX)/Contents/Resources/AppIcon.icns
	@cp -R Support/holidays $(APPEX)/Contents/Resources/holidays
	@printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0"><dict>' \
	  '  <key>com.apple.security.app-sandbox</key><true/>' \
	  '</dict></plist>' > $(BUILD_DIR)/widget.entitlements
	@echo "签名扩展…"
	@codesign --force --sign - --entitlements $(BUILD_DIR)/widget.entitlements --generate-entitlement-der $(APPEX)
	@codesign --force --sign - --generate-entitlement-der $(APP)
	@$(MAKE) -s register
	@echo ""
	@echo "下一步：点击菜单栏最右侧的时间 → 通知中心底部「编辑小组件…」→ 搜索「年进度」。"
	@echo "（若看不到，先在 Finder 里双击打开 $(APP) 一次，或执行 make register）"

# 把扩展与宿主 App 注册给系统（widget 库靠这两步发现我们）
register:
	@# LaunchServices/PlugInKit 会缓存扩展的 Info.plist（图标、渲染能力等）。
	@# 只 -a 不 -r 时，升级后仍可能继续使用旧记录；先清掉再注册。
	@pluginkit -r $(APPEX) 2>/dev/null || true
	@pluginkit -a $(APPEX) 2>&1 | sed 's/^/  /' || echo "  (pluginkit 注册返回非零，可能已注册)"
	@$(LSREGISTER) -f $(APP) >/dev/null 2>&1 || true
	@killall chronod 2>/dev/null || true
	@sleep 1
	@echo "已注册：$$(pluginkit -m -i $(WIDGET_ID) 2>/dev/null | head -1 || echo 'pluginkit 未列出')"

# 把宿主 App 装到 /Applications（系统小组件库对这里的 App 最友好）
INSTALL_PATH := /Applications/YearProgress.app
APPEX_INSTALL := $(INSTALL_PATH)/Contents/PlugIns/YearProgressWidget.appex

install: widget
	@osascript -e 'tell application id "$(BUNDLE_ID)" to quit' >/dev/null 2>&1 || true
	@sleep 1
	@# widget 目标会先注册 build/ 下的 App；装到 /Applications 后必须清掉 build 记录，
	@# 否则同一个 bundle id 会出现两条 LaunchServices 记录，chronod 可能报
	@# “LS doesn't have a containing bundle” 或继续用旧图标。
	@pluginkit -r $(APPEX) 2>/dev/null || true
	@$(LSREGISTER) -u $(APP) >/dev/null 2>&1 || true
	@# 只替换已安装副本；不要 -u 卸载 /Applications，否则会破坏 appex 的 containing bundle 关系。
	@rm -rf "$(INSTALL_PATH)"
	@cp -R $(APP) "$(INSTALL_PATH)"
	@pluginkit -r "$(APPEX_INSTALL)" 2>/dev/null || true
	@$(LSREGISTER) -f "$(INSTALL_PATH)" >/dev/null 2>&1 || true
	@sleep 1
	@pluginkit -a "$(APPEX_INSTALL)" 2>/dev/null || true
	@$(MAKE) -s reset-widget-cache
	@killall chronod 2>/dev/null || true
	@# 小组件库/桌面宿主的图标与渲染缓存由通知中心持有，重启后才会重新读取 appex。
	@killall NotificationCenter 2>/dev/null || true
	@killall iconservicesagent 2>/dev/null || true
	@sleep 1
	@echo "已安装到 $(INSTALL_PATH) 并重新注册"
	@open "$(INSTALL_PATH)"

# 清掉本扩展的归档/快照缓存；这些文件由 chronod 生成，删掉后会按需重建。
# 覆盖安装后如果不清理，桌面小组件可能继续展示旧版本留下的白板快照。
reset-widget-cache:
	@find "$(HOME)/Library/Containers/$(WIDGET_ID)/Data/SystemData/com.apple.chrono" -type f -delete 2>/dev/null || true
	@echo "已清理 $(WIDGET_ID) 的小组件归档缓存"

uninstall:
	@pluginkit -r "$(INSTALL_PATH)/Contents/PlugIns/YearProgressWidget.appex" 2>/dev/null || true
	@rm -rf "$(INSTALL_PATH)"
	@killall chronod 2>/dev/null || true
	@echo "已卸载 $(INSTALL_PATH)"

widget-uninstall:
	@pluginkit -r $(APPEX) 2>/dev/null || true
	@killall chronod 2>/dev/null || true
	@echo "已移除注册"

open: app
	open $(APP)

# 重新生成 App 图标（Tools/make-icon.swift → .iconset → .icns）
icon:
	@mkdir -p $(BUILD_DIR)/AppIcon.iconset
	$(SWIFT) Tools/make-icon.swift light $(BUILD_DIR)/AppIcon-1024.png 1024
	@sips -z 16 16   $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16.png >/dev/null
	@sips -z 32 32   $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16@2x.png >/dev/null
	@sips -z 32 32   $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32.png >/dev/null
	@sips -z 64 64   $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32@2x.png >/dev/null
	@sips -z 128 128 $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128.png >/dev/null
	@sips -z 256 256 $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128@2x.png >/dev/null
	@sips -z 256 256 $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256.png >/dev/null
	@sips -z 512 512 $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256@2x.png >/dev/null
	@sips -z 512 512 $(BUILD_DIR)/AppIcon-1024.png --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512.png >/dev/null
	@cp $(BUILD_DIR)/AppIcon-1024.png $(BUILD_DIR)/AppIcon.iconset/icon_512x512@2x.png
	@iconutil -c icns $(BUILD_DIR)/AppIcon.iconset -o Support/AppIcon.icns
	@echo "已生成 Support/AppIcon.icns"

# 拉取某年的官方节假日安排（来源：holiday-cn 镜像国务院通知）
# 用法：make holidays YEAR=2027
YEAR ?= 2026
holidays:
	@mkdir -p Support/holidays
	@curl -fsSL -H "Accept: application/vnd.github.raw" \
	  "https://api.github.com/repos/NateScarlet/holiday-cn/contents/$(YEAR).json?ref=master" \
	  -o Support/holidays/$(YEAR).json
	@echo "已更新 Support/holidays/$(YEAR).json（请检查 days 是否非空后再打包）"

# 一键体检：注册状态 / 入口点 / 最近崩溃 / 扩展是否被调用
diagnose:
	@echo "== 注册 =="; pluginkit -m -v -i $(WIDGET_ID) 2>/dev/null || echo "  未注册"
	@echo "== 入口点（应为 _NSExtensionMain 的桩）=="
	@otool -l "$(APP)/Contents/PlugIns/YearProgressWidget.appex/Contents/MacOS/YearProgressWidget" 2>/dev/null | awk '/cmd LC_MAIN/{f=1} f{print} f&&/entryoff/{f=0}' | grep entryoff || true
	@otool -IV "$(APP)/Contents/PlugIns/YearProgressWidget.appex/Contents/MacOS/YearProgressWidget" 2>/dev/null | grep -i NSExtensionMain | head -1 || echo "  缺少 _NSExtensionMain（入口点未修好）"
	@echo "== 图标 =="
	@plutil -p "$(INSTALL_PATH)/Contents/Info.plist" 2>/dev/null | grep -E 'CFBundleIcon' || true
	@plutil -p "$(APPEX_INSTALL)/Contents/Info.plist" 2>/dev/null | grep -E 'CFBundleIcon' || true
	@ls -l "$(APPEX_INSTALL)/Contents/Resources/AppIcon.icns" 2>/dev/null || echo "  缺少 appex 图标"
	@echo "== 最近 1 小时崩溃（应无输出）=="
	@find ~/Library/Logs/DiagnosticReports -name "YearProgressWidget-*.ips" -mmin -60 2>/dev/null | head -3 || true
	@echo "== 扩展最近一次被调用 =="
	@log show --last 30m --style compact --predicate 'process == "YearProgressWidget"' 2>/dev/null | grep -E "main \[WidgetBundle\]|WidgetHost" | tail -3 || echo "  还没被系统调用过（去「编辑小组件」里打开一次）"

clean:
	rm -rf .build $(BUILD_DIR)
