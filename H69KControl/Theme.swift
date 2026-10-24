import SwiftUI

// MARK: - H69K 控制台 设计系统
// 深色专业运维风格，主色呼应 LuCI argon 主题 #5A6CC5

enum AppTheme {
    // 主色
    static let primary     = Color(red: 0.353, green: 0.424, blue: 0.773) // #5A6CC5
    static let accent      = Color(red: 0.557, green: 0.329, blue: 0.914) // #8E54E9
    static let cyan        = Color(red: 0.29,  green: 0.76,  blue: 0.85)

    // 背景与卡片
    static let bg          = Color(red: 0.047, green: 0.055, blue: 0.086) // 深空蓝黑
    static let bgSoft      = Color(red: 0.075, green: 0.086, blue: 0.125)
    static let card        = Color(red: 0.105, green: 0.118, blue: 0.155)
    static let cardHigh    = Color(red: 0.14,  green: 0.155, blue: 0.20)
    static let cardBorder  = Color.white.opacity(0.06)

    // 文字
    static let textPrimary   = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let textSecondary = Color(red: 0.55, green: 0.58, blue: 0.64)

    // 语义色
    static let good   = Color(red: 0.26, green: 0.80, blue: 0.55)
    static let warn   = Color(red: 0.96, green: 0.68, blue: 0.26)
    static let danger = Color(red: 0.94, green: 0.36, blue: 0.38)
    static let info   = Color(red: 0.45, green: 0.62, blue: 0.95)

    static let gradient = LinearGradient(gradient: Gradient(colors: [primary, accent]),
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let gradientSoft = LinearGradient(gradient: Gradient(colors: [primary.opacity(0.35), accent.opacity(0.28)]),
                                             startPoint: .topLeading, endPoint: .bottomTrailing)

    // 字体
    static func mono(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .semibold, design: .monospaced)
    }
}

// MARK: - 通用卡片容器
struct CardView<Content: View>: View {
    var corner: CGFloat = 20
    var padding: CGFloat = 16
    let content: Content

    init(corner: CGFloat = 20, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.corner = corner
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - 卡片小标题
struct CardTitle: View {
    let icon: String
    let title: String
    var iconColor: Color = AppTheme.primary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }
}

// MARK: - 环形仪表
struct GaugeRing: View {
    let value: Double   // 0...1
    var size: CGFloat = 84
    var lineWidth: CGFloat = 9
    var color: Color = AppTheme.primary
    var trackColor: Color = Color.white.opacity(0.08)
    var centerText: String?
    var subText: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
                .stroke(color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: value)
            if let centerText = centerText {
                VStack(spacing: 2) {
                    Text(centerText)
                        .font(.system(size: size * 0.24, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    if let subText = subText {
                        Text(subText)
                            .font(.system(size: size * 0.11))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 迷你折线图（自绘）
struct Sparkline: View {
    let points: [Double]
    var lineColor: Color = AppTheme.primary
    var fill: Bool = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minV = points.min() ?? 0
            let maxV = points.max() ?? 1
            let range = max(maxV - minV, 1)
            let step = points.count > 1 ? w / CGFloat(points.count - 1) : w
            let path = Path { p in
                for (i, v) in points.enumerated() {
                    let x = step * CGFloat(i)
                    let y = h - CGFloat((v - minV) / range) * (h - 4) - 2
                    if i == 0 { p.move(to: CGPoint(x: 0, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            ZStack {
                if fill {
                    Path { p in
                        p.addPath(path)
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(gradient: Gradient(colors: [lineColor.opacity(0.30), lineColor.opacity(0.0)]),
                                         startPoint: .top, endPoint: .bottom))
                }
                path.stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - 分区标题（iOS 设置风格）
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(AppTheme.textSecondary.opacity(0.85))
            .padding(.leading, 4)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

// MARK: - 信号强度条（蜂窝风格）
struct SignalBars: View {
    let level: Int    // 0...5
    var size: CGFloat = 22
    var active: Color = AppTheme.good
    var inactive: Color = Color.white.opacity(0.15)

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < level ? active : inactive)
                    .frame(width: size * 0.16, height: size * (0.25 + 0.17 * CGFloat(i)))
            }
        }
        .frame(height: size)
    }
}

// MARK: - 快捷开关按钮（路由器 App 风格）
struct QuickToggle: View {
    let icon: String
    let label: String
    let on: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(on ? accent.opacity(0.18) : Color.white.opacity(0.07))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(on ? accent : AppTheme.textSecondary)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(on ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 大数值指标
struct BigMetric: View {
    let icon: String
    let title: String
    let value: String
    var unit: String = ""
    var color: Color = AppTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(AppTheme.mono(20))
                    .foregroundColor(AppTheme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 状态行（图标 + 文本 + 可选值）
struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = AppTheme.textPrimary
    var iconColor: Color = AppTheme.primary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - 底部安全区间距
extension View {
    func cardSectionSpacing() -> some View {
        self.padding(.top, 12)
    }
}

// MARK: - 进度条
struct MetricBar: View {
    let value: Double // 0...1
    var color: Color = AppTheme.primary
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.7), color]),
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                    .animation(.easeInOut(duration: 0.5), value: value)
            }
        }
        .frame(height: height)
    }
}
