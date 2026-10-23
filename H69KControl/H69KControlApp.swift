import SwiftUI

@main
struct H69KControlApp: App {
    @ObservedObject var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(settings.colorScheme)
        }
    }
}

// 根视图：设置未完成时引导去设置
struct RootView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showSettings = false

    var body: some View {
        Group {
            if settings.isValid {
                MainTabView()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "router.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppTheme.primary)
                    Text("H69K 控制台")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("先配置服务器地址和 Token\n才能连接你的 H69K 路由器")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.textSecondary)
                    Button(action: { showSettings = true }) {
                        Text("去配置")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(AppTheme.gradient))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.bg.edgesIgnoringSafeArea(.all))
                .sheet(isPresented: $showSettings) { SettingsView() }
            }
        }
    }
}

struct MainTabView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationView { DashboardView() }
                .tabItem { Label("总览", systemImage: "gauge") }
                .tag(0)

            NavigationView { FiveGView() }
                .tabItem { Label("网络", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(1)

            NavigationView { SMSView() }
                .tabItem { Label("短信", systemImage: "message") }
                .tag(2)

            NavigationView { Aria2View() }
                .tabItem { Label("下载", systemImage: "arrow.down.circle") }
                .tag(3)

            NavigationView { ServiceView() }
                .tabItem { Label("服务", systemImage: "bolt.horizontal.circle") }
                .tag(4)

            NavigationView { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(5)
        }
        .accentColor(AppTheme.primary)
        .background(AppTheme.bg.edgesIgnoringSafeArea(.all))
    }
}
