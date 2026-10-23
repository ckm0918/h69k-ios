import SwiftUI

// MARK: - 设置页
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var serverText = ""
    @State private var tokenText = ""
    @State private var testing = false
    @State private var testResult: (Bool, String)?

    var body: some View {
        ZStack {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 14) {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            CardTitle(icon: "server.rack", title: "服务器连接")
                            TextField("服务器地址", text: $serverText)
                                .font(AppTheme.mono(13))
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                            TextField("访问 Token（Bearer）", text: $tokenText)
                                .font(AppTheme.mono(12))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                            HStack(spacing: 8) {
                                Button(action: testConnection) {
                                    HStack(spacing: 6) {
                                        if testing { ProgressView().scaleEffect(0.7) }
                                        Text("测试连接")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(Capsule().fill(AppTheme.gradient))
                                }
                                Button("保存") {
                                    save()
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.primary)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                            }
                            if let r = testResult {
                                HStack(spacing: 6) {
                                    StatusDot(color: r.0 ? AppTheme.good : AppTheme.danger)
                                    Text(r.1).font(.system(size: 12))
                                        .foregroundColor(r.0 ? AppTheme.good : AppTheme.danger)
                                }
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            CardTitle(icon: "info.circle", title: "关于")
                            infoRow("版本", "1.0.0")
                            infoRow("设备", "HINLINK OPC-H69K")
                            infoRow("接口", "本地 JSON API 网关 :8788")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitle("设置", displayMode: .large)
        .onAppear {
            serverText = settings.serverURL
            tokenText = settings.token
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(v).font(.system(size: 12, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
        }
    }

    private func save() {
        settings.serverURL = serverText.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.token = tokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        testResult = nil
    }

    private func testConnection() {
        save()
        testing = true
        testResult = nil
        APIClient.shared.ping { r in
            DispatchQueue.main.async {
                testing = false
                switch r {
                case .success(let ok):
                    testResult = (ok, ok ? "连接成功，API 正常响应" : "网关无响应")
                case .failure(let e):
                    testResult = (false, e.localizedDescription)
                }
            }
        }
    }
}
