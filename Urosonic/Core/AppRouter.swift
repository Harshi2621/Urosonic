// AppRouter.swift — Single Navigation Router for UroFlow
// All app navigation is controlled from this file.
import SwiftUI
import Combine
// MARK: - Root Screens
enum AppScreen {
    case splash
    case login
    case register
    case forgotPassword
    case patient
    case doctor
}

// MARK: - Patient Destinations (used in NavigationStack paths)
enum PatientHomeDestination: Hashable {
    case activeRecording
    case volumeEntry
    case resultGraph
    case fluidLogger
}

enum PatientHistoryDestination: Hashable {
    case resultGraph
}

// MARK: - Doctor Destinations
enum DoctorHomeDestination: Hashable {
    case writeFeedback
    case stockInventory
    case followUpReminders
}

enum DoctorPatientsDestination: Hashable {
    case patientDetail(id: String)
    case writeFeedback
}

// MARK: - App Router (Single Source of Truth for Navigation)
class AppRouter: ObservableObject {

    // MARK: Root screen
    @Published var screen: AppScreen = .splash

    // MARK: Patient Tab Navigation
    @Published var patientTab: Int = 0
    @Published var patientHomePath: [PatientHomeDestination] = []
    @Published var patientHistoryPath: [PatientHistoryDestination] = []

    // MARK: Doctor Tab Navigation
    @Published var doctorTab: Int = 0
    @Published var doctorHomePath: [DoctorHomeDestination] = []
    @Published var doctorPatientsPath: [DoctorPatientsDestination] = []

    // MARK: - Pending Measurement (ActiveRecording → VolumeEntry → ResultGraph)
    /// Qmax calculated/simulated by the audio recording
    @Published var pendingQmax:     Double = 0.0
    /// Void time in seconds (timer value when recording stopped)
    @Published var pendingVoidTime: Int    = 0
    /// Average flow simulated from qmax
    @Published var pendingAvgFlow:  Double = 0.0
    /// ID of the measurement saved to the backend (set by VolumeEntryView after POST)
    @Published var pendingMeasurementId: Int? = nil

    // MARK: - Phase 6 AI / ML Flow Predictions
    /// Real timestamped flow curve points returned by Flask ML backend inference
    @Published var pendingFlowCurve: [PredictedFlowPoint] = []
    /// Cumulative volume curve points
    @Published var pendingVolumeCurve: [PredictedVolumePoint] = []
    /// Estimated voided volume in mL computed via trapezoidal integration of flow curve
    @Published var pendingEstimatedVolume: Double = 0.0
    /// Flow start time / Hesitancy delay in seconds
    @Published var pendingFlowStartTime: Double = 0.0
    /// Time of maximum flow in seconds
    @Published var pendingMaxFlowTime: Double = 0.0
    /// Start & stop recording times in seconds
    @Published var pendingStartTime: Double = 0.0
    @Published var pendingStopTime: Double = 0.0
    /// Number of flow intervals / interruptions
    @Published var pendingFlowIntervals: Int = 0
    /// Siroky nomogram standard deviation scores
    @Published var pendingSirokyMaxSD: Double? = nil
    @Published var pendingSirokyAvgSD: Double? = nil
    /// Research disclaimer status string from ML backend
    @Published var pendingResearchStatus: String = ""

    // MARK: - Pending Feedback Context (DoctorPatientDetailView → WriteFeedbackView)
    @Published var feedbackMeasurementId: Int = 0
    @Published var feedbackPatientId:     Int = 0

    // MARK: - Root Navigation
    func navigate(to dest: AppScreen) {
        withAnimation(.easeInOut(duration: 0.3)) {
            screen = dest
        }
    }

    func loginAsPatient() { navigate(to: .patient) }
    func loginAsDoctor()  { navigate(to: .doctor)  }

    func logout() {
        patientHomePath    = []
        patientHistoryPath = []
        doctorHomePath     = []
        doctorPatientsPath = []
        // Clear pending state
        pendingQmax            = 0.0
        pendingVoidTime        = 0
        pendingAvgFlow         = 0.0
        pendingMeasurementId   = nil
        pendingFlowCurve       = []
        pendingVolumeCurve     = []
        pendingEstimatedVolume = 0.0
        pendingFlowStartTime   = 0.0
        pendingMaxFlowTime     = 0.0
        pendingStartTime       = 0.0
        pendingStopTime        = 0.0
        pendingFlowIntervals   = 0
        pendingSirokyMaxSD     = nil
        pendingSirokyAvgSD     = nil
        pendingResearchStatus  = ""
        feedbackMeasurementId = 0
        feedbackPatientId     = 0
        navigate(to: .login)
    }

    // MARK: - Patient Navigation Helpers
    func startMeasurement() {
        patientTab = 0
        patientHomePath.append(.activeRecording)
    }

    func openFluidLogger() {
        patientTab = 0
        patientHomePath.append(.fluidLogger)
    }

