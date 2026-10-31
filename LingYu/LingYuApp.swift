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

    var body: some View {
        ZStack {
            BackgroundLayer()
                .environmentObject(theme)

            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case 0: ChatView()
                    case 1: MemoryView()
                    default: SettingsPane()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .environmentObject(store)
        .environmentObject(theme)
        .preferredColorScheme(.dark)
        .onAppear { store.bootstrap() }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabItem(0, "bubble.left.and.bubble.right", "聊天")
            tabItem(1, "sparkles", "回忆")
            tabItem(2, "person", "我")
        }
        .padding(6)
        .glassCapsule()
        .padding(.top, 8)
    }

    private func tabItem(_ index: Int, _ icon: String, _ label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { tab = index }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                if tab == index {
                    Text(label).font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(tab == index ? Color.black.opacity(0.85) : Color.white.opacity(0.65))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if tab == index {
                    Capsule(style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .white.opacity(0.35), radius: 10, y: 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 透明玻璃浮层（二级菜单）

extension View {
    func glassSheet<C: View>(_ isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> C) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .environmentObject(AppStore.shared)
                .presentationBackground(.clear)
                .presentationCornerRadius(36)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
    }
}
