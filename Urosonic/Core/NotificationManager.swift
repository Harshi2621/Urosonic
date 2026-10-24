// NotificationManager.swift — Clinical Alerts & Session Reminders Engine
// Manages local notifications, daily uroflow recording reminders, permissions, and foreground presentation.

import Foundation
import UserNotifications
import SwiftUI
import Combine

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    // Identifier Constants
    private let reminderPrefix          = "urosonic_session_reminder_"
    private let morningReminderId       = "urosonic_session_reminder_morning"
    private let afternoonReminderId     = "urosonic_session_reminder_afternoon"
    private let eveningReminderId       = "urosonic_session_reminder_evening"
    private let testReminderId          = "urosonic_session_reminder_test"
    private let doctorReviewReminderId   = "urosonic_doctor_review_reminder"

    // Published State
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isScheduling: Bool = false
    @Published var showSettingsAlert: Bool = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task {
            await refreshAuthorizationStatus()
        }
    }

    // MARK: - Authorization
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .denied {
            self.showSettingsAlert = true
            return false
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Session Reminders (Daily Clinical Voiding Checkpoints)
    /// Schedules daily recurring local notifications for clinical voiding & uroflow monitoring.
    func scheduleDailySessionReminders() async -> Bool {
        let hasPermission = await requestAuthorization()
        guard hasPermission else {
            showSettingsAlert = true
            return false
        }

        let center = UNUserNotificationCenter.current()

        // Remove existing reminders to avoid duplicates
        cancelSessionReminders()

        // 1. Morning Voiding Checkpoint (08:30 AM)
        var morningComponents = DateComponents()
        morningComponents.hour = 8
        morningComponents.minute = 30
        scheduleRecurringNotification(
            id: morningReminderId,
            title: "Urosonic • Morning Uroflow Check",
            body: "Good morning! Record your first morning uroflowmetry session for clinical accuracy.",
            dateComponents: morningComponents
        )

        // 2. Midday Hydration & Flow Check (02:00 PM)
        var afternoonComponents = DateComponents()
        afternoonComponents.hour = 14
        afternoonComponents.minute = 0
        scheduleRecurringNotification(
            id: afternoonReminderId,
            title: "Urosonic • Hydration & Fluid Log",
            body: "Midday check: Log your fluid intake and any voiding episodes in your health journal.",
            dateComponents: afternoonComponents
        )

        // 3. Evening Session Check (08:30 PM)
        var eveningComponents = DateComponents()
        eveningComponents.hour = 20
        eveningComponents.minute = 30
        scheduleRecurringNotification(
            id: eveningReminderId,
            title: "Urosonic • Evening Voiding Check",
            body: "Complete your daily voiding log before resting. Tap to record your evening measurement.",
            dateComponents: eveningComponents
        )

        return true
    }

    /// Cancels all scheduled uroflow session reminders
    func cancelSessionReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            morningReminderId,
            afternoonReminderId,
            eveningReminderId,
            testReminderId
        ])
    }

    // MARK: - Immediate / Test Reminder (Verifiable by User & App Store Reviewers)
    /// Schedules a test reminder that fires 4 seconds after triggering, proving notification subsystem works.
    func scheduleImmediateTestReminder(seconds: TimeInterval = 4) async -> Bool {
        let hasPermission = await requestAuthorization()
        guard hasPermission else {
            showSettingsAlert = true
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Urosonic • Session Reminder Active"
        content.body = "Your daily clinical recording reminders are configured and active. Tap to open Urosonic."
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(identifier: testReminderId, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Doctor Clinical Alerts
    func scheduleDoctorReviewReminders() async -> Bool {
        let hasPermission = await requestAuthorization()
        guard hasPermission else {
            showSettingsAlert = true
            return false
        }

        // 09:00 AM Morning Clinic Digest
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        scheduleRecurringNotification(
            id: doctorReviewReminderId,
            title: "Urosonic • Physician Portal",
            body: "Review today's pending patient uroflowmetry reports and follow-up requests.",
            dateComponents: components
        )
        return true
    }

    func cancelDoctorReviewReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [doctorReviewReminderId])
    }

    // MARK: - Internal Scheduling Helper
    private func scheduleRecurringNotification(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification \(id): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate (Foreground Presentation)
extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Display banner and play sound even when the user is actively inside the app
        completionHandler([.banner, .sound, .badge, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Clear app badge when notification tapped
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        completionHandler()
    }
}
