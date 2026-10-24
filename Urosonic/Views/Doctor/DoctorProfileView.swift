// DoctorProfileView.swift — Aura MedTech Redesign with Live Backend Data

import SwiftUI

struct DoctorProfileView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("doctorPushNotificationsEnabled") private var doctorPushEnabled = false
    @AppStorage("doctorCriticalAlertsEnabled") private var doctorAlertsEnabled   = false
    @State private var showSettingsPermissionAlert = false
    @State private var showTestAlertToast          = false
    @State private var appeared                    = false

    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount      = false
    @State private var deleteErrorMessage: String? = nil
    @State private var showErrorAlert         = false

    private var doctorPushBinding: Binding<Bool> {
        Binding<Bool>(
            get: { doctorPushEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await NotificationManager.shared.requestAuthorization()
                        await MainActor.run {
                            if granted {
                                doctorPushEnabled = true
                            } else {
                                doctorPushEnabled = false
                                showSettingsPermissionAlert = true
                            }
                        }
                    }
                } else {
                    doctorPushEnabled = false
                }
            }
        )
    }

    private var doctorAlertsBinding: Binding<Bool> {
        Binding<Bool>(
            get: { doctorAlertsEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let scheduled = await NotificationManager.shared.scheduleDoctorReviewReminders()
                        await MainActor.run {
                            if scheduled {
                                doctorAlertsEnabled = true
                                doctorPushEnabled = true
                                withAnimation { showTestAlertToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                    withAnimation { showTestAlertToast = false }
                                }
                            } else {
                                doctorAlertsEnabled = false
                                showSettingsPermissionAlert = true
                            }
                        }
                    }
                } else {
                    doctorAlertsEnabled = false
                    NotificationManager.shared.cancelDoctorReviewReminders()
                }
            }
        )
    }

    private var isDarkBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                if appTheme == "dark" { return true }
                if appTheme == "light" { return false }
                return systemColorScheme == .dark
            },
            set: { newValue in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    appTheme = newValue ? "dark" : "light"
                }
            }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Physician Profile")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.slateText)
                        Text("Clinical account & diagnostic settings")
                            .font(.system(size: 12))
                            .foregroundColor(.slateSub)
                    }
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.appTeal.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "stethoscope")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.appTeal)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color.slateCard)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle().fill(Color.slateBorder).frame(height: 1)
                    }
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Physician Hero Identity Card
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appNavy, Color.appNavyDark],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 86, height: 86)
                                    .shadow(color: Color.appTeal.opacity(0.25), radius: 14, y: 6)

                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.appTeal, Color.appCyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 86, height: 86)

                                Text(authState.currentUser?.avatarInitials ?? "DR")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            VStack(spacing: 4) {
                                Text(authState.currentUser?.fullName ?? "Dr. Urologist")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.slateText)

                                HStack(spacing: 6) {
                                    Text(authState.currentUser?.specialization ?? "Urology Specialist")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.appTeal)

                                    Text("•")
                                        .foregroundColor(.slateBorder)

                                    Text("License #\(authState.currentUser?.licenseNumber ?? "N/A")")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.slateSub)
                                }

                                Text(authState.currentUser?.email ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(.slateSub)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .uroCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .offset(y: appeared ? 0 : 16)
                        .opacity(appeared ? 1 : 0)

                        // Professional Info Card
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeaderView(title: "Clinical Credentials", icon: "doc.text.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 10)

                            Divider().background(Color.slateBorder.opacity(0.6)).padding(.horizontal, 16)

                            profRow(icon: "cross.case.fill", label: "Specialty", value: authState.currentUser?.specialization ?? "General Urology", last: false)
                            profRow(icon: "number.square.fill", label: "Medical License", value: authState.currentUser?.licenseNumber ?? "—", last: false)
                            profRow(icon: "phone.fill", label: "Direct Phone", value: authState.currentUser?.phone ?? "—", last: true)
                        }
                        .uroCard()
                        .padding(.horizontal, 16)
                        .offset(y: appeared ? 0 : 16)
                        .opacity(appeared ? 1 : 0)

                        // Clinical Preferences & Notifications
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeaderView(title: "System & Alerts", icon: "bell.badge.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 10)

                            Divider().background(Color.slateBorder.opacity(0.6)).padding(.horizontal, 16)

                            settingRow(
                                icon: "bell.fill",
                                label: "Push Notifications",
                                subtitle: "Instant test and patient report alerts",
                                binding: doctorPushBinding
                            )
                            Divider().background(Color.slateBorder.opacity(0.6)).padding(.leading, 52)

                            settingRow(
                                icon: "exclamationmark.triangle.fill",
                                label: "Critical Flow Alerts",
                                subtitle: doctorAlertsEnabled ? "Active (Low Qmax <10 mL/s alerts & daily 9 AM digest)" : "Alert for severe low Qmax (<10 mL/s)",
                                binding: doctorAlertsBinding
                            )

                            if doctorAlertsEnabled {
                                Button {
                                    Task {
                                        _ = await NotificationManager.shared.scheduleImmediateTestReminder(seconds: 4)
                                        withAnimation { showTestAlertToast = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                                            withAnimation { showTestAlertToast = false }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Send Test Physician Alert")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(Color.appTeal)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(Color.appTeal.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }

                            Divider().background(Color.slateBorder.opacity(0.6)).padding(.leading, 52)

                            settingRow(icon: "moon.fill", label: "Dark Interface Mode", subtitle: "High-contrast clinical viewing", binding: isDarkBinding)
                        }
                        .uroCard()
                        .padding(.horizontal, 16)
                        .offset(y: appeared ? 0 : 16)
                        .opacity(appeared ? 1 : 0)

                        if showTestAlertToast {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(Color.uroSuccess)
                                Text("Physician alert active. Test banner arriving in 4 seconds.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.slateText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.uroSuccessBg)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.uroSuccess.opacity(0.3), lineWidth: 1))
                            .padding(.horizontal, 16)
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Account Actions (Logout & Delete Account)
                        VStack(spacing: 12) {
                            Button {
                                authState.clear()
                                router.logout()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.slateText)
                                    Text("Sign Out of Clinical Account")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.slateText)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.slateCard)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder, lineWidth: 1.2))
                                .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
                            }
                            .buttonStyle(TactileButtonStyle())

                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    if isDeletingAccount {
                                        ProgressView()
                                            .tint(Color.uroDanger)
                                    } else {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    Text(isDeletingAccount ? "Deleting Account..." : "Delete Clinical Account")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(Color.uroDanger)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.uroDangerBg.opacity(0.85))
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.uroDanger.opacity(0.35), lineWidth: 1.2))
                                .shadow(color: Color.uroDanger.opacity(0.06), radius: 6, y: 2)
                            }
                            .disabled(isDeletingAccount)
                            .buttonStyle(TactileButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .offset(y: appeared ? 0 : 16)
                        .opacity(appeared ? 1 : 0)

                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appeared = true } }
        .confirmationDialog(
            "Delete Clinical Account",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account Permanently", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete your clinical physician account? All credentials, stock inventories, patient feedback records, and surgery logs will be permanently deleted. This action cannot be undone.")
        }
        .alert("Enable Notifications in Settings", isPresented: $showSettingsPermissionAlert) {
            Button("Open Settings") {
                NotificationManager.shared.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are currently disabled for Urosonic in your device Settings. Please enable them to receive critical patient alerts and clinic reminders.")
        }
        .alert("Error Deleting Account", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "An unexpected error occurred. Please check your connection and try again.")
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await APIClient.shared.deleteAccount(userId: authState.userId)
                await MainActor.run {
                    isDeletingAccount = false
                    authState.clear()
                    router.logout()
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteErrorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    @ViewBuilder
    func profRow(icon: String, label: String, value: String, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appNavy.opacity(0.06))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.appNavy)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 11)).foregroundColor(.slateSub)
                    Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(.slateText)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !last {
                Divider().background(Color.slateBorder.opacity(0.6)).padding(.leading, 56)
            }
        }
    }

    @ViewBuilder
    func settingRow(icon: String, label: String, subtitle: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appTeal.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.appTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 14, weight: .semibold)).foregroundColor(.slateText)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.slateSub)
            }

            Spacer()

            UroToggle(isOn: binding, activeColor: .appTeal)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
