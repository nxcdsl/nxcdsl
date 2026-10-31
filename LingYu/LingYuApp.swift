import SwiftUI
import AppIntents

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
                    .padding(.top, 8)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            ParticleLayer()
        }
        .environmentObject(store)
        .environmentObject(theme)
        .preferredColorScheme(.dark)
        .onAppear { store.bootstrap() }
        .onOpenURL { url in
            guard url.scheme == "lingyu" else { return }
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let raw = comps?.queryItems?.first(where: { $0.name == "text" })?.value ?? ""
            if let parsed = HealthTextParser.parse(raw) {
                store.healthSummary = parsed
                store.save()
                store.showToast("健康数据已同步")
            }
        }
    }

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

// MARK: - 底部栏：长按浮出玻璃球，拖着换页

struct GlassTabBar: View {

    @Binding var tab: Int
    @Namespace private var ns

    @State private var orbX: CGFloat? = nil

    private let items: [(icon: String, title: String)] = [
        ("bubble.left.and.bubble.right", "聊天"),
        ("sparkles", "回忆"),
        ("person", "我")
    ]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let slot = width / CGFloat(items.count)

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
                            if tab == index && orbX == nil { pill }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .barGlass()
            .overlay(alignment: .leading) {
                if let x = orbX {
                    orb(index: index(at: x, slot: slot))
                        .offset(x: x - 27, y: 3)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.2)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onChanged { value in
                        switch value {
                        case .second(true, let dragValue?):
                            if orbX == nil {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    orbX = min(width, max(0, slot * (CGFloat(tab) + 0.5)))
                                }
                            }
                            let x = min(width, max(0, dragValue.location.x))
                            orbX = x
                            let target = index(at: x, slot: slot)
                            if target != tab {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { tab = target }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { orbX = nil }
                    }
            )
        }
        .frame(height: 64)
    }

    private func index(at x: CGFloat, slot: CGFloat) -> Int {
        min(items.count - 1, max(0, Int(x / max(1, slot))))
    }

    /// 那颗会折射的玻璃球
    private func orb(index: Int) -> some View {
        ZStack {
            orbGlass
            Image(systemName: items[index].0)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .scaleEffect(1.06)
        }
        .frame(width: 54, height: 54)
        .shadow(color: Color.white.opacity(0.30), radius: 14)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    @ViewBuilder
    private var orbGlass: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Circle()
                .fill(Color.white.opacity(0.06))
                .glassEffect(.regular, in: .circle)
                .overlay(rim)
                .overlay(specular)
        } else {
            fallbackOrb
        }
        #else
        fallbackOrb
        #endif
    }

    private var fallbackOrb: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().fill(Color.white.opacity(0.10)))
            .overlay(rim)
            .overlay(specular)
    }

    private var rim: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [Color.white.opacity(0.85),
                             Color.white.opacity(0.10),
                             Color.white.opacity(0.55),
                             Color.white.opacity(0.08),
                             Color.white.opacity(0.85)],
                    center: .center
                ),
                lineWidth: 1.4
            )
            .blendMode(.plusLighter)
    }

    private var specular: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                    center: UnitPoint(x: 0.32, y: 0.26),
                    startRadius: 1,
                    endRadius: 22
                )
            )
            .blendMode(.plusLighter)
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

// MARK: - 快捷指令动作

struct SaveHealthIntent: AppIntent {

    static var title: LocalizedStringResource = "保存健康数据到灵语"
    static var description = IntentDescription("把一段健康数据交给灵语，聊天时会参考")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "健康数据")
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let raw = text
        AppStore.shared.healthSummary = HealthTextParser.parse(raw) ?? "近 7 天：\(raw.prefix(120))"
        AppStore.shared.save()
        return .result(dialog: "已同步到灵语")
    }
}

struct LingYuShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SaveHealthIntent(),
                    phrases: ["把健康数据存到\(.applicationName)"],
                    shortTitle: "保存健康数据",
                    systemImageName: "heart.text.square")
    }
}
