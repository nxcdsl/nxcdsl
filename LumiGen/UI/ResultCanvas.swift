import SwiftUI

struct ResultCanvas: View {

    @EnvironmentObject private var studio: Studio
    @EnvironmentObject private var themeStore: ThemeStore

    @State private var sharePayload: SharePayload?
    @State private var pulse = false

    private let radius: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )

            if let image = studio.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                placeholder
            }

            if studio.isBusy {
                busyLayer
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.08)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .blur(radius: 22)
                .offset(y: 14)
        )
        .overlay(alignment: .bottom) {
            if studio.image != nil && !studio.isBusy {
                actionBar.padding(12)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: studio.image)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.image])
        }
    }

    // MARK: - 空状态

    private var placeholder: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 84, height: 84)
                    .blur(radius: 1)
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.04)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                    .frame(width: 84, height: 84)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
                    .scaleEffect(pulse ? 1.06 : 0.96)
            }

            VStack(spacing: 5) {
                Text("写下你想看到的画面")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                Text("比如：雨后的老街，一只橘猫蹲在灯下")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - 生成中

    private var busyLayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black.opacity(0.25))

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 3)
                        .frame(width: 62, height: 62)
                    Circle()
                        .trim(from: 0, to: max(0.04, studio.phase.fraction))
                        .stroke(
                            LinearGradient(colors: [.white, .white.opacity(0.5)],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 62, height: 62)
                        .animation(.easeOut(duration: 0.35), value: studio.phase.fraction)
                    Text("\(Int(studio.phase.fraction * 100))%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text(studio.phase.caption)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .transition(.opacity)
    }

    // MARK: - 结果操作

    private var actionBar: some View {
        HStack(spacing: 8) {
            actionButton(title: "保存", icon: "square.and.arrow.down") {
                guard let image = studio.image else { return }
                ImageExport.saveToPhotos(image) { result in
                    switch result {
                    case .success:
                        studio.isSaved = true
                        studio.showBanner("已存进相册")
                    case .failure(let error):
                        studio.showBanner(error.localizedDescription)
                    }
                }
            }

            actionButton(title: "分享", icon: "square.and.arrow.up") {
                if let image = studio.image {
                    sharePayload = SharePayload(image: image)
                }
            }

            actionButton(title: "当背景", icon: "photo") {
                if let image = studio.image {
                    themeStore.setCustom(image)
                    studio.showBanner("背景换好了")
                }
            }

            Spacer(minLength: 0)

            actionButton(title: "再画", icon: "arrow.triangle.2.circlepath") {
                studio.generate()
            }
            .disabled(studio.isBusy)
        }
        .padding(8)
        .glassCapsule()
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11.5, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous).fill(Color.white.opacity(0.10))
            )
        }
        .buttonStyle(SoftPressStyle())
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}
