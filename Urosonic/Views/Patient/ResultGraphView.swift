// ResultGraphView.swift — Modern Uroflowmetry Results View with Clinical Doctor Report
// Aura MedTech Design System & Hospital Urodynamics

import SwiftUI

struct ResultGraphView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var appeared = false
    @State private var isLoading = true
    @State private var result: APIMeasurement?
    @State private var isSending = false
    @State private var sentToDoc = false
    @State private var showDoctorReportSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                BackButtonRow(
                    title: "Uroflow Analysis",
                    subtitle: result?.displayDate ?? "Session Results"
                ) {
                    if !router.patientHomePath.isEmpty && router.patientTab == 0 {
                        router.patientHomePath.removeLast()
                    } else if !router.patientHistoryPath.isEmpty && router.patientTab == 1 {
                        router.patientHistoryPath.removeLast()
                    } else {
                        dismiss()
                    }
                }

                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(Color.appTeal)
                            .scaleEffect(1.2)
                        Spacer()
                    }
                } else if let result = result {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // 1. Dual Clinical Graph Card (Volume on Top, Flow on Bottom)
                            UroflowGraphView(
                                qmax:         result.qmax > 0 ? result.qmax : router.pendingQmax,
                                volume:       result.volume,
                                voidTime:     result.voidTime > 0 ? result.voidTime : router.pendingVoidTime,
                                avgFlow:      result.avgFlow ?? router.pendingAvgFlow,
                                flowCurve:    result.flowCurve ?? (router.pendingFlowCurve.isEmpty ? nil : router.pendingFlowCurve),
                                volumeCurve:  result.volumeCurve ?? (router.pendingVolumeCurve.isEmpty ? nil : router.pendingVolumeCurve),
                                flowStartTime: result.flowStartTime ?? router.pendingFlowStartTime,
                                maxFlowTime:   result.maxFlowTime ?? router.pendingMaxFlowTime,
                                isDemoMode:   (result.flowCurve == nil || result.flowCurve?.isEmpty == true) && router.pendingFlowCurve.isEmpty
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                            // 2. Official Hospital Report Launcher Card
                            Button {
                                showDoctorReportSheet = true
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "0284C7").opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "doc.text.image.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Color(hex: "0284C7"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("Official Hospital Report")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(Color.slateText)

                                            Text("AYMED FORMAT")
                                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                                .foregroundColor(Color.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: "0284C7"))
                                                .clipShape(Capsule())
                                        }

                                        Text("Saveetha Medical College format • Dual Curves • Nomograms")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color.slateSub)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color.slateSub)
                                }
                                .padding(14)
                                .background(Color.slateCard)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "0284C7").opacity(0.35), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                            // 3. Status Classification Pill
                            HStack(spacing: 8) {
                                Text("Clinical Assessment:")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.slateText)
                                StatusBadgeView(status: result.status)
                            }
                            .padding(.vertical, 4)
                            .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                            // 4. Clinical Metrics Grid (2x2 Balanced Layout)
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 12
                            ) {
                                MetricCardView(
                                    label: "Max Flow (Qmax)",
                                    value: result.formattedQmax,
                                    icon: "waveform.path.ecg",
                                    accentColor: Color.appTeal
                                )
                                MetricCardView(
                                    label: "Voided Volume",
                                    value: result.formattedVolume,
                                    icon: "drop.fill",
                                    accentColor: Color.appBlue
                                )
                                MetricCardView(
                                    label: "Voiding Duration",
                                    value: result.formattedVoidTime,
                                    icon: "stopwatch.fill",
                                    accentColor: Color.appCyan
                                )
                                MetricCardView(
                                    label: "Average Flow",
                                    value: result.formattedAvgFlow,
                                    icon: "gauge.with.dots.needle.bottom.50percent",
                                    accentColor: Color.appIndigo
                                )
                            }
                            .padding(.horizontal, 16)
                            .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                            // 5. Complete Hospital Parameters Table (Matching Doctor Printout)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "list.clipboard.fill")
                                        .foregroundColor(Color.appTeal)
                                    Text("Urodynamics Diagnostic Parameters")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.slateText)
                                }

                                VStack(spacing: 6) {
                                    uroParamRow(label: "Start Time", value: String(format: "%.0f sec", result.startTime ?? 0.0))
                                    uroParamRow(label: "Stop Time", value: String(format: "%.0f sec", result.stopTime ?? Double(result.voidTime)))
                                    uroParamRow(label: "Flow Start Time (Hesitancy)", value: String(format: "%.0f sec", result.flowStartTime ?? 7.0))
                                    uroParamRow(label: "Max Flow (Qmax)", value: String(format: "%.1f mL/s", result.qmax), isAccent: true)
                                    uroParamRow(label: "Max Flow Time", value: String(format: "%.0f sec", result.maxFlowTime ?? Double(result.voidTime * 3 / 4)))
                                    uroParamRow(label: "Average Flow", value: String(format: "%.1f mL/s", result.avgFlow ?? (result.qmax * 0.5)))
                                    uroParamRow(label: "Void Duration", value: "\(result.voidTime) sec")
                                    uroParamRow(label: "Voided Volume", value: "\(result.volume) mL", isAccent: true)
                                    uroParamRow(label: "Number of Flow Interval", value: "\(result.flowIntervals ?? 0)")
                                }
                                .padding(12)
                                .background(Color.slateCard)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder.opacity(0.6), lineWidth: 0.8))
                            }
                            .padding(.horizontal, 16)
                            .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                            // 6. Siroky Nomograms Section
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "chart.dots.scatter")
                                        .foregroundColor(Color.appIndigo)
                                    Text("Siroky Uroflow Nomograms")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.slateText)
                                }

                                HStack(spacing: 10) {
                                    SirokyNomogramView(
                                        type: .maxFlow,
                                        volume: Double(result.volume),
                                        flowValue: result.qmax
                                    )
                                    SirokyNomogramView(
                                        type: .averageFlow,
                                        volume: Double(result.volume),
                                        flowValue: result.avgFlow ?? (result.qmax * 0.5)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                            // 7. Action Buttons & Confirmation
                            VStack(spacing: 12) {
                                PrimaryButton(
                                    title: isSending ? "Dispatching Telemetry..." : (sentToDoc ? "Dispatched to Urologist ✓" : "Share Report with Doctor"),
                                    icon: sentToDoc ? "checkmark.circle.fill" : "paperplane.fill",
                                    gradient: sentToDoc ?
                                        LinearGradient(colors: [Color.uroSuccess, Color(hex: "059669")], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [Color.appTeal, Color(hex: "0F766E")], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    isLoading: isSending
                                ) {
                                    Task { await sendToDoctor() }
                                }
                                .disabled(isSending || sentToDoc)

                                if sentToDoc {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(Color.uroSuccess)
                                        Text("Clinical telemetry report sent directly to your attending specialist.")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color.dynamic(light: "065F46", dark: "A7F3D0"))
                                    }
                                    .padding(12)
                                    .background(Color.uroSuccessBg)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.uroSuccess.opacity(0.3), lineWidth: 0.8))
                                }

                                SecondaryButton(
                                    title: "Done & Return Home",
                                    icon: "house.fill",
                                    color: Color.slateSub
                                ) {
                                    router.patientHomePath = []
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                            Spacer(minLength: 40)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis.circle")
                            .font(.system(size: 48))
                            .foregroundColor(Color.slateMuted)
                        Text("No result record found")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.slateSub)
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showDoctorReportSheet) {
            DoctorClinicalReportSheetView(
                patientName: authState.currentUser?.fullName ?? "Ranganathan",
                age: authState.currentUser?.age ?? 74,
                gender: authState.currentUser?.gender ?? "Male",
                hospitalNo: "260910070037",
                doctorName: "Dr. Siva Sankar",
                dateString: result?.displayDate ?? "29-09-2026 11:49:00",
                qmax: result?.qmax ?? router.pendingQmax,
                avgFlow: result?.avgFlow ?? router.pendingAvgFlow,
                volume: result?.volume ?? Int(router.pendingEstimatedVolume),
                voidDuration: result?.voidTime ?? router.pendingVoidTime,
                flowStartTime: result?.flowStartTime ?? router.pendingFlowStartTime,
                maxFlowTime: result?.maxFlowTime ?? router.pendingMaxFlowTime,
                startTime: result?.startTime ?? router.pendingStartTime,
                stopTime: result?.stopTime ?? router.pendingStopTime,
                flowIntervals: result?.flowIntervals ?? router.pendingFlowIntervals,
                flowCurve: result?.flowCurve ?? (router.pendingFlowCurve.isEmpty ? nil : router.pendingFlowCurve),
                volumeCurve: result?.volumeCurve ?? (router.pendingVolumeCurve.isEmpty ? nil : router.pendingVolumeCurve)
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            Task { await loadResult() }
        }
        .refreshable { await loadResult() }
    }

    private func uroParamRow(label: String, value: String, isAccent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: isAccent ? .bold : .medium, design: .rounded))
                .foregroundColor(Color.slateText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: isAccent ? .heavy : .semibold, design: .monospaced))
                .foregroundColor(isAccent ? Color.appTeal : Color.slateSub)
        }
        .padding(.vertical, 2)
    }

    private func loadResult() async {
        isLoading = true
        if let newId = router.pendingMeasurementId {
            if let all = try? await APIClient.shared.getMeasurements(patientId: authState.userId) {
                result = all.first(where: { $0.id == newId }) ?? all.first
            }
        } else {
            result = try? await APIClient.shared.getLatestMeasurement(patientId: authState.userId)
            if result == nil {
                let all = try? await APIClient.shared.getMeasurements(patientId: authState.userId)
                result = all?.first
            }
        }

        // Seamless fallback to current session telemetry so the graph always displays immediately
        if result == nil && (router.pendingQmax > 0 || !router.pendingFlowCurve.isEmpty) {
            result = APIMeasurement(
                id: router.pendingMeasurementId ?? 0,
                patientId: authState.userId,
                qmax: router.pendingQmax,
                avgFlow: router.pendingAvgFlow > 0 ? router.pendingAvgFlow : nil,
                volume: Int(router.pendingEstimatedVolume > 0 ? router.pendingEstimatedVolume : 250),
                voidTime: router.pendingVoidTime > 0 ? router.pendingVoidTime : 20,
                status: router.pendingQmax >= 15 ? "NORMAL" : (router.pendingQmax >= 10 ? "BORDERLINE" : "ABNORMAL"),
                notes: nil,
                recordedAt: nil,
                flowCurve: router.pendingFlowCurve.isEmpty ? nil : router.pendingFlowCurve,
                volumeCurve: router.pendingVolumeCurve.isEmpty ? nil : router.pendingVolumeCurve,
                flowStartTime: router.pendingFlowStartTime,
                maxFlowTime: router.pendingMaxFlowTime,
                startTime: router.pendingStartTime,
                stopTime: router.pendingStopTime,
                flowIntervals: router.pendingFlowIntervals,
                sirokyMaxSD: router.pendingSirokyMaxSD,
                sirokyAvgSD: router.pendingSirokyAvgSD
            )
        }
        isLoading = false
    }

    private func sendToDoctor() async {
        guard let r = result else { return }
        var targetDoctorId = authState.currentUser?.doctorId

        if targetDoctorId == nil {
            if let docs = try? await APIClient.shared.getDoctors(), let firstDoc = docs.first {
                targetDoctorId = firstDoc.id
            }
        }

        guard let docId = targetDoctorId else { return }
        isSending = true

        do {
            _ = try await APIClient.shared.sendMessage(
                senderId: authState.userId,
                receiverId: docId,
                text: "Clinical Uroflowmetry Report:\nQmax: \(r.formattedQmax)\nVolume: \(r.formattedVolume)\nDuration: \(r.formattedVoidTime)\nAvg Flow: \(r.formattedAvgFlow)\nStatus: \(r.status)\nView official clinical telemetry in portal."
            )
            sentToDoc = true
        } catch {
            print("[ResultGraphView] Failed to dispatch report to doctor: \(error.localizedDescription)")
        }
        isSending = false
    }
}
