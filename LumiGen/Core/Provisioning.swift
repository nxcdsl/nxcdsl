import Foundation

/// 读一下签名证书的到期时间（自签的 App 里会带 embedded.mobileprovision）
/// 7 天签名的人最需要这个：能提前知道哪天该续签了。
enum Provisioning {

    struct Info {
        let expires: Date?
        let teamName: String?
        let daysLeft: Int?
    }

    static func current() -> Info? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1) else {
            return nil
        }

        let expires = value(for: "ExpirationDate", in: text).flatMap { parseDate($0.value) }
        let team = value(for: "TeamName", in: text)?.value

        var days: Int?
        if let expires {
            days = Calendar.current.dateComponents([.day], from: Date(), to: expires).day
        }
        return Info(expires: expires, teamName: team, daysLeft: days)
    }

    /// 在明文 XML 片段里找某个 key 后面最近的那个值
    private static func value(for key: String, in text: String) -> (tag: String, value: String)? {
        guard let keyRange = text.range(of: "<key>\(key)</key>") else { return nil }
        let rest = text[keyRange.upperBound...]

        var best: (tag: String, value: String, distance: Int)?
        for tag in ["string", "date", "integer"] {
            guard let open = rest.range(of: "<\(tag)>"),
                  let close = rest.range(of: "</\(tag)>"),
                  open.upperBound <= close.lowerBound else { continue }
            let distance = rest.distance(from: rest.startIndex, to: open.lowerBound)
            if best == nil || distance < best!.distance {
                best = (tag, String(rest[open.upperBound..<close.lowerBound]), distance)
            }
        }
        guard let best else { return nil }
        return (best.tag, best.value)
    }

    private static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: trimmed) { return date }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        fallback.timeZone = TimeZone(identifier: "UTC")
        return fallback.date(from: trimmed)
    }

    /// 给界面用的一句话
    static var summary: String {
        guard let info = current(), let days = info.daysLeft else {
            return "Xcode 直装（无 7 天限制）"
        }
        if days < 0 { return "已过期，重新签一次" }
        if days == 0 { return "今天到期，记得续签" }
        return "还剩 \(days) 天"
    }

    /// 快到期了要不要提醒一下
    static var needsRenewalSoon: Bool {
        guard let info = current(), let days = info.daysLeft else { return false }
        return days <= 2
    }
}
