import SwiftUI

@main
struct LingYuApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {

    @StateObject private var store = AppStore.shared
    @StateObject private var theme = ThemeStore()
    @State private var tab = 0

    private let tabs: [(String, String)] = [
        ("bubble.left.and.bubble.right", "聊天"),
        ("sparkles", "回忆"),
        ("person", "我")
    ]

    var body: some View {
        ZStack {
            BackgroundLayer()
                .environmentObject(theme)

            VStack(spacing: 0) {
                TabView(selection: $tab) {
                    ChatView().tag(0)
                    MemoryView().tag(1)
                    SettingsPane().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                tabBar
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            if let kind = store.menu {
                menuOverlay(kind)
            }
        }
        .environmentObject(store)
        .environmentObject(theme)
        .preferredColorScheme(.dark)
        .onAppear { store.bootstrap() }
    }

    // MARK: - iOS 26 那种底部栏

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { tab = index }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.0)
                            .font(.system(size: 19, weight: tab == index ? .semibold : .regular))
                        Text(item.1)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(tab == index ? Color.white : Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if tab == index {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.16))
                                .overlay(Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .glassCapsule()
        .padding(.top, 6)
    }

    // MARK: - 弹出列表

    @ViewBuilder
    private func menuOverlay(_ kind: MenuKind) -> some View {
        switch kind {
        case .personas:
            GlassMenuPanel(items: store.personas.map {
                GlassMenuItem(id: $0.id.uuidString, title: $0.name,
                              icon: $0.emoji, isEmoji: true, subtitle: $0.relation)
            }, selected: store.currentID.uuidString) { item in
                if let p = store.personas.first(where: { $0.id.uuidString == item.id }) {
                    store.select(p)
                }
                closeMenu()
            } onClose: { closeMenu() }

        case .modes:
            GlassMenuPanel(items: ChatMode.allCases.map {
                GlassMenuItem(id: $0.rawValue, title: $0.title, icon: $0.icon)
            }, selected: store.mode.rawValue) { item in
                if let m = ChatMode(rawValue: item.id) { store.mode = m }
                closeMenu()
            } onClose: { closeMenu() }
        }
    }

    private func closeMenu() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { store.menu = nil }
    }
}
