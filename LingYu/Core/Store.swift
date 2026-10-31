import SwiftUI
import UIKit
import Combine

enum MenuKind { case personas, modes }

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
    @Published var healthSummary: String? = nil
    private var rawReply = ""
    private var flushTimer: Timer?
    @Published var toast: String?
    @Published var summarizing = false
    @Published var hasKey = KeyStore.hasKey
    @Published var menu: MenuKind? = nil
    @Published var popupStyle = true

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
        rawReply = ""
        isStreaming = true
        startFlush()

        do {
            let api = buildAPIMessages(latest: content, image: image)
            let client = DeepSeekClient(key: KeyStore.key)
            let used = try await client.stream(messages: api, maxTokens: maxTokens) { piece in
                DispatchQueue.main.async { self.rawReply += piece }
            }
            stopFlush()
            streamingText = rawReply
            var reply = rawReply.trimmed
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

    func select(_ p: Persona) {
        currentID = p.id
        if chats[p.id] == nil {
            chats[p.id] = [ChatMessage(role: "assistant", text: "嗯，我在。", date: Date())]
        }
        save()
    }

    func add(_ p: Persona) {
        personas.append(p)
        chats[p.id] = [ChatMessage(role: "assistant", text: "你好。", date: Date())]
        currentID = p.id
        save()
    }

    func update(_ p: Persona) {
        if let i = personas.firstIndex(where: { $0.id == p.id }) { personas[i] = p }
        save()
    }

    @MainActor
    func makePersona(from text: String) async -> Persona? {
        guard hasKey else {
            showToast("先去「我」里填 API Key")
            return nil
        }
        let prompt = """
        根据这段印象，设计一个聊天角色。只输出 JSON：
        {"name":"两个汉字的昵称","emoji":"一个 emoji","relation":"一句话：TA 是谁、和我什么关系","tone":"TA 说话的具体方式，包含口头禅和对情绪的反应"}
        要求：relation 和 tone 必须严格贴着我的印象，不要发挥成别人，不要写性格分析。
        印象：\(text)
        """
        do {
            let client = DeepSeekClient(key: KeyStore.key)
            let raw = try await client.complete(prompt: prompt, maxTokens: 400)
            guard let start = raw.firstIndex(of: "{"),
                  let end = raw.lastIndex(of: "}") else { return nil }
            let json = String(raw[start...end])
            guard let data = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let p = Persona(name: (obj["name"] as? String) ?? "无名",
                            emoji: (obj["emoji"] as? String) ?? "🙂",
                            relation: (obj["relation"] as? String) ?? "朋友",
                            tone: (obj["tone"] as? String) ?? "自然",
                            hue: Double.random(in: 0...1))
            add(p)
            return p
        } catch {
            showToast(error.localizedDescription)
            return nil
        }
    }

    private func startFlush() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.streamingText != self.rawReply { self.streamingText = self.rawReply }
        }
    }

    private func stopFlush() {
        flushTimer?.invalidate()
        flushTimer = nil
    }

    func deleteMessage(_ id: UUID) {
        chats[currentID]?.removeAll { $0.id == id }
        save()
    }

    func deleteMemory(_ id: UUID) {
        memories.removeAll { $0.id == id }
        save()
    }

    func clearChat(_ personaID: UUID, greeting: String) {
        chats[personaID] = [ChatMessage(role: "assistant", text: greeting, date: Date())]
        save()
    }

    /// 用一张健康截图读出数据（HealthKit 拿不到权限时的兜底）
    @MainActor
    func healthFromImage(_ image: UIImage) async -> String? {
        guard hasKey else {
            showToast("先去「我」里填 API Key")
            return nil
        }
        guard let b64 = Self.jpegBase64(image) else { return nil }
        let prompt = """
        读这张健康/运动截图，提取这些数字（没有的填 0）。只输出 JSON：
        {"steps":日均步数,"sleep":平均睡眠小时,"hr":静息心率,"weight":体重公斤,"exercise":日均运动分钟}
        """
        do {
            let client = DeepSeekClient(key: KeyStore.key)
            let raw = try await client.completeWithImage(prompt: prompt, imageBase64: b64, maxTokens: 300)
            guard let start = raw.firstIndex(of: "{"),
                  let end = raw.lastIndex(of: "}") else { return nil }
            let json = String(raw[start...end])
            guard let data = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            func num(_ k: String) -> Double {
                if let d = obj[k] as? Double { return d }
                if let i = obj[k] as? Int { return Double(i) }
                if let s = obj[k] as? String { return Double(s) ?? 0 }
                return 0
            }
            var parts: [String] = []
            if num("steps") > 0 { parts.append("日均步数 \(Int(num("steps")))") }
            if num("sleep") > 0 { parts.append("睡眠 \(String(format: "%.1f", num("sleep"))) 小时") }
            if num("hr") > 0 { parts.append("静息心率 \(Int(num("hr")))") }
            if num("exercise") > 0 { parts.append("日均运动 \(Int(num("exercise"))) 分钟") }
            if num("weight") > 0 { parts.append("体重 \(String(format: "%.1f", num("weight"))) kg") }
            guard !parts.isEmpty else { return nil }
            let text = "近 7 天：" + parts.joined(separator: "，")
            healthSummary = text
            save()
            return text
        } catch {
            showToast(error.localizedDescription)
            return nil
        }
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
        if let h = healthSummary, !h.isEmpty {
            sys += "\n我的身体数据（知道就行，别主动复述）：\(h)"
        }
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
        var popupStyle: Bool?
        var healthSummary: String?
    }

    func save() {
        let snap = Snapshot(personas: personas, currentID: currentID, chats: chats,
                            memories: memories, usage: usage, level: level, dailyCap: dailyCap, popupStyle: popupStyle, healthSummary: healthSummary)
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
        if let ps = snap.popupStyle { popupStyle = ps }
        healthSummary = snap.healthSummary
    }
}
