import SwiftUI

// MARK: - 短信页
struct SMSView: View {
    @State private var items: [SMSItem] = []
    @State private var loading = false
    @State private var errorMsg: String?
    @State private var showCompose = false
    @State private var timer: Timer?

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
                    ForEach(items) { item in
                        SMSRow(item: item) {
                            markRead(item)
                        } onDelete: {
                            deleteSMS(item)
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

    private func markRead(_ item: SMSItem) {
        guard !item.read else { return }
        APIClient.shared.smsRead(id: item.id, read: true) { _ in
            DispatchQueue.main.async { load() }
        }
    }

    private func deleteSMS(_ item: SMSItem) {
        APIClient.shared.smsDelete(id: item.id) { r in
            DispatchQueue.main.async {
                switch r {
                case .success: load()
                case .failure(let e): errorMsg = e.localizedDescription
                }
            }
        }
    }
}

// MARK: - 短信行
struct SMSRow: View {
    let item: SMSItem
    var onTap: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(item.read ? Color.clear : AppTheme.primary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 18)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.sender)
                            .font(.system(size: 14, weight: item.read ? .medium : .bold))
                            .foregroundColor(item.read ? AppTheme.textSecondary : AppTheme.textPrimary)
                        Spacer()
                        Text(item.time)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                    }
                    Text(item.text)
                        .font(.system(size: 12))
                        .foregroundColor(item.read ? AppTheme.textSecondary : AppTheme.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(item.read ? AppTheme.card : AppTheme.cardHigh)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(item.read ? AppTheme.cardBorder : AppTheme.primary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - 发送短信
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
