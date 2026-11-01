import Foundation

// MARK: - 控制标签（UI 上的三颗胶囊，只是"意图声明"，不改文本）

enum ControlTag: String, CaseIterable, Codable, Identifiable {
    case landscape, portrait, still

    var id: String { rawValue }

    var title: String {
        switch self {
        case .landscape: return "只要风景"
        case .portrait: return "人物特写"
        case .still: return "静物"
        }
    }

    var emoji: String {
        switch self {
        case .landscape: return "🌄"
        case .portrait: return "🧑"
        case .still: return "🫖"
        }
    }

    var tint: [Double] {
        switch self {
        case .landscape: return [0.45, 0.82, 0.72]
        case .portrait: return [1.00, 0.66, 0.72]
        case .still: return [0.98, 0.82, 0.52]
        }
    }
}

// MARK: - 意图

enum SceneIntent {
    case landscape, object, portrait, abstract, unknown
}

// MARK: - 规范化

enum TextNormalizer {

    /// 全角转半角、中文标点转英文、去重标点与空白
    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 中文标点 → 英文逗号
        for ch in ["，", "、", "。", "；", "：", "\n"] {
            s = s.replacingOccurrences(of: ch, with: ", ")
        }
        for ch in ["！", "？", "!", "?", "；"] {
            s = s.replacingOccurrences(of: ch, with: "")
        }
        // 全角空格
        s = s.replacingOccurrences(of: "\u{3000}", with: " ")
        // 折叠连续标点与空格
        while s.contains(",,") { s = s.replacingOccurrences(of: ",,", with: ",") }
        while s.contains(", ,") { s = s.replacingOccurrences(of: ", ,", with: ",") }
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        while s.hasPrefix(",") { s.removeFirst() }
        while s.hasSuffix(",") { s.removeLast() }
        return s.trimmingCharacters(in: .whitespaces)
    }

    static func isTooShort(_ s: String) -> Bool {
        s.trimmingCharacters(in: .whitespaces).count < 3
    }
}

// MARK: - 中英词典（CLIP 是英文训练的，中文直接喂命中率会掉）

enum ZhEnLexicon {

    /// 长词优先匹配，避免"老巷"被"巷"抢先
    static let table: [String: String] = [
        "老巷": "old alley", "街道": "street", "街角": "street corner", "城市": "city",
        "夜色": "night", "夜晚": "night", "星空": "starry sky", "日落": "sunset", "日出": "sunrise",
        "海边": "seaside", "沙滩": "beach", "山脉": "mountain", "雪山": "snow mountain",
        "森林": "forest", "树林": "woods", "河流": "river", "小桥": "bridge",
        "街道上": "on the street", "屋顶": "rooftop", "窗户": "window", "房间": "room",
        "教室": "classroom", "厨房": "kitchen", "车站": "station", "地铁": "subway",
        "咖啡": "coffee", "杯子": "cup", "书本": "book", "台灯": "lamp",
        "花朵": "flower", "玫瑰": "rose", "树叶": "leaves", "草地": "grass field",
        "猫": "cat", "橘猫": "orange tabby cat", "狗": "dog", "鸟": "bird",
        "女孩": "girl", "少女": "young girl", "男孩": "boy", "少年": "young boy",
        "女人": "woman", "男人": "man", "老人": "elderly person", "小孩": "child",
        "手": "hand", "脸": "face", "眼睛": "eyes",
        "雨": "rain", "雪": "snow", "雾": "fog", "云": "clouds", "天空": "sky",
        "月亮": "moon", "太阳": "sun", "星星": "stars", "灯光": "warm light",
        "汽车": "car", "自行车": "bicycle", "火车": "train", "飞船": "spaceship",
        "机器人": "robot", "龙": "dragon", "剑": "sword", "盔甲": "armor",
        "赛博朋克": "cyberpunk", "水墨": "ink painting", "油画": "oil painting",
        "安静": "quiet", "温暖": "warm", "孤独": "lonely", "梦幻": "dreamy",
        "破旧": "worn out", "干净": "clean", "极简": "minimal"
    ]

    private static let keysByLength: [String] = table.keys.sorted { $0.count > $1.count }

