import AppKit
import CoreGraphics

// iOS masks the icon itself, so this variant is a full opaque square with no
// macOS-style transparent margin. The grid, colors and week states match the
// macOS icon; output is exactly 1024x1024 and RGB-only.
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"
let size = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Unable to allocate icon bitmap")
}

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0xF7F8FA).cgColor, color(0xE4E6EC).cgColor] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: CGFloat(size)),
    end: CGPoint(x: CGFloat(size), y: 0),
    options: []
)

let columns = 4
let rows = 4
let block: CGFloat = 150
let gap: CGFloat = 30
let gridWidth = CGFloat(columns) * block + CGFloat(columns - 1) * gap
let gridHeight = CGFloat(rows) * block + CGFloat(rows - 1) * gap
let originX = (CGFloat(size) - gridWidth) / 2
let originY = (CGFloat(size) - gridHeight) / 2

for index in 0..<(columns * rows) {
    let column = index % columns
    let row = index / columns
    let rect = CGRect(
        x: originX + CGFloat(column) * (block + gap),
        y: originY + CGFloat(rows - 1 - row) * (block + gap),
        width: block,
        height: block
    )
    let blockPath = CGPath(
        roundedRect: rect,
        cornerWidth: block * 0.26,
        cornerHeight: block * 0.26,
        transform: nil
    )
    if index == 10 {
        context.setFillColor(color(0x7C5CE0).cgColor)
    } else if index < 11 {
        context.setFillColor(color(0x2A2C31).cgColor)
    } else {
        context.setFillColor(color(0xCDD0D7).cgColor)
    }
    context.addPath(blockPath)
    context.fillPath()
}

guard let image = context.makeImage() else {
    fatalError("Unable to create icon image")
}
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
