import SwiftUI

// MARK: - Aria2 下载管理页
struct Aria2View: View {
    @State private var tasks: [Aria2Task] = []
    @State private var global: Aria2GlobalStat?
    @State private var error: String?
    @State private var showAdd = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 14) {
                    if let g = global { globalBar(g) }
                    if let e = error, tasks.isEmpty {
                        ErrorCard(message: e)
                    }
                    if tasks.isEmpty && error == nil {
                        VStack(spacing: 10) {
                            Image(systemName: "tray").font(.system(size: 36)).foregroundColor(AppTheme.textSecondary)
                            Text("暂无下载任务").foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 80)
                    }
                    ForEach(tasks) { task in
                        Aria2TaskCard(task: task, onChanged: refresh)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitle("下载", displayMode: .large)
        .navigationBarItems(trailing: HStack(spacing: 12) {
            if let g = global {
                Text(Fmt.speed(Int64(g.downloadSpeed) ?? 0))
                    .font(AppTheme.mono(11)).foregroundColor(AppTheme.good)
            }
            Button(action: { showAdd = true }) {
                Image(systemName: "plus")
            }
        })
        .sheet(isPresented: $showAdd) { AddTaskView(onAdded: refresh) }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            refresh()
        }
    }

    func refresh() {
        var active: [Aria2Task] = []
        var stopped: [Aria2Task] = []
        let group = DispatchGroup()

        group.enter()
        APIClient.shared.aria2(method: "aria2.tellActive") { r in
            defer { group.leave() }
            if case .success(let o) = r,
               let result = o["result"] as? [[String: Any]],
               let data = try? JSONSerialization.data(withJSONObject: result) {
                active = (try? JSONDecoder().decode([Aria2Task].self, from: data)) ?? []
            }
        }
        group.enter()
        APIClient.shared.aria2(method: "aria2.tellStopped", params: [0, 50]) { r in
            defer { group.leave() }
            if case .success(let o) = r,
               let result = o["result"] as? [[String: Any]],
               let data = try? JSONSerialization.data(withJSONObject: result) {
                stopped = (try? JSONDecoder().decode([Aria2Task].self, from: data)) ?? []
            }
        }
        group.notify(queue: .main) {
            error = nil
            tasks = active + stopped.filter { t in
                !active.contains { $0.gid == t.gid }
            }
            fetchGlobal()
        }
    }

    private func fetchGlobal() {
        APIClient.shared.aria2(method: "aria2.getGlobalStat") { r in
            DispatchQueue.main.async {
                if case .success(let o) = r,
                   let result = o["result"] as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: result) {
                    global = try? JSONDecoder().decode(Aria2GlobalStat.self, from: data)
                }
            }
        }
    }

    private func globalBar(_ g: Aria2GlobalStat) -> some View {
        CardView {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("全局下载")
                        .font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
                    Text(Fmt.speed(Int64(g.downloadSpeed) ?? 0))
                        .font(AppTheme.mono(24)).foregroundColor(AppTheme.good)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 6) {
                        StatusDot(color: AppTheme.good)
                        Text("\(g.numActive) 活动").font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Text("\(g.numStopped) 已完成 · 上传 \(Fmt.speed(Int64(g.uploadSpeed) ?? 0))")
                        .font(.system(size: 11)).foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - 单个任务卡片
struct Aria2TaskCard: View {
    let task: Aria2Task
    var onChanged: () -> Void
    @State private var removing = false

    var body: some View {
        CardView(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        GaugeRing(value: task.progress, size: 46, lineWidth: 5,
                                  color: stateColor(),
                                  centerText: String(format: "%.0f%%", task.progress * 100),
                                  subText: nil)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                        let (stateTxt, _) = task.stateColor
                        HStack(spacing: 5) {
                            StatusDot(color: stateColor())
                            Text(stateTxt).font(.system(size: 11))
                                .foregroundColor(AppTheme.textSecondary)
                            if task.speedBytes > 0 {
                                Text(Fmt.speed(task.speedBytes)).font(AppTheme.mono(11))
                                    .foregroundColor(stateColor())
                            }
                        }
                    }
                    Spacer()
                    if task.status == "active" || task.status == "waiting" {
                        Button(action: pause) {
                            Image(systemName: "pause.fill").font(.system(size: 15))
                                .foregroundColor(AppTheme.warn)
                        }
                    } else if task.status == "paused" {
                        Button(action: resume) {
                            Image(systemName: "play.fill").font(.system(size: 15))
                                .foregroundColor(AppTheme.good)
                        }
                    }
                    if removing {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button(action: remove) {
                            Image(systemName: "trash").font(.system(size: 15))
                                .foregroundColor(AppTheme.danger)
                        }
                    }
                }
                MetricBar(value: task.progress, color: stateColor(), height: 6)
                HStack {
                    Text("\(Fmt.bytes(task.doneBytes)) / \(Fmt.bytes(task.totalBytes))")
                        .font(AppTheme.mono(10)).foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    if let n = Int(task.numSeeders) {
                        Text("↓\(task.connections) 连接 · ↑\(n) 种子")
                            .font(.system(size: 10)).foregroundColor(AppTheme.textSecondary)
                    }
                }
                if task.status == "error", let em = task.errorMessage {
                    Text("错误: \(em)").font(.system(size: 11))
                        .foregroundColor(AppTheme.danger)
                }
            }
        }
    }

    private func stateColor() -> Color {
        switch task.status {
        case "active": return task.totalBytes > 0 ? AppTheme.good : AppTheme.warn
        case "paused": return AppTheme.textSecondary
        case "complete": return AppTheme.good
        case "error": return AppTheme.danger
        default: return AppTheme.textSecondary
        }
    }

    private func pause() {
        APIClient.shared.aria2(method: "aria2.pause", params: [task.gid]) { _ in
            DispatchQueue.main.async { onChanged() }
        }
    }
    private func resume() {
        APIClient.shared.aria2(method: "aria2.unpause", params: [task.gid]) { _ in
            DispatchQueue.main.async { onChanged() }
        }
    }
    private func remove() {
        removing = true
        APIClient.shared.aria2(method: "aria2.remove", params: [task.gid]) { r in
            DispatchQueue.main.async {
                removing = false
                if case .failure = r {
                    APIClient.shared.aria2(method: "aria2.forceRemove", params: [task.gid]) { _ in
                        DispatchQueue.main.async { onChanged() }
                    }
                } else {
                    onChanged()
                }
            }
        }
    }
}

