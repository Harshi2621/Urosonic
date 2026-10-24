// ForgotPasswordView.swift — Modern Password Reset Screen
// Aura MedTech Design System

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var router: AppRouter
    @State private var email       = ""
    @State private var isSubmitted = false
    @State private var appeared    = false
    @State private var isSending   = false
    @State private var errorMsg: String? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.slateBg, Color.slateCard],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.appTeal.opacity(0.06))
                .frame(width: 260, height: 260)
                .offset(x: 120, y: -80)
                .blur(radius: 50)

            VStack(spacing: 0) {
                // Back Button Bar
                HStack {
                    Button {
                        router.navigate(to: .login)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.slateCard)
                                .frame(width: 42, height: 42)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.slateText)
                        }
                    }
                    .tactileButton()

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -16)

                if !isSubmitted {
                    // Reset Form
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appTeal.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(Color.appTeal)
                        }
                        .padding(.bottom, 6)

                        Text("Reset Password")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)

                        Text("Enter the email associated with your account and we'll send instructions to reset your password.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.slateSub)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account Email")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.slateText)

                        UroInputField(
                            icon: "envelope.fill",
                            placeholder: "name@example.com",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                    if let err = errorMsg {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.uroDanger)
                            Text(err)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "991B1B"))
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.uroDangerBg)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.uroDanger.opacity(0.3), lineWidth: 1))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }

                    PrimaryButton(
                        title: isSending ? "Sending Instructions..." : "Send Reset Link",
                        icon: "paperplane.fill",
                        isLoading: isSending
                    ) {
                        Task { await sendResetLink() }
                    }
                    .disabled(isSending || email.isEmpty)
                    .opacity((isSending || email.isEmpty) ? 0.6 : 1.0)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)

                    Spacer()
                } else {
                    // Success Confirmation State
                    Spacer()
                    VStack(spacing: 22) {
                        ZStack {
                            Circle()
                                .fill(Color.uroSuccessBg)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.uroSuccess.opacity(0.25), radius: 18, y: 8)

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundColor(Color.uroSuccess)
                        }
                        .scaleEffect(isSubmitted ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: isSubmitted)

                        VStack(spacing: 8) {
                            Text("Instructions Sent")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            Text("We have dispatched password recovery instructions to")
                                .font(.system(size: 14))
                                .foregroundColor(Color.slateSub)
                                .multilineTextAlignment(.center)

                            Text(email)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.appTeal)
                        }
                        .padding(.horizontal, 32)

                        PrimaryButton(
                            title: "Back to Login",
                            icon: "arrow.left"
                        ) {
                            router.navigate(to: .login)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                    Spacer()
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
        .animation(.easeInOut(duration: 0.4), value: isSubmitted)
    }

    private func sendResetLink() async {
        isSending = true
        errorMsg = nil
        do {
            try await Task.sleep(nanoseconds: 800_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isSubmitted = true
            }
        } catch {
            errorMsg = "Failed to send reset instructions."
        }
        isSending = false
    }
}