    /// 贪心最长匹配；未命中的中文原样保留（模型有一定容忍度）
    static func translate(_ text: String) -> String {
        var out = ""
        var i = text.startIndex
        while i < text.endIndex {
            var matched = false
            for key in keysByLength {
                if text[i...].hasPrefix(key) {
                    if let value = table[key] {
                        out += (out.isEmpty ? "" : " ") + value
                    }
                    i = text.index(i, offsetBy: key.count)
                    matched = true
                    break
                }
            }
            if !matched {
                out.append(text[i])
                i = text.index(after: i)
            }
        }
        return out
    }
}

// MARK: - 意图识别（纯规则，零依赖）

enum IntentRouter {

    private static let landscape = ["街", "路", "山", "海", "雨", "夜", "城市", "楼", "天", "云", "森林",
                                    "street", "city", "mountain", "ocean", "rain", "sky", "forest", "alley", "rooftop"]
    private static let object = ["猫", "狗", "杯", "花", "书", "椅", "灯", "桌", "车", "瓶子", "帽子",
                                 "cat", "dog", "cup", "flower", "book", "chair", "lamp", "car", "bottle"]
    private static let human = ["女孩", "男孩", "少女", "少年", "男人", "女人", "老人", "小孩", "人", "脸", "手",
                                "girl", "boy", "man", "woman", "person", "portrait", "face", "hand", "child"]

    static func containsHuman(_ text: String) -> Bool {
        let lower = text.lowercased()
        return human.contains { lower.contains($0.lowercased()) }
    }

    static func classify(_ text: String) -> SceneIntent {
        let lower = text.lowercased()
        var score: [SceneIntent: Int] = [:]
        // 人像权重更高：宁可放过，不可错杀
        for w in human where lower.contains(w.lowercased()) { score[.portrait, default: 0] += 3 }
        for w in landscape where lower.contains(w.lowercased()) { score[.landscape, default: 0] += 2 }
        for w in object where lower.contains(w.lowercased()) { score[.object, default: 0] += 2 }

        guard let best = score.max(by: { $0.value < $1.value }), best.value > 0 else { return .unknown }
        return best.key
    }
}

// MARK: - 策略

struct PromptPolicy {
    var banHumans: Bool
    var widenScene: Bool
    var hint: String?
}

enum ConflictResolver {

    /// 一句话原则：文本永远优先，标签只在文本没表态时生效
    static func resolve(text: String, tag: ControlTag?, intent: SceneIntent) -> PromptPolicy {
        let hasHuman = IntentRouter.containsHuman(text)

        switch tag {
        case .landscape?:
            if hasHuman {
                return PromptPolicy(banHumans: false, widenScene: true,
                                    hint: "你写了人物，已自动放开人像限制")
            }
            return PromptPolicy(banHumans: true, widenScene: true, hint: nil)

        case .portrait?:
            return PromptPolicy(banHumans: false, widenScene: false, hint: nil)

        case .still?:
            return PromptPolicy(banHumans: !hasHuman, widenScene: !hasHuman, hint: nil)

        case nil:
            if intent == .portrait {
                return PromptPolicy(banHumans: false, widenScene: false, hint: nil)
            }
            return PromptPolicy(banHumans: !hasHuman, widenScene: true, hint: nil)
        }
    }
}

// MARK: - 词库

enum BaseNegative {
    static let all = ["lowres", "blurry", "jpeg artifacts", "watermark", "text", "signature",
                      "bad anatomy", "deformed", "disfigured", "extra limbs", "mutated hands"]
}

enum SubjectBan {
    static let humans = ["1girl", "1boy", "person", "human", "face", "hand", "fingers",
                         "figure", "character", "portrait", "people", "crowd"]
}

// MARK: - 质量档位

enum QualityMode: String, Codable, CaseIterable {
    case fast, accurate

    var title: String { self == .fast ? "快" : "准" }
    var subtitle: String {
        self == .fast ? "4 步 · 不启用负面 · 约 5-8 秒"
                      : "6 步 · CFG 1.8（负面生效）· 约 15-25 秒"
    }
}

// MARK: - 预算

