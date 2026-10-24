import SwiftUI

// MARK: - 路由器体检报告 (v1.4)
// 全能体检：健康评分 + 检测项 + 自动优化建议，参考华硕/小米路由体检页
struct HealthView: View {
    @State private var result: DiagnoseResult?
    @State private var error: String?
    @State private var loading = false
    @State private var expandItems = false

    var body: some View {
        ZStack {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 14) {
                    if loading && result == nil {
                        ProgressView("正在全面体检…")
                            .padding(.top, 120)
                            .foregroundColor(AppTheme.textSecondary)
                    } else if let err = error, result == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(AppTheme.danger)
                            Text(err).font(.system(size: 14)).foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("重试") { load() }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(Capsule().fill(AppTheme.gradient))
                        }
                        .padding(.top, 80)
                    } else if let r = result {
                        scoreHeader(r)
                        if let sugs = r.suggestions, !sugs.isEmpty {
                            SectionLabel(text: "优化建议")
                            ForEach(sugs) { s in
                                suggestionCard(s)
                            }
                        }
                        SectionLabel(text: "检测项目（\(r.items?.count ?? 0) 项）")
                        itemSummaryBar(r)
                        ForEach(r.items ?? []) { it in
                            itemCard(it)
                        }
                        Text("体检时间：\(Fmt.time(r.ts ?? 0))")
                            .font(AppTheme.mono(10))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("路由器体检", displayMode: .large)
        .navigationBarItems(trailing: Button(action: load) {
            Image(systemName: "arrow.clockwise")
        }.disabled(loading))
        .onAppear { if result == nil { load() } }
    }

    // MARK: 健康评分头部
    private func scoreHeader(_ r: DiagnoseResult) -> some View {
        let score = Double(r.score ?? 0)
        let color: Color = score >= 90 ? AppTheme.good : (score >= 70 ? AppTheme.warn : AppTheme.danger)
        return CardView {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(score / 100.0))
                        .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: score)
                    VStack(spacing: 2) {
                        Text("\(r.score ?? 0)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                        Text("健康分")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 8) {
                    Text(r.summary ?? "--")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        statChip("正常", count: okCount(r), color: AppTheme.good)
                        statChip("关注", count: warnCount(r), color: AppTheme.warn)
                        statChip("异常", count: errCount(r), color: AppTheme.danger)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    private func okCount(_ r: DiagnoseResult) -> Int { (r.items ?? []).filter { $0.status == "ok" }.count }
    private func warnCount(_ r: DiagnoseResult) -> Int { (r.items ?? []).filter { $0.status == "warn" }.count }
    private func errCount(_ r: DiagnoseResult) -> Int { (r.items ?? []).filter { $0.status == "error" }.count }

    private func statChip(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
    }

    // MARK: 检测项统计条
    private func itemSummaryBar(_ r: DiagnoseResult) -> some View {
        let items = r.items ?? []
        let ok = okCount(r), warn = warnCount(r), err = errCount(r)
        let total = max(items.count, 1)
        return VStack(spacing: 6) {
            GeometryReader { g in
                let w = g.size.width
                HStack(spacing: 0) {
                    AppTheme.good.frame(width: w * CGFloat(ok) / CGFloat(total))
                    AppTheme.warn.frame(width: w * CGFloat(warn) / CGFloat(total))
                    AppTheme.danger.frame(width: w * CGFloat(err) / CGFloat(total))
                }
            }
            .frame(height: 5)
            .clipShape(Capsule())
            HStack(spacing: 10) {
                Text("✓ 正常 \(ok)").font(.system(size: 10)).foregroundColor(AppTheme.good)
                Text("⚠ 关注 \(warn)").font(.system(size: 10)).foregroundColor(AppTheme.warn)
                Text("✗ 异常 \(err)").font(.system(size: 10)).foregroundColor(AppTheme.danger)
                Spacer()
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: 优化建议卡
    private func suggestionCard(_ s: DiagnoseSuggestion) -> some View {
        let isError = s.level == "error"
        let color = isError ? AppTheme.danger : AppTheme.warn
        return CardView {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isError ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(color)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(s.desc)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !s.action.isEmpty {
                        Text("👉 \(s.action)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: 检测项卡
    private func itemCard(_ it: DiagnoseItem) -> some View {
        let color: Color = it.status == "ok" ? AppTheme.good : (it.status == "warn" ? AppTheme.warn : AppTheme.danger)
        return CardView {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: it.status == "ok" ? "checkmark.circle.fill"
                        : (it.status == "warn" ? "exclamationmark.circle.fill" : "xmark.circle.fill"))
                    .font(.system(size: 15))
                    .foregroundColor(color)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(it.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(statusText(it.status))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(color)
                    }
                    Text(it.detail.isEmpty ? "--" : it.detail)
                        .font(AppTheme.mono(11))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !it.advice.isEmpty {
                        Text(it.advice)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.warn)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    private func statusText(_ s: String) -> String {
        s == "ok" ? "正常" : (s == "warn" ? "关注" : "异常")
    }

    private func load() {
        loading = true
        error = nil
        APIClient.shared.diagnose { r in
            DispatchQueue.main.async {
                loading = false
                switch r {
                case .success(let d): result = d
                case .failure(let e): error = e.localizedDescription
                }
            }
        }
    }
}

// MARK: - 时间格式化
extension Fmt {
    static func time(_ ts: Int) -> String {
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm:ss"
        return df.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}
