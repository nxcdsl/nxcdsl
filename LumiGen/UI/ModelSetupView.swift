import SwiftUI
import UIKit

struct ModelSetupView: View {

    @EnvironmentObject private var studio: Studio
    @EnvironmentObject private var library: ModelLibrary
    @EnvironmentObject private var installer: ModelInstaller
    @Environment(\.dismiss) private var dismiss

    @AppStorage("lumigen.mirror") private var mirror: String = ModelInstaller.defaultMirror
    @State private var showAdvanced = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    intro
                    if !library.models.isEmpty { installedSection }
                    presetSection
                    advancedSection
                    footnote
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(backdrop)
            .navigationTitle("模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onChange(of: installer.state) { _, newValue in
            if case .finished = newValue {
                library.refresh()
                if let installed = library.models.first(where: { $0.presetID == currentInstallingID }) {
                    library.select(installed)
                }
                studio.showBanner("模型装好了")
            }
        }
    }

    @State private var currentInstallingID: String?

    // MARK: - 背景

    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.09, blue: 0.13),
                         Color(red: 0.03, green: 0.03, blue: 0.05)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(colors: [Color(red: 0.30, green: 0.42, blue: 0.95).opacity(0.30), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 420)
                .blendMode(.screen)
        }
        .ignoresSafeArea()
    }

    // MARK: - 介绍

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("只下载一次，之后彻底离线")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("模型会存到 App 自己的文件夹里，出图时不上传任何内容，也不联网。建议先接上 Wi-Fi。")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 已安装

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("已在本机")
            VStack(spacing: 8) {
                ForEach(library.models) { model in
                    installedRow(model)
                }
            }
        }
    }

    private func installedRow(_ model: InstalledModel) -> some View {
        let isSelected = library.current?.id == model.id
        return HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isSelected ? 0.92 : 0.10))
                        .frame(width: 30, height: 30)
                    Image(systemName: isSelected ? "checkmark" : "cube")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.7))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                    Text("\(model.kind.displayName) · \(model.sizeText) · \(model.steps)步")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 0)
                Button {
                    library.delete(model)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 18, strength: 0.9)
            .contentShape(Rectangle())
            .onTapGesture {
                library.select(model)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
    }

    // MARK: - 可选模型

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("挑一个")
            ForEach(ModelCatalog.presets) { preset in
                presetCard(preset)
            }
        }
    }

    private func presetCard(_ preset: ModelPreset) -> some View {
        let isInstalled = library.models.contains { $0.presetID == preset.id }
        let isWorking = installer.state == .working && currentInstallingID == preset.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [preset.accent.opacity(0.95), preset.accent.opacity(0.35)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.72))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(preset.tagline)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.50))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Text(preset.summary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))

            if isWorking {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: max(0.02, installer.progress))
                        .progressViewStyle(.linear)
                        .tint(preset.accent)
                    Text(installer.detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button {
                        installer.cancel()
                    } label: {
                        Text("取消")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            } else if isInstalled {
                Label("已安装", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.45, green: 0.92, blue: 0.72))
            } else {
                Button {
                    currentInstallingID = preset.id
                    installer.install(preset: preset, mirror: mirror) { result in
                        if case .failure(let error) = result {
                            studio.showBanner(error.localizedDescription)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 13))
                        Text("下载 \(String(format: "%.1f", preset.sizeGB)) GB")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.92)))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(installer.state == .working)
                .opacity(installer.state == .working ? 0.45 : 1)
            }

            if case .failed(let message) = installer.state, currentInstallingID == preset.id {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.55))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
    }

    // MARK: - 高级

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("下载源").font(.system(size: 12.5, weight: .medium))
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(alignment: .leading, spacing: 8) {
                    Text("默认走镜像站，下载不动时可以换成 huggingface.co 或其他可用镜像。")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.40))
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("hf-mirror.com", text: $mirror)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08)))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 18, strength: 0.8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("模型本身没有任何内容过滤，理解任意描述；生成完全在本地完成。")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.32))
            Text("也可以把模型文件夹（含 Unet.mlmodelc、vocab.json 等）放进「文件 → 我的 iPhone → 灵绘 → Models」。")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.32))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.42))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
