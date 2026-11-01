import Foundation

/// 内置文件清单：不再依赖镜像站的目录接口，避免"卡在读取清单"
enum ModelManifest {
    static let dreamshaperFiles: [(String, Int64)] = [
        ("TextEncoder.mlmodelc/analytics/coremldata.bin", 243),
        ("TextEncoder.mlmodelc/coremldata.bin", 958),
        ("TextEncoder.mlmodelc/metadata.json", 3005),
        ("TextEncoder.mlmodelc/model.mil", 185770),
        ("TextEncoder.mlmodelc/weights/weight.bin", 139910080),
        ("TextEncoder2.mlmodelc/analytics/coremldata.bin", 243),
        ("TextEncoder2.mlmodelc/coremldata.bin", 958),
        ("TextEncoder2.mlmodelc/metadata.json", 3012),
        ("TextEncoder2.mlmodelc/model.mil", 482215),
        ("TextEncoder2.mlmodelc/weights/weight.bin", 600794240),
        ("UnetChunk1.mlmodelc/analytics/coremldata.bin", 243),
        ("UnetChunk1.mlmodelc/coremldata.bin", 661),
        ("UnetChunk1.mlmodelc/metadata.json", 6497),
        ("UnetChunk1.mlmodelc/model.mil", 5232320),
        ("UnetChunk1.mlmodelc/weights/weight.bin", 968067264),
        ("UnetChunk2.mlmodelc/analytics/coremldata.bin", 243),
        ("UnetChunk2.mlmodelc/coremldata.bin", 590),
        ("UnetChunk2.mlmodelc/metadata.json", 5594),
        ("UnetChunk2.mlmodelc/model.mil", 5446157),
        ("UnetChunk2.mlmodelc/weights/weight.bin", 959821632),
        ("VAEDecoder.mlmodelc/analytics/coremldata.bin", 243),
        ("VAEDecoder.mlmodelc/coremldata.bin", 907),
        ("VAEDecoder.mlmodelc/metadata.json", 2724),
        ("VAEDecoder.mlmodelc/model.mil", 194896),
        ("VAEDecoder.mlmodelc/weights/weight.bin", 98993280),
        ("merges.txt", 524657),
        ("vocab.json", 862328),
    ]
    static let sd15Files: [(String, Int64)] = [
        ("TextEncoder.mlmodelc/analytics/coremldata.bin", 207),
        ("TextEncoder.mlmodelc/coremldata.bin", 825),
        ("TextEncoder.mlmodelc/metadata.json", 2771),
        ("TextEncoder.mlmodelc/model.mil", 208229),
        ("TextEncoder.mlmodelc/weights/weight.bin", 139866304),
        ("Unet.mlmodelc/analytics/coremldata.bin", 207),
        ("Unet.mlmodelc/coremldata.bin", 1207),
        ("Unet.mlmodelc/metadata.json", 3705),
        ("Unet.mlmodelc/model.mil", 3040467),
        ("Unet.mlmodelc/weights/weight.bin", 645167616),
        ("VAEDecoder.mlmodelc/analytics/coremldata.bin", 207),
        ("VAEDecoder.mlmodelc/coremldata.bin", 755),
        ("VAEDecoder.mlmodelc/metadata.json", 2472),
        ("VAEDecoder.mlmodelc/model.mil", 181386),
        ("VAEDecoder.mlmodelc/weights/weight.bin", 98993280),
        ("VAEEncoder.mlmodelc/analytics/coremldata.bin", 207),
        ("VAEEncoder.mlmodelc/coremldata.bin", 761),
        ("VAEEncoder.mlmodelc/metadata.json", 2460),
        ("VAEEncoder.mlmodelc/model.mil", 139736),
        ("VAEEncoder.mlmodelc/weights/weight.bin", 68338112),
        ("merges.txt", 524657),
        ("vocab.json", 862328),
    ]

    static func files(for presetID: String) -> [(String, Int64)]? {
        switch presetID {
        case "dreamshaper-xl-turbo": return dreamshaperFiles
        case "sd15-palettized": return sd15Files
        default: return nil
        }
    }
}