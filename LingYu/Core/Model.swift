import SwiftUI
import Foundation

// MARK: - 人设

struct Persona: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var relation: String
    var tone: String
    var hue: Double

    static let starter: [Persona] = [
        Persona(name: "小满", emoji: "🌙", relation: "认识很久的朋友，说话随意不客套",
                tone: "温和、有点俏皮、不煽情", hue: 0.58),
        Persona(name: "阿树", emoji: "🌳", relation: "话少但靠谱的老哥", tone: "简洁、直接、偶尔冷幽默", hue: 0.35),
        Persona(name: "灯下", emoji: "🕯️", relation: "会认真听你说话的倾听者", tone: "安静、耐心、先共情再建议", hue: 0.09),
    ]

    var tint: Color { Color(hue: hue, saturation: 0.55, brightness: 0.95) }
}

// MARK: - 模式

enum ChatMode: String, CaseIterable, Codable, Identifiable {
    case chat, heart, pro, vision, idea
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "陪聊"
        case .heart: return "树洞"
        case .pro: return "专业"
        case .vision: return "看图"
        case .idea: return "灵感"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left"
        case .heart: return "heart"
        case .pro: return "square.stack.3d.up"
        case .vision: return "camera"
        case .idea: return "lightbulb"
        }
    }

    var directive: String {
        switch self {
        case .chat:
            return "像朋友一样自然聊天。口语、简短、有来有回，不要说教，不要列清单。"
        case .heart:
            return "先接住情绪再谈其它。共情具体，不敷衍地安慰，不急着给方案，除非我问。"
        case .pro:
            return "直接给结论和可执行的步骤。结构清晰，多用短句和代码/公式块，少寒暄。"
        case .vision:
            return "我在发图给你。先描述你看到的关键信息，再回答我的问题。看不清就说看不清。"
        case .idea:
            return "给我有画面感的点子，短、具体、可直接拿去用。不要泛泛而谈。"
        }
    }
}

// MARK: - 消息

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: String        // user / assistant
    var text: String
    var date = Date()
    var mood: Int? = nil    // -2...2
    var hasImage = false

    var isUser: Bool { role == "user" }
}

// MARK: - 记忆卡

struct MemoryCard: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var title: String
    var detail: String
    var mood: Int
}

// MARK: - 用量

struct Usage: Codable, Equatable {
    var input = 0
    var output = 0
    var total: Int { input + output }
}

// MARK: - 小工具

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum Mood {
    static func score(_ text: String) -> Int {
        let pos = ["开心", "高兴", "舒服", "喜欢", "爱", "谢谢", "期待", "顺利", "棒", "好", "轻松", "温暖", "幸福"]
        let neg = ["累", "难过", "烦", "焦虑", "压力", "孤独", "生气", "害怕", "哭", "痛", "委屈", "崩溃", "失眠"]
        var s = 0
        for w in pos where text.contains(w) { s += 1 }
        for w in neg where text.contains(w) { s -= 1 }
        return max(-2, min(2, s / 2))
    }

    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

extension FileManager {
    var docsURL: URL { urls(for: .documentDirectory, in: .userDomainMask)[0] }
}
