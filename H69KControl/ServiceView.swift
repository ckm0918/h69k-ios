import SwiftUI

// MARK: - 服务页（OpenClash + AdGuard）
struct ServiceView: View {
    @State private var clash: ClashStatus?
    @State private var adguard: AdGuardStatus?
    @State private var loading = false
    @State private var acting = false
    @State private var errorMsg: String?
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
                                        }
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
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
        .onDisappear { timer?.invalidate() }
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
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in load() }
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
