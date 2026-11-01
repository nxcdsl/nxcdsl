import Foundation
import Combine

/// 从 HuggingFace（或国内镜像）直接下载一个 Core ML 模型目录
final class ModelInstaller: ObservableObject {

    enum State: Equatable {
        case idle
        case working
        case finished
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var detail: String = ""

    /// 镜像站，留空则走 huggingface.co
    static let defaultMirror = "hf-mirror.com"

    private let queue = DispatchQueue(label: "lumigen.installer", qos: .userInitiated)
    private var cancelled = false

    func cancel() {
        cancelled = true
    }

    func reset() {
        state = .idle
        progress = 0
        detail = ""
    }

    // MARK: - 安装

    func install(preset: ModelPreset, mirror: String = ModelInstaller.defaultMirror,
                 completion: @escaping (Result<URL, Error>) -> Void) {
        guard state != .working else { return }
        cancelled = false
        state = .working
        progress = 0
        detail = "读取模型清单…"

        let host = ModelInstaller.cleanHost(mirror)
        let base = host.isEmpty ? "https://huggingface.co" : "https://\(host)"
        var bases = [base]
        if !base.contains("huggingface.co") { bases.append("https://huggingface.co") }
        if !base.contains("hf-mirror.com") { bases.append("https://hf-mirror.com") }

        queue.async { [weak self] in
            guard let self else { return }
            do {
                let files = try self.fileList(for: preset, base: base)
                guard !files.isEmpty else { throw InstallError.emptyRepo }

                let totalBytes = files.reduce(Int64(0)) { $0 + $1.size }
                let dest = ModelLibrary.rootURL.appendingPathComponent(preset.id, isDirectory: true)
                // 注意：不删目录。断了再点一次下载会接着传，不用从头再来 2.6GB。
                try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

                // 已经完整的文件先计入进度
                var doneBytes: Int64 = 0
                for file in files {
                    let target = dest.appendingPathComponent(file.path)
                    if let size = Self.fileSize(target), file.size > 0, size == file.size {
                        doneBytes += file.size
                    }
                }

                for (index, file) in files.enumerated() {
                    if self.cancelled { throw InstallError.cancelled }
                    let target = dest.appendingPathComponent(file.path)
                    if let size = Self.fileSize(target), file.size > 0, size == file.size {
                        continue // 上次已经下好了
                    }
                    self.report(progress: Double(doneBytes) / Double(max(totalBytes, 1)),
                                detail: "下载 \(index + 1)/\(files.count) · \(file.path)")
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true)

                    var lastError: Error?
                    var saved = false
                    for hostBase in bases {
                        for attempt in 0..<2 {
                            if self.cancelled { throw InstallError.cancelled }
                            guard let url = URL(string: "\(hostBase)/\(preset.repo)/resolve/main/\(file.remotePath)") else { continue }
                            do {
                                try self.download(url, to: target)
                                saved = true
                                break
                            } catch {
                                lastError = error
                                if attempt == 0 { usleep(400_000) }
                            }
                        }
                        if saved { break }
                    }
                    guard saved else { throw lastError ?? InstallError.emptyDownload }
                    doneBytes += file.size
                    self.report(progress: Double(doneBytes) / Double(max(totalBytes, 1)),
                                detail: "下载 \(index + 1)/\(files.count) · \(file.path)")
                }

                // 写入元信息
                let meta: [String: Any] = [
                    "preset": preset.id,
                    "name": preset.name,
                    "steps": preset.steps,
                    "guidance": Double(preset.guidance),
                    "resolution": preset.resolution,
                ]
                if let data = try? JSONSerialization.data(withJSONObject: meta) {
                    try? data.write(to: dest.appendingPathComponent("lumigen.json"))
                }

                DispatchQueue.main.async {
                    self.state = .finished
                    self.progress = 1
                    self.detail = "安装完成"
                    completion(.success(dest))
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                DispatchQueue.main.async {
                    self.state = .failed(message)
                    self.detail = message
                    completion(.failure(error))
                }
            }
        }
    }

    static func cleanHost(_ raw: String) -> String {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://", "http://"] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        while host.hasSuffix("/") { host.removeLast() }
        return host
    }

