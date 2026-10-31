import SwiftUI

/// 一次粒子爆发
struct Burst {
    struct Seed {
        var angle: Double
        var speed: Double
        var size: Double
        var warm: Bool
    }

    let id = UUID()
    let origin: CGPoint
    let start: Date
    let seeds: [Seed]
}

/// 全局爆发中心：谁想炸就在自己的位置点一下名
final class BurstCenter: ObservableObject {

    static let shared = BurstCenter()
    @Published var bursts: [Burst] = []

    func fire(at point: CGPoint, count: Int = 28) {
        let seeds = (0..<count).map { _ in
            Burst.Seed(angle: Double.random(in: 0..<(2 * Double.pi)),
                       speed: Double.random(in: 70...300),
                       size: Double.random(in: 1.6...4.6),
                       warm: Bool.random())
        }
        let burst = Burst(origin: point, start: Date(), seeds: seeds)
        bursts.append(burst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            self?.bursts.removeAll { $0.id == burst.id }
        }
    }
}

/// 盖在最上层的粒子画布
struct ParticleLayer: View {

    @ObservedObject private var center = BurstCenter.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: center.bursts.isEmpty)) { timeline in
            Canvas { ctx, _ in
                let now = timeline.date
                for burst in center.bursts {
                    let t = now.timeIntervalSince(burst.start)
                    guard t >= 0, t < 1.05 else { continue }
                    for seed in burst.seeds {
                        let drag = max(0, 1 - t * 2.0)
                        let x = burst.origin.x + cos(seed.angle) * seed.speed * t * drag
                        let y = burst.origin.y + sin(seed.angle) * seed.speed * t * drag + 140 * t * t
                        let alpha = max(0, 1 - t / 0.95)
                        let r = seed.size * max(0.2, 1 - t * 0.7)
                        guard r > 0.3 else { continue }
                        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                        let color = seed.warm
                            ? Color(hue: 0.09, saturation: 0.55, brightness: 1)
                            : Color(hue: 0.60, saturation: 0.45, brightness: 1)
                        ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha * 0.9)))
                    }
                }
            }
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
