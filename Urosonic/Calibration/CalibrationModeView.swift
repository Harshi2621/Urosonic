// CalibrationModeView.swift
// Urosonic — Phase 4 Research & Calibration Mode Dashboard

import SwiftUI
import Combine

struct CalibrationModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = CalibrationSessionManager.shared
    @StateObject private var audioService = AudioCaptureService.shared

    // Navigation & Sheet States
    @State private var isLiveRecording = false
    @State private var recordingSeconds = 0
    @State private var activeMetadata = ExperimentalMetadata.currentDeviceDefaults()

    @State private var sessionForGroundTruth: CalibrationSession? = nil
    @State private var sessionForDualGraph: CalibrationSession? = nil
    @State private var sessionForMetadataEdit: CalibrationSession? = nil

    @State private var exportedURL: URL? = nil
    @State private var isSharingExport = false
    @State private var alertMessage: String? = nil
    @State private var showAlert = false

    let recordingTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F8FAFC").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Status Banner
                    researchModeBanner

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // 1. Dataset Quality Summary Card
                            if let report = manager.qualityReport {
                                qualityReportCard(report: report)
                            }

                            // 2. Action Controls (Record New / Export)
                            HStack(spacing: 12) {
                                Button {
                                    startNewCalibrationRecording()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "record.circle.fill")
                                            .foregroundColor(.red)
                                        Text("New Calibration Run")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.slateCard)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))
                                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                                }

                                Button {
                                    triggerDatasetExport()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up.fill")
                                        Text("Export Dataset")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.appTeal)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.appTeal.opacity(0.3), radius: 6, y: 2)
                                }
                            }
                            .padding(.horizontal, 16)

                            // 3. Sessions List
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Calibration Sessions (\(manager.sessions.count))")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.slateText)
                                    Spacer()
                                    Text("Swipe to Delete")
                                        .font(.system(size: 10))
                                        .foregroundColor(.slateSub)
                                }
                                .padding(.horizontal, 16)

                                if manager.sessions.isEmpty {
                                    emptySessionsPlaceholder
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(manager.sessions) { session in
                                            calibrationSessionCard(session: session)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            Spacer().frame(height: 30)
                        }
                        .padding(.top, 14)
                    }
                }
            }
            .navigationTitle("Calibration & Research Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Exit") { dismiss() }
                }
            }
            // Active Live Calibration Recording Sheet
            .fullScreenCover(isPresented: $isLiveRecording) {
                calibrationLiveRecordingView
            }
            // Ground Truth Input Sheet
            .sheet(item: $sessionForGroundTruth) { session in
                GroundTruthInputView(session: session) { updatedGT in
                    manager.updateGroundTruth(sessionId: session.id, groundTruth: updatedGT)
                }
            }
            // Dual Graph Inspection Sheet
            .sheet(item: $sessionForDualGraph) { session in
                AcousticVsGroundTruthView(session: session)
            }
            // Dataset Share Sheet
            .sheet(isPresented: $isSharingExport) {
                if let url = exportedURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Calibration Lab", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // MARK: - Research Mode Banner
    private var researchModeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "flask.fill")
                .foregroundColor(Color(hex: "F59E0B"))
            Text("Calibration / Research Mode • Phase 4 Ground-Truth Alignment")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "92400E"))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "FEF3C7"))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "FDE68A")), alignment: .bottom)
    }

    // MARK: - Quality Report Card
    private func qualityReportCard(report: DatasetQualityReport) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label("Dataset Quality Metrics", systemImage: "chart.pie.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.slateText)
                Spacer()
                Text("ML Readiness")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(report.validSessions > 0 ? Color.appTeal.opacity(0.12) : Color.slateBorder)
                    .foregroundColor(report.validSessions > 0 ? Color.appTeal : Color.slateSub)
                    .clipShape(Capsule())
            }

            Divider().background(Color.slateBorder.opacity(0.5))

            HStack(spacing: 12) {
                metricCell(title: "Total", value: "\(report.totalSessions)", color: .slateText)
                metricCell(title: "Valid", value: "\(report.validSessions)", color: Color(hex: "10B981"))
                metricCell(title: "Incomplete", value: "\(report.incompleteSessions)", color: Color(hex: "F59E0B"))
                metricCell(title: "Exported", value: "\(report.exportedSessions)", color: Color.appBlue)
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.appTeal).frame(width: 6, height: 6)
                    Text("Flow Curves: \(report.sessionsWithFlowCurves)")
                        .font(.system(size: 11))
                        .foregroundColor(.slateSub)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.slateSub).frame(width: 6, height: 6)
                    Text("Volume Only: \(report.sessionsWithTotalVolumeOnly)")
                        .font(.system(size: 11))
                        .foregroundColor(.slateSub)
                }
                Spacer()
                Text(String(format: "Avg: %.1fs", report.averageRecordingDuration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.slateSub)
            }
        }
        .padding(14)
        .background(Color.slateCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func metricCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.slateSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.slateLight.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Calibration Session Card
    private func calibrationSessionCard(session: CalibrationSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Session ID, Status Badge
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session: \(session.id.uuidString.prefix(8))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.slateText)
                    Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundColor(.slateSub)
                }
                Spacer()

                // Status Badge
                Text(session.status.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: session.status.badgeColorHex).opacity(0.15))
                    .foregroundColor(Color(hex: session.status.badgeColorHex))
                    .clipShape(Capsule())
            }

            Divider().background(Color.slateBorder.opacity(0.5))

            // Row 2: Acoustic vs Ground Truth Summary
            HStack(spacing: 16) {
                // Acoustic Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Acoustic Event")
                        .font(.system(size: 10))
                        .foregroundColor(.slateSub)
                    if let dur = session.eventDuration {
                        Text(String(format: "%.1f s", dur))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.appTeal)
                    } else {
                        Text("No Event")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.slateSub)
                    }
                    Text(String(format: "%d frames", session.acousticFeatures.count))
                        .font(.system(size: 9))
                        .foregroundColor(.slateSub)
                }

                Spacer()

                // Ground Truth Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ground Truth")
                        .font(.system(size: 10))
                        .foregroundColor(.slateSub)
                    if let gt = session.groundTruth {
                        Text(String(format: "%.0f mL (%.1fs)", gt.totalVolumeML, gt.duration))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "10B981"))
                        Text("\(gt.flowPoints.count) curve points")
                            .font(.system(size: 9))
                            .foregroundColor(.slateSub)
                    } else {
                        Text("Missing")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "F59E0B"))
                        Text("Tap below to enter")
                            .font(.system(size: 9))
                            .foregroundColor(.slateSub)
                    }
                }

                Spacer()

                // Setup Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.metadata.deviceModel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.slateText)
                    if let dist = session.metadata.recordingDistanceInches {
                        Text(String(format: "Dist: %.0f\"", dist))
                            .font(.system(size: 9))
                            .foregroundColor(.slateSub)
                    }
                    Text(session.metadata.environment)
                        .font(.system(size: 9))
                        .foregroundColor(.slateSub)
                        .lineLimit(1)
                }
            }

            // Row 3: Action Buttons
            HStack(spacing: 10) {
                Button {
                    sessionForGroundTruth = session
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: session.groundTruth == nil ? "plus.circle.fill" : "pencil.circle.fill")
                        Text(session.groundTruth == nil ? "Attach Ground Truth" : "Edit Ground Truth")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.appTeal.opacity(0.1))
                    .foregroundColor(.appTeal)
                    .cornerRadius(8)
                }

                Button {
                    sessionForDualGraph = session
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                        Text("Compare Timelines")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.slateLight)
                    .foregroundColor(.slateText)
                    .cornerRadius(8)
                }

                Button {
                    manager.deleteSession(id: session.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color.slateCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 1))
    }

    private var emptySessionsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "flask")
                .font(.system(size: 36))
                .foregroundColor(.slateSub.opacity(0.5))
            Text("No calibration sessions recorded yet")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.slateText)
            Text("Tap \"New Calibration Run\" to capture microphone audio and pair it with an independent ground-truth flow measurement.")
                .font(.system(size: 12))
                .foregroundColor(.slateSub)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.slateCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Live Calibration Recording Modal
    private var calibrationLiveRecordingView: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Calibration Recording")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Controlled Physical Acoustic Measurement")
                            .font(.system(size: 11))
                            .foregroundColor(.slateSub)
                    }
                    Spacer()
                    Button("Cancel") {
                        audioService.stopRecording()
                        isLiveRecording = false
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                Spacer()

                // Live Audio Waveform
                WaveformView(waveformPoints: audioService.liveWaveform, color: Color.appTeal)
                    .frame(height: 120)
                    .padding(.horizontal, 20)

                // Timer & Live Telemetry
                VStack(spacing: 10) {
                    let m = recordingSeconds / 60
                    let s = recordingSeconds % 60
                    Text(String(format: "%02d:%02d", m, s))
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text(audioService.detectorState.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(audioService.detectorState == .active ? Color(hex: "10B981") : Color.appTeal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }

                // Acoustic Metrics Grid
                HStack(spacing: 16) {
                    VStack {
                        Text("Signal Level").font(.system(size: 10)).foregroundColor(.slateSub)
                        Text(String(format: "%.1f dBFS", audioService.currentDBFS))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    VStack {
                        Text("Dominant Freq").font(.system(size: 10)).foregroundColor(.slateSub)
                        Text(String(format: "%.0f Hz", audioService.dominantFrequency))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    VStack {
                        Text("Noise Floor").font(.system(size: 10)).foregroundColor(.slateSub)
                        Text(String(format: "%.0f dBFS", audioService.noiseFloorDBFS))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal, 20)

                Spacer()

                // Stop Button
                Button {
                    stopAndSaveCalibrationRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "EF4444"))
                            .frame(width: 80, height: 80)
                            .shadow(color: Color(hex: "EF4444").opacity(0.5), radius: 15)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onReceive(recordingTimer) { _ in
            if isLiveRecording {
                recordingSeconds += 1
            }
        }
    }

    // MARK: - Actions
    private func startNewCalibrationRecording() {
        Task {
            let started = await audioService.startRecording()
            if started {
                recordingSeconds = 0
                isLiveRecording = true
            } else {
                alertMessage = audioService.errorMessage ?? "Microphone permission required."
                showAlert = true
            }
        }
    }

    private func stopAndSaveCalibrationRecording() {
        audioService.stopRecording()
        isLiveRecording = false

        guard let session = audioService.recordingSession else { return }

        // Create new calibration session and save to manager
        let newSession = manager.addSession(
            recordingSession: session,
            metadata: activeMetadata,
            features: audioService.recordedFeatures,
            events: audioService.detectedEvents,
            noiseFloor: audioService.noiseFloorDBFS
        )

        // Automatically prompt to attach ground truth
        sessionForGroundTruth = newSession
    }

    private func triggerDatasetExport() {
        guard !manager.sessions.isEmpty else {
            alertMessage = "No calibration sessions available to export. Record at least one calibration session first."
            showAlert = true
            return
        }

        do {
            let url = try manager.exportAllSessions()
            self.exportedURL = url
            self.isSharingExport = true
        } catch {
            alertMessage = "Export failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Share Sheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
