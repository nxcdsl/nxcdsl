import Foundation

// MARK: - 控制标签

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
    case landscape      // 风景/建筑
    case object         // 静物/物品/载具
    case character      // 人物/角色（含二次元、角色名）
    case unknown
}

// MARK: - 规范化

enum TextNormalizer {
    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for ch in ["，", "、", "。", "；", "：", "\n"] {
            s = s.replacingOccurrences(of: ch, with: ", ")
        }
        for ch in ["！", "？", "!", "?", "；", "~", "～"] {
            s = s.replacingOccurrences(of: ch, with: "")
        }
        s = s.replacingOccurrences(of: "\u{3000}", with: " ")
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

// MARK: - 中英词典

enum ZhEnLexicon {

    static let table: [String: String] = [
        // 场景
        "老巷": "old alley", "街道": "street", "街角": "street corner", "城市": "city",
        "夜色": "night", "夜晚": "night", "星空": "starry sky", "日落": "sunset", "日出": "sunrise",
        "海边": "seaside", "沙滩": "beach", "山脉": "mountain", "雪山": "snow mountain",
        "森林": "forest", "树林": "woods", "河流": "river", "小桥": "bridge", "桥": "bridge",
        "屋顶": "rooftop", "窗户": "window", "房间": "room", "教室": "classroom",
        "厨房": "kitchen", "车站": "station", "地铁": "subway", "咖啡馆": "cafe",
        "雨": "rain", "雪": "snow", "雾": "fog", "云": "clouds", "天空": "sky",
        "月亮": "moon", "太阳": "sun", "星星": "stars", "灯光": "warm light",
        // 静物 / 载具
        "跑车": "sports car", "汽车": "car", "自行车": "bicycle", "火车": "train",
        "飞船": "spaceship", "机器人": "robot", "咖啡": "coffee", "杯子": "cup",
        "书本": "book", "台灯": "lamp", "花朵": "flower", "玫瑰": "rose",
        "树叶": "leaves", "草地": "grass field", "剑": "sword", "盔甲": "armor",
        "帽子": "hat", "鞋子": "shoes", "手表": "watch", "蛋糕": "cake",
        // 生物
        "橘猫": "orange tabby cat", "猫": "cat", "狗": "dog", "鸟": "bird", "龙": "dragon",
        // 人物 / 角色
        "二次元": "anime style", "动漫": "anime", "角色": "character", "人物": "character",
        "少女": "young girl", "男孩": "boy", "少年": "young boy", "女孩": "girl",
        "女人": "woman", "男人": "man", "老人": "elderly person", "小孩": "child",
        "女主": "female protagonist", "男主": "male protagonist", "拟人": "anthropomorphic",
        "半身": "upper body", "全身": "full body", "特写": "close-up",
        "站姿": "standing pose", "坐姿": "sitting pose", "微笑": "smiling",
        "长发": "long hair", "短发": "short hair", "双马尾": "twintails",
        "裙子": "dress", "校服": "school uniform", "和服": "kimono",
        "猫耳": "cat ears", "翅膀": "wings", "魔法": "magic", "发光": "glowing",
        "原神": "Genshin Impact", "星穹铁道": "Honkai Star Rail", "崩坏": "Honkai",
        "明日方舟": "Arknights", "蔚蓝档案": "Blue Archive", "塞尔达": "Zelda",
        "英雄联盟": "League of Legends", "宝可梦": "Pokemon",
        // 白底
        "白色背景": "white background", "白底": "white background", "纯色背景": "solid background",
        // 氛围
        "赛博朋克": "cyberpunk", "水墨": "ink painting", "油画": "oil painting",
        "安静": "quiet", "温暖": "warm", "孤独": "lonely", "梦幻": "dreamy",
        "破旧": "worn out", "干净": "clean", "极简": "minimal", "可爱": "cute", "帅气": "handsome"
    ]

    private static let keysByLength: [String] = table.keys.sorted { $0.count > $1.count }

