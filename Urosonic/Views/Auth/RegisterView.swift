// RegisterView.swift — Modern Registration View
// Aura MedTech Design System

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState

    @State private var role: RegRole = .patient
    @State private var fullName  = ""
    @State private var email     = ""
    @State private var phone     = ""
    @State private var password  = ""
    @State private var confirm   = ""
    @State private var license   = ""
    @State private var spec      = "Urology"
    @State private var agreed    = false
    @State private var appeared  = false
    @State private var isLoading = false
    @State private var errorMsg: String? = nil

    enum RegRole: String, CaseIterable {
        case patient = "Patient"
        case doctor  = "Doctor"
    }

    let specializations = ["Urology", "Nephrology", "General Practice", "Other"]

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
                .frame(width: 280, height: 280)
                .offset(x: -120, y: -180)
                .blur(radius: 60)

            Circle()
                .fill(Color.appCyan.opacity(0.05))
                .frame(width: 240, height: 240)
                .offset(x: 130, y: 220)
                .blur(radius: 60)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appTeal.opacity(0.15), Color.appCyan.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.appTeal.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.appTeal.opacity(0.15), radius: 10, y: 4)

                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(Color.appTeal)
                        }

                        VStack(spacing: 4) {
                            Text("Create Account")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)
                            Text("Join UroSonic Digital Health")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.slateSub)
                        }
                    }
                    .padding(.top, 44)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -16)

                    // Role Switcher
                    HStack(spacing: 0) {
                        ForEach(RegRole.allCases, id: \.self) { r in
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
                                .frame(height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 11)
                                        .fill(role == r ? Color.slateCard : Color.clear)
                                        .shadow(color: Color.black.opacity(role == r ? 0.08 : 0), radius: 5, y: 2)
                                )
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.slateLight)
                    .cornerRadius(15)
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.slateBorder, lineWidth: 0.8))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                    // Input Form Fields
                    VStack(spacing: 16) {
                        labeledField("Full Name", icon: "person.fill", placeholder: "Dr. / Jane Doe", text: $fullName)
                        labeledField("Email Address", icon: "envelope.fill", placeholder: "name@example.com", text: $email, keyboard: .emailAddress)
                        labeledField("Phone Number", icon: "phone.fill", placeholder: "+1 (555) 000-0000", text: $phone, keyboard: .phonePad)

                        if role == .doctor {
                            Group {
                                labeledField("Medical License #", icon: "creditcard.fill", placeholder: "e.g. MED-84920", text: $license)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Clinical Specialization")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.slateText)

                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.appTeal.opacity(0.12))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "stethoscope")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color.appTeal)
                                        }

                                        Picker("Specialization", selection: $spec) {
                                            ForEach(specializations, id: \.self) { Text($0) }
                                        }
                                        .pickerStyle(.menu)
                                        .accentColor(Color.appTeal)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: 52)
                                    .background(Color.slateCard)
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder, lineWidth: 1))
                                }
                            }
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                        }

                        labeledField("Password", icon: "lock.fill", placeholder: "Create secure password", text: $password, secure: true)
                        labeledField("Confirm Password", icon: "lock.fill", placeholder: "Confirm password", text: $confirm, secure: true)

                        // Terms & Conditions Checkbox
                        Button {
                            withAnimation(.spring(response: 0.25)) { agreed.toggle() }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: agreed ? "checkmark.square.fill" : "square")
                                    .foregroundColor(agreed ? Color.appTeal : Color.slateSub)
                                    .font(.system(size: 18))

                                Text("I agree to the Clinical Terms of Service and Privacy Policy")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.slateSub)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.3), value: role)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                    // Error Notification
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
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Primary CTA
                    PrimaryButton(
                        title: isLoading ? "Creating Account..." : "Create Account",
                        icon: "checkmark.circle.fill",
                        isLoading: isLoading
                    ) {
                        guard !isLoading else { return }
                        Task { await performRegister() }
                    }
                    .disabled(isLoading || fullName.isEmpty || email.isEmpty || password.isEmpty || !agreed)
                    .opacity((isLoading || fullName.isEmpty || email.isEmpty || password.isEmpty || !agreed) ? 0.6 : 1.0)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(Color.slateSub)

                        Button {
                            router.navigate(to: .login)
                        } label: {
                            Text("Sign In")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.appTeal)
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
    }

    @ViewBuilder
    func labeledField(_ label: String, icon: String, placeholder: String, text: Binding<String>,
                      keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color.slateText)

            UroInputField(
                icon: icon,
                placeholder: placeholder,
                text: text,
                isSecure: secure,
                keyboardType: keyboard
            )
        }
    }

    private func performRegister() async {
        guard password == confirm else {
            withAnimation { errorMsg = "Passwords do not match" }
            return
        }
        isLoading = true
        errorMsg = nil
        do {
            let user = try await APIClient.shared.register(
                fullName: fullName,
                email: email.lowercased().trimmingCharacters(in: .whitespaces),
                phone: phone,
                password: password,
                role: role.rawValue.lowercased(),
                licenseNumber: license,
                specialization: spec
            )
            authState.set(user)
            if user.role == "patient" { router.loginAsPatient() }
            else                      { router.loginAsDoctor()  }
        } catch {
            withAnimation(.spring()) {
                errorMsg = error.localizedDescription
            }
        }
        isLoading = false
    }
}
