import SwiftUI

struct MemoryView: View {

    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                moodStrip
                reviewButton
                cards
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 心情条

    private var moodStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近两周").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text(moodWord).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
            }

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(days, id: \.self) { day in
                    let v = moodValue(day)
                    Capsule(style: .continuous)
                        .fill(barColor(v))
                        .frame(height: max(6, 46 * (abs(v) + 0.15)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 54, alignment: .bottom)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24, strength: 0.9)
    }

    private var days: [Date] {
        (0..<14).reversed().compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date())
        }
    }

    private func moodValue(_ day: Date) -> Double {
        let key = Mood.dayKey(day)
        let moods = store.messages.compactMap { msg -> Int? in
            guard msg.role == "assistant", Mood.dayKey(msg.date) == key else { return nil }
            return msg.mood
        }
        guard !moods.isEmpty else { return 0 }
        return Double(moods.reduce(0, +)) / Double(moods.count) / 2.0
    }

    private func barColor(_ v: Double) -> Color {
        if v > 0.1 { return Color(red: 0.45, green: 0.90, blue: 0.78).opacity(0.85) }
        if v < -0.1 { return Color(red: 0.98, green: 0.55, blue: 0.62).opacity(0.85) }
        return Color.white.opacity(0.22)
    }

    private var moodWord: String {
        let vals = days.map { moodValue($0) }.filter { $0 != 0 }
        guard !vals.isEmpty else { return "还没有数据" }
        let avg = vals.reduce(0, +) / Double(vals.count)
        if avg > 0.25 { return "挺亮的" }
        if avg < -0.25 { return "有点沉" }
        return "平常"
    }

    // MARK: - 回顾

    private var reviewButton: some View {
        Button {
            Task { await store.summarize() }
        } label: {
            HStack(spacing: 8) {
                if store.summarizing {
                    ProgressView().tint(.black).scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold))
                }
                Text(store.summarizing ? "在想…" : "回顾一下")
                    .font(.system(size: 14.5, weight: .semibold))
            }
            .foregroundStyle(.black.opacity(0.86))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.92)))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(store.summarizing)
    }

    // MARK: - 记忆卡

    private var cards: some View {
        VStack(spacing: 8) {
            if store.memories.isEmpty {
                Text("聊着聊着，这里会长出东西")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 24)
            } else {
                ForEach(store.memories) { card in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(card.mood > 0 ? Color(red: 0.45, green: 0.90, blue: 0.78).opacity(0.8)
                                             : (card.mood < 0 ? Color(red: 0.98, green: 0.55, blue: 0.62).opacity(0.8)
                                                              : Color.white.opacity(0.25)))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.title)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                            if !card.detail.isEmpty {
                                Text(card.detail)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .lineSpacing(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 20, strength: 0.85)
                }
            }
        }
    }
}
