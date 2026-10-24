import SwiftUI

// MARK: - 短信页（会话列表，仿手机短信 App）
struct SMSView: View {
    @State private var items: [SMSItem] = []
    @State private var loading = false
    @State private var errorMsg: String?
    @State private var showCompose = false
    @State private var timer: Timer?
    @State private var chatTarget: ChatTarget?

    var body: some View {
        ZStack {
            AppTheme.bg.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 10) {
                    if let errorMsg = errorMsg {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                            Text(errorMsg).font(.system(size: 12))
                        }
                        .foregroundColor(AppTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }
                    SectionLabel(text: "收件箱")
                    if !items.isEmpty {
                        CardView(padding: 12) {
                            HStack {
                                StatusRow(icon: "envelope", title: "短信总数",
                                          value: "\(items.count) 条", iconColor: AppTheme.info)
                                Spacer()
                                let unread = items.filter { !$0.read }.count
                                if unread > 0 {
                                    Text("\(unread) 条未读")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.warn)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Capsule().fill(AppTheme.warn.opacity(0.14)))
                                }
                            }
                        }
                    }
                    if items.isEmpty && !loading {
                        VStack(spacing: 12) {
                            Image(systemName: "message")
                                .font(.system(size: 40))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                            Text("暂无短信")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                    ForEach(conversations) { conv in
                        Button(action: { chatTarget = ChatTarget(phone: conv.sender) }) {
                            ConversationRow(conv: conv)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(action: { deleteAll(conv.sender) }) {
                                Label("删除该会话", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            if loading {
                VStack {
                    ProgressView()
                    Text("加载中…").font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.cardHigh))
            }
        }
        .navigationBarTitle("短信", displayMode: .large)
        .navigationBarItems(trailing:
            Button(action: { showCompose = true }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
            }
        )
        .onAppear { load(); startTimer() }
        .onDisappear { timer?.invalidate() }
        .sheet(isPresented: $showCompose) { ComposeSMSView(onSent: { load() }) }
        .sheet(item: $chatTarget) { target in
            ChatDetailView(phone: target.phone, allItems: items, onChanged: { load() })
        }
    }

    // 会话打开目标（sheet item 需 Identifiable）
    struct ChatTarget: Identifiable {
        let id = UUID()
        let phone: String
    }

    // 按号码分组会话，取最新一条作摘要
    private var conversations: [Conversation] {
        var groups: [String: [SMSItem]] = [:]
        for it in items {
            let key = it.sender.isEmpty ? "未知号码" : it.sender
            groups[key, default: []].append(it)
        }
        return groups.map { key, list in
            let sorted = list.sorted { $0.time > $1.time }
            return Conversation(sender: key,
                                lastText: sorted.first?.text ?? "",
                                lastTime: sorted.first?.time ?? "",
                                unread: list.filter { !$0.read }.count,
                                count: list.count)
        }
        .sorted { $0.lastTime > $1.lastTime }
    }

    private func load() {
        loading = true
        errorMsg = nil
        APIClient.shared.smsList { r in
            DispatchQueue.main.async {
                loading = false
                switch r {
                case .success(let list):
                    items = list
                case .failure(let e):
                    errorMsg = e.localizedDescription
                }
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in load() }
    }

    private func deleteAll(_ sender: String) {
        let target = items.filter { $0.sender == sender }
        var rest = items
        for it in target {
            APIClient.shared.smsDelete(id: it.id) { r in
                DispatchQueue.main.async {
                    if case .success = r {
                        rest.removeAll { $0.id == it.id }
                        items = rest
                    }
                }
            }
        }
    }
}

// MARK: - 会话模型
struct Conversation: Identifiable {
    var id: String { sender }
    let sender: String
    let lastText: String
    let lastTime: String
    let unread: Int
    let count: Int
}

// MARK: - 会话行
struct ConversationRow: View {
    let conv: Conversation

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.gradientSoft)
                    .frame(width: 44, height: 44)
                Text(shortName(conv.sender))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conv.sender)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(conv.lastTime)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                }
                HStack {
                    Text(conv.lastText)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if conv.unread > 0 {
                        Text("\(conv.unread)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Circle().fill(AppTheme.primary))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(conv.unread > 0 ? AppTheme.primary.opacity(0.35) : AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func shortName(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        if trimmed.count >= 4 {
            let idx = trimmed.index(trimmed.startIndex, offsetBy: trimmed.count - 4)
            return String(trimmed[idx...])
        }
        return trimmed
    }
}

// MARK: - 对话详情（仿 iPhone 短信界面）
struct ChatDetailView: View {
    let phone: String
    let allItems: [SMSItem]
    var onChanged: () -> Void

    @Environment(\.presentationMode) var presentationMode
    @State private var outbox: [OutMsg] = []
    @State private var input = ""
    @State private var sending = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var deleting = false

    struct OutMsg: Identifiable {
        let id = UUID()
        let text: String
        let time: String
    }

    private var thread: [SMSItem] {
        allItems.filter { $0.sender == phone }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.bg.edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    // 消息气泡列表
                    ScrollView {
                        VStack(spacing: 6) {
                            Text("与 \(phone) 的短信")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                                .padding(.top, 10)
                            ForEach(thread) { it in
                                BubbleRow(text: it.text, time: it.time, isOut: false)
                            }
                            ForEach(outbox) { m in
                                BubbleRow(text: m.text, time: m.time, isOut: true)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                    // 底部输入条
                    HStack(spacing: 10) {
                        TextField("短信内容", text: $input)
                            .font(.system(size: 14))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                        Button(action: send) {
                            HStack(spacing: 5) {
                                if sending { ProgressView().scaleEffect(0.7) }
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 40, height: 36)
                            .background(sendButtonBackground)
                        }
                        .disabled(sending || input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardHigh)
                }
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 30 : 0)
            }
            .navigationBarTitle(phone, displayMode: .inline)
            .navigationBarItems(leading:
                Button("完成") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(AppTheme.primary),
                trailing:
                Button(action: deleteThread) {
                    if deleting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                            .foregroundColor(AppTheme.danger)
                    }
                }
            )
        }
        .preferredColorScheme(.dark)
        .onAppear {
            registerKeyboard()
            markThreadRead()
            scrollToBottom()
        }
    }

    // 发送按钮背景（禁用时灰色、可用时渐变；iOS14 无 AnyShapeStyle 需分支构建）
    @ViewBuilder private var sendButtonBackground: some View {
        if input.isEmpty {
            Capsule().fill(AppTheme.textSecondary.opacity(0.3))
        } else {
            Capsule().fill(AppTheme.gradient)
        }
    }

    private func scrollToBottom() {
        // 进页直接显示最新内容（顶部预览），iOS14 无需自动滚动
    }

    private func markThreadRead() {
        for it in thread where !it.read {
            APIClient.shared.smsRead(id: it.id, read: true) { _ in }
        }
        onChanged()
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        APIClient.shared.smsSend(phone: phone, content: text) { r in
            DispatchQueue.main.async {
                sending = false
                switch r {
                case .success:
                    let now = Self.nowString()
                    outbox.append(OutMsg(text: text, time: now))
                    input = ""
                case .failure:
                    break
                }
            }
        }
    }

    private func deleteThread() {
        deleting = true
        let target = thread
        var done = 0
        for it in target {
            APIClient.shared.smsDelete(id: it.id) { _ in
                done += 1
                if done == target.count {
                    DispatchQueue.main.async {
                        deleting = false
                        onChanged()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private static func nowString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    private func registerKeyboard() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                               object: nil, queue: .main) { n in
            if let v = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = v.height
            }
        }
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                               object: nil, queue: .main) { _ in
            keyboardHeight = 0
        }
    }
}

// MARK: - 聊天气泡
struct BubbleRow: View {
    let text: String
    let time: String
    let isOut: Bool

    var body: some View {
        HStack {
            if isOut { Spacer(minLength: 48) }
            VStack(alignment: isOut ? .trailing : .leading, spacing: 3) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(isOut ? .white : AppTheme.textPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        Group {
                            if isOut {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.gradient)
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.cardHigh)
                            }
                        }
                    )
                Text(time)
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.6))
            }
            if !isOut { Spacer(minLength: 48) }
        }
    }
}

