import SwiftUI

// MARK: - 总览页（专业仪表盘，参考 ASUS Router / 小米路由风格）
struct DashboardView: View {
    @State private var status: SystemStatus?
    @State private var devices: DevicesList?
    @State private var error: String?
    @State private var loading = false
    @State private var rxHistory: [Double] = []
    @State private var txHistory: [Double] = []
    @State private var timer: Timer?
    @State private var showSettingsSheet = false
    @State private var acting = false

    var body: some View {
        ZStack {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    if loading && status == nil {
                        ProgressView("连接 H69K…")
                            .padding(.top, 80)
                            .foregroundColor(AppTheme.textSecondary)
                    } else if let err = error, status == nil {
                        ErrorCard(message: err) { showSettingsSheet = true }
                            .padding(.top, 40)
                    } else if let s = status {
                        heroBanner(s)
                        SectionLabel(text: "路由器体检")
                        healthEntryCard(s)
                        SectionLabel(text: "网络状态")
                        networkCard(s)
                        SectionLabel(text: "实时流量")
                        trafficCard(s)
                        SectionLabel(text: "快捷控制")
                        quickControlCard(s)
                        if let d = devices {
                            SectionLabel(text: "接入设备")
                            devicesCard(d)
                        }
                        SectionLabel(text: "系统资源")
                        gaugesRow(s)
                        if !(s.modemStatus ?? "").isEmpty {
                            SectionLabel(text: "5G 模组日志")
                            modemCard(s)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitle("H69K", displayMode: .large)
        .navigationBarItems(trailing: HStack(spacing: 14) {
            if let s = status {
                HStack(spacing: 5) {
                    StatusDot(color: AppTheme.good)
                    Text(Fmt.uptime(s.uptimeS ?? 0))
                        .font(AppTheme.mono(10))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            Button(action: refresh) { Image(systemName: "arrow.clockwise") }
                .disabled(loading || acting)
        })
        .sheet(isPresented: $showSettingsSheet) { SettingsView() }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: 体检入口
    private func healthEntryCard(_ s: SystemStatus) -> some View {
        let hint = healthHint(s)
        let color = hint == 0 ? AppTheme.good : (hint == 1 ? AppTheme.warn : AppTheme.danger)
        let text = hint == 0 ? "状态良好" : (hint == 1 ? "建议关注" : "需要处理")
        return NavigationLink(destination: HealthView()) {
            CardView {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 46, height: 46)
                        Image(systemName: hint == 0 ? "stethoscope" : (hint == 1 ? "waveform.path.ecg" : "exclamationmark.octagon"))
                            .font(.system(size: 20))
                            .foregroundColor(color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("路由器体检")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("全面检测 20+ 项 · 自动生成优化报告")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text(text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func healthHint(_ s: SystemStatus) -> Int {
        var hint = 0
        if let ts = s.tempC, let t = ts.max(), t > 80 { hint = 2 }
        else if let ts = s.tempC, let t = ts.max(), t > 70 { hint = 1 }
        if let l = s.load?.first.flatMap(Double.init), l > 2.5 { hint = max(hint, 1) }
        if let l = s.load?.first.flatMap(Double.init), l > 4.0 { hint = max(hint, 2) }
        return hint
    }

    // MARK: 数据获取
    private func refresh() {
        loading = true
        error = nil
        APIClient.shared.status { r in
            DispatchQueue.main.async {
                loading = false
                switch r {
                case .success(let s):
                    status = s
                    pushTraffic(s)
                case .failure(let e):
                    error = e.localizedDescription
                }
            }
        }
        APIClient.shared.devices { r in
            DispatchQueue.main.async {
                if case .success(let d) = r {
                    devices = d
                }
            }
        }
    }

    private func startTimer() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            refresh()
        }
    }

    private func pushTraffic(_ s: SystemStatus) {
        let rx = Double(s.net?["eth0"]?.rxB ?? s.net?["br-lan"]?.rxB ?? 0)
        let tx = Double(s.net?["eth0"]?.txB ?? s.net?["br-lan"]?.txB ?? 0)
        let lastRxAbs = lastRx
        let lastTxAbs = lastTx
        if lastRxAbs > 0 { rxHistory.append(max(rx - lastRxAbs, 0)) }
        else { rxHistory.append(0) }
        if lastTxAbs > 0 { txHistory.append(max(tx - lastTxAbs, 0)) }
        else { txHistory.append(0) }
        if rxHistory.count > 40 { rxHistory.removeFirst(rxHistory.count - 40) }
        if txHistory.count > 40 { txHistory.removeFirst(txHistory.count - 40) }
        lastRx = rx
        lastTx = tx
    }

    @State private var lastRx: Double = 0
    @State private var lastTx: Double = 0

    // MARK: 顶部渐变横幅
    private func heroBanner(_ s: SystemStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    StatusDot(color: AppTheme.good, size: 9)
                    Text("在线")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Text(s.netMode == "lock-5g" ? "仅 5G" : s.netMode == "lock-wan" ? "仅宽带" : "宽带优先")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }
            Text("HINLINK OPC-H69K")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("出口 IP")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                    Text(s.wanIp ?? "--")
                        .font(AppTheme.mono(15))
                        .foregroundColor(.white)
                }
                Divider().frame(height: 28).background(Color.white.opacity(0.25))
                VStack(alignment: .leading, spacing: 3) {
                    Text("5G IP")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                    Text(s.wwanIp ?? "--")
                        .font(AppTheme.mono(15))
                        .foregroundColor(.white)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 58, height: 58)
                    Image(systemName: "router.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(gradient: Gradient(colors: [
                        Color(red: 0.24, green: 0.30, blue: 0.62),
                        AppTheme.accent.opacity(0.75)
                    ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
    }

    // MARK: 网络状态卡
    private func networkCard(_ s: SystemStatus) -> some View {
        CardView {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    modePill(name: "宽带", on: s.netConf?["wifi"] == "on", color: AppTheme.good, icon: "wifi")
                    modePill(name: "5G 数据", on: s.netConf?["data"] == "on", color: AppTheme.cyan,
                             icon: "antenna.radiowaves.left.and.right")
                    Spacer()
                }
                Divider().background(AppTheme.cardBorder)
                StatusRow(icon: "arrow.triangle.2.circlepath", title: "切换策略",
                          value: s.netMode == "auto" ? "宽带优先，5G 备用"
                                : s.netMode == "lock-wan" ? "已锁定宽带"
                                : s.netMode == "lock-5g" ? "已锁定 5G"
                                : s.netMode == "none" ? "全部关闭（断网）"
                                : s.netMode ?? "--")
                StatusRow(icon: "thermometer", title: "系统温度",
                          value: s.tempC?.map { "\($0)°" }.joined(separator: " / ") ?? "--",
                          iconColor: AppTheme.warn)
                StatusRow(icon: "hourglass", title: "运行时间", value: Fmt.uptime(s.uptimeS ?? 0),
                          iconColor: AppTheme.info)
            }
        }
    }

    private func modePill(name: String, on: Bool, color: Color, icon: String) -> some View {
        HStack(spacing: 5) {
            StatusDot(color: on ? color : AppTheme.textSecondary, size: 7)
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(on ? color : AppTheme.textSecondary)
            Text(name).font(.system(size: 12, weight: .semibold))
                .foregroundColor(on ? AppTheme.textPrimary : AppTheme.textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(on ? color.opacity(0.14) : Color.white.opacity(0.05)))
    }

    // MARK: 实时流量卡
    private func trafficCard(_ s: SystemStatus) -> some View {
        CardView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    BigMetric(icon: "arrow.down.circle.fill", title: "下载速率",
                              value: Fmt.speed(Int64(rxHistory.last ?? 0)),
                              color: AppTheme.good)
                    Divider().frame(height: 34).background(AppTheme.cardBorder)
                    BigMetric(icon: "arrow.up.circle.fill", title: "上传速率",
                              value: Fmt.speed(Int64(txHistory.last ?? 0)),
                              color: AppTheme.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("实时曲线")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                    Sparkline(points: rxHistory, lineColor: AppTheme.good)
                        .frame(height: 46)
                }
            }
        }
    }

    // MARK: 快捷控制卡
    private func quickControlCard(_ s: SystemStatus) -> some View {
        CardView {
            HStack(spacing: 6) {
                QuickToggle(icon: "wifi", label: "WiFi",
                            on: s.netConf?["wifi"] == "on", accent: AppTheme.good) {
                    runAction("net_wifi", arg: s.netConf?["wifi"] == "on" ? "off" : "on")
                }
                QuickToggle(icon: "antenna.radiowaves.left.and.right", label: "5G 数据",
                            on: s.netConf?["data"] == "on", accent: AppTheme.cyan) {
                    runAction("net_data", arg: s.netConf?["data"] == "on" ? "off" : "on")
                }
                QuickToggle(icon: "fan.fill", label: "风扇自动",
                            on: fanAuto, accent: AppTheme.warn) {
                    runAction("fan_mode", arg: fanAuto ? "manual" : "auto")
                }
                QuickToggle(icon: "arrow.triangle.2.circlepath", label: "宽带优先",
                            on: s.netMode == "auto", accent: AppTheme.info) {
                    runAction("net_mode", arg: s.netMode == "auto" ? "lock-5g" : "auto")
                }
            }
        }
    }

    private var fanAuto: Bool {
        status?.netConf?["fan"] == "auto" || status?.netConf?["fan"] == nil
    }

    private func runAction(_ action: String, arg: String?) {
        acting = true
        APIClient.shared.action(action, arg: arg) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                acting = false
                refresh()
            }
        }
    }

    // MARK: 仪表行
    private func gaugesRow(_ s: SystemStatus) -> some View {
        HStack(spacing: 14) {
            CardView(padding: 14) {
                VStack(spacing: 10) {
                    CardTitle(icon: "cpu", title: "CPU")
                    GaugeRing(value: (s.cpu ?? 0) / 100.0,
                              size: 92, lineWidth: 9,
                              color: cpuColor(s.cpu ?? 0),
                              centerText: String(format: "%.0f%%", s.cpu ?? 0))
                    HStack(spacing: 8) {
                        Text("负载").font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
                        if let l = s.load, l.count >= 3 {
                            Text("\(l[0]) / \(l[1]) / \(l[2])")
                                .font(AppTheme.mono(10)).foregroundColor(AppTheme.textPrimary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            CardView(padding: 14) {
                VStack(spacing: 10) {
                    CardTitle(icon: "memorychip", title: "内存")
                    let usedPct = s.memTotalMb.map { t -> Double in
                        let u = t - (s.memAvailMb ?? t)
                        return Double(u) / Double(t)
                    } ?? 0
                    GaugeRing(value: usedPct,
                              size: 92, lineWidth: 9,
                              color: AppTheme.cyan,
                              centerText: String(format: "%.0f%%", usedPct * 100),
                              subText: nil)
                    VStack(spacing: 3) {
                        Text("\(s.memAvailMb ?? 0) MB 可用")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
                        Text("共 \(s.memTotalMb ?? 0) MB")
                            .font(.system(size: 10)).foregroundColor(AppTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func cpuColor(_ v: Double) -> Color {
        v < 50 ? AppTheme.good : v < 80 ? AppTheme.warn : AppTheme.danger
    }

    // MARK: 接入设备
    private func devicesCard(_ d: DevicesList) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CardTitle(icon: "desktopcomputer", title: "接入设备", iconColor: AppTheme.info)
                    Spacer()
                    HStack(spacing: 5) {
                        StatusDot(color: AppTheme.good)
                        Text("\(d.onlineCount ?? 0)/\(d.total ?? 0) 在线")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                if let list = d.devices, !list.isEmpty {
                    ForEach(list.prefix(10)) { dev in
                        DeviceRowView(device: dev)
                    }
                } else {
                    Text("暂无已知设备（上级路由分配 DHCP 时此处可能为空）")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: 5G 模组日志
    private func modemCard(_ s: SystemStatus) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle(icon: "antenna.radiowaves.left.and.right", title: "5G 模组", iconColor: AppTheme.cyan)
                Text(s.modemStatus ?? "")
                    .font(AppTheme.mono(9))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(6)
            }
        }
    }
}

// MARK: - 错误卡片
struct ErrorCard: View {
    let message: String
    var onSettings: (() -> Void)? = nil

    var body: some View {
        CardView {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22)).foregroundColor(AppTheme.warn)
                VStack(alignment: .leading, spacing: 6) {
                    Text("无法连接 H69K").font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(message).font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
                    Button(action: { onSettings?() }) {
                        Text("打开设置")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.primary)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - 设备行
struct DeviceRowView: View {
    let device: DeviceItem

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(device.online ? AppTheme.good.opacity(0.14) : Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: deviceIcon)
                    .font(.system(size: 15))
                    .foregroundColor(device.online ? AppTheme.good : AppTheme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name.isEmpty ? device.ip : device.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(device.ip)
                    .font(AppTheme.mono(10))
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            HStack(spacing: 5) {
                StatusDot(color: device.online ? AppTheme.good : AppTheme.textSecondary.opacity(0.4))
                Text(device.online ? "在线" : "离线")
                    .font(.system(size: 11))
                    .foregroundColor(device.online ? AppTheme.good : AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var deviceIcon: String {
        let n = device.name.lowercased()
        if n.contains("iphone") || n.contains("ipad") || n.contains("apple") {
            return "iphone"
        }
        if n.contains("xiaomi") || n.contains("mi ") || n.contains("redmi") {
            return "iphone"
        }
        if n.contains("tv") || n.contains("box") {
            return "tv"
        }
        return "desktopcomputer"
    }
}
