import SwiftUI
import UIKit

struct PromptDock: View {

    @EnvironmentObject private var studio: Studio
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 9) {
            styleRail

            HStack(alignment: .bottom, spacing: 10) {
                inputField
                generateButton
            }

            footer
        }
        .padding(12)
        .glassCard(cornerRadius: 30)
    }

    // MARK: - 风格

    private var styleRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StylePreset.all) { style in
                    GlassChip(title: style.name,
                              emoji: style.emoji,
                              isOn: studio.styleID == style.id,
                              tint: style.tint) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            studio.styleID = style.id
                        }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    // MARK: - 输入

    private var inputField: some View {
        ZStack(alignment: .leading) {
            if studio.prompt.isEmpty {
                Text("想要什么画面？")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.white.opacity(0.38))
                    .padding(.leading, 15)
                    .allowsHitTesting(false)
            }
            TextField("", text: $studio.prompt, axis: .vertical)
                .lineLimit(1...3)
                .focused($focused)
                .font(.system(size: 14.5))
                .foregroundStyle(.white.opacity(0.95))
                .tint(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .submitLabel(.return)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var generateButton: some View {
        Button {
            if studio.isBusy {
                studio.cancel()
            } else {
                focused = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                studio.generate()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Color.white, Color(white: 0.80)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))

                if studio.isBusy {
                    Circle()
                        .trim(from: 0, to: max(0.05, studio.phase.fraction))
                        .stroke(Color.black.opacity(0.65),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(5)
                        .animation(.easeOut(duration: 0.3), value: studio.phase.fraction)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.75))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.88))
                }
            }
            .frame(width: 54, height: 54)
            .shadow(color: Color.white.opacity(0.22), radius: 14, y: 5)
            .opacity(studio.canGenerate || studio.isBusy ? 1 : 0.4)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!studio.canGenerate && !studio.isBusy)
    }

    // MARK: - 底部小字

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 10))
            Text("\(studio.resolution)px · \(studio.style.steps ?? studio.model?.steps ?? 4) 步 · 全程离线")
                .font(.system(size: 10.5))
            Spacer(minLength: 0)
            if studio.lastSeconds > 0, studio.image != nil {
                Text(String(format: "上次 %.1fs", studio.lastSeconds))
                    .font(.system(size: 10.5))
            }
        }
        .foregroundStyle(.white.opacity(0.38))
        .padding(.horizontal, 4)
        .padding(.bottom, 1)
    }
}