    func showVolumeEntry() {
        patientHomePath.append(.volumeEntry)
    }

    func showResultGraph() {
        patientHomePath.append(.resultGraph)
    }

    func showResultFromHistory() {
        patientHistoryPath.append(.resultGraph)
    }

    func popPatientHome() {
        if !patientHomePath.isEmpty { patientHomePath.removeLast() }
    }

    // MARK: - Doctor Navigation Helpers
    func openWriteFeedback() {
        doctorHomePath.append(.writeFeedback)
    }

    func openStockInventory() {
        doctorHomePath.append(.stockInventory)
    }

    func openFollowUpReminders() {
        doctorHomePath.append(.followUpReminders)
    }

    func openPatientDetail(id: String) {
        doctorTab = 1
        doctorPatientsPath.append(.patientDetail(id: id))
    }

    func openWriteFeedbackFromPatient() {
        doctorPatientsPath.append(.writeFeedback)
    }

    @Published var activeDoctorChatUserId: Int? = nil

    func openDoctorMessages(patientId: Int? = nil) {
        if let pid = patientId {
            activeDoctorChatUserId = pid
        }
        doctorTab = 3
    }
}

// MARK: - Dynamic UIColor Helper
extension UIColor {
    convenience init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255.0,
                  green: CGFloat(g) / 255.0,
                  blue: CGFloat(b) / 255.0,
                  alpha: CGFloat(a) / 255.0)
    }

    static func dynamic(light: String, dark: String) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }
}

// MARK: - Aura MedTech Design System & Color Tokens
extension Color {
    static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor.dynamic(light: light, dark: dark))
    }

    // Brand & Core Themes
    static let appNavy        = Color(hex: "0F172A")
    static let appNavyDark    = Color(hex: "090E17")
    static let appNavyLight   = Color(hex: "1E293B")
    static let appTeal        = Color(hex: "0D9488")
    static let appTealLight   = Color(hex: "14B8A6")
    static let appCyan        = Color(hex: "06B6D4")
    static let appCyanLight   = Color(hex: "22D3EE")
    static let appBlue        = Color(hex: "2563EB")
    static let appBlueLight   = Color(hex: "3B82F6")
    static let appIndigo      = Color(hex: "4F46E5")

    // Semantic Status Colors
    static let uroSuccess     = Color(hex: "10B981")
    static let uroSuccessBg   = Color.dynamic(light: "D1FAE5", dark: "064E3B")
    static let uroWarning     = Color(hex: "F59E0B")
    static let uroWarningBg   = Color.dynamic(light: "FEF3C7", dark: "78350F")
    static let uroDanger      = Color(hex: "EF4444")
    static let uroDangerBg    = Color.dynamic(light: "FEE2E2", dark: "7F1D1D")
    static let uroInfo        = Color(hex: "3B82F6")
    static let uroInfoBg      = Color.dynamic(light: "DBEAFE", dark: "1E3A8A")

    // Neutrals & Surfaces (Fully Dynamic for Light & Dark Mode)
    static let slateBg        = Color.dynamic(light: "F8FAFC", dark: "0B111E")
    static let slateCard      = Color.dynamic(light: "FFFFFF", dark: "131D31")
    static let slateLight     = Color.dynamic(light: "F1F5F9", dark: "1E293B")
    static let slateBorder    = Color.dynamic(light: "E2E8F0", dark: "27354E")
    static let slateText      = Color.dynamic(light: "0F172A", dark: "F8FAFC")
    static let slateSub       = Color.dynamic(light: "64748B", dark: "94A3B8")
    static let slateMuted     = Color.dynamic(light: "94A3B8", dark: "64748B")

    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Tactile Spring Button Style
struct TactileButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Modern Card Modifiers
struct UroCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var isElevated: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.slateCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.slateBorder.opacity(0.8), lineWidth: 0.75)
                    )
                    .shadow(color: isElevated ? Color.black.opacity(0.08) : .clear, radius: 10, x: 0, y: 4)
                    .shadow(color: isElevated ? Color.black.opacity(0.04) : .clear, radius: 1, x: 0, y: 1)
            )
    }
}

struct UroGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.6), Color.white.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
            )
    }
}

extension View {
    func uroCard(cornerRadius: CGFloat = 20, isElevated: Bool = true) -> some View {
        modifier(UroCardModifier(cornerRadius: cornerRadius, isElevated: isElevated))
    }

    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(UroGlassModifier(cornerRadius: cornerRadius))
    }

    func tactileButton(scale: CGFloat = 0.97) -> some View {
        buttonStyle(TactileButtonStyle(scaleAmount: scale))
    }
}

extension Notification.Name {
    static let resetPatientMessagesToRoot = Notification.Name("resetPatientMessagesToRoot")
    static let resetDoctorMessagesToRoot = Notification.Name("resetDoctorMessagesToRoot")
}

