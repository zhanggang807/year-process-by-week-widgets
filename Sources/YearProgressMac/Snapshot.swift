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
        if options.popoverPreview {
            let cardSize = AppState.defaultSize
            let view = QuickPopoverView(progress: progress,
                                        theme: options.theme,
                                        cardSize: cardSize,
                                        arrowHeight: 11,
                                        cornerRadius: 20,
                                        tailCenterX: cardSize.width / 2)
                .padding(options.margin)
                .background(Color.clear)
            let renderer = ImageRenderer(content: view)
            renderer.scale = options.scale
            renderer.isOpaque = false
            if let image = renderer.nsImage,
               let tiff = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: outputPath))
                print("已导出 \(outputPath)  \(Int(image.size.width * options.scale))x\(Int(image.size.height * options.scale))")
                exit(0)
            }
        }

        let chrome: CardChrome = options.chrome == .widget ? .widget : .card
        let card = YearProgressCardView(progress: progress,
                                        theme: options.theme,
                                        size: options.size,
                                        profile: options.chrome == .widget ? .widget : .app,
                                        chrome: chrome,
                                        fixedColumns: options.columns ?? (chrome == .card ? WidgetGridReference.columns(weekCount: progress.totalWeeks) : nil),
                                        headerFontOverride: options.headerFontOverride)
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
        // 布局诊断（和卡片内部用同一套算法）
        let profile: CardProfile = options.chrome == .widget ? .widget : .app
        let metrics = CardMetrics(size: options.size, profile: profile, headerFontOverride: options.headerFontOverride)
        let fixedColumns = options.columns ?? (chrome == .card ? WidgetGridReference.columns(weekCount: progress.totalWeeks) : nil)
        let layout = GridLayoutCalculator.compute(weekCount: progress.totalWeeks,
                                                 available: metrics.gridArea(noteVisible: progress.boundaryNote != nil),
                                                 forcedColumns: fixedColumns)
        print("  布局: \(layout.columns) 列 × \(layout.rows) 行 · 方块 \(String(format: "%.1f", layout.cellSize))pt · 末行 \(layout.lastRowCount(weekCount: progress.totalWeeks)) 块 · 顶部字号 \(String(format: "%.1f", metrics.headerFont))pt")

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
