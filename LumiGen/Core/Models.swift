import SwiftUI
import Foundation

// MARK: - 模型种类

enum ModelKind: String, Codable {
    case sdxl
    case sd15

    var displayName: String {
        switch self {
        case .sdxl: return "SDXL"
        case .sd15: return "SD 1.5"
        }
    }
}

// MARK: - 可下载的模型预设

struct ModelPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    /// HuggingFace 仓库 ID
    let repo: String
    /// 仓库内的子目录（可选）
    let subfolder: String?
    let kind: ModelKind
    let sizeGB: Double
    let steps: Int
    let guidance: Float
    let resolution: Int
    let accent: Color

    var summary: String {
        "\(kind.displayName) · \(String(format: "%.1f", sizeGB))GB · \(steps)步 · \(resolution)px"
    }
}

enum ModelCatalog {

    static let presets: [ModelPreset] = [
        ModelPreset(
            id: "dreamshaper-xl-turbo",
            name: "DreamShaper XL Turbo",
            tagline: "推荐 · 全能风格，最适合这台手机",
            repo: "BulentOngun/coreml-dreamshaper-xl-turbo",
            subfolder: nil,
            kind: .sdxl,
            sizeGB: 2.6,
            steps: 4,
            guidance: 0,
            resolution: 768,
            accent: Color(red: 0.55, green: 0.72, blue: 1.0)
        ),
        ModelPreset(
            id: "sd15-palettized",
            name: "SD 1.5 轻量版",
            tagline: "省电省内存，出图更快，画质朴素",
            repo: "apple/coreml-stable-diffusion-v1-5-palettized",
            subfolder: "split_einsum_v2/compiled",
            kind: .sd15,
            sizeGB: 0.9,
            steps: 22,
            guidance: 6.5,
            resolution: 512,
            accent: Color(red: 0.75, green: 0.62, blue: 1.0)
        ),
    ]

    static func preset(id: String) -> ModelPreset? {
        presets.first { $0.id == id }
    }
}

// MARK: - 风格

struct StylePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    /// 悄悄加在提示词后面的风格描述（不给用户看，保持简单）
    let promptSuffix: String
    /// 覆盖模型默认步数（nil = 用模型默认）
    let steps: Int?
    let tint: Color
}

extension StylePreset {

    static let all: [StylePreset] = [
        StylePreset(id: "none", name: "原样", emoji: "◌",
                    promptSuffix: "", steps: nil,
                    tint: Color(white: 0.85)),
        StylePreset(id: "anime", name: "二次元", emoji: "✿",
                    promptSuffix: "anime style, clean line art, vibrant colors, detailed illustration, beautiful lighting, high quality",
                    steps: nil,
                    tint: Color(red: 1.0, green: 0.62, blue: 0.78)),
        StylePreset(id: "photo", name: "写实", emoji: "◎",
                    promptSuffix: "photorealistic, 85mm photograph, natural light, shallow depth of field, ultra detailed, film grain",
                    steps: nil,
                    tint: Color(red: 0.62, green: 0.82, blue: 0.72)),
        StylePreset(id: "guofeng", name: "国风", emoji: "❋",
                    promptSuffix: "traditional chinese painting, ink wash, elegant brushwork, silk texture, misty mountains, oriental aesthetic",
                    steps: nil,
                    tint: Color(red: 0.92, green: 0.78, blue: 0.52)),
        StylePreset(id: "3d", name: "3D", emoji: "◈",
                    promptSuffix: "3d render, soft studio lighting, subtle subsurface scattering, clay and glass materials, octane render, cute",
                    steps: nil,
                    tint: Color(red: 0.58, green: 0.88, blue: 0.92)),
        StylePreset(id: "watercolor", name: "水彩", emoji: "❀",
                    promptSuffix: "watercolor illustration, soft washes, bleeding pigment, textured paper, gentle pastel palette",
                    steps: nil,
                    tint: Color(red: 0.88, green: 0.70, blue: 0.95)),
        StylePreset(id: "cyber", name: "赛博", emoji: "◐",
                    promptSuffix: "cyberpunk, neon reflections, rainy night city, cinematic lighting, volumetric fog, moody atmosphere",
                    steps: nil,
                    tint: Color(red: 0.50, green: 0.90, blue: 0.98)),
        StylePreset(id: "flat", name: "极简", emoji: "▢",
                    promptSuffix: "minimal flat vector illustration, bold geometric shapes, limited color palette, lots of negative space, poster design",
                    steps: nil,
                    tint: Color(red: 0.98, green: 0.85, blue: 0.60)),
    ]

    /// 隐藏的负向描述，用户不需要操心
    static let baseNegative = "lowres, blurry, jpeg artifacts, watermark, signature, text, extra limbs, deformed hands, bad anatomy"

    func prompt(from userPrompt: String) -> String {
        let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptSuffix.isEmpty else { return trimmed }
        return trimmed + ", " + promptSuffix
    }
}

// MARK: - 已安装模型

struct InstalledModel: Identifiable, Hashable {
    let url: URL
    let name: String
    let kind: ModelKind
    let sizeBytes: Int64
    let steps: Int
    let guidance: Float
    let resolution: Int
    let presetID: String?

    var id: String { url.path }

    var sizeText: String {
        let gb = Double(sizeBytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(sizeBytes) / 1_048_576)
    }

    /// 内存吃紧的机型打开低内存模式
    var reduceMemory: Bool {
        ProcessInfo.processInfo.physicalMemory < 11 * 1024 * 1024 * 1024
    }
}
