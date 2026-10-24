import SwiftUI

// MARK: - 设置页（服务器 + 常用设置 + 散热风扇 + 外观 + 关于）
struct SettingsView: View {
    var body: some View {
        ZStack {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 14) {
                    SectionLabel(text: "连接配置")
                    ServerSectionView()
                    SectionLabel(text: "常用设置")
                    QuickSettingsView()
                    SectionLabel(text: "散热风扇")
                    FanSectionView()
                    SectionLabel(text: "外观")
                    AppearanceSectionView()
                    SectionLabel(text: "关于")
                    AboutSectionView()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitle("设置", displayMode: .large)
    }
}

// MARK: - 服务器连接
struct ServerSectionView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var serverText = ""
    @State private var tokenText = ""
    @State private var testing = false
    @State private var testResult: (Bool, String)?

    var body: some View {
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
                    Button("保存") { save() }
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
                // 局域网权限引导（iOS 14 首次访问局域网需要授权）
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.warn)
                    Text("连接失败时，请先在「设置 → 隐私 → 本地网络」中允许本 App 访问局域网")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .onAppear {
            serverText = settings.serverURL
            tokenText = settings.token
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

// MARK: - 常用设置（WiFi / 5G 数据 / 网络模式）
struct QuickSettingsView: View {
    @State private var wifiOn = true
    @State private var dataOn = true
    @State private var netModeIdx = 0
    @State private var switchBusy = false
    @State private var switchMsg: String?

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle(icon: "switch.2", title: "常用设置")
                if let switchMsg = switchMsg {
                    Text(switchMsg)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                toggleRow(icon: "network", title: "宽带", isOn: $wifiOn) { on in
                    netSwitch("net_wifi", on ? "on" : "off")
                }
                Divider().background(AppTheme.cardBorder)
                toggleRow(icon: "antenna.radiowaves.left.and.right", title: "5G 数据", isOn: $dataOn) { on in
                    netSwitch("net_data", on ? "on" : "off")
                }
                Divider().background(AppTheme.cardBorder)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.primary)
                        Text("网络模式")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Picker("网络模式", selection: $netModeIdx) {
                        Text("自动").tag(0)
                        Text("锁 WAN").tag(1)
                        Text("锁 5G").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: netModeIdx) { v in
                        let arg = v == 0 ? "auto" : (v == 1 ? "lock-wan" : "lock-5g")
                        netSwitch("net_mode", arg)
                    }
                }
            }
        }
        .onAppear {
            loadSwitchState()
        }
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>, onChange: @escaping (Bool) -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.primary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .onChange(of: isOn.wrappedValue) { v in onChange(v) }
        }
    }

    private func loadSwitchState() {
        APIClient.shared.status { r in
            DispatchQueue.main.async {
                if case .success(let s) = r {
                    // 常用设置: 宽带 / 5G 数据开关（net_conf 语义：wifi=宽带出口, data=5G数据）
                    wifiOn = s.netConf?["wifi"] != "off"
                    dataOn = s.netConf?["data"] != "off"
                    netModeIdx = s.netMode == "lock-wan" ? 1 : (s.netMode == "lock-5g" ? 2 : 0)
                }
            }
        }
    }

    private func netSwitch(_ action: String, _ arg: String) {
        switchBusy = true
        switchMsg = nil
        APIClient.shared.action(action, arg: arg) { r in
            DispatchQueue.main.async {
                switchBusy = false
                switch r {
                case .success(let result):
                    switchMsg = result.hasPrefix("ERR") ? result : "已执行"
                case .failure(let e):
                    switchMsg = e.localizedDescription
                }
            }
        }
    }
}

// MARK: - 散热风扇（档位控制）
struct FanSectionView: View {
    @State private var fanInfo: [String: Any]?
    @State private var fanBusy = false
    @State private var fanMsg: String?

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(icon: "fanblades", title: "散热风扇", iconColor: AppTheme.cyan)
                if let f = fanInfo {
                    FanStatsRow(fanInfo: f)
                    FanLevelPicker(fanInfo: f, busy: fanBusy) { lv in
                        fanTapLevel(lv)
                    }
                    if let msg = fanMsg {
                        Text(msg).font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
                    }
                    FanModeButton(fanInfo: f, busy: fanBusy) {
                        fanMode("auto")
                    }
                } else {
                    Text("风扇状态获取中…")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .onAppear { loadFan() }
    }

