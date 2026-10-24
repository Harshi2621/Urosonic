// DoctorPatientDetailView.swift — Live patient detail & clinical diagnostics
// Aura MedTech Design System

import SwiftUI

struct DoctorPatientDetailView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    let patientId: String

    @State private var patient:      APIPatientListItem? = nil
    @State private var measurements: [APIMeasurement]   = []
    @State private var appeared      = false
    @State private var isLoading     = true

    var latest: APIMeasurement? { measurements.first }
    var pid: Int { Int(patientId) ?? 0 }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                BackButtonRow(
                    title: patient?.name ?? "Patient Clinical Profile",
                    subtitle: "Medical ID #\(patientId)"
                ) {
                    if !router.doctorPatientsPath.isEmpty {
                        router.doctorPatientsPath.removeLast()
                    } else {
                        dismiss()
                    }
                }

                if isLoading && patient == nil {
                    VStack {
                        Spacer()
                        ProgressView().tint(Color.appTeal)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Patient Info Card
                            if let p = patient {
                                VStack(spacing: 12) {
                                    HStack(spacing: 14) {
                                        AvatarView(
                                            initials: p.avatar,
                                            size: 52,
                                            bg: Color.appTeal.opacity(0.12),
                                            fg: Color.appTeal
                                        )

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(p.name)
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundColor(Color.slateText)

                                            Text("Condition: \(p.condition ?? "General Monitoring")")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(Color.appTeal)
                                        }

                                        Spacer()
                                    }

                                    Divider()

                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                        infoCell("Age / Gender", "\(p.age ?? 0) yrs / \(p.gender ?? "—")")
                                        infoCell("Patient ID", "#\(p.id)")
                                    }
                                }
                                .padding(16)
                                .uroCard(cornerRadius: 20)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)
                            }

                            // Latest Measurement Card
                            if let m = latest {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeaderView(
                                        title: "Latest Recorded Uroflow",
                                        badge: m.displayDate
                                    )

                                    UroflowGraphView(
                                        qmax: m.qmax,
                                        volume: m.volume,
                                        voidTime: m.voidTime,
                                        avgFlow: m.avgFlow ?? 0,
                                        flowCurve: m.flowCurve,
                                        isDemoMode: m.flowCurve == nil || m.flowCurve?.isEmpty == true
                                    )

                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                        MetricCardView(label: "Max Flow (Qmax)", value: m.formattedQmax, icon: "waveform.path.ecg", accentColor: Color.appTeal)
                                        MetricCardView(label: "Void Volume", value: m.formattedVolume, icon: "drop.fill", accentColor: Color.appBlue)
                                        MetricCardView(label: "Void Duration", value: m.formattedVoidTime, icon: "stopwatch.fill", accentColor: Color.appCyan)
                                        MetricCardView(label: "Average Flow", value: m.formattedAvgFlow, icon: "gauge.medium", accentColor: Color.appIndigo)
                                    }

                                    HStack {
                                        Spacer()
                                        StatusBadgeView(status: m.status)
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)
                            }

                            // Quick Doctor Action Buttons
                            HStack(spacing: 12) {
                                PrimaryButton(
                                    title: "Write Clinical Feedback",
                                    icon: "square.and.pencil"
                                ) {
                                    router.feedbackPatientId     = pid
                                    router.feedbackMeasurementId = latest?.id ?? 0
                                    router.openWriteFeedbackFromPatient()
                                }

                                Button {
                                    router.openDoctorMessages(patientId: pid)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "message.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Message")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(Color.slateText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.slateCard)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 1))
                                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                                }
                                .tactileButton()
                            }
                            .padding(.horizontal, 16)
                            .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                            // Historical Timeline
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeaderView(
                                    title: "Past Uroflowmetry Records",
                                    badge: "\(measurements.count)"
                                )

                                ForEach(Array(measurements.dropFirst().prefix(5).enumerated()), id: \.element.id) { idx, record in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(record.displayDate)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Color.slateSub)
                                            Text(record.formattedQmax)
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(Color.slateText)
                                            Text("\(record.formattedVolume) • \(record.formattedVoidTime)")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.appTeal)
                                        }

                                        Spacer()

                                        StatusBadgeView(status: record.status)
                                    }
                                    .padding(14)
                                    .uroCard(cornerRadius: 18)
                                    .padding(.horizontal, 16)
                                }

                                if measurements.count <= 1 {
                                    Text("No prior history records on file.")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.slateSub)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            Task { await loadData() }
        }
    }

    @ViewBuilder
    func infoCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.slateSub)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.slateText)
        }
    }

    private func loadData() async {
        isLoading = true
        async let ms = try? APIClient.shared.getMeasurements(patientId: pid)
        async let ps = try? APIClient.shared.getDoctorPatients(doctorId: authState.userId)
        measurements = await ms ?? []
        let all = await ps ?? []
        if let found = all.first(where: { $0.id == pid }) {
            patient = found
        } else if let prof = try? await APIClient.shared.getProfile(userId: pid) {
            patient = APIPatientListItem(
                id: prof.id,
                name: prof.fullName,
                avatar: prof.initials,
                age: prof.age,
                gender: prof.gender,
                condition: prof.condition ?? "Clinical Monitoring",
                isFlagged: false
            )
        }
        isLoading = false
    }
}
