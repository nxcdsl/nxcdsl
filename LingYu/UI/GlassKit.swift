import SwiftUI

/// 液态玻璃（Liquid Glass）表面。
///
/// - iOS 26 + Xcode 26：使用系统原生 `.glassEffect`。
/// - 其他情况：自动退回一层非常接近的拟态玻璃，保证老工具链也能编译。
///
/// 如果编译时提示找不到 glassEffect，把 `useSystemGlass` 改成 false 即可。
enum GlassKit {
    static let useSystemGlass = true
}

// MARK: - 退回用的玻璃底

struct FakeGlass<S: InsettableShape>: View {
    let shape: S
    var strength: Double = 1.0

    var body: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.white.opacity(0.06 * strength))
            shape.fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.16 * strength), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            )
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.50), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.30), radius: 24, x: 0, y: 14)
    }
}

// MARK: - 修饰器

struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    var strength: Double = 1.0

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if GlassKit.useSystemGlass, #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(FakeGlass(shape: shape, strength: strength))
        }
        #else
        content.background(FakeGlass(shape: shape, strength: strength))
        #endif
    }
}

extension View {
    /// 给任意视图套一层玻璃
    func glassSurface<S: InsettableShape>(_ shape: S, strength: Double = 1.0) -> some View {
        modifier(GlassSurface(shape: shape, strength: strength))
    }

    func glassCard(cornerRadius: CGFloat = 26, strength: Double = 1.0) -> some View {
        glassSurface(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), strength: strength)
    }

    func glassCapsule(strength: Double = 1.0) -> some View {
        glassSurface(Capsule(style: .continuous), strength: strength)
    }
}

// MARK: - 可点击的玻璃胶囊

struct GlassChip: View {
    let title: String
    var emoji: String? = nil
    var isOn: Bool = false
    var tint: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.system(size: 13, weight: .semibold))
                }
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isOn ? Color.black.opacity(0.85) : Color.white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isOn {
                    Capsule(style: .continuous)
                        .fill(tint)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: tint.opacity(0.55), radius: 12, y: 4)
                }
            }
            .glassCapsule(strength: isOn ? 0.25 : 0.8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 玻璃图标按钮

struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 42
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: size, height: size)
                .glassSurface(Circle(), strength: 0.9)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 按下回弹

struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
