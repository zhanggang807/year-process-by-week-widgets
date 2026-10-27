import SwiftUI
import YearProgressCore
import YearProgressUI

struct YearProgressHomeView: View {
    @State private var theme: CardTheme = .violet

    private let previewThemes: [CardTheme] = [.violet, .graphite, .slate]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let progress = IOSProgressFactory.make(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(progress)
                    card(progress)
                    themePicker
                    instructions
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background {
                LinearGradient(
                    colors: [Color(red: 0.96, green: 0.95, blue: 1.0), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }

    private func header(_ progress: YearProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("年度周进度")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.16))

            Text("把一年铺成 \(progress.totalWeeks) 格，看看时间走到了哪里。")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func card(_ progress: YearProgress) -> some View {
        GeometryReader { geometry in
            YearProgressCardView(
                progress: progress,
                theme: theme,
                size: geometry.size,
                profile: .app,
                chrome: .card,
                showsTooltips: false
            )
        }
        .aspectRatio(600.0 / 292.0, contentMode: .fit)
        .shadow(color: theme.pastFill.opacity(0.18), radius: 22, y: 12)
        .accessibilityElement(children: .combine)
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("预览主题")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Picker("预览主题", selection: $theme) {
                ForEach(previewThemes) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("添加到主屏幕")
                .font(.system(size: 18, weight: .bold))

            Label("长按主屏幕空白处，点击左上角“编辑”。", systemImage: "hand.tap")
            Label("选择“添加小组件”，搜索“年进度”。", systemImage: "plus.square")
            Label("可选小号、中号、大号，也可添加到锁屏。", systemImage: "rectangle.3.group")

            Divider()

            Text("小组件固定使用暗岩灰配色，并在下一个本地零点自动更新。主题选择只影响此处预览。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(18)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    YearProgressHomeView()
}