    private static func fileSize(_ url: URL) -> Int64? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return nil }
        return Int64(size)
    }

    // MARK: - 清单

    /// 优先用内置清单，没有才去问仓库接口
    private func fileList(for preset: ModelPreset, base: String) throws -> [RemoteFile] {
        if let table = ModelManifest.files(for: preset.id) {
            return table.map { path, size in
                let remote = (preset.subfolder.map { $0 + "/" } ?? "") + path
                return RemoteFile(path: path, remotePath: remote, size: size)
            }
        }
        return try listFiles(repo: preset.repo, base: base, subfolder: preset.subfolder)
    }

    private struct RemoteFile {
        let path: String        // 本地相对路径（已去掉 subfolder）
        let remotePath: String  // 仓库里的真实路径
        let size: Int64
    }

    private func listFiles(repo: String, base: String, subfolder: String?) throws -> [RemoteFile] {
        let urlString = "\(base)/api/models/\(repo)/tree/main?recursive=true"
        guard let url = URL(string: urlString) else { throw InstallError.badURL }
        let data = try syncGet(url)
        guard let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw InstallError.badManifest
        }

        let skippedExtensions: Set<String> = ["zip", "png", "jpg", "jpeg", "gif", "pdf"]
        var files: [RemoteFile] = []

        for entry in entries {
            guard let type = entry["type"] as? String, type == "file",
                  var path = entry["path"] as? String else { continue }

            if let sub = subfolder, !sub.isEmpty {
                guard path.hasPrefix(sub + "/") else { continue }
                path = String(path.dropFirst(sub.count + 1))
            }
            if path.hasPrefix(".") { continue }
            let ext = (path as NSString).pathExtension.lowercased()
            if skippedExtensions.contains(ext) { continue }

            // 只保留真正需要的东西：*.mlmodelc 里的文件 + 分词表
            let firstComponent = path.components(separatedBy: "/").first ?? path
            // 内容审查模型不下（这个 App 不要审查）
            if firstComponent == "SafetyChecker.mlmodelc" { continue }
            let isModel = firstComponent.hasSuffix(".mlmodelc")
            let isTokenizer = firstComponent == "vocab.json" || firstComponent == "merges.txt"
            guard isModel || isTokenizer else { continue }

            let size = (entry["size"] as? NSNumber)?.int64Value ?? 0
            let remotePath = (subfolder.map { $0 + "/" } ?? "") + path
            files.append(RemoteFile(path: path, remotePath: remotePath, size: size))
        }

        return files.sorted { $0.path < $1.path }
    }

    // MARK: - 网络

    private func report(progress: Double, detail: String) {
        DispatchQueue.main.async {
            self.progress = min(max(progress, 0), 1)
            self.detail = detail
        }
    }

    private func syncGet(_ url: URL) throws -> Data {
        let sem = DispatchSemaphore(value: 0)
        var payload: Data?
        var failure: Error?
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            payload = data
            failure = error
            sem.signal()
        }
        task.resume()
        sem.wait()
        if let failure { throw failure }
        guard let payload else { throw InstallError.badManifest }
        return payload
    }

    private func download(_ url: URL, to destination: URL) throws {
        let sem = DispatchSemaphore(value: 0)
        var moveError: Error?
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        let task = URLSession.shared.downloadTask(with: request) { tmp, response, error in
            defer { sem.signal() }
            if let error { moveError = error; return }
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                moveError = InstallError.http(http.statusCode)
                return
            }
            guard let tmp else { moveError = InstallError.emptyDownload; return }
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tmp, to: destination)
            } catch {
                moveError = error
            }
        }
        task.resume()
        sem.wait()
        if let moveError { throw moveError }
    }
}

enum InstallError: LocalizedError, Equatable {
    case badURL
    case badManifest
    case emptyRepo
    case emptyDownload
    case cancelled
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .badURL: return "下载地址无效"
        case .badManifest: return "读取模型清单失败，检查网络或镜像地址"
        case .emptyRepo: return "这个仓库里没有找到 Core ML 模型文件"
        case .emptyDownload: return "下载内容为空"
        case .cancelled: return "已取消"
        case .http(let code): return "服务器返回 \(code)"
        }
    }
}