enum TokenBudget {
    /// CLIP 单段 77 token；留后缀与质量词的位置
    static let max = 77
    static let reserveSuffix = 18
    static let reserveQuality = 6
    static var userBudget: Int { max - reserveSuffix - reserveQuality }

    /// 粗估：英文按词、中文按字
    static func estimate(_ s: String) -> Int {
        var count = 0
        for scalar in s.unicodeScalars {
            if scalar.value > 0x2E80 { count += 1 }        // CJK 一字≈1 token
        }
        let words = s.split(whereSeparator: { $0 == " " || $0 == "," }).count
        return words + count
    }

    /// 按逗号丢弃尾部，永不截断在词中间
    static func truncate(_ s: String, limit: Int) -> String {
        guard estimate(s) > limit else { return s }
        var parts = s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        while parts.count > 1, estimate(parts.joined(separator: ", ")) > limit {
            parts.removeLast()
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 最终产物

struct PromptPlan {
    var positive: String
    var negative: String
    var steps: Int
    var cfg: Float
    var size: Int
    var hint: String?
}

// MARK: - 中间件：用户一句话 → (正向, 负向, 参数)

enum PromptMiddleware {

    static func plan(user raw: String,
                     style: StylePreset,
                     tag: ControlTag?,
                     kind: ModelKind,
                     quality: QualityMode,
                     sizeOverride: Int,
                     attempt: Int) -> PromptPlan {

        let normalized = TextNormalizer.normalize(raw)
        let translated = ZhEnLexicon.translate(normalized)
        let intent = IntentRouter.classify(translated)
        var policy = ConflictResolver.resolve(text: translated, tag: tag, intent: intent)

        // 输入为空：给一个安全的默认场景，不发火也不空转
        var subject = translated
        if subject.isEmpty {
            subject = "quiet empty scene, soft light"
            policy.hint = "没写描述，先来一张空镜"
        } else if TextNormalizer.isTooShort(subject) {
            subject += ", single subject, centered, clean background"
        }

        let userPart = TokenBudget.truncate(subject, limit: TokenBudget.userBudget)

        var pos: [String] = [userPart]
        if policy.widenScene { pos.append("empty scene, no humans, wide shot") }
        switch intent {
        case .landscape: pos.append("landscape, natural light, detailed background")
        case .object: pos.append("single subject, centered composition, clean background")
        case .portrait: pos.append("portrait, sharp focus on face, soft rim light")
        default: break
        }
        pos.append("masterpiece, best quality")
        if !style.promptSuffix.isEmpty { pos.append(style.promptSuffix) }

        var neg: [String] = BaseNegative.all
        if policy.banHumans { neg.append(contentsOf: SubjectBan.humans) }

        let positive = TokenBudget.truncate(pos.joined(separator: ", "), limit: 75)
        let negative = TokenBudget.truncate(neg.joined(separator: ", "), limit: 70)

        // 参数：模型自带优先，SDXL 用两档
        let params = resolveParams(kind: kind, quality: quality, style: style, sizeOverride: sizeOverride)

        return PromptPlan(positive: positive,
                          negative: quality == .fast ? "" : negative,   // CFG=0 时负面无效，干脆不发
                          steps: params.steps,
                          cfg: params.cfg,
                          size: params.size,
                          hint: policy.hint)
    }

    private static func resolveParams(kind: ModelKind, quality: QualityMode,
                                      style: StylePreset, sizeOverride: Int) -> (steps: Int, cfg: Float, size: Int) {
        if kind == .sdxl {
            let size = sizeOverride > 0 ? sizeOverride : 768
            return quality == .fast ? (4, 0, size) : (6, 1.8, size)
        }
        // SD1.5 走它自己的常规参数
        let size = sizeOverride > 0 ? sizeOverride : 512
        return (18, 6.5, size)
    }

    /// 重绘：换锚点而不是死磨同一个种子
    static func nextSeed(_ current: UInt32, attempt: Int) -> UInt32 {
        attempt <= 0 ? UInt32.random(in: 1...4_000_000_000)
                     : current &+ UInt32((attempt * 7919) % 100_000)
    }

    static func variantSubject(_ text: String, attempt: Int) -> String {
        guard attempt >= 3 else { return text }
        return text + ", slightly different composition, new angle"
    }
}