    static func translate(_ text: String) -> String {
        var out = ""
        var i = text.startIndex
        while i < text.endIndex {
            var matched = false
            for key in keysByLength where text[i...].hasPrefix(key) {
                if let value = table[key] {
                    out += (out.isEmpty ? "" : " ") + value
                }
                i = text.index(i, offsetBy: key.count)
                matched = true
                break
            }
            if !matched {
                out.append(text[i])
                i = text.index(after: i)
            }
        }
        return out
    }
}

// MARK: - 意图识别

enum IntentRouter {

    private static let landscapeWords = ["街", "路", "山", "海", "雨", "夜", "城市", "楼", "天", "云", "森林", "巷",
                                         "street", "city", "mountain", "ocean", "rain", "sky", "forest", "alley", "rooftop"]
    private static let objectWords = ["车", "杯", "花", "书", "椅", "灯", "桌", "瓶", "帽", "鞋", "表", "蛋糕",
                                      "car", "cup", "flower", "book", "chair", "lamp", "bottle", "cake", "cat", "dog"]
    private static let characterWords = ["角色", "人物", "二次元", "动漫", "少女", "少年", "女孩", "男孩", "女人", "男人",
                                         "女主", "男主", "肖像", "特写", "拟人", "猫耳", "翅膀",
                                         "anime", "character", "girl", "boy", "woman", "man", "portrait", "genshin"]

    static func containsHuman(_ text: String) -> Bool {
        let lower = text.lowercased()
        return characterWords.contains { lower.contains($0.lowercased()) }
    }

    static func classify(_ text: String) -> SceneIntent {
        let lower = text.lowercased()
        var score: [SceneIntent: Int] = [:]
        for w in characterWords where lower.contains(w.lowercased()) { score[.character, default: 0] += 3 }
        for w in landscapeWords where lower.contains(w.lowercased()) { score[.landscape, default: 0] += 2 }
        for w in objectWords where lower.contains(w.lowercased()) { score[.object, default: 0] += 2 }

        guard let best = score.max(by: { $0.value < $1.value }), best.value > 0 else { return .unknown }
        // 人物权重本来就高；这里再兜一层：有"角色/人物"就不许判成风景
        if score[.character, default: 0] > 0 { return .character }
        return best.key
    }

