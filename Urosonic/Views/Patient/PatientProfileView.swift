// PatientProfileView.swift — Modern Patient Profile & Clinical Settings
// Aura MedTech Design System

import SwiftUI

struct PatientProfileView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("patientPushNotificationsEnabled") private var pushNotificationsEnabled = false
    @AppStorage("patientSessionRemindersEnabled") private var sessionRemindersEnabled   = false
    @State private var showSettingsPermissionAlert = false
    @State private var showTestReminderToast       = false
    @State private var isSchedulingReminder        = false
    @State private var isEditing                   = false
    @State private var showDoctorPicker  = false
    @State private var isLinkingDoctor   = false
    @State private var doctors: [APIDoctorItem] = []
    @State private var appeared          = false

    @State private var name  = ""
    @State private var phone = ""

    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount      = false
    @State private var deleteErrorMessage: String? = nil
    @State private var showErrorAlert         = false

    private var pushNotificationsBinding: Binding<Bool> {
        Binding<Bool>(
            get: { pushNotificationsEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await NotificationManager.shared.requestAuthorization()
                        await MainActor.run {
                            if granted {
                                pushNotificationsEnabled = true
                            } else {
                                pushNotificationsEnabled = false
                                showSettingsPermissionAlert = true
                            }
                        }
                    }
                } else {
                    pushNotificationsEnabled = false
                }
            }
        )
    }

    private var sessionRemindersBinding: Binding<Bool> {
        Binding<Bool>(
            get: { sessionRemindersEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        isSchedulingReminder = true
                        let scheduled = await NotificationManager.shared.scheduleDailySessionReminders()
                        await MainActor.run {
                            isSchedulingReminder = false
                            if scheduled {
                                sessionRemindersEnabled = true
                                pushNotificationsEnabled = true
                                withAnimation { showTestReminderToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                    withAnimation { showTestReminderToast = false }
                                }
                            } else {
                                sessionRemindersEnabled = false
                                showSettingsPermissionAlert = true
                            }
                        }
                    }
                } else {
                    sessionRemindersEnabled = false
                    NotificationManager.shared.cancelSessionReminders()
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

    private var currentDoctor: APIDoctorItem? {
        if let docId = authState.currentUser?.doctorId {
            return doctors.first(where: { $0.id == docId }) ?? doctors.first
        }
        return doctors.first
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Text("Patient Profile")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            if isEditing { saveProfile() }
                            isEditing.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isEditing ? "checkmark" : "pencil")
                                .font(.system(size: 13, weight: .bold))
                            Text(isEditing ? "Save" : "Edit")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(isEditing ? Color.uroSuccess : Color.appTeal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background((isEditing ? Color.uroSuccess : Color.appTeal).opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .tactileButton()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Avatar Section
                        VStack(spacing: 12) {
                            AvatarView(
                                initials: authState.currentUser?.avatarInitials ?? "P",
                                size: 84,
                                bg: Color.appTeal.opacity(0.15),
                                fg: Color.appTeal,
                                showBadge: true
                            )
                            .shadow(color: Color.appTeal.opacity(0.2), radius: 14, y: 6)

                            if isEditing {
                                TextField("Full Name", text: $name)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Color.slateText)
                                    .padding(.horizontal, 20)
                                    .frame(height: 40)
                                    .background(Color.slateCard)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appTeal, lineWidth: 1.5))
                            } else {
                                Text(authState.currentUser?.fullName ?? "Patient")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.slateText)
                            }

                            Text(authState.currentUser?.email ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.slateSub)
                        }
                        .padding(.vertical, 16)
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Personal Information Card
                        cardSection(title: "Personal Information", icon: "person.text.rectangle.fill") {
                            infoGrid([
                                ("Age",        "\(authState.currentUser?.age ?? 0) yrs"),
                                ("Gender",     authState.currentUser?.gender ?? "—"),
                                ("Patient ID", "URO-\(authState.currentUser?.id ?? 0)"),
                                ("Phone",      isEditing ? nil : (authState.currentUser?.phone ?? "—"))
                            ], phoneBinding: isEditing ? $phone : nil)
                        }
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Clinical Details Card
                        cardSection(title: "Clinical Reference & Care Team", icon: "stethoscope") {
                            if let doc = currentDoctor {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(doc.fullName)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.slateText)
                                        Text(doc.specialization ?? "Attending Specialist")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTeal)
                                    }
                                    Spacer()
                                    Button {
                                        showDoctorPicker = true
                                    } label: {
                                        Text("Change")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.appTeal)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.appTeal.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .tactileButton()
                                }
                                .padding(.vertical, 4)
                                Divider().padding(.vertical, 2)
                            }
                            medRow("Primary Condition", authState.currentUser?.condition ?? "Standard Monitoring", last: true)
                        }
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Settings & Preferences (Push, Reminders, Display)
                        VStack(spacing: 0) {
                            settingsRow(
                                icon: "bell.badge.fill",
                                label: "Push Notifications",
                                subtitle: "Instant health reports & messages",
                                binding: pushNotificationsBinding
                            )
                            Divider().padding(.leading, 56)

                            settingsRow(
                                icon: "clock.badge.checkmark.fill",
                                label: "Session Reminders",
                                subtitle: sessionRemindersEnabled ? "Active (8:30 AM, 2:00 PM, 8:30 PM)" : "Daily voiding & logging check-ins",
                                binding: sessionRemindersBinding
                            )

                            // Active Schedule Detail Drawer
                            if sessionRemindersEnabled {
                                VStack(alignment: .leading, spacing: 10) {
                                    Divider().padding(.leading, 16)

                                    VStack(alignment: .leading, spacing: 6) {
                                        reminderScheduleRow(time: "08:30 AM", label: "Morning Uroflow Recording")
                                        reminderScheduleRow(time: "02:00 PM", label: "Hydration & Fluid Output Check")
                                        reminderScheduleRow(time: "08:30 PM", label: "Evening Flow Log Review")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)

                                    Button {
                                        Task {
                                            _ = await NotificationManager.shared.scheduleImmediateTestReminder(seconds: 4)
                                            withAnimation { showTestReminderToast = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                                                withAnimation { showTestReminderToast = false }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "paperplane.fill")
                                                .font(.system(size: 11, weight: .bold))
                                            Text("Send Test Reminder Banner")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(Color.appTeal)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(Color.appTeal.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .tactileButton()
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Divider().padding(.leading, 56)
                            settingsRow(
                                icon: "moon.fill",
                                label: "Dark Mode Display",
                                subtitle: "High-contrast clinical visual theme",
                                binding: isDarkBinding,
                                activeColor: Color.appTeal
                            )
                        }
                        .uroCard(cornerRadius: 20)
                        .padding(.horizontal, 16)
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        if showTestReminderToast {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(Color.uroSuccess)
                                Text("Session reminder active. Test banner arriving in 4 seconds.")
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

                        // Account Actions (Log Out & Delete Account)
                        VStack(spacing: 12) {
                            Button {
                                authState.clear()
                                router.logout()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Log Out Account")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color.slateText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.slateCard)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 1.2))
                            }
                            .tactileButton()

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
                                    Text(isDeletingAccount ? "Deleting Account..." : "Delete Account")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color.uroDanger)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.uroDangerBg.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.uroDanger.opacity(0.35), lineWidth: 1.2))
                            }
                            .disabled(isDeletingAccount)
                            .tactileButton()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .onAppear {
            name  = authState.currentUser?.fullName ?? ""
            phone = authState.currentUser?.phone ?? ""
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            Task {
                doctors = (try? await APIClient.shared.getDoctors()) ?? []
            }
        }
        .sheet(isPresented: $showDoctorPicker) {
            VStack(spacing: 0) {
                HStack {
                    Text("Select Attending Specialist")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                    Spacer()
                    Button("Done") { showDoctorPicker = false }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTeal)
                }
                .padding(20)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(doctors) { doc in
                            Button {
                                Task {
                                    isLinkingDoctor = true
                                    _ = try? await APIClient.shared.linkDoctor(patientId: authState.userId, doctorId: doc.id)
                                    let refreshed = try? await APIClient.shared.getProfile(userId: authState.userId)
                                    if let refreshed {
                                        DispatchQueue.main.async { authState.currentUser = refreshed }
                                    }
                                    isLinkingDoctor = false
                                    showDoctorPicker = false
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    AvatarView(initials: doc.avatarInitials ?? "DR", size: 46, bg: Color.appTeal.opacity(0.12), fg: Color.appTeal)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(doc.fullName)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.slateText)
                                        Text(doc.specialization ?? "Urology Specialist")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTeal)
                                    }
                                    Spacer()
                                    if authState.currentUser?.doctorId == doc.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.uroSuccess)
                                    }
                                }
                                .padding(14)
                                .uroCard(cornerRadius: 16)
                            }
                            .tactileButton()
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.slateBg)
        }
        .alert("Enable Notifications in Settings", isPresented: $showSettingsPermissionAlert) {
            Button("Open Settings") {
                NotificationManager.shared.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are currently disabled for Urosonic in your device Settings. Please enable them to receive daily session reminders and health alerts.")
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account Permanently", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete your account? All your clinical history, recorded uroflow measurements, fluid logs, and medical profile will be permanently deleted. This action cannot be undone.")
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

    private func saveProfile() {
        Task {
            if let newProfile = try? await APIClient.shared.updateProfile(userId: authState.userId, body: ["full_name": name, "phone": phone]) {
                DispatchQueue.main.async { authState.currentUser = newProfile }
            }
        }
    }

    @ViewBuilder
    func cardSection(title: String, icon: String?, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appTeal)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
            }
            content()
        }
        .padding(18)
        .uroCard(cornerRadius: 20)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    func infoGrid(_ pairs: [(String, String?)], phoneBinding: Binding<String>?) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(pairs, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.slateSub)
                    if label == "Phone", let binding = phoneBinding {
                        TextField("Phone", text: binding)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                    } else {
                        Text(value ?? "—")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func medRow(_ label: String, _ value: String, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.slateSub)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
            }
            .padding(.vertical, 8)
            if !last { Divider().padding(.vertical, 2) }
        }
    }

    @ViewBuilder
    func reminderScheduleRow(time: String, label: String) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.appTeal)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.appTeal.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.slateSub)
            Spacer()
        }
    }

    @ViewBuilder
    func settingsRow(icon: String, label: String, subtitle: String? = nil, binding: Binding<Bool>, activeColor: Color = .appTeal) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.slateLight)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.appTeal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.slateText)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.slateSub)
                }
            }
            Spacer()
            UroToggle(isOn: binding, activeColor: activeColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
