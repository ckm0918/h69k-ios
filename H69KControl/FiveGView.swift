import SwiftUI

// MARK: - 网络页（5G + WiFi）
struct FiveGView: View {
    @State private var fiveG: FiveGStatus?
    @State private var wifi: WifiStatus?
    @State private var loading = false
    @State private var acting = false
    @State private var errorMsg: String?
    @State private var showRebootConfirm = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 14) {
                    if let errorMsg = errorMsg {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                            Text(errorMsg).font(.system(size: 12))
                        }
                        .foregroundColor(AppTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }

                    // 5G 主状态卡片
                    CardView {
                        VStack(spacing: 14) {
                            CardTitle(icon: "antenna.radiowaves.left.and.right", title: "5G 蜂窝网络")
                            HStack(spacing: 18) {
                                if let sig = fiveG?.signal {
                                    GaugeRing(
                                        value: Double(min(max(sig.csq ?? 0, 0), 31)) / 31.0,
                                        size: 96, lineWidth: 10,
                                        color: sig.levelColor,
                                        centerText: "\(sig.rssiDbm ?? 0)",
                                        subText: "dBm")
                                } else {
                                    GaugeRing(value: 0, size: 96, centerText: "--", subText: "信号")
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    statusRow("信号等级", fiveG?.signal?.levelText ?? "未获取",
                                              color: fiveG?.signal?.levelColor ?? AppTheme.textSecondary)
                                    statusRow("网络模式", fiveG?.net?.mode ?? "--")
                                    statusRow("注册状态",
                                              fiveG?.registered == true ? "已注册" : "未注册",
                                              color: fiveG?.registered == true ? AppTheme.good : AppTheme.danger)
                                    statusRow("拨号 IP", fiveG?.wwanIp ?? "--")
                                }
                                Spacer()
                            }
                            if let raw = fiveG?.raw, !raw.isEmpty {
                                Text(raw)
                                    .font(AppTheme.mono(9))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                                    .lineLimit(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    // WiFi 频段卡片
                    CardView {
                        VStack(spacing: 12) {
                            CardTitle(icon: "wifi", title: "WiFi 频段与开关")
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("当前频段")
                                        .font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
                                    Text(wifi?.activeBand ?? "--")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                Spacer()
                                VStack(spacing: 6) {
                                    Text("WiFi 状态")
                                        .font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
                                    HStack(spacing: 4) {
                                        StatusDot(color: wifiEnabled ? AppTheme.good : AppTheme.danger)
                                        Text(wifiEnabled ? "已开启" : "已关闭")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(wifiEnabled ? AppTheme.good : AppTheme.danger)
                                    }
                                }
                            }
                            HStack(spacing: 10) {
                                bandButton("2.4G", target: "2.4", active: wifi?.activeBand == "2.4G")
                                bandButton("5G", target: "5", active: wifi?.activeBand == "5G")
                                Spacer()
                                Button(action: toggleWifi) {
                                    HStack(spacing: 6) {
                                        Image(systemName: wifiEnabled ? "wifi.slash" : "wifi")
                                        Text(wifiEnabled ? "关闭 WiFi" : "开启 WiFi")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(wifiEnabled ? AppTheme.danger : AppTheme.good)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(Capsule().fill(Color.white.opacity(0.06)))
                                }
                                .disabled(acting)
                            }
                        }
                    }

                    // 网络模式卡片
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            CardTitle(icon: "arrow.triangle.branch", title: "5G 网络模式")
                            Picker("网络模式", selection: $modeSelection) {
                                Text("自动(5G优先)").tag(0)
                                Text("4G").tag(1)
                                Text("2G").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onChange(of: modeSelection) { newVal in
                                let arg = newVal == 0 ? "20" : (newVal == 1 ? "14" : "2")
                                switchMode(arg)
                            }
                            HStack(spacing: 8) {
                                Button(action: { showRebootConfirm = true }) {
                                    Label("重启 5G 模组", systemImage: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.danger)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.danger.opacity(0.12)))
                                }
                                .disabled(acting)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable_ios {
                loadAll()
            }
            if loading || acting {
                VStack {
                    ProgressView()
                    Text(acting ? "执行中…" : "加载中…")
                        .font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.cardHigh))
            }
        }
        .navigationBarTitle("网络", displayMode: .large)
        .onAppear { loadAll(); startTimer() }
        .onDisappear { timer?.invalidate() }
        .alert(isPresented: $showRebootConfirm) {
            Alert(title: Text("重启 5G 模组"),
                  message: Text("将重新拨号，网络会短暂中断（约 1-2 分钟）。继续？"),
                  primaryButton: .destructive(Text("重启")) { rebootModem() },
                  secondaryButton: .cancel())
        }
    }

    private var wifiEnabled: Bool {
        // radio1 未 disabled 视为开启
        guard let radios = wifi?.radios else { return true }
        return !(radios.first?.disabled ?? false)
    }

    @State private var modeSelection: Int = 0

    private func statusRow(_ k: String, _ v: String, color: Color = AppTheme.textPrimary) -> some View {
        HStack(spacing: 8) {
            Text(k).font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
            Text(v).font(.system(size: 12, weight: .semibold)).foregroundColor(color)
        }
    }

    private func bandButton(_ name: String, target: String, active: Bool) -> some View {
        Button(action: { switchBand(target) }) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(active ? .white : AppTheme.textSecondary)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(
                    Group {
                        if active {
                            Capsule().fill(AppTheme.gradient)
                        } else {
                            Capsule().fill(Color.white.opacity(0.06))
                        }
                    }
                )
        }
        .disabled(acting)
    }

    private func loadAll() {
        loading = true
        errorMsg = nil
        APIClient.shared.fiveGStatus { r in
            DispatchQueue.main.async {
                loading = false
                switch r {
                case .success(let s):
                    fiveG = s
                    modeSelection = s.net?.modeCode == "14" ? 1 : (s.net?.modeCode == "2" ? 2 : 0)
                case .failure(let e):
                    errorMsg = e.localizedDescription
                }
            }
        }
        APIClient.shared.wifiStatus { r in
            DispatchQueue.main.async {
                switch r {
                case .success(let w): wifi = w
                case .failure: break
                }
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { _ in
            loadAll()
        }
    }

    private func switchBand(_ target: String) {
        guard wifi?.activeBand != (target == "2.4" ? "2.4G" : "5G") else { return }
        acting = true
        APIClient.shared.wifiAction("band", arg: target) { r in
            DispatchQueue.main.async {
                acting = false
                switch r {
                case .success: 
                    errorMsg = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 9) { loadAll() }
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }

    private func toggleWifi() {
        acting = true
        APIClient.shared.wifiAction(wifiEnabled ? "off" : "on") { r in
            DispatchQueue.main.async {
                acting = false
                switch r {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { loadAll() }
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }

    private func switchMode(_ arg: String) {
        acting = true
        APIClient.shared.fiveGAction("act", arg: arg) { r in
            DispatchQueue.main.async {
                acting = false
                switch r {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) { loadAll() }
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }

    private func rebootModem() {
        acting = true
        APIClient.shared.fiveGAction("reboot") { r in
            DispatchQueue.main.async {
                acting = false
                switch r {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { loadAll() }
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }
}

// MARK: - iOS 14 下拉刷新兼容封装
extension View {
    func refreshable_ios(_ action: @escaping () -> Void) -> some View {
        // iOS 14 无原生 refreshable，保留空实现保持 API 一致
        self
    }
}
