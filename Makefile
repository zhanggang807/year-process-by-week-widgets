# 年进度小组件（macOS）— 无 Xcode 也能构建
#
#   make run        直接跑（菜单栏出现小图标 + 桌面卡片）
#   make app        打包成 build/YearProgress.app（含 Info.plist + ad-hoc 签名）
#   make open       打包并启动
#   make test       跑单元测试
#   make preview    用几个典型日期导出 PNG 到 docs/
#   make spec       重新生成 spec/year-weeks.json（跨平台真值表）
#   make clean

SWIFT      ?= swift
CONFIG     ?= release
BUILD_DIR  := build
APP        := $(BUILD_DIR)/YearProgress.app
BIN        := .build/$(CONFIG)/YearProgressMac
BUNDLE_ID  := com.local.yearprogress

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

.PHONY: all build test run preview spec app open clean help

all: build

help:
	@sed -n '1,12p' Makefile

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

spec:
	$(SWIFT) run year-weeks-dump spec/year-weeks.json

app: build
	@rm -rf $(APP)
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	@cp $(BIN) $(APP)/Contents/MacOS/YearProgress
	@printf '%s\n' \
	  '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0"><dict>' \
	  '  <key>CFBundleName</key><string>YearProgress</string>' \
	  '  <key>CFBundleDisplayName</key><string>年进度</string>' \
	  '  <key>CFBundleIdentifier</key><string>$(BUNDLE_ID)</string>' \
	  '  <key>CFBundleExecutable</key><string>YearProgress</string>' \
	  '  <key>CFBundlePackageType</key><string>APPL</string>' \
	  '  <key>CFBundleShortVersionString</key><string>0.1.0</string>' \
	  '  <key>CFBundleVersion</key><string>1</string>' \
	  '  <key>LSMinimumSystemVersion</key><string>14.0</string>' \
	  '  <key>NSHighResolutionCapable</key><true/>' \
	  '  <key>LSUIElement</key><true/>' \
	  '</dict></plist>' > $(APP)/Contents/Info.plist
	@codesign --force --sign - --timestamp=none $(APP) >/dev/null 2>&1 || echo "  (签名跳过)"
	@echo "已生成 $(APP)"

open: app
	open $(APP)

clean:
	rm -rf .build $(BUILD_DIR)
