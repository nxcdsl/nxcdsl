import SwiftUI
import PhotosUI
import UIKit

struct SettingsPane: View {

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeStore

    @State private var keyField = ""
    @State private var editTarget: Persona?
    @State private var showEditor = false
    @State private var showAI = false
    @State private var bgItem: PhotosPickerItem?
    @State private var healthItem: PhotosPickerItem?
    @ObservedObject private var health = HealthStore.shared

    private let caps = [20_000, 60_000, 120_000, 0]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                keyCard
                levelCard
                usageCard
                backgroundCard
                healthCard
                personaCard
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .glassSheet($showEditor) { PersonaEditor(editing: editTarget) }
        .glassSheet($showAI) { PersonaAIEditor() }
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

    // MARK: - 推理

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
            Text(levelHint).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.32))
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

    // MARK: - 背景（含自定义照片）

    private var backgroundCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("背景").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                if theme.customImage != nil {
                    Button { theme.clearCustom() } label: {
                        Text("清除照片").font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.45))
                    }
                }
            }

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

                PhotosPicker(selection: $bgItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        if let img = theme.customImage {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.white.opacity(0.10))
                            Image(systemName: "photo").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(height: 30)
                    .frame(width: 30)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(theme.selectedID == ThemeStore.customID ? 0.9 : 0.18),
                                                   lineWidth: theme.selectedID == ThemeStore.customID ? 2 : 1))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
        .onChange(of: bgItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        theme.setCustom(img)
                        store.showToast("背景换好了")
                    }
                }
            }
        }
    }

    // MARK: - 健康

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("健康").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                if health.busy { ProgressView().tint(.white).scaleEffect(0.6) }
                Text(health.status.isEmpty ? (store.healthSummary == nil ? "未连接" : "已启用") : health.status)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.35))
            }

            if let s = store.healthSummary {
                Text(s)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                chip("剪贴板导入") { importClipboard() }
                chip("连接 Health") {
                    Task {
                        await health.connect()
                        if let s = health.summary { store.healthSummary = s; store.save() }
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                PhotosPicker(selection: $healthItem, matching: .images, photoLibrary: .shared()) {
                    Text("截图导入")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
                chip("刷新 Health") {
                    Task { await health.refresh() }
                }
                Spacer(minLength: 0)
            }

            Text("快捷指令做法：新建 →「查找健康样本」(全部，近 7 天) →「拷贝到剪贴板」→ 回来点剪贴板导入")
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.28))
                .fixedSize(horizontal: false, vertical: true)

            if store.healthSummary != nil {
                Button {
                    store.healthSummary = nil
                    store.save()
                    health.summary = nil
                    health.status = ""
                } label: {
                    Text("不再使用")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
        .onChange(of: healthItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    _ = await store.healthFromImage(img)
                    await MainActor.run { healthItem = nil }
                }
            }
        }
    }

    private func importClipboard() {
        let raw = UIPasteboard.general.string ?? ""
        if let parsed = HealthTextParser.parse(raw) {
            store.healthSummary = parsed
            store.save()
            health.status = "已从剪贴板导入"
            health.summary = parsed
        } else {
            store.showToast("剪贴板里没读出健康数据")
        }
    }

    private func chip(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 角色

    private var personaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("角色").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button { showAI = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars").font(.system(size: 10, weight: .semibold))
                        Text("描述生成").font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)

                Button {
                    editTarget = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }

            ForEach(store.personas) { p in
                HStack(spacing: 10) {
                    Text(p.emoji).font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 13.5, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                        Text(p.tone).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.35)).lineLimit(1)
                    }
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
                                .foregroundStyle(.white.opacity(0.30))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    editTarget = p
                    showEditor = true
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, strength: 0.9)
    }

}

// MARK: - 用一句话描述生成角色

struct PersonaAIEditor: View {

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("描述一下你想到的人")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("比如：一个嘴很毒但关键时刻靠得住的程序员，说话短，爱用反问")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(height: 130)
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.08)))

            Spacer(minLength: 0)

            Button {
                Task {
                    busy = true
                    _ = await store.makePersona(from: text)
                    busy = false
                    if store.hasKey { dismiss() }
                }
            } label: {
                HStack(spacing: 6) {
                    if busy { ProgressView().tint(.black).scaleEffect(0.8) }
                    Text(busy ? "正在捏人…" : "生成")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Capsule().fill(Color.white.opacity(0.92)))
            }
            .buttonStyle(SoftPressStyle())
            .disabled(busy || text.trimmed.isEmpty)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }
}
