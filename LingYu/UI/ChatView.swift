import SwiftUI
import PhotosUI
import UIKit

struct ChatView: View {

    @EnvironmentObject private var store: AppStore
    @State private var input = ""
    @State private var showPersonas = false
    @State private var showModes = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingImage: UIImage?

    var body: some View {
        VStack(spacing: 8) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.messages) { m in
                            bubble(m).id(m.id)
                        }
                        if store.isStreaming {
                            streamingBubble.id("stream")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: store.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: store.streamingText) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            composer
        }
        .glassSheet($showPersonas) { PersonaPicker() }
        .glassSheet($showModes) { ModePicker() }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                open(.personas)
            } label: {
                HStack(spacing: 7) {
                    Text(store.persona.emoji).font(.system(size: 14))
                    Text(store.persona.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassCapsule(strength: 0.9)
            }
            .buttonStyle(SoftPressStyle())

            Spacer(minLength: 0)

            Button {
                open(.modes)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: store.mode.icon).font(.system(size: 11, weight: .semibold))
                    Text(store.mode.title).font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassCapsule(strength: 0.9)
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(.top, 2)
    }

    private func open(_ kind: MenuKind) {
        if store.popupStyle {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) { store.menu = kind }
        } else {
            switch kind {
            case .personas: showPersonas = true
            case .modes: showModes = true
            }
        }
    }

    // MARK: - 气泡

    private func bubble(_ m: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            if m.isUser { Spacer(minLength: 46) }

            Text(m.text)
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(m.isUser ? Color.black.opacity(0.88) : Color.white.opacity(0.94))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if m.isUser {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.90))
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    }
                }
                .textSelection(.enabled)

            if !m.isUser { Spacer(minLength: 46) }
        }
    }

    private var streamingBubble: some View {
        HStack(alignment: .bottom) {
            Group {
                if store.streamingText.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.white.opacity(0.55))
                                .frame(width: 5, height: 5)
                                .opacity(0.4 + 0.6 * Double(i) / 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                } else {
                    Text(store.streamingText)
                        .font(.system(size: 15))
                        .lineSpacing(3)
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    )
            }
            Spacer(minLength: 46)
        }
    }

    // MARK: - 输入

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "camera")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            pendingImage = img
                            store.mode = .vision
                        }
                    }
                }
            }

            ZStack(alignment: .leading) {
                if input.isEmpty {
                    Text(pendingImage == nil ? "说点什么" : "这张图…")
                        .font(.system(size: 14.5))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextField("", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 14.5))
                    .foregroundStyle(.white.opacity(0.95))
                    .tint(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let text = input
                let img = pendingImage
                input = ""
                pendingImage = nil
                pickerItem = nil
                Task { await store.send(text, image: img) }
            } label: {
                Image(systemName: store.isStreaming ? "ellipsis" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(canSend ? 0.92 : 0.35)))
            }
            .buttonStyle(SoftPressStyle())
            .disabled(!canSend)
        }
        .padding(8)
        .glassCard(cornerRadius: 26)
        .padding(.bottom, 2)
        .overlay(alignment: .topLeading) {
            if let pendingImage {
                Image(uiImage: pendingImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.leading, 12)
                    .offset(y: -54)
                    .onTapGesture { self.pendingImage = nil }
            }
        }
    }

    private var canSend: Bool {
        !store.isStreaming && (!input.trimmed.isEmpty || pendingImage != nil)
    }
}

// MARK: - 底部浮层版（设置里可切换）

struct PersonaPicker: View {

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("和谁聊")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.personas) { p in
                        Button {
                            store.select(p)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(p.emoji).font(.system(size: 22))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(p.tint.opacity(0.30)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                    Text(p.relation).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                                }
                                Spacer()
                                if store.currentID == p.id {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                            .padding(12)
                            .glassCard(cornerRadius: 20, strength: 0.8)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(.ultraThinMaterial)
    }
}

struct ModePicker: View {

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("这次想要")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(ChatMode.allCases) { m in
                        Button {
                            store.mode = m
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: m.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 38, height: 38)
                                    .background(Circle().fill(Color.white.opacity(0.10)))
                                Text(m.title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                                Spacer()
                                if store.mode == m {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                            .padding(11)
                            .glassCard(cornerRadius: 18, strength: 0.8)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - 角色编辑（新建 / 修改）

struct PersonaEditor: View {

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var editing: Persona? = nil

    @State private var name = ""
    @State private var emoji = "🌙"
    @State private var relation = ""
    @State private var tone = ""
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(editing == nil ? "新角色" : "改角色")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            field("名字", $name, "小满")
            field("头像 emoji", $emoji, "🌙")
            field("关系", $relation, "大学的室友，毒舌但靠谱")
            field("语气", $tone, "短句、爱开玩笑、偶尔安慰人")

            Spacer(minLength: 0)

            Button {
                if var p = editing {
                    p.name = name.trimmed.isEmpty ? p.name : name.trimmed
                    p.emoji = emoji.trimmed.isEmpty ? p.emoji : emoji.trimmed
                    p.relation = relation.trimmed.isEmpty ? p.relation : relation.trimmed
                    p.tone = tone.trimmed.isEmpty ? p.tone : tone.trimmed
                    store.update(p)
                } else {
                    let p = Persona(name: name.trimmed.isEmpty ? "无名" : name.trimmed,
                                    emoji: emoji.trimmed.isEmpty ? "🙂" : emoji.trimmed,
                                    relation: relation.trimmed.isEmpty ? "朋友" : relation.trimmed,
                                    tone: tone.trimmed.isEmpty ? "自然" : tone.trimmed,
                                    hue: Double.random(in: 0...1))
                    store.add(p)
                }
                dismiss()
            } label: {
                Text("保存")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Color.white.opacity(0.92)))
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let p = editing {
                name = p.name; emoji = p.emoji; relation = p.relation; tone = p.tone
            }
        }
    }

    private func field(_ label: String, _ binding: Binding<String>, _ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            TextField(hint, text: binding)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))
        }
    }
}
