import AppKit
import SwiftUI
import YearProgressCore
import YearProgressUI

/// 离屏渲染：不需要打开窗口就能把卡片画成 PNG，用于自查视觉效果。
enum SnapshotRunner {
    @MainActor
    static func run(options: CLIOptions, outputPath: String) {
        let progress = YearProgressCalculator.progress(for: options.date ?? Date(),
                                                      timeZone: options.timeZone,
                                                      weekStartMode: options.weekStartMode)
        let chrome: CardChrome = options.chrome == .widget ? .widget : .card
        let card = YearProgressCardView(progress: progress,
                                        theme: options.theme,
                                        size: options.size,
                                        profile: options.chrome == .widget ? .widget : .app,
                                        chrome: chrome)
            .padding(options.margin)
            .background(Color.clear)

        let renderer = ImageRenderer(content: card)
        renderer.scale = options.scale
        renderer.isOpaque = false

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot: 渲染失败\n".utf8))
            exit(1)
        }
        let url = URL(fileURLWithPath: outputPath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try png.write(to: url)
            print("已导出 \(outputPath)  \(Int(image.size.width * options.scale))x\(Int(image.size.height * options.scale))")
            print("  \(progress.yearTitle)  \(progress.subtitle)  \(progress.footerText)")
        } catch {
            FileHandle.standardError.write(Data("snapshot: 写入失败 \(error)\n".utf8))
            exit(1)
        }
        exit(0)
    }
}
