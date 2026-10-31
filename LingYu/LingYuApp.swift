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
    @State private var drag: CGFloat = 0

    var body: some View {
        ZStack {
            BackgroundLayer()
                .environmentObject(theme)

            VStack(spacing: 0) {
                pager

                GlassTabBar(tab: $tab)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            ParticleLayer()
        }
        .environmentObject(store)
        .environmentObject(theme)
        .preferredColorScheme(.dark)
        .onAppear { store.bootstrap() }
    }

    // MARK: - 自己的分页器（比系统 TabView 顺，取消手势时是回弹而不是跳）

    private var pager: some View {
        GeometryReader { geo in
            let width = geo.size.width
            HStack(spacing: 0) {
                ChatView().frame(width: width)
                MemoryView().frame(width: width)
                SettingsPane().frame(width: width)
            }
            .frame(width: width * 3, alignment: .leading)
            .offset(x: -CGFloat(tab) * width + drag)
            .simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        var dx = value.translation.width
                        if (tab == 0 && dx > 0) || (tab == 2 && dx < 0) { dx *= 0.28 }
                        drag = dx
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { drag = 0 }
                            return
                        }
                        let dx = value.translation.width
                        let predicted = value.predictedEndTranslation.width
                        var target = tab
                        if dx < -width * 0.22 || predicted < -width * 0.5 {
                            target = min(2, tab + 1)
                        } else if dx > width * 0.22 || predicted > width * 0.5 {
                            target = max(0, tab - 1)
                        }
                        if target != tab { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            tab = target
                            drag = 0
                        }
                    }
            )
        }
        .clipped()
    }
}

// MARK: - 底部栏：按住可以左右滑着换

struct GlassTabBar: View {

    @Binding var tab: Int
    @Namespace private var ns

    private let items: [(icon: String, title: String)] = [
        ("bubble.left.and.bubble.right", "聊天"),
        ("sparkles", "回忆"),
        ("person", "我")
    ]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Button {
                        select(index)
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
                            if tab == index { pill }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .barGlass()
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let width = max(1, geo.size.width) / CGFloat(items.count)
                        let index = min(items.count - 1, max(0, Int(value.location.x / width)))
                        if index != tab { select(index) }
                    }
            )
        }
        .frame(height: 64)
    }

    private func select(_ index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { tab = index }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    @ViewBuilder
    private var pill: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.14))
                .glassEffect(.regular, in: .capsule)
                .glassEffectID("tab-pill", in: ns)
        } else {
            plainPill
        }
        #else
        plainPill
        #endif
    }

    private var plainPill: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.16))
            .overlay(Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - 栏底玻璃

private struct BarGlass: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                content
                    .glassEffect(.regular, in: .capsule)
            }
        } else {
            content.glassCapsule()
        }
        #else
        content.glassCapsule()
        #endif
    }
}

extension View {
    func barGlass() -> some View { modifier(BarGlass()) }
}
