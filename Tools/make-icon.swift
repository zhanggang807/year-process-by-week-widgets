import AppKit

// 年进度 App 图标生成器
// 用法: swift Tools/make-icon.swift <dark|light> <out.png> [size]
// 概念：一张「一年的周」网格，已过部分实、未来部分淡，当前周高亮。

let variant = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dark"
let outPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/icon.png"
let canvas = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3])! : 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let s = CGFloat(canvas) / 1024.0
NSGraphicsContext.current?.cgContext.scaleBy(x: s, y: s)

// 1) 圆角方形底板（macOS 图标留白约 9.4%）
let plate = NSRect(x: 96, y: 96, width: 832, height: 832)
let path = NSBezierPath(roundedRect: plate, xRadius: 186, yRadius: 186)

let bgColors: [NSColor]
let pastColor: NSColor
let futureColor: NSColor
let currentColor: NSColor
switch variant {
case "light":
    bgColors = [color(0xF7F8FA), color(0xE4E6EC)]
    pastColor = color(0x2A2C31)
    futureColor = color(0xCDD0D7)
    currentColor = color(0x7C5CE0)
default:
    bgColors = [color(0x3B3D43), color(0x1B1C20)]
    pastColor = color(0xE9EBEF)
    futureColor = color(0xFFFFFF, 0.14)
    currentColor = color(0xA8CBE2)
}
NSGradient(colors: bgColors)!.draw(in: path, angle: -50)

// 极淡的边，让浅色图标在浅色背景上也有轮廓
path.lineWidth = 2
color(0x000000, variant == "light" ? 0.07 : 0.20).setStroke()
path.stroke()

// 2) 一年 52 周：4 行 × 13 列，已过 41 周，当前周高亮
let cols = 13, rows = 4
let block: CGFloat = 48, gap: CGFloat = 8
let gridW = CGFloat(cols) * block + CGFloat(cols - 1) * gap
let gridH = CGFloat(rows) * block + CGFloat(rows - 1) * gap
let originX = (1024 - gridW) / 2
let originY = (1024 - gridH) / 2

let currentIndex = 40   // 0-based：第 41 周
for i in 0..<(cols * rows) {
    let c = i % cols, r = i / cols
    let rect = NSRect(x: originX + CGFloat(c) * (block + gap),
                      y: originY + CGFloat(rows - 1 - r) * (block + gap),
                      width: block, height: block)
    let blockPath = NSBezierPath(roundedRect: rect, xRadius: block * 0.26, yRadius: block * 0.26)
    if i == currentIndex {
        currentColor.setFill()
    } else if i < currentIndex {
        pastColor.setFill()
    } else {
        futureColor.setFill()
    }
    blockPath.fill()
}

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
