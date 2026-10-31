import SwiftUI

struct GlassMenuItem: Identifiable {
    let id: String
    let title: String
    var icon: String = "circle"
    var isEmoji = false
    var subtitle: String? = nil
}

/// 相册那种浮在最上层的玻璃列表
struct GlassMenuPanel: View {

    let items: [GlassMenuItem]
    let selected: String?
    var onSelect: (GlassMenuItem) -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    if selected == item.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                                .frame(width: 18)

                                if item.isEmoji {
                                    Text(item.icon).font(.system(size: 19)).frame(width: 26)
                                } else {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 17, weight: .regular))
                                        .frame(width: 26)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title).font(.system(size: 17))
                                    if let sub = item.subtitle {
                                        Text(sub).font(.system(size: 11)).opacity(0.45).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(Color.white.opacity(0.95))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 460)
            .frame(maxWidth: 360)
            .glassCard(cornerRadius: 34)
            .padding(.top, 92)
            .padding(.horizontal, 22)
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        }
    }
}
