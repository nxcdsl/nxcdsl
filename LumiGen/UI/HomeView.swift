import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var studio: Studio
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        VStack(spacing: 10) {
            topBar
            Spacer(minLength: 4)
            ResultCanvas()
            Spacer(minLength: 4)
            PromptDock()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("灵绘")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.72)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text("说一句话，画面就出来了")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer(minLength: 6)

            modelPill

            GlassIconButton(systemName: "circle.lefthalf.filled", size: 40) {
                studio.showSettings = true
            }
        }
    }

    private var modelPill: some View {
        Button {
            studio.showSetup = true
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(studio.model == nil ? Color.orange : Color(red: 0.45, green: 0.92, blue: 0.72))
                    .frame(width: 6, height: 6)
                Text(studio.model?.name ?? "装个模型")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .glassCapsule(strength: 0.9)
        }
        .buttonStyle(SoftPressStyle())
    }
}
