import SwiftUI
import UIKit

struct SettingsPane: View {

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeStore

    @State private var keyField = ""
    @State private var showAddPersona = false

    private let caps = [20_000, 60_000, 120_000, 0]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                keyCard
                levelCard
                usageCard
                backgroundCard
                personaCard
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .glassSheet($showAddPersona) { PersonaEditor() }
    }

    // MARK: - Key

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(store.hasKey ? Color(red: 0.45, green: 0.90, blue: 0.78) : Color.orange)
                    .frame(width: 6, height: 6)
                Text("DeepSeek API Key").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 8) {
                SecureField("sk-…", text: $keyField)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))

                Button {
                    KeyStore.key = keyField
                    store.hasKey = KeyStore.hasKey
                    keyField = ""
                    store.showToast(store.hasKey ? "已保存" : "已清除")
                } label: {
                    Text("保存")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.9)))
                }
                .buttonStyle(SoftPressStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
    }

    // MARK: - 推理等级

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("推理").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 8) {
                ForEach(Array(["轻", "标准", "深度"].enumerated()), id: \.offset) { i, title in
                    let on = store.level == i
                    Button {
                        store.level = i
                        store.save()
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        Text(title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(on ? Color.black.opacity(0.85) : Color.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                if on {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.9))
                                }
                            }
                            .glassCard(cornerRadius: 14, strength: on ? 0.15 : 0.75)
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            Text(levelHint)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.32))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
    }

    private var levelHint: String {
        switch store.level {
        case 0: return "省 token，回答短"
        case 2: return "想得更久，token 也更多"
        default: return "日常刚好"
        }
    }

    // MARK: - 用量

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今天").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("\(store.todayUsage.total.formatted()) / \(store.dailyCap == 0 ? "不限" : store.dailyCap.formatted())")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(store.capRatio > 0.85 ? Color(red: 1.0, green: 0.55, blue: 0.55)
                                                   : Color(red: 0.55, green: 0.85, blue: 1.0))
                        .frame(width: max(4, proxy.size.width * store.capRatio))
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                ForEach(caps, id: \.self) { cap in
                    let on = store.dailyCap == cap
                    Button {
                        store.dailyCap = cap
                        store.save()
                    } label: {
                        Text(cap == 0 ? "不限" : "\(cap / 1000)k")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(on ? Color.black.opacity(0.85) : Color.white.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(on ? Color.white.opacity(0.9) : Color.white.opacity(0.08))
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
    }

    // MARK: - 背景

    private var backgroundCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("背景").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 8) {
                ForEach(ThemeCatalog.all) { t in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { theme.select(t.id) }
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: [t.top, t.glowA, t.bottom],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 30)
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(theme.selectedID == t.id ? 0.9 : 0.15),
                                                      lineWidth: theme.selectedID == t.id ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                if theme.customImage != nil {
                    Button { theme.select(ThemeStore.customID) } label: {
                        Image(uiImage: theme.customImage!)
                            .resizable().scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
    }

    // MARK: - 角色

    private var personaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("角色").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button { showAddPersona = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
            }

            ForEach(store.personas) { p in
                HStack(spacing: 10) {
                    Text(p.emoji).font(.system(size: 16))
                    Text(p.name).font(.system(size: 13.5, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    if store.personas.count > 1 {
                        Button {
                            store.personas.removeAll { $0.id == p.id }
                            if store.currentID == p.id, let first = store.personas.first {
                                store.currentID = first.id
                            }
                            store.save()
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
    }
}