    private func loadFan() {
        APIClient.shared.action("fan_status") { r in
            DispatchQueue.main.async {
                if case .success(let s) = r,
                   let d = s.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    fanInfo = obj
                }
            }
        }
    }

    private func fanMode(_ mode: String) {
        fanBusy = true
        fanMsg = nil
        APIClient.shared.action("fan_mode", arg: mode) { r in
            DispatchQueue.main.async {
                fanBusy = false
                switch r {
                case .success(let result):
                    fanMsg = result.hasPrefix("ERR") ? result : "已切换"
                    loadFan()
                case .failure(let e): fanMsg = e.localizedDescription
                }
            }
        }
    }

    private func fanTapLevel(_ lv: Int) {
        if fanInfo?["mode"] as? String != "manual" {
            fanBusy = true
            fanMsg = nil
            APIClient.shared.action("fan_mode", arg: "manual") { r in
                DispatchQueue.main.async {
                    if case .success = r {
                        fanSet(lv)
                    } else if case .failure(let e) = r {
                        fanBusy = false
                        fanMsg = e.localizedDescription
                    }
                }
            }
        } else {
            fanSet(lv)
        }
    }

    private func fanSet(_ lv: Int) {
        fanBusy = true
        fanMsg = nil
        APIClient.shared.action("fan_set", arg: "\(lv)") { r in
            DispatchQueue.main.async {
                fanBusy = false
                switch r {
                case .success(let result):
                    fanMsg = result.hasPrefix("ERR") ? result : "已设为 \(lv) 档"
                    loadFan()
                case .failure(let e): fanMsg = e.localizedDescription
                }
            }
        }
    }
}

// 温度与模式统计行
struct FanStatsRow: View {
    let fanInfo: [String: Any]

    var body: some View {
        HStack(spacing: 12) {
            statCell("CPU", "\(fanInfo["cpu"] ?? "--")°C", AppTheme.warn)
            statCell("GPU", "\(fanInfo["gpu"] ?? "--")°C", AppTheme.danger)
            statCell("模式", isAuto ? "自动" : "手动", isAuto ? AppTheme.good : AppTheme.cyan)
            statCell("当前档位", levelText, levelColor)
        }
    }

    private var isAuto: Bool {
        (fanInfo["mode"] as? String) == "auto"
    }

    private var levelText: String {
        let st = fanInfo["state"] as? Int ?? -1
        if st == 0 { return "关闭" }
        if st > 0 { return "\(st) 档" }
        return "--"
    }

    private var levelColor: Color {
        let st = fanInfo["state"] as? Int ?? -1
        if st == 0 { return AppTheme.textSecondary }
        return AppTheme.cyan
    }

    private func statCell(_ k: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 3) {
            Text(k).font(.system(size: 10)).foregroundColor(AppTheme.textSecondary)
            Text(v).font(.system(size: 15, weight: .bold)).foregroundColor(c)
        }
        .frame(maxWidth: .infinity)
    }
}

// 档位按钮行
struct FanLevelPicker: View {
    let fanInfo: [String: Any]
    let busy: Bool
    var onSet: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("档位")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text(isAuto ? "自动温控中 · 点击档位切换手动" : "手动模式 · PWM \(pwm)")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.7))
            }
            HStack(spacing: 8) {
                ForEach(0...6, id: \.self) { lv in
                    Button(action: { onSet(lv) }) {
                        Text(lv == 0 ? "关" : "\(lv)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isCurrent(lv) ? .white : AppTheme.textSecondary)
                            .frame(width: 36, height: 32)
                            .background(
                                Group {
                                    if isCurrent(lv) {
                                        RoundedRectangle(cornerRadius: 8).fill(AppTheme.gradient)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06))
                                    }
                                }
                            )
                    }
                    .disabled(busy)
                }
            }
        }
    }

    private var isAuto: Bool {
        (fanInfo["mode"] as? String) == "auto"
    }

    private var pwm: Int {
        (fanInfo["pwm"] as? Int) ?? 0
    }

    private func isCurrent(_ lv: Int) -> Bool {
        (fanInfo["state"] as? Int) == lv
    }
}

// 恢复自动温控按钮
struct FanModeButton: View {
    let fanInfo: [String: Any]
    let busy: Bool
    var onAuto: () -> Void

    var body: some View {
        Button(action: onAuto) {
            Text("恢复自动温控")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isAuto ? .white : AppTheme.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    Group {
                        if isAuto {
                            Capsule().fill(AppTheme.gradient)
                        } else {
                            Capsule().fill(Color.white.opacity(0.06))
                        }
                    }
                )
        }
        .disabled(busy)
    }

    private var isAuto: Bool {
        (fanInfo["mode"] as? String) == "auto"
    }
}

// MARK: - 外观
struct AppearanceSectionView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(icon: "paintpalette", title: "外观")
                Picker("主题", selection: $settings.themeMode) {
                    Text("深色").tag(0)
                    Text("浅色").tag(1)
                    Text("跟随系统").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
}

// MARK: - 关于
struct AboutSectionView: View {
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle(icon: "info.circle", title: "关于")
                infoRow("版本", "1.3.0")
                infoRow("设备", "HINLINK OPC-H69K")
                infoRow("接口", "本地 JSON API 网关 :8788")
                infoRow("网关", "v2.3 · 5G / 短信 / WiFi / Clash / AdGuard / 设备")
            }
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(v).font(.system(size: 12, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
        }
    }
}
