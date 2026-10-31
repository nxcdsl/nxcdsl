import SwiftUI
import UIKit
import Combine

final class AppStore: ObservableObject {

    static let shared = AppStore()

    @Published var personas: [Persona] = Persona.starter
    @Published var currentID: UUID = Persona.starter[0].id
    @Published var mode: ChatMode = .chat
    @Published var chats: [UUID: [ChatMessage]] = [:]
    @Published var memories: [MemoryCard] = []
    @Published var usage: [String: Usage] = [:]
    @Published var level = 1                 // 0 轻 / 1 标准 / 2 深度
    @Published var dailyCap = 60_000         // token
    @Published var isStreaming = false
    @Published var streamingText = ""
    @Published var toast: String?
    @Published var summarizing = false
    @Published var hasKey = KeyStore.hasKey

    private var toastTask: DispatchWorkItem?
    private let fileURL = FileManager.default.docsURL.appendingPathComponent("lingyu.json")

    // MARK: - 派生

    var persona: Persona {
        personas.first { $0.id == currentID } ?? personas[0]
    }

    var messages: [ChatMessage] {
        chats[currentID] ?? []
    }

    var todayUsage: Usage {
        usage[Mood.dayKey()] ?? Usage()
    }

    var capRatio: Double {
        dailyCap > 0 ? min(1, Double(todayUsage.total) / Double(dailyCap)) : 0
    }

    var maxTokens: Int {
        switch level {
        case 0: return 700
        case 2: return 4000
        default: return 1800
        }
    }

    // MARK: - 生命周期

    func bootstrap() {
        load()
        if personas.isEmpty { personas = Persona.starter }
        if chats[currentID] == nil, messages.isEmpty {
            let hello = ChatMessage(role: "assistant",
                                    text: "在的，今天怎么样？",
                                    date: Date())
            chats[currentID] = [hello]
        }
        hasKey = KeyStore.hasKey
    }

    // MARK: - 发送

    @MainActor
    func send(_ text: String, image: UIImage? = nil) async {
        let content = text.trimmed
        guard !content.isEmpty || image != nil else { return }
        guard hasKey, !KeyStore.key.isEmpty else {
            showToast("先去「我」里填 API Key")
            return
        }
        if dailyCap > 0, todayUsage.total >= dailyCap {
            showToast("今日额度用完了")
            return
        }
        guard !isStreaming else { return }

        var userMsg = ChatMessage(role: "user", text: content, date: Date())
        userMsg.hasImage = image != nil
        append(userMsg)

        streamingText = ""
        isStreaming = true

        do {
            let api = buildAPIMessages(latest: content, image: image)
            let client = DeepSeekClient(key: KeyStore.key)
            let used = try await client.stream(messages: api, maxTokens: maxTokens) { piece in
                Task { @MainActor in self.streamingText += piece }
            }
            var reply = streamingText.trimmed
            if reply.isEmpty { reply = "……" }
            var assistant = ChatMessage(role: "assistant", text: reply, date: Date())
            assistant.mood = Mood.score(reply)
            append(assistant)
            addUsage(used)
        } catch {
            showToast(error.localizedDescription)
        }

        streamingText = ""
        isStreaming = false
        save()
    }

    func append(_ msg: ChatMessage) {
        var list = chats[currentID] ?? []
        list.append(msg)
        chats[currentID] = list
    }

    // MARK: - 组装请求

    private func buildAPIMessages(latest: String, image: UIImage?) -> [[String: Any]] {
        var sys = "你是\(persona.name)。\(persona.relation)。语气：\(persona.tone)。"
        sys += mode.directive
        if level == 2 { sys += "想清楚再回答，但只说结论和关键推理。" }
        sys += "用中文，短句，别啰嗦，别总结我说过的话。"
        let recent = memories.suffix(3)
        if !recent.isEmpty {
            sys += "\n已知的关于我的事（不必主动提）：" + recent.map { "\($0.title)：\($0.detail)" }.joined(separator: "；")
        }

        var out: [[String: Any]] = [["role": "system", "content": sys]]
        let history = messages.suffix(12)
        for m in history {
            out.append(["role": m.role, "content": m.text])
        }

        if let image, let b64 = Self.jpegBase64(image) {
            out.append([
                "role": "user",
                "content": [
                    ["type": "text", "text": latest.isEmpty ? "看看这张图" : latest],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
                ]
            ])
        } else if !latest.isEmpty {
            out.append(["role": "user", "content": latest])
        }
        return out
    }

