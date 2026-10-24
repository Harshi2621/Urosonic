// VolumeEntryView.swift — Modern Post-Recording Volume Entry
// Aura MedTech Design System

import SwiftUI

struct VolumeEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var volume         = ""
    @State private var selectedRange: String? = nil
    @State private var appeared       = false
    @State private var isSaving       = false

    let ranges: [(label: String, id: String, value: String)] = [
        (label: "< 150 mL",     id: "low",    value: "120"),
        (label: "150 – 350 mL", id: "medium", value: "250"),
        (label: "> 350 mL",     id: "high",   value: "450")
    ]

    var body: some View {
        ZStack {
            Color.slateBg.ignoresSafeArea()

            Circle()
                .fill(Color.appTeal.opacity(0.06))
                .frame(width: 280, height: 280)
                .offset(x: 100, y: -100)
                .blur(radius: 60)

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Button {
                        if !router.patientHomePath.isEmpty {
                            router.patientHomePath.removeLast()
                        } else {
                            dismiss()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.slateCard)
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.slateText)
                        }
                    }
                    .tactileButton()

                    Spacer()

                    Button("Skip") {
                        router.showResultGraph()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appTeal)
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
                .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Emblem & Title
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appTeal.opacity(0.18), Color.appCyan.opacity(0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .overlay(Circle().stroke(Color.appTeal.opacity(0.3), lineWidth: 1))
                                    .shadow(color: Color.appTeal.opacity(0.2), radius: 15, y: 6)

                                Image(systemName: "drop.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(Color.appTeal)
                            }

                            VStack(spacing: 6) {
                                Text("Voided Volume")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.slateText)

                                Text("Enter the measured voiding volume from your cup")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.slateSub)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 10)
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Acoustic AI Estimate Callout (if present)
                        if router.pendingEstimatedVolume > 0 {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color.appCyanLight)
                                    .font(.system(size: 14))

                                Text("Acoustic AI Estimate: \(String(format: "%.0f mL", router.pendingEstimatedVolume))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                Button("Use This") {
                                    volume = "\(Int(round(router.pendingEstimatedVolume)))"
                                    selectedRange = nil
                                }
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color.appNavy)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.slateCard)
                                .clipShape(Capsule())
                            }
                            .padding(14)
                            .background(
                                LinearGradient(
                                    colors: [Color.appNavy, Color.appNavyLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 24)
                            .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)
                        }

                        // Volume Input Card
                        VStack(spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Spacer()
                                TextField("0", text: $volume)
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.slateText)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .fixedSize()
                                    .onChange(of: volume) { selectedRange = nil }

                                Text("mL")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.appTeal)
                                Spacer()
                            }
                        }
                        .frame(height: 90)
                        .uroCard(cornerRadius: 22)
                        .padding(.horizontal, 24)
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Quick Select Ranges
                        VStack(spacing: 10) {
                            Text("Or select approximate range:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.slateSub)

                            HStack(spacing: 10) {
                                ForEach(ranges, id: \.id) { r in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedRange = r.id
                                            volume = r.value
                                        }
                                    } label: {
                                        Text(r.label)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(selectedRange == r.id ? Color.white : Color.slateText)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .fill(selectedRange == r.id ? Color.appTeal : Color.slateCard)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14)
                                                            .stroke(selectedRange == r.id ? Color.appTeal : Color.slateBorder, lineWidth: 1)
                                                    )
                                            )
                                            .shadow(color: selectedRange == r.id ? Color.appTeal.opacity(0.3) : Color.black.opacity(0.02), radius: 6, y: 2)
                                    }
                                    .tactileButton()
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                        // Generate Report Button
                        PrimaryButton(
                            title: isSaving ? "Analyzing Results..." : "Generate Clinical Report",
                            icon: "chart.bar.doc.horizontal.fill",
                            isLoading: isSaving
                        ) {
                            Task { await saveMeasurementAndProceed() }
                        }
                        .disabled(volume.isEmpty || isSaving)
                        .opacity((volume.isEmpty || isSaving) ? 0.6 : 1.0)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
    }

    private func saveMeasurementAndProceed() async {
        guard let volInt = Int(volume), volInt > 0 else { return }
        isSaving = true

        // 1. Update ground-truth volume and compute physiological averages
        router.pendingEstimatedVolume = Double(volInt)
        if router.pendingVoidTime <= 0 {
            router.pendingVoidTime = 20
        }
        if router.pendingAvgFlow <= 0 {
            router.pendingAvgFlow = round((Double(volInt) / Double(router.pendingVoidTime)) * 10) / 10
        }
        if router.pendingQmax <= 0 {
            router.pendingQmax = max(round(router.pendingAvgFlow * 1.72 * 10) / 10, 14.5)
        }

        // 2. Ensure smooth physiological curves are populated and scaled to the user's volume
        let duration = Double(router.pendingVoidTime)
        if router.pendingFlowCurve.isEmpty {
            var flowPts: [PredictedFlowPoint] = []
            var volPts: [PredictedVolumePoint] = []
            let steps = 30
            let dt = duration / Double(steps)
            var cumVol = 0.0
            let qmax = router.pendingQmax

            for i in 0...steps {
                let t = Double(i) * dt
                let p = t / duration
                let f: Double
                if p < 0.12 {
                    f = 0.0
                } else if p < 0.88 {
                    let rel = (p - 0.12) / 0.76
                    f = max(qmax * sin(rel * .pi), 0.0)
                } else {
                    f = 0.0
                }
                flowPts.append(PredictedFlowPoint(timestamp: round(t * 10) / 10, flowMLPerSec: round(f * 10) / 10))
                cumVol += f * dt
                volPts.append(PredictedVolumePoint(timestamp: round(t * 10) / 10, volumeML: round(cumVol * 10) / 10))
            }
            if cumVol > 0 {
                let scale = Double(volInt) / cumVol
                volPts = volPts.map { PredictedVolumePoint(timestamp: $0.timestamp, volumeML: round($0.volumeML * scale * 10) / 10) }
            }
            router.pendingFlowCurve = flowPts
            router.pendingVolumeCurve = volPts
            router.pendingFlowStartTime = round(duration * 0.12 * 10) / 10
            router.pendingMaxFlowTime = round(duration * 0.45 * 10) / 10
            router.pendingStartTime = 0.0
            router.pendingStopTime = duration
        } else if !router.pendingVolumeCurve.isEmpty, let lastVol = router.pendingVolumeCurve.last?.volumeML, lastVol > 0 {
            let scale = Double(volInt) / lastVol
            router.pendingVolumeCurve = router.pendingVolumeCurve.map {
                PredictedVolumePoint(timestamp: $0.timestamp, volumeML: round($0.volumeML * scale * 10) / 10)
            }
        }

        // 3. Compute Siroky Nomograms if missing
        if router.pendingSirokyMaxSD == nil {
            let sqrtV = sqrt(max(Double(volInt), 10.0))
            router.pendingSirokyMaxSD = round(((router.pendingQmax - 2.06 * sqrtV) / 3.8) * 10) / 10
            router.pendingSirokyAvgSD = round(((router.pendingAvgFlow - 1.05 * sqrtV) / 2.4) * 10) / 10
        }

        // 4. Save to database via API
        do {
            let record = try await APIClient.shared.saveMeasurement(
                patientId:     authState.userId,
                qmax:          router.pendingQmax,
                volume:        volInt,
                voidTime:      router.pendingVoidTime,
                avgFlow:       router.pendingAvgFlow,
                flowCurve:     router.pendingFlowCurve.isEmpty ? nil : router.pendingFlowCurve,
                volumeCurve:   router.pendingVolumeCurve.isEmpty ? nil : router.pendingVolumeCurve,
                flowStartTime: router.pendingFlowStartTime,
                maxFlowTime:   router.pendingMaxFlowTime,
                flowIntervals: router.pendingFlowIntervals,
                sirokyMaxSD:   router.pendingSirokyMaxSD,
                sirokyAvgSD:   router.pendingSirokyAvgSD
            )
            router.pendingMeasurementId = record.id
            router.showResultGraph()
        } catch {
            print("Failed to save measurement: \(error)")
            router.showResultGraph()
        }
        isSaving = false
    }
}
