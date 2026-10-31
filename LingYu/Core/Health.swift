import Foundation
import HealthKit
import UIKit

/// 健康数据：优先 HealthKit，签名不给权限就走截图导入
final class HealthStore: ObservableObject {

    static let shared = HealthStore()

    @Published var status = ""
    @Published var summary: String? = nil
    @Published var busy = false

    private let store = HKHealthStore()

    /// 当前这份 ipa 的签名里有没有健康权限
    /// （自签用的 profile 决定，没有就别去碰 HKHealthStore，会直接崩）
    var entitlementOK: Bool {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1) else { return false }
        return text.contains("com.apple.developer.healthkit")
    }

    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - 连接

    func connect() async {
        guard available else { status = "这台设备不支持健康数据"; return }
        guard entitlementOK else {
            status = "当前签名不含健康权限"
            return
        }
        let types = readTypes()
        guard !types.isEmpty else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            await refresh()
        } catch {
            status = "授权失败"
        }
    }

    private func readTypes() -> Set<HKObjectType> {
        var set = Set<HKObjectType>()
        let ids: [HKQuantityTypeIdentifier] = [.stepCount, .restingHeartRate, .bodyMass, .appleExerciseTime]
        for id in ids {
            if let t = HKObjectType.quantityType(forIdentifier: id) { set.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        return set
    }

    // MARK: - 拉数据

    func refresh() async {
        guard entitlementOK, available else { return }
        busy = true
        defer { busy = false }

        async let steps = averagePerDay(.stepCount, unit: .count(), days: 7)
        async let sleep = sleepHours(days: 7)
        async let hr = average(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 7)
        async let exercise = averagePerDay(.appleExerciseTime, unit: .minute(), days: 7)
        async let weight = latest(.bodyMass, unit: .gramUnit(with: .kilo))

        var parts: [String] = []
        let s = await steps
        if s > 0 { parts.append("日均步数 \(Int(s.rounded()))") }
        let sl = await sleep
        if sl > 0 { parts.append("睡眠 \(String(format: "%.1f", sl)) 小时") }
        let h = await hr
        if h > 0 { parts.append("静息心率 \(Int(h.rounded()))") }
        let e = await exercise
        if e > 0 { parts.append("日均运动 \(Int(e.rounded())) 分钟") }
        let w = await weight
        if w > 0 { parts.append("体重 \(String(format: "%.1f", w)) kg") }

        if parts.isEmpty {
            status = "没读到数据（Health 里可能还没有）"
        } else {
            let text = "近 7 天：" + parts.joined(separator: "，")
            summary = text
            status = "已读取"
            AppStore.shared.healthSummary = text
            AppStore.shared.save()
        }
    }

    // MARK: - 查询

    private func samples(_ id: HKSampleType, days: Int) async -> [HKSample] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: id,
                                  predicate: predicate,
                                  limit: 500,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate,
                                                                     ascending: false)]) { _, result, _ in
                cont.resume(returning: result ?? [])
            }
            store.execute(q)
        }
    }

    private func averagePerDay(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let list = await samples(type, days: days)
        let total = list.compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: unit) }.reduce(0, +)
        return total / Double(days)
    }

    private func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let list = await samples(type, days: days)
        let values = list.compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: unit) }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let list = await samples(type, days: 60)
        return list.compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: unit) }.first ?? 0
    }

    private func sleepHours(days: Int) async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let list = await samples(type, days: days)
        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        var seconds: Double = 0
        for sample in list {
            guard let cat = sample as? HKCategorySample, asleep.contains(cat.value) else { continue }
            seconds += cat.endDate.timeIntervalSince(cat.startDate)
        }
        return seconds / 3600 / Double(days)
    }
}

/// 从「快捷指令 → 拷贝到剪贴板」的健康文本里挑数字
enum HealthTextParser {

    static func parse(_ raw: String) -> String? {
        guard !raw.isEmpty else { return nil }
        var parts: [String] = []

        let steps = average(raw, pattern: "([0-9][0-9,]*)\\s*步")
        if steps > 0 { parts.append("日均步数 \(Int(steps.rounded()))") }

        let sleep = averageSleep(raw)
        if sleep > 0 { parts.append("睡眠 \(String(format: "%.1f", sleep)) 小时") }

        let hr = average(raw, pattern: "([0-9]{2,3})\\s*次/?分")
        if hr > 0 { parts.append("静息心率 \(Int(hr.rounded()))") }

        let weight = average(raw, pattern: "([0-9]+(?:\\.[0-9]+)?)\\s*(?:公斤|kg)")
        if weight > 0 { parts.append("体重 \(String(format: "%.1f", weight)) kg") }

        let exercise = average(raw, pattern: "([0-9]+)\\s*分钟")
        if exercise > 0 { parts.append("日均运动 \(Int(exercise.rounded())) 分钟") }

        guard !parts.isEmpty else { return nil }
        return "近 7 天：" + parts.joined(separator: "，")
    }

    private static func average(_ text: String, pattern: String) -> Double {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let ns = text as NSString
        let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        let values = matches.compactMap { m -> Double? in
            guard m.numberOfRanges > 1 else { return nil }
            let s = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: "")
            return Double(s)
        }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// “7小时32分” 这种也能算
    private static func averageSleep(_ text: String) -> Double {
        guard let re = try? NSRegularExpression(pattern: "([0-9]+)\\s*小时\\s*(?:([0-9]+)\\s*分)?") else { return 0 }
        let ns = text as NSString
        let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        let values = matches.compactMap { m -> Double? in
            guard m.numberOfRanges > 1 else { return nil }
            let h = Double(ns.substring(with: m.range(at: 1))) ?? 0
            var mins: Double = 0
            if m.numberOfRanges > 2, m.range(at: 2).location != NSNotFound {
                mins = Double(ns.substring(with: m.range(at: 2))) ?? 0
            }
            let v = h + mins / 60
            return (v > 0.5 && v < 16) ? v : nil
        }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}