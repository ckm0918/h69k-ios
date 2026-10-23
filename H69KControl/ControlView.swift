import SwiftUI

// MARK: - 控制中心（对应 h69k 控制脚本白名单）
struct ControlView: View {
    @State private var mode = "auto"
    @State private var wifiOn = true
    @State private var dataOn = true
    @State private var busying: String?
    @State private var toast: String?
    @State private var showRebootConfirm = false
    @State private var fanInfo: String = ""

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 14) {
                    if let t = toast {
                        Text(t)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(AppTheme.cardHigh))
                            .transition(.opacity)
                    }
                    networkCard
                    wifiCard
                    fanCard
                    dangerCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitle("控制", displayMode: .large)
        .navigationBarItems(trailing: Button(action: loadStatus) {
            Image(systemName: "arrow.clockwise")
        })
        .onAppear { loadStatus() }
    }

    // MARK: 读取当前状态
    private func loadStatus() {
        APIClient.shared.status { r in
            DispatchQueue.main.async {
                if case .success(let s) = r {
                    mode = s.netMode ?? "auto"
                    wifiOn = s.netConf?["wifi"] == "on"
                    dataOn = s.netConf?["data"] == "on"
                }
            }
        }
        APIClient.shared.action("fan-control", arg: "status") { r in
            DispatchQueue.main.async {
                if case .success(let txt) = r { fanInfo = txt }
            }
        }
    }

    private func run(_ action: String, arg: String? = nil, key: String) {
        guard busying == nil else { return }
        busying = key
        APIClient.shared.action(action, arg: arg) { r in
            DispatchQueue.main.async {
                busying = nil
                switch r {
                case .success(let txt):
                    toast = "✓ \(txt)"
                    if action == "net-switch" { loadStatus() }
                case .failure(let e):
                    toast = "✗ \(e.localizedDescription)"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { toast = nil }
                }
            }
        }
    }

    // MARK: 网络模式
    private var networkCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(icon: "arrow.triangle.2.circlepath", title: "双线路模式")
                HStack(spacing: 8) {
                    modeButton("宽带优先", mode == "auto", "auto")
                    modeButton("仅宽带", mode == "lock-wan", "lock-wan")
                    modeButton("仅 5G", mode == "lock-5g", "lock-5g")
                }
                HStack(spacing: 12) {
                    toggleItem(name: "WiFi", icon: "wifi", on: $wifiOn) { on in
                        run("net-switch", arg: on ? "set-wifi on" : "set-wifi off", key: "wifi")
                    }
                    toggleItem(name: "5G 数据", icon: "antenna.radiowaves.left.and.right", on: $dataOn) { on in
                        run("net-switch", arg: on ? "set-data on" : "set-data off", key: "data")
                    }
                }
            }
        }
    }

    private func modeButton(_ name: String, _ active: Bool, _ value: String) -> some View {
        Button(action: {
            run("net-switch", arg: value, key: "mode")
        }) {
            HStack(spacing: 5) {
                if busying == "mode" && active { ProgressView().scaleEffect(0.7) }
                Text(name).font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                Group {
                    if active {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.gradient)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06))
                    }
                }
            )
            .foregroundColor(active ? .white : AppTheme.textSecondary)
        }
    }

    private func toggleItem(name: String, icon: String, on: Binding<Bool>,
                            handler: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(on.wrappedValue ? AppTheme.good : AppTheme.textSecondary)
            Text(name).font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
            Spacer()
            Toggle("", isOn: on)
                .labelsHidden()
                .scaleEffect(0.75)
                .onChange(of: on.wrappedValue) { newVal in
                    handler(newVal)
                }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    // MARK: WiFi 频段
    private var wifiCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(icon: "wifi", title: "WiFi 频段")
                HStack(spacing: 8) {
                    bandButton("2.4GHz", "2.4")
                    bandButton("5GHz", "5")
                }
                Text("切换后客户端会短暂断开重连")
                    .font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private func bandButton(_ name: String, _ band: String) -> some View {
        Button(action: { run("wifi-band", arg: band, key: "band") }) {
            HStack(spacing: 5) {
                if busying == "band" { ProgressView().scaleEffect(0.7) }
                Text(name).font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06)))
            .foregroundColor(AppTheme.textPrimary)
        }
    }

    // MARK: 风扇
    private var fanCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(icon: "fanblades", title: "散热风扇", iconColor: AppTheme.cyan)
                Text(fanInfo.isEmpty ? "未知状态" : fanInfo)
                    .font(AppTheme.mono(11))
                    .foregroundColor(AppTheme.textSecondary)
                HStack(spacing: 8) {
                    Button("自动") { run("fan-control", arg: "mode auto", key: "fan") }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(AppTheme.gradient))
                        .foregroundColor(.white)
                    Button("手动") { run("fan-control", arg: "mode manual", key: "fan") }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
    }

    // MARK: 危险操作
    private var dangerCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(icon: "exclamationmark.triangle", title: "危险操作", iconColor: AppTheme.danger)
                Button(action: { showRebootConfirm = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重启路由器")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.danger))
                }
                .actionSheet(isPresented: $showRebootConfirm) {
                    ActionSheet(title: Text("确认重启路由器？"),
                                message: Text("所有设备将断网约 1-2 分钟"),
                                buttons: [
                                    .destructive(Text("重启")) {
                                        run("reboot", key: "reboot")
                                    },
                                    .cancel()
                                ])
                }
            }
        }
    }
}