// MARK: - 添加任务
struct AddTaskView: View {
    @Environment(\.presentationMode) var presentation
    var onAdded: () -> Void
    @State private var uri = ""
    @State private var adding = false
    @State private var msg: String?

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.bg.edgesIgnoringSafeArea(.all)
                VStack(spacing: 16) {
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            CardTitle(icon: "link", title: "链接 / 磁力")
                            TextField("http://... 或 magnet:?xt=...", text: $uri)
                                .font(AppTheme.mono(13))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                                .disableAutocorrection(true)
                        }
                    }
                    if let m = msg {
                        Text(m).font(.system(size: 12)).foregroundColor(AppTheme.warn)
                    }
                    Button(action: add) {
                        HStack(spacing: 8) {
                            if adding { ProgressView().scaleEffect(0.8) }
                            Text(adding ? "添加中…" : "添加到下载")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(AppTheme.gradient))
                    }
                    .disabled(adding || uri.trimmingCharacters(in: .whitespaces).isEmpty)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationBarTitle("添加下载", displayMode: .inline)
            .navigationBarItems(trailing: Button("取消") { presentation.wrappedValue.dismiss() })
        }
    }

    private func add() {
        adding = true
        msg = nil
        APIClient.shared.aria2(method: "aria2.addUri",
                               params: [[uri.trimmingCharacters(in: .whitespacesAndNewlines)]]) { r in
            DispatchQueue.main.async {
                adding = false
                switch r {
                case .success:
                    onAdded()
                    presentation.wrappedValue.dismiss()
                case .failure(let e):
                    msg = "添加失败：\(e.localizedDescription)"
                }
            }
        }
    }
}
