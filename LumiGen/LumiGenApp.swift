import SwiftUI

@main
struct LumiGenApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {

    @StateObject private var studio = Studio()
    @StateObject private var themeStore = ThemeStore()

    var body: some View {
        ZStack(alignment: .top) {
            BackgroundLayer()
                .environmentObject(themeStore)

            HomeView()
                .environmentObject(studio)
                .environmentObject(themeStore)

            if let banner = studio.banner {
                Text(banner)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassCapsule()
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: studio.banner)
        .preferredColorScheme(.dark)
        .environmentObject(studio.library)
        .environmentObject(studio.installer)
        .sheet(isPresented: $studio.showSetup) {
            ModelSetupView()
                .environmentObject(studio)
                .environmentObject(themeStore)
                .environmentObject(studio.library)
                .environmentObject(studio.installer)
        }
        .sheet(isPresented: $studio.showSettings) {
            SettingsView()
                .environmentObject(studio)
                .environmentObject(themeStore)
                .environmentObject(studio.library)
                .environmentObject(studio.installer)
        }
        .onAppear {
            studio.library.refresh()
            if studio.library.isEmpty {
                studio.showSetup = true
            }
        }
    }
}
