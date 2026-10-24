// LoginView.swift — Modern Authentication View
// Aura MedTech Design System

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState

    @State private var role: LoginRole = .patient
    @State private var email = ""
    @State private var password = ""
    @State private var appeared = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    enum LoginRole: String, CaseIterable {
        case patient = "Patient"
        case doctor  = "Doctor"
    }

    var body: some View {
        ZStack {
            // Ambient Gradient Background
            LinearGradient(
                colors: [Color.slateBg, Color.slateCard],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Decorative Aura Lights
            Circle()
                .fill(Color.appTeal.opacity(0.06))
                .frame(width: 300, height: 300)
                .offset(x: 130, y: -160)
                .blur(radius: 60)

            Circle()
                .fill(Color.appBlue.opacity(0.05))
                .frame(width: 260, height: 260)
                .offset(x: -120, y: 180)
                .blur(radius: 60)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerView
                    roleToggleView
                    fieldsView
                    actionsView
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Header View
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [Color.appTeal.opacity(0.15), Color.appCyan.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.appTeal.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.appTeal.opacity(0.2), radius: 15, y: 6)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(Color.appTeal)
            }

            VStack(spacing: 6) {
                Text("Welcome Back")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)

                Text("Sign in to your clinical health portal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.slateSub)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 24)
        .offset(y: appeared ? 0 : -20)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Role Switcher
    @ViewBuilder
    private var roleToggleView: some View {
        HStack(spacing: 0) {
            ForEach(LoginRole.allCases, id: \.self) { r in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        role = r
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: r == .patient ? "person.fill" : "cross.case.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(r.rawValue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(role == r ? Color.slateText : Color.slateSub)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(role == r ? Color.slateCard : Color.clear)
                            .shadow(color: Color.black.opacity(role == r ? 0.08 : 0), radius: 6, y: 2)
                    )
                }
            }
        }
        .padding(5)
        .background(Color.slateLight)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 0.8))
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .offset(y: appeared ? 0 : 16)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Input Fields
    @ViewBuilder
    private var fieldsView: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Email Address")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.slateText)

                UroInputField(
                    icon: "envelope.fill",
                    placeholder: "name@example.com",
                    text: $email,
                    keyboardType: .emailAddress
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Password")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.slateText)
                    Spacer()
                    Button {
                        router.navigate(to: .forgotPassword)
                    } label: {
                        Text("Forgot Password?")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.appTeal)
                    }
                }

                UroInputField(
                    icon: "lock.fill",
                    placeholder: "Enter your password",
                    text: $password,
                    isSecure: true
                )
            }
        }
        .padding(.horizontal, 24)
        .offset(y: appeared ? 0 : 16)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Actions & CTA
    @ViewBuilder
    private var actionsView: some View {
        VStack(spacing: 0) {
            if let err = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.uroDanger)

                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "991B1B"))

                        Spacer()
                    }
                }
                .padding(12)
                .background(Color.uroDangerBg)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.uroDanger.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            PrimaryButton(
                title: isLoading ? "Signing in..." : "Sign In",
                icon: "arrow.right",
                isLoading: isLoading
            ) {
                guard !isLoading else { return }
                Task { await performLogin() }
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1 : 0)

            HStack(spacing: 5) {
                Text("Don't have an account?")
                    .font(.system(size: 14))
                    .foregroundColor(Color.slateSub)

                Button {
                    router.navigate(to: .register)
                } label: {
                    Text("Register")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appTeal)
                }
            }
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 48)
        }
    }

    private func performLogin() async {
        isLoading = true
        errorMessage = nil
        do {
            let user = try await APIClient.shared.login(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                role: role.rawValue.lowercased()
            )
            authState.set(user)
            if user.role == "patient" { router.loginAsPatient() }
            else                      { router.loginAsDoctor()  }
        } catch {
            withAnimation(.spring()) {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}