// MARK: - 发送短信（新建会话）
struct ComposeSMSView: View {
    var onSent: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var phone = ""
    @State private var content = ""
    @State private var sending = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.bg.edgesIgnoringSafeArea(.all)
                VStack(spacing: 14) {
                    TextField("收件人号码", text: $phone)
                        .font(AppTheme.mono(15))
                        .keyboardType(.phonePad)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    TextEditor(text: $content)
                        .font(.system(size: 14))
                        .padding(8)
                        .frame(height: 140)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                    if let errorMsg = errorMsg {
                        Text(errorMsg)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(action: send) {
                        HStack(spacing: 8) {
                            if sending { ProgressView().scaleEffect(0.7) }
                            Text("发送")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(AppTheme.gradient))
                    }
                    .disabled(sending || phone.isEmpty || content.isEmpty)
                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitle("发送短信", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("取消") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(AppTheme.textSecondary)
            )
        }
        .preferredColorScheme(.dark)
    }

    private func send() {
        sending = true
        errorMsg = nil
        APIClient.shared.smsSend(phone: phone, content: content) { r in
            DispatchQueue.main.async {
                sending = false
                switch r {
                case .success:
                    onSent()
                    presentationMode.wrappedValue.dismiss()
                case .failure(let e):
                    errorMsg = e.localizedDescription
                }
            }
        }
    }
}