    /// 句子里有没有"场景"，用来决定要不要白底
    static func hasScene(_ text: String) -> Bool {
        let lower = text.lowercased()
        let sceneWords = ["街", "路", "山", "海", "房间", "室内", "森林", "城市", "雨", "夜", "窗", "床", "学校",
                          "street", "room", "forest", "city", "beach", "sky", "indoor", "night", "rain"]
        return sceneWords.contains { lower.contains($0.lowercased()) }
    }
}

// MARK: - 策略

struct PromptPolicy {
    var banHumans: Bool
    var whiteBackground: Bool
    var hint: String?
}

enum ConflictResolver {
    static func resolve(text: String, tag: ControlTag?, intent: SceneIntent) -> PromptPolicy {
        let hasHuman = IntentRouter.containsHuman(text)
        let hasScene = IntentRouter.hasScene(text)

        switch tag {
        case .landscape?:
            if hasHuman {
                return PromptPolicy(banHumans: false, whiteBackground: false,
                                    hint: "你写了人物，已放开人像限制")
            }
            return PromptPolicy(banHumans: true, whiteBackground: false, hint: nil)

        case .portrait?:
            // 明确要人像：强制人像，没写场景就给白底
            return PromptPolicy(banHumans: false, whiteBackground: !hasScene, hint: nil)

        case .still?:
            if hasHuman {
                return PromptPolicy(banHumans: false, whiteBackground: !hasScene,
                                    hint: "你写了人物，已按人物处理")
            }
            return PromptPolicy(banHumans: false, whiteBackground: true, hint: nil)

        case nil:
            switch intent {
            case .character:
                // 「可爱的二次元角色特写」走这里：白底、不 ban
                return PromptPolicy(banHumans: false, whiteBackground: !hasScene, hint: nil)
            case .landscape:
                return PromptPolicy(banHumans: true, whiteBackground: false, hint: nil)
            default:
                // 注意：这里绝对不能再加 no humans，之前"跑车→人"、"角色→花"就是这么来的
                return PromptPolicy(banHumans: false, whiteBackground: false, hint: nil)
            }
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
    static let background = ["cluttered background", "busy background", "landscape", "scenery"]
}

// MARK: - 质量档

enum QualityMode: String, Codable, CaseIterable {
    case fast, accurate
    var title: String { self == .fast ? "快" : "准" }
    var subtitle: String {
        self == .fast ? "5 步 · CFG 1.5 · 负面生效 · 约 12-16 秒"
                      : "6 步 · CFG 1.8 · 负面更强 · 约 16-22 秒"
    }
}

// MARK: - 预算

enum TokenBudget {
    static let max = 77
    static let reserveSuffix = 16
    static let reserveQuality = 5
    static var userBudget: Int { max - reserveSuffix - reserveQuality }

    static func estimate(_ s: String) -> Int {
        var cjk = 0
        for scalar in s.unicodeScalars where scalar.value > 0x2E80 { cjk += 1 }
        let words = s.split(whereSeparator: { $0 == " " || $0 == "," }).count
        return words + cjk
    }

    static func truncate(_ s: String, limit: Int) -> String {
        guard estimate(s) > limit else { return s }
        var parts = s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        while parts.count > 1, estimate(parts.joined(separator: ", ")) > limit { parts.removeLast() }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 产物

struct PromptPlan {
    var positive: String
    var negative: String
    var steps: Int
    var cfg: Float
    var size: Int
    var hint: String?
}

// MARK: - 中间件

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

        var subject = translated
        if subject.isEmpty {
            subject = "simple subject"
            policy.hint = "没写描述，先来一张空镜"
        } else if TextNormalizer.isTooShort(subject) {
            subject = "close-up of \(subject)"
        }

        let userPart = TokenBudget.truncate(subject, limit: TokenBudget.userBudget)

        var pos: [String] = [userPart]

        // 白底特写：只加这一组，不加场景词
        if policy.whiteBackground {
            pos.append("simple white background, isolated on white, clean edges")
        }
        // 只有明确要"没人"时才加，且必须配合负面一起（否则会画成风景）
        if policy.banHumans {
            pos.append("empty scene, no people, wide shot")
        }

        switch intent {
        case .character:
            pos.append("detailed face, sharp focus, character design")
        case .object:
            pos.append("single subject, product shot, clean background")
        case .landscape:
            pos.append("detailed background, natural light")
        case .unknown:
            break
        }

        pos.append("masterpiece, best quality")
        if !style.promptSuffix.isEmpty { pos.append(style.promptSuffix) }

        var neg: [String] = BaseNegative.all
        if policy.banHumans { neg.append(contentsOf: SubjectBan.humans) }
        if policy.whiteBackground { neg.append(contentsOf: SubjectBan.background) }

        let positive = TokenBudget.truncate(pos.joined(separator: ", "), limit: 75)
        let negative = TokenBudget.truncate(neg.joined(separator: ", "), limit: 70)
        let params = resolveParams(kind: kind, quality: quality, sizeOverride: sizeOverride)

        return PromptPlan(positive: positive, negative: negative,
                          steps: params.steps, cfg: params.cfg, size: params.size,
                          hint: policy.hint)
    }

    private static func resolveParams(kind: ModelKind, quality: QualityMode, sizeOverride: Int)
        -> (steps: Int, cfg: Float, size: Int) {
        if kind == .sdxl {
            let size = sizeOverride > 0 ? sizeOverride : 768
            return quality == .fast ? (5, 1.5, size) : (6, 1.8, size)
        }
        let size = sizeOverride > 0 ? sizeOverride : 512
        return (18, 6.5, size)
    }

    static func nextSeed(_ current: UInt32, attempt: Int) -> UInt32 {
        attempt <= 0 ? UInt32.random(in: 1...4_000_000_000)
                     : current &+ UInt32((attempt * 7919) % 100_000)
    }

    static func variantSubject(_ text: String, attempt: Int) -> String {
        guard attempt >= 3 else { return text }
        return text + ", slightly different composition, new angle"
    }
}
