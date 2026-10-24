// WriteFeedbackView.swift — Posts real feedback to backend
// Aura MedTech Design System

import SwiftUI

struct WriteFeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState

    var measurementId: Int { router.feedbackMeasurementId }
    var patientId:     Int { router.feedbackPatientId }

    @State private var interpretation: Interpretation = .normal
    @State private var notes            = ""
    @State private var prescription     = ""
    @State private var showPrescription = false
    @State private var setFollowUp      = false
    @State private var followUpDate     = Date()
    @State private var appeared         = false
    @State private var isSubmitting     = false
    @State private var errorMsg: String? = nil

    enum Interpretation: String, CaseIterable {
        case normal     = "Normal"
        case borderline = "Borderline"
        case abnormal   = "Abnormal"
        case followUp   = "Needs Follow-up"
    }

    let quickPhrases = [
        "Normal flow pattern observed.",
        "Maintain current fluid intake schedule.",
        "Qmax slightly reduced; monitor over 7 days.",
        "Recommend clinic follow-up uroflowmetry."
    ]

    var canSend: Bool { !notes.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                BackButtonRow(
                    title: "Write Clinical Feedback",
                    subtitle: "Patient #\(patientId)"
                ) {
                    if !router.doctorHomePath.isEmpty && router.doctorTab == 0 {
                        router.doctorHomePath.removeLast()
                    } else if !router.doctorPatientsPath.isEmpty && router.doctorTab == 1 {
                        router.doctorPatientsPath.removeLast()
                    } else {
                        dismiss()
                    }
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Interpretation Selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Clinical Interpretation")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(Interpretation.allCases, id: \.self) { option in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { interpretation = option }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(statusColor(option))
                                                .frame(width: 8, height: 8)

                                            Text(option.rawValue)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(interpretation == option ? Color.slateText : Color.slateSub)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(interpretation == option ? Color.slateCard : Color.slateCard.opacity(0.6))
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(interpretation == option ? statusColor(option) : Color.slateBorder, lineWidth: interpretation == option ? 1.5 : 1)
                                        )
                                        .shadow(color: interpretation == option ? statusColor(option).opacity(0.15) : Color.clear, radius: 6, y: 2)
                                    }
                                    .tactileButton()
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Quick Phrase Chips
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Observations")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.slateSub)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(quickPhrases, id: \.self) { phrase in
                                        Button {
                                            if notes.isEmpty {
                                                notes = phrase
                                            } else {
                                                notes += " " + phrase
                                            }
                                        } label: {
                                            Text(phrase)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(Color.appTeal)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(Color.appTeal.opacity(0.08))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(Color.appTeal.opacity(0.2), lineWidth: 0.8))
                                        }
                                        .tactileButton()
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Clinical Notes Text Editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Physician Notes & Recommendations")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            ZStack(alignment: .topLeading) {
                                if notes.isEmpty {
                                    Text("Enter your clinical evaluation and instructions for the patient...")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.slateMuted)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 14)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $notes)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.slateText)
                                    .frame(height: 120)
                                    .padding(10)
                                    .scrollContentBackground(.hidden)
                            }
                            .background(Color.slateCard)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(notes.isEmpty ? Color.slateBorder : Color.appTeal, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                        }
                        .padding(.horizontal, 16)
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Prescription Section
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3)) { showPrescription.toggle() }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: showPrescription ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(showPrescription ? Color.appTeal : Color.slateSub)
                                        .font(.system(size: 18))
                                    Text("Attach Prescription / Medication Note")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.slateText)
                                    Spacer()
                                }
                                .padding(16)
                            }

                            if showPrescription {
                                VStack {
                                    ZStack(alignment: .topLeading) {
                                        if prescription.isEmpty {
                                            Text("Enter dosage and medication name...")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color.slateMuted)
                                                .padding(12)
                                                .allowsHitTesting(false)
                                        }
                                        TextEditor(text: $prescription)
                                            .font(.system(size: 13))
                                            .frame(height: 80)
                                            .padding(6)
                                            .scrollContentBackground(.hidden)
                                    }
                                    .background(Color.slateLight)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                                }
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        .uroCard(cornerRadius: 18)
                        .padding(.horizontal, 16)

                        // Follow-up Date Section
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3)) { setFollowUp.toggle() }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: setFollowUp ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(setFollowUp ? Color.appTeal : Color.slateSub)
                                        .font(.system(size: 18))
                                    Text("Schedule Follow-Up Reminder")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.slateText)
                                    Spacer()
                                }
                                .padding(16)
                            }

                            if setFollowUp {
                                DatePicker("Follow-up Date", selection: $followUpDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .accentColor(Color.appTeal)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 16)
                                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        .uroCard(cornerRadius: 18)
                        .padding(.horizontal, 16)

                        // Error Banner
                        if let err = errorMsg {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(Color.uroDanger)
                                .padding(.horizontal, 16)
                        }

                        // Submit Button
                        PrimaryButton(
                            title: isSubmitting ? "Submitting..." : "Send Clinical Feedback",
                            icon: "paperplane.fill",
                            isLoading: isSubmitting
                        ) {
                            Task { await submitFeedback() }
                        }
                        .disabled(!canSend || isSubmitting)
                        .opacity((!canSend || isSubmitting) ? 0.6 : 1.0)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 14)
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appeared = true } }
    }

    private func statusColor(_ opt: Interpretation) -> Color {
        switch opt {
        case .normal: return Color.uroSuccess
        case .borderline: return Color.uroWarning
        case .abnormal: return Color.uroDanger
        case .followUp: return Color.appBlue
        }
    }

    private func submitFeedback() async {
        isSubmitting = true
        errorMsg = nil
        let fDate: String? = setFollowUp ? ISO8601DateFormatter().string(from: followUpDate).prefix(10).description : nil
        do {
            _ = try await APIClient.shared.submitFeedback(
                measurementId: measurementId,
                doctorId:      authState.userId,
                patientId:     patientId,
                interpretation: interpretation.rawValue,
                notes:          notes,
                prescription:   prescription,
                followUpDate:   fDate
            )
            dismiss()
            router.doctorTab = 0
            router.doctorHomePath     = []
            router.doctorPatientsPath = []
        } catch {
            errorMsg = error.localizedDescription
        }
        isSubmitting = false
    }
}
