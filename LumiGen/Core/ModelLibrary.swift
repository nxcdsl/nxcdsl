import Foundation
import Combine

/// 管理已经安装到本机的模型
final class ModelLibrary: ObservableObject {

    @Published private(set) var models: [InstalledModel] = []
    @Published private(set) var selectedPath: String?

    private let selectionKey = "lumigen.selectedModel"
    private let fm = FileManager.default

    static var rootURL: URL {
        let docs = fm.documentsURL
        return docs.appendingPathComponent("Models", isDirectory: true)
    }

    init() {
        selectedPath = UserDefaults.standard.string(forKey: selectionKey)
        refresh()
    }

    var current: InstalledModel? {
        if let p = selectedPath, let hit = models.first(where: { $0.url.path == p }) {
            return hit
        }
        return models.first
    }

    var isEmpty: Bool { models.isEmpty }

    func select(_ model: InstalledModel) {
        selectedPath = model.url.path
        UserDefaults.standard.set(model.url.path, forKey: selectionKey)
    }

    func refresh() {
        var found: [InstalledModel] = []
        let root = ModelLibrary.rootURL
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)

        let dirs = (try? fm.contentsOfDirectory(at: root,
                                                includingPropertiesForKeys: [.isDirectoryKey],
                                                options: [.skipsHiddenFiles])) ?? []

        for dir in dirs {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            if let model = Self.inspect(folder: dir) {
                found.append(model)
            }
        }

        found.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        models = found
        if current == nil, let first = found.first {
            select(first)
        }
        objectWillChange.send()
    }

    func delete(_ model: InstalledModel) {
        try? fm.removeItem(at: model.url)
        if selectedPath == model.url.path {
            selectedPath = nil
            UserDefaults.standard.removeObject(forKey: selectionKey)
        }
        refresh()
    }

    // MARK: - 识别一个模型目录

    static func inspect(folder: URL) -> InstalledModel? {
        let fm = FileManager.default
        func has(_ name: String) -> Bool {
            fm.fileExists(atPath: folder.appendingPathComponent(name).path)
        }

        // 必须有的东西（编码器 / UNet / 解码器 / 分词表）
        let hasUnet = has("Unet.mlmodelc") || (has("UnetChunk1.mlmodelc") && has("UnetChunk2.mlmodelc"))
        guard hasUnet, has("VAEDecoder.mlmodelc"), has("TextEncoder.mlmodelc"), has("vocab.json") else {
            return nil
        }

        let kind: ModelKind = has("TextEncoder2.mlmodelc") ? .sdxl : .sd15

        var meta: [String: Any] = [:]
        if let data = try? Data(contentsOf: folder.appendingPathComponent("lumigen.json")),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            meta = obj
        }

        let presetID = meta["preset"] as? String
        let preset = presetID.flatMap { ModelCatalog.preset(id: $0) }

        let steps = (meta["steps"] as? Int) ?? preset?.steps ?? (kind == .sdxl ? 4 : 22)
        var guidance: Float = preset?.guidance ?? (kind == .sdxl ? 0 : 6.5)
        if let stored = meta["guidance"] as? Double { guidance = Float(stored) }
        let resolution = (meta["resolution"] as? Int) ?? preset?.resolution ?? (kind == .sdxl ? 768 : 512)
        let name = (meta["name"] as? String) ?? preset?.name ?? folder.lastPathComponent

        return InstalledModel(url: folder,
                              name: name,
                              kind: kind,
                              sizeBytes: ModelLibrary.folderSize(folder),
                              steps: steps,
                              guidance: guidance,
                              resolution: resolution,
                              presetID: presetID)
    }

    static func folderSize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let e = fm.enumerator(at: url,
                                   includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                                   options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let f as URL in e {
            guard let v = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  v.isRegularFile == true else { continue }
            total += Int64(v.fileSize ?? 0)
        }
        return total
    }
}

extension FileManager {
    var documentsURL: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
