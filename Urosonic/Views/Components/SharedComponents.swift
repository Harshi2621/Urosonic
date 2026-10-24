// SharedComponents.swift — Reusable UI components across the Urosonic app
// Aura MedTech Design System

import SwiftUI

// MARK: - Status Badge View
struct StatusBadgeView: View {
    let status: String // "NORMAL","BORDERLINE","ABNORMAL","OK","LOW","CRITICAL","UPCOMING","DUE","OVERDUE","RECORDING"
    var label: String? = nil

    private var config: (bg: Color, fg: Color, dot: Color) {
        switch status.uppercased() {
        case "NORMAL", "OK":
            return (Color.uroSuccessBg, Color.dynamic(light: "065F46", dark: "A7F3D0"), Color.uroSuccess)
        case "BORDERLINE", "DUE", "LOW":
            return (Color.uroWarningBg, Color.dynamic(light: "92400E", dark: "FDE68A"), Color.uroWarning)
        case "ABNORMAL", "CRITICAL", "OVERDUE", "RECORDING":
            return (Color.uroDangerBg, Color.dynamic(light: "991B1B", dark: "FECACA"), Color.uroDanger)
        case "UPCOMING":
            return (Color.uroInfoBg, Color.dynamic(light: "1E40AF", dark: "BFDBFE"), Color.uroInfo)
        default:
            return (Color.slateLight, Color.slateSub, Color.slateMuted)
        }
    }

    private var isPulsing: Bool {
        ["ABNORMAL", "CRITICAL", "OVERDUE", "RECORDING"].contains(status.uppercased())
    }

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(config.dot)
                .frame(width: 6, height: 6)
                .scaleEffect(pulse && isPulsing ? 1.3 : 1.0)
                .opacity(pulse && isPulsing ? 0.6 : 1.0)
                .animation(
                    isPulsing ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )

            Text(label ?? status)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(config.fg)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(config.bg)
                .overlay(
                    Capsule()
                        .stroke(config.dot.opacity(0.2), lineWidth: 0.75)
                )
        )
        .onAppear {
            if isPulsing { pulse = true }
        }
    }
}

// MARK: - Metric Card View
struct MetricCardView: View {
    let label: String
    let value: String
    var icon: String? = nil
    var accentColor: Color = Color.appTeal
    var badge: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                if let icon = icon {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.slateSub)
                    .lineLimit(1)

                Spacer()
                badge
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.slateText)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .uroCard(cornerRadius: 18)
    }
}

// MARK: - Modern Input Field
struct UroInputField: View {
    var title: String? = nil
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var isError: Bool = false

    // Initializer with title
    init(title: String, text: Binding<String>, placeholder: String, icon: String, isSecure: Bool = false, keyboardType: UIKeyboardType = .default, isError: Bool = false) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.isError = isError
    }

    // Initializer without title (default icon first)
    init(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool = false, keyboardType: UIKeyboardType = .default, isError: Bool = false) {
        self.title = nil
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.isError = isError
    }

    @State private var showPassword = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isFocused ? Color.appTeal : Color.slateSub)
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isFocused ? Color.appTeal.opacity(0.12) : Color.slateLight)
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isFocused ? Color.appTeal : Color.slateSub)
                }

                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 15))
                        .foregroundColor(Color.slateText)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 15))
                        .foregroundColor(Color.slateText)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                }

                if isSecure {
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.slateSub)
                    }
                } else if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.slateMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(Color.slateCard)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isError ? Color.uroDanger :
                        isFocused ? Color.appTeal : Color.slateBorder,
                        lineWidth: isFocused ? 1.5 : 1.0
                    )
            )
            .shadow(color: isFocused ? Color.appTeal.opacity(0.12) : Color.black.opacity(0.02), radius: 6, y: 2)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = LinearGradient(
        colors: [Color.appTeal, Color(hex: "0F766E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.appTeal.opacity(0.35), radius: 10, y: 5)
        }
        .tactileButton()
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Color.appTeal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
        .tactileButton()
    }
}

// MARK: - Avatar View
struct AvatarView: View {
    let initials: String
    var size: CGFloat = 44
    var bg: Color = Color.appTeal.opacity(0.15)
    var fg: Color = Color.appTeal
    var showBadge: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [bg, bg.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                        .foregroundColor(fg)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

            if showBadge {
                Circle()
                    .fill(Color.uroSuccess)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    var icon: String? = nil
    var badge: String? = nil
    var actionText: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTeal)
                }

                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appTeal)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.appTeal.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            if let actionText = actionText, let action = action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionText)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color.appTeal)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Back Button Row
struct BackButtonRow: View {
    let title: String
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.slateCard)
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.slateText)
                }
            }
            .tactileButton()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(Color.slateSub)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Sparkline View
struct SparklineView: View {
    let status: MeasurementStatus

    private var points: [Double] {
        switch status {
        case .normal:     return [6, 12, 18, 24, 20, 15, 6]
        case .borderline: return [5, 10, 14, 16, 13, 9, 4]
        case .abnormal:   return [4, 7, 9, 11, 8, 5, 2]
        }
    }

    private var lineColor: Color {
        switch status {
        case .normal:     return Color.uroSuccess
        case .borderline: return Color.uroWarning
        case .abnormal:   return Color.uroDanger
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let maxV = (points.max() ?? 1) * 1.15
            let w = size.width
            let h = size.height
            var path = Path()

            for (i, p) in points.enumerated() {
                let x = CGFloat(i) / CGFloat(points.count - 1) * w
                let y = h - CGFloat(p / maxV) * h
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else       { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            var area = path
            area.addLine(to: CGPoint(x: w, y: h))
            area.addLine(to: CGPoint(x: 0, y: h))
            area.closeSubpath()

            ctx.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [lineColor.opacity(0.3), lineColor.opacity(0.0)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h)
                )
            )
            ctx.stroke(path, with: .color(lineColor), lineWidth: 2.2)
        }
        .frame(width: 48, height: 24)
    }
}

// MARK: - Toggle Switch
struct UroToggle: View {
    @Binding var isOn: Bool
    var activeColor: Color = Color.appTeal

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? activeColor : Color.dynamic(light: "CBD5E1", dark: "334155"))
                    .frame(width: 46, height: 26)

                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
                    .padding(2)
            }
        }
        .tactileButton(scale: 0.95)
    }
}
