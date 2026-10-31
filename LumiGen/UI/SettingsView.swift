import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {

    @EnvironmentObject private var studio: Studio
    @EnvironmentObject private var themeStore: ThemeStore
    @EnvironmentObject private var library: ModelLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?

    private let sizeOptions = [512, 768, 1024]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    backgroundSection
                    sizeSection
                    modelSection
                    aboutSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(backdrop)
            .navigationTitle("外观")
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
        .onChange(of: pickerItem) { _, newValue in
            handlePicked(newValue)
        }
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.13),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.62, green: 0.32, blue: 0.95).opacity(0.28), .clear],
                           center: .topTrailing, startRadius: 10, endRadius: 420)
                .blendMode(.screen)
        }
        .ignoresSafeArea()
    }

    // MARK: - 背景

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("背景")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                ForEach(ThemeCatalog.all) { theme in
                    themeSwatch(theme)
                }
                if let custom = themeStore.customImage {
                    customSwatch(custom)
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 12))
                        Text("从相册选一张").font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassCapsule(strength: 0.9)
                }

                if themeStore.customImage != nil {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { themeStore.clearCustom() }
                    } label: {
                        Text("清除自定义")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .glassCapsule(strength: 0.7)
                    }
                    .buttonStyle(SoftPressStyle())
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func themeSwatch(_ theme: SceneTheme) -> some View {
        let isOn = themeStore.selectedID == theme.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                themeStore.select(theme.id)
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [theme.top, theme.glowA, theme.bottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [theme.glowB.opacity(0.8), .clear],
                               center: .topTrailing, startRadius: 2, endRadius: 90)
                    .blendMode(.screen)
                Text(theme.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(8)
                if isOn {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(isOn ? 0.85 : 0.12), lineWidth: isOn ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 6)
        }
        .buttonStyle(SoftPressStyle())
    }

    private func customSwatch(_ image: UIImage) -> some View {
        let isOn = themeStore.selectedID == ThemeStore.customID
        return Button {
            themeStore.select(ThemeStore.customID)
        } label: {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 84)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                Text("我的照片")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(8)
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(isOn ? 0.85 : 0.12), lineWidth: isOn ? 2 : 1)
            )
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: - 尺寸

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("出图尺寸")
            HStack(spacing: 8) {
                ForEach(availableSizes, id: \.self) { size in
                    let isOn = studio.resolution == size
                    Button {
                        studio.resolutionOverride = size
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(size)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(size == 512 ? "秒出" : (size == 768 ? "均衡" : "高清"))
                                .font(.system(size: 10))
                                .opacity(0.6)
                        }
                        .foregroundStyle(isOn ? Color.black.opacity(0.85) : Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.9))
                            }
                        }
                        .glassCard(cornerRadius: 16, strength: isOn ? 0.2 : 0.8)
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            Text("尺寸越大细节越多，出图也越慢、越费电。")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var availableSizes: [Int] {
        guard let model = studio.model else { return [512, 768] }
        return model.kind == .sdxl ? [512, 768, 1024] : [384, 512]
    }

    // MARK: - 模型

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("模型")
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    studio.showSetup = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(studio.model?.name ?? "还没装模型")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                        Text(studio.model?.sizeText ?? "点这里去挑一个")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(14)
                .glassCard(cornerRadius: 18, strength: 0.85)
            }
            .buttonStyle(SoftPressStyle())
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("关于")
            VStack(alignment: .leading, spacing: 7) {
                infoRow("版本", "1.0")
                infoRow("推理", "Core ML · 全部在本机")
                infoRow("联网", "只在下载模型时使用")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 18, strength: 0.8)
        }
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: -

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.42))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handlePicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    themeStore.setCustom(image)
                    studio.showBanner("背景换好了")
                }
            }
        }
    }
}
