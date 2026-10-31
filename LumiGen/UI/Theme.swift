import SwiftUI
import UIKit
import Combine

/// 背景主题
struct SceneTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let top: Color
    let bottom: Color
    let glowA: Color
    let glowB: Color
}

enum ThemeCatalog {

    static let all: [SceneTheme] = [
        SceneTheme(id: "aurora",
                   name: "极光",
                   top: Color(red: 0.07, green: 0.09, blue: 0.20),
                   bottom: Color(red: 0.02, green: 0.03, blue: 0.07),
                   glowA: Color(red: 0.24, green: 0.42, blue: 0.95),
                   glowB: Color(red: 0.62, green: 0.26, blue: 0.90)),
        SceneTheme(id: "dusk",
                   name: "暮色",
                   top: Color(red: 0.22, green: 0.10, blue: 0.24),
                   bottom: Color(red: 0.05, green: 0.03, blue: 0.06),
                   glowA: Color(red: 0.95, green: 0.38, blue: 0.42),
                   glowB: Color(red: 0.55, green: 0.22, blue: 0.85)),
        SceneTheme(id: "mint",
                   name: "薄荷",
                   top: Color(red: 0.05, green: 0.16, blue: 0.16),
                   bottom: Color(red: 0.01, green: 0.04, blue: 0.05),
                   glowA: Color(red: 0.24, green: 0.85, blue: 0.68),
                   glowB: Color(red: 0.18, green: 0.55, blue: 0.95)),
        SceneTheme(id: "peach",
                   name: "蜜桃",
                   top: Color(red: 0.20, green: 0.12, blue: 0.14),
                   bottom: Color(red: 0.05, green: 0.03, blue: 0.05),
                   glowA: Color(red: 1.00, green: 0.62, blue: 0.45),
                   glowB: Color(red: 0.92, green: 0.36, blue: 0.62)),
        SceneTheme(id: "ink",
                   name: "墨黑",
                   top: Color(red: 0.10, green: 0.10, blue: 0.12),
                   bottom: Color(red: 0.02, green: 0.02, blue: 0.03),
                   glowA: Color(red: 0.35, green: 0.36, blue: 0.42),
                   glowB: Color(red: 0.20, green: 0.22, blue: 0.30)),
        SceneTheme(id: "sakura",
                   name: "樱粉",
                   top: Color(red: 0.22, green: 0.12, blue: 0.20),
                   bottom: Color(red: 0.06, green: 0.03, blue: 0.06),
                   glowA: Color(red: 1.00, green: 0.60, blue: 0.78),
                   glowB: Color(red: 0.66, green: 0.44, blue: 0.98)),
    ]

    static func theme(id: String) -> SceneTheme? {
        all.first { $0.id == id }
    }
}

/// 背景管理（内置渐变 + 自定义照片）
final class ThemeStore: ObservableObject {

    static let customID = "custom"
    private static let key = "lumigen.theme"

    @Published var selectedID: String
    @Published var customImage: UIImage?

    static var customImageURL: URL {
        FileManager.default.documentsURL.appendingPathComponent("background.jpg")
    }

    init() {
        selectedID = UserDefaults.standard.string(forKey: ThemeStore.key) ?? ThemeCatalog.all[0].id
        customImage = UIImage(contentsOfFile: ThemeStore.customImageURL.path)
        if selectedID == ThemeStore.customID && customImage == nil {
            selectedID = ThemeCatalog.all[0].id
        }
    }

    var theme: SceneTheme {
        ThemeCatalog.theme(id: selectedID) ?? ThemeCatalog.all[0]
    }

    var isCustom: Bool {
        selectedID == ThemeStore.customID && customImage != nil
    }

    func select(_ id: String) {
        selectedID = id
        UserDefaults.standard.set(id, forKey: ThemeStore.key)
    }

    func setCustom(_ image: UIImage) {
        // 压到合适尺寸再存，别把相册原图拷进 App
        let target = ThemeStore.downscale(image, maxSide: 1600)
        if let data = target.jpegData(compressionQuality: 0.92) {
            try? data.write(to: ThemeStore.customImageURL)
        }
        customImage = target
        select(ThemeStore.customID)
    }

    func clearCustom() {
        try? FileManager.default.removeItem(at: ThemeStore.customImageURL)
        customImage = nil
        if selectedID == ThemeStore.customID {
            select(ThemeCatalog.all[0].id)
        }
    }

    static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - 背景视图

struct BackgroundLayer: View {

    @EnvironmentObject private var store: ThemeStore
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if store.isCustom, let image = store.customImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay(Color.black.opacity(0.38))
                        .overlay(
                            LinearGradient(colors: [Color.black.opacity(0.35), .clear, Color.black.opacity(0.55)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                } else {
                    gradientContent(size: proxy.size)
                }

                // 顶部提亮 + 底部压暗，让玻璃有层次
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear, Color.black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func gradientContent(size: CGSize) -> some View {
        let theme = store.theme
        return ZStack {
            LinearGradient(colors: [theme.top, theme.bottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)

            RadialGradient(colors: [theme.glowA.opacity(0.75), theme.glowA.opacity(0.0)],
                           center: drift ? UnitPoint(x: 0.28, y: 0.16) : UnitPoint(x: 0.18, y: 0.26),
                           startRadius: 8,
                           endRadius: max(size.width, size.height) * 0.78)
                .blendMode(.screen)

            RadialGradient(colors: [theme.glowB.opacity(0.55), theme.glowB.opacity(0.0)],
                           center: drift ? UnitPoint(x: 0.78, y: 0.82) : UnitPoint(x: 0.86, y: 0.70),
                           startRadius: 8,
                           endRadius: max(size.width, size.height) * 0.70)
                .blendMode(.screen)

            RadialGradient(colors: [Color.clear, Color.black.opacity(0.55)],
                           center: .center,
                           startRadius: min(size.width, size.height) * 0.30,
                           endRadius: max(size.width, size.height) * 0.85)
        }
    }
}