    private static func jpegBase64(_ image: UIImage) -> String? {
        let maxSide: CGFloat = 1024
        let size = image.size
        let longest = max(size.width, size.height)
        var target = image
        if longest > maxSide, longest > 0 {
            let scale = maxSide / longest
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let f = UIGraphicsImageRendererFormat.default()
            f.scale = 1
            target = UIGraphicsImageRenderer(size: newSize, format: f).image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        return target.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }

    // MARK: - 用量

    private func addUsage(_ u: Usage) {
        let k = Mood.dayKey()
        var day = usage[k] ?? Usage()
        day.input += u.input
        day.output += u.output
        usage[k] = day
        if dailyCap > 0, day.total >= dailyCap {
            showToast("今日额度已用完")
        } else if dailyCap > 0, Double(day.total) / Double(dailyCap) > 0.8 {
            showToast("今日额度已用 80%")
        }
    }

    // MARK: - 回忆 / 摘要

    @MainActor
    func summarize() async {
        guard hasKey, !summarizing else { return }
        let history = messages.suffix(40)
        guard history.count >= 4 else {
            showToast("聊几句再回顾")
            return
        }
        summarizing = true
        defer { summarizing = false }

        let log = history.map { "\($0.isUser ? "我" : "TA")：\($0.text)" }.joined(separator: "\n")
        let prompt = """
        下面是最近的对话。请输出 JSON：
        {"summary":"一段 120 字以内的回顾，用第二人称对我说话，像朋友在讲我最近的状态",
         "cards":[{"title":"不超过8字","detail":"一句话事实","mood":-2到2的整数}]}
         cards 最多 3 条，只挑值得记住的事。不要输出 JSON 以外的任何字符。

        对话：
        \(log)
        """

        do {
            let client = DeepSeekClient(key: KeyStore.key)
            let reply = try await client.complete(prompt: prompt, maxTokens: 700)
            if let parsed = Self.parseSummary(reply) {
                if let s = parsed.summary {
                    memories.insert(MemoryCard(date: Date(), title: "最近", detail: s, mood: 0), at: 0)
                }
                for c in parsed.cards {
                    memories.insert(MemoryCard(date: Date(), title: c.title, detail: c.detail, mood: c.mood), at: 0)
                }
                if memories.count > 60 { memories = Array(memories.prefix(60)) }
                save()
                showToast("记下了")
            } else {
                showToast("没能整理出来")
            }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private struct ParsedSummary {
        var summary: String?
        var cards: [(title: String, detail: String, mood: Int)]
    }

    private static func parseSummary(_ text: String) -> ParsedSummary? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var out = ParsedSummary(summary: nil, cards: [])
        out.summary = obj["summary"] as? String
        if let arr = obj["cards"] as? [[String: Any]] {
            out.cards = arr.prefix(3).map {
                (($0["title"] as? String) ?? "记一笔",
                 ($0["detail"] as? String) ?? "",
                 ($0["mood"] as? Int) ?? 0)
            }
        }
        return out
    }

    // MARK: - 提示

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        let w = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) { self?.toast = nil }
        }
        toastTask = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: w)
    }

    // MARK: - 存档

    private struct Snapshot: Codable {
        var personas: [Persona]
        var currentID: UUID
        var chats: [UUID: [ChatMessage]]
        var memories: [MemoryCard]
        var usage: [String: Usage]
        var level: Int
        var dailyCap: Int
    }

    func save() {
        let snap = Snapshot(personas: personas, currentID: currentID, chats: chats,
                            memories: memories, usage: usage, level: level, dailyCap: dailyCap)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        personas = snap.personas
        currentID = snap.currentID
        chats = snap.chats
        memories = snap.memories
        usage = snap.usage
        level = snap.level
        dailyCap = snap.dailyCap
    }
}
