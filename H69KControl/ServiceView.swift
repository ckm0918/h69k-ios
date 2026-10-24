import SwiftUI

// MARK: - 服务页（OpenClash + AdGuard）
struct ServiceView: View {
    @State private var clash: ClashStatus?
    @State private var adguard: AdGuardStatus?
    @State private var traffic: ClashTraffic?
    @State private var stats: AdGuardStats?
    @State private var delay: ClashDelay?
    @State private var loading = false
    @State private var acting = false
    @State private var delayBusy = false
    @State private var errorMsg: String?
    @State private var timer: Timer?
    @State private var trafficTimer: Timer?
    @State private var downHistory: [Double] = []
    @State private var upHistory: [Double] = []

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

                    // OpenClash 卡片
                    CardView {
                        VStack(spacing: 14) {
                            HStack {
                                CardTitle(icon: "bolt.horizontal.circle", title: "OpenClash 代理")
                                Spacer()
                                HStack(spacing: 5) {
                                    StatusDot(color: clash?.running == true ? AppTheme.good : AppTheme.danger)
                                    Text(clash?.running == true ? "运行中" : "已停止")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(clash?.running == true ? AppTheme.good : AppTheme.danger)
                                }
                            }
                            HStack(spacing: 12) {
                                VStack(spacing: 4) {
                                    Text("\(clash?.nodeCount ?? 0)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("节点 / 策略组")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                VStack(spacing: 4) {
                                    Text("\(clash?.httpPort ?? 7890)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(AppTheme.primary)
                                    Text("HTTP 代理端口")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                VStack(spacing: 4) {
                                    Text("\(clash?.dnsPort ?? 7874)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(AppTheme.info)
                                    Text("DNS 端口")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 6)
                            HStack(spacing: 8) {
                                Button(action: { toggleClash() }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: clash?.running == true ? "stop.fill" : "play.fill")
                                        Text(clash?.running == true ? "停止代理" : "启动代理")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(clash?.running == true ? AppTheme.danger : AppTheme.good)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .fill((clash?.running == true ? AppTheme.danger : AppTheme.good).opacity(0.12)))
                                }
                                .disabled(acting)
                                Button(action: { restartClash() }) {
                                    Label("重启", systemImage: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.primary)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.primary.opacity(0.12)))
                                }
                                .disabled(acting)
                            }
                            if let nodes = clash?.nodes, !nodes.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("节点列表")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                    ForEach(nodes.prefix(12), id: \.self) { n in
                                        HStack(spacing: 8) {
                                            Image(systemName: "circle.fill")
                                                .font(.system(size: 5))
                                                .foregroundColor(AppTheme.primary.opacity(0.6))
                                            Text(n)
                                                .font(.system(size: 12))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            if let d = delay, let res = d.results?.first(where: { $0.name == n }) {
                                                Text(res.delay == nil ? "超时" : "\(res.delay!)ms")
                                                    .font(AppTheme.mono(10))
                                                    .foregroundColor(res.delay == nil ? AppTheme.danger : delayColor(res.delay!))
                                            }
                                        }
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                            }
                            // 实时流量
                            if let t = traffic, t.running == true {
                                ClashTrafficRow(download: t.download ?? 0, upload: t.upload ?? 0,
                                                downHistory: downHistory, upHistory: upHistory)
                            }
                            // 节点测速
                            HStack(spacing: 8) {
                                Button(action: runDelayTest) {
                                    HStack(spacing: 6) {
                                        if delayBusy { ProgressView().scaleEffect(0.7) }
                                        Image(systemName: "speedometer")
                                        Text(delayBusy ? "测速中…" : "节点延迟测速")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.cyan)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.cyan.opacity(0.12)))
                                }
                                .disabled(delayBusy || acting)
                            }
                            if let d = delay, d.running == false, let e = d.error {
                                Text(e).font(.system(size: 11)).foregroundColor(AppTheme.warn)
                            }
                        }
                    }

                    // AdGuard 卡片
                    CardView {
                        VStack(spacing: 14) {
                            HStack {
                                CardTitle(icon: "shield.lefthalf.filled", title: "AdGuard Home 广告过滤",
                                          iconColor: AppTheme.good)
                                Spacer()
                                HStack(spacing: 5) {
                                    StatusDot(color: adguard?.running == true ? AppTheme.good : AppTheme.danger)
                                    Text(adguard?.running == true ? "运行中" : "已停止")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(adguard?.running == true ? AppTheme.good : AppTheme.danger)
                                }
                            }
                            HStack(spacing: 12) {
                                VStack(spacing: 4) {
                                    Text("\(adguard?.webPort ?? 3001)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(AppTheme.good)
                                    Text("Web 管理端口")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                VStack(spacing: 4) {
                                    Text("\(adguard?.dnsPort ?? 5553)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(AppTheme.info)
                                    Text("DNS 端口")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                VStack(spacing: 4) {
                                    Text("\(adguard?.upstreams?.count ?? 0)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(AppTheme.warn)
                                    Text("上游 DNS")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 6)
                            Button(action: { toggleAdguard() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: adguard?.running == true ? "stop.fill" : "play.fill")
                                    Text(adguard?.running == true ? "停止过滤" : "启动过滤")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(adguard?.running == true ? AppTheme.danger : AppTheme.good)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill((adguard?.running == true ? AppTheme.danger : AppTheme.good).opacity(0.12)))
                            }
                            .disabled(acting)
                            if let st = stats, st.running == true {
                                Divider().background(AppTheme.cardBorder)
                                AdGuardStatsRow(stats: st)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
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
        .navigationBarTitle("服务", displayMode: .large)
        .onAppear { load(); startTimer() }
        .onDisappear { timer?.invalidate(); trafficTimer?.invalidate() }
    }

    private func load() {
        loading = true
        errorMsg = nil
        APIClient.shared.clashStatus { r in
            DispatchQueue.main.async {
                loading = false
                switch r {
                case .success(let s): clash = s
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
        APIClient.shared.adguardStatus { r in
            DispatchQueue.main.async {
                switch r {
                case .success(let s): adguard = s
                case .failure(let e): if errorMsg == nil { errorMsg = e.localizedDescription }
                }
            }
        }
        loadTraffic()
        loadStats()
    }

    private func loadTraffic() {
        APIClient.shared.clashTraffic { r in
            DispatchQueue.main.async {
                switch r {
                case .success(let t):
                    traffic = t
                    if t.running == true {
                        let d = Double(t.download ?? 0)
                        let u = Double(t.upload ?? 0)
                        downHistory.append(d)
                        upHistory.append(u)
                        if downHistory.count > 40 { downHistory.removeFirst(downHistory.count - 40) }
                        if upHistory.count > 40 { upHistory.removeFirst(upHistory.count - 40) }
                    } else {
                        downHistory = []
                        upHistory = []
                    }
                case .failure: break
                }
            }
        }
    }

    private func loadStats() {
        APIClient.shared.adguardStats { r in
            DispatchQueue.main.async {
                if case .success(let s) = r { stats = s }
            }
        }
    }

    private func runDelayTest() {
        delayBusy = true
        delay = nil
        APIClient.shared.clashDelay { r in
            DispatchQueue.main.async {
                delayBusy = false
                switch r {
                case .success(let d): delay = d
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }

    private func delayColor(_ ms: Int) -> Color {
        ms < 150 ? AppTheme.good : ms < 300 ? AppTheme.warn : AppTheme.danger
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in load() }
        trafficTimer?.invalidate()
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in loadTraffic() }
    }

    private func toggleClash() {
        acting = true
        APIClient.shared.clashAction(clash?.running == true ? "stop" : "start") { r in
            DispatchQueue.main.async {
                acting = false
                switch r {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { load() }
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }

    private func restartClash() {
        acting = true
        APIClient.shared.clashAction("restart") { r in
            DispatchQueue.main.async {
                acting = false
                switch r {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { load() }
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }

    private func toggleAdguard() {
        acting = true
        APIClient.shared.adguardAction(adguard?.running == true ? "stop" : "start") { r in
            DispatchQueue.main.async {
                acting = false
                switch r {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { load() }
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }
}

// MARK: - OpenClash 实时流量行
struct ClashTrafficRow: View {
    let download: Int64
    let upload: Int64
    let downHistory: [Double]
    let upHistory: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                metric(icon: "arrow.down.circle", title: "下载", value: download, color: AppTheme.good)
                metric(icon: "arrow.up.circle", title: "上传", value: upload, color: AppTheme.primary)
            }
            HStack(spacing: 12) {
                Sparkline(points: downHistory, lineColor: AppTheme.good)
                    .frame(height: 30)
                Sparkline(points: upHistory, lineColor: AppTheme.primary)
                    .frame(height: 30)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
    }

    private func metric(icon: String, title: String, value: Int64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(color)
                Text(title).font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
            }
            Text(Fmt.speed(value)).font(AppTheme.mono(15)).foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - AdGuard 统计行
struct AdGuardStatsRow: View {
    let stats: AdGuardStats

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 3) {
                Text("\(stats.queries ?? 0)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("最近查询")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 3) {
                Text("\(stats.blocked ?? 0)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.danger)
                Text("已拦截")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 3) {
                Text(String(format: "%.1f%%", stats.blockedPercent ?? 0))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.warn)
                Text("拦截率")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 2)
    }
}
