import SwiftUI

// MARK: - 总览页（高端仪表风格）
struct DashboardView: View {
    @State private var status: SystemStatus?
    @State private var error: String?
    @State private var loading = false
    @State private var rxHistory: [Double] = []
    @State private var txHistory: [Double] = []
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 14) {
                    if loading && status == nil {
                        ProgressView("连接 H69K…")
                            .padding(.top, 60)
                    } else if let err = error, status == nil {
                        ErrorCard(message: err)
                    } else if let s = status {
                        headerCard(s)
                        gaugesRow(s)
                        networkCard(s)
                        modeCard(s)
                        if !(s.modemStatus ?? "").isEmpty { modemCard(s) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitle("总览", displayMode: .large)
        .navigationBarItems(trailing: HStack(spacing: 12) {
            if let s = status {
                HStack(spacing: 5) {
                    StatusDot(color: AppTheme.good)
                    Text(Fmt.uptime(s.uptimeS ?? 0)).foregroundColor(AppTheme.textSecondary)
                }
            }
            Button(action: refresh) { Image(systemName: "arrow.clockwise") }
                .disabled(loading)
        })
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
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
    }

    private func startTimer() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            refresh()
        }
    }

    private func pushTraffic(_ s: SystemStatus) {
        let rx = Double(s.net?["eth0"]?.rxB ?? s.net?["br-lan"]?.rxB ?? 0)
        let tx = Double(s.net?["eth0"]?.txB ?? s.net?["br-lan"]?.txB ?? 0)
        if let last = rxHistory.last {
            rxHistory.append(max(rx - last, 0))
        } else {
            rxHistory.append(0)
        }
        if let last = txHistory.last {
            txHistory.append(max(tx - last, 0))
        } else {
            txHistory.append(0)
        }
        if rxHistory.count > 30 { rxHistory.removeFirst(rxHistory.count - 30) }
        if txHistory.count > 30 { txHistory.removeFirst(txHistory.count - 30) }
        // 保存原始值供下一次差值计算（用内部存储）
        lastRx = rx; lastTx = tx
    }

    @State private var lastRx: Double = 0
    @State private var lastTx: Double = 0

    // MARK: 顶栏
    private func headerCard(_ s: SystemStatus) -> some View {
        CardView {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.gradient)
                        .frame(width: 52, height: 52)
                    Image(systemName: "router.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("HINLINK OPC-H69K")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    HStack(spacing: 8) {
                        Text(s.wanIp ?? "--").font(AppTheme.mono(11)).foregroundColor(AppTheme.textSecondary)
                        StatusDot(color: AppTheme.good)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(s.netMode == "lock-5g" ? "仅 5G" : s.netMode == "lock-wan" ? "仅宽带" : "宽带优先")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.gradientSoft))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("5G \(s.wwanIp ?? "--")")
                        .font(AppTheme.mono(10)).foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: 仪表行
    private func gaugesRow(_ s: SystemStatus) -> some View {
        HStack(spacing: 14) {
            // CPU
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
            // 内存
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
        .frame(height: 210)
    }

    private func cpuColor(_ v: Double) -> Color {
        v < 50 ? AppTheme.good : v < 80 ? AppTheme.warn : AppTheme.danger
    }

    // MARK: 网络流量
    private func networkCard(_ s: SystemStatus) -> some View {
        CardView {
            VStack(spacing: 12) {
                CardTitle(icon: "network", title: "网络流量", iconColor: AppTheme.cyan)
                HStack {
                    metricItem(icon: "arrow.down", title: "下行",
                               value: rxHistory.last ?? 0,
                               color: AppTheme.good)
                    Divider().frame(height: 40)
                    metricItem(icon: "arrow.up", title: "上行",
                               value: txHistory.last ?? 0,
                               color: AppTheme.primary)
                }
                .padding(.vertical, 2)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("下行速率").font(.system(size: 10)).foregroundColor(AppTheme.textSecondary)
                        Sparkline(points: rxHistory, lineColor: AppTheme.good)
                            .frame(height: 38)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("上行速率").font(.system(size: 10)).foregroundColor(AppTheme.textSecondary)
                        Sparkline(points: txHistory, lineColor: AppTheme.primary)
                            .frame(height: 38)
                    }
                }
                .frame(height: 54)
            }
        }
    }

    private func metricItem(icon: String, title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(color)
                Text(title).font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
            }
            Text(Fmt.speed(Int64(value)))
                .font(AppTheme.mono(16)).foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 网络模式
    private func modeCard(_ s: SystemStatus) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(icon: "arrow.triangle.2.circlepath", title: "网络模式")
                HStack(spacing: 8) {
                    modePill(name: "宽带", on: s.netConf?["wifi"] == "on", color: AppTheme.good, icon: "wifi")
                    modePill(name: "5G 数据", on: s.netConf?["data"] == "on", color: AppTheme.cyan, icon: "antenna.radiowaves.left.and.right")
                }
                Text(s.netMode == "auto" ? "宽带优先，5G 备用"
                     : s.netMode == "lock-wan" ? "已锁定宽带"
                     : s.netMode == "lock-5g" ? "已锁定 5G"
                     : s.netMode == "none" ? "全部关闭（断网）"
                     : s.netMode ?? "--")
                    .font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private func modePill(name: String, on: Bool, color: Color, icon: String) -> some View {
        HStack(spacing: 5) {
            StatusDot(color: on ? color : AppTheme.textSecondary)
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(on ? color : AppTheme.textSecondary)
            Text(name).font(.system(size: 12, weight: .semibold))
                .foregroundColor(on ? AppTheme.textPrimary : AppTheme.textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(on ? color.opacity(0.14) : Color.white.opacity(0.05)))
    }

    // MARK: 5G 信息
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
    var body: some View {
        CardView {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22)).foregroundColor(AppTheme.warn)
                VStack(alignment: .leading, spacing: 6) {
                    Text("无法连接 H69K").font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(message).font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
                    Button("打开设置") { }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
                }
                Spacer()
            }
        }
    }
}
