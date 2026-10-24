// AudioCaptureService.swift
// Urosonic — Core AVAudioEngine Microphone Audio Capture & Feature Pipeline Coordinator

import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
final class AudioCaptureService: ObservableObject {
    static let shared = AudioCaptureService()

    // MARK: - Published State for SwiftUI Views
    @Published var isRecording: Bool = false
    @Published var isCalibrating: Bool = false
    @Published var currentDBFS: Float = -100.0
    @Published var currentRMS: Float = 0.0
    @Published var currentPeak: Float = 0.0
    @Published var dominantFrequency: Float = 0.0
    @Published var noiseFloorDBFS: Float = -60.0
    @Published var liveWaveform: [CGFloat] = [CGFloat](repeating: 0.05, count: 40)

    @Published var detectorState: FlowDetectionState = .idle
    @Published var activeEvent: FlowEvent? = nil
    @Published var detectedEvents: [FlowEvent] = []

    @Published var recordedFeatures: [AudioFrameFeature] = []
    @Published var recordingSession: RecordingSession? = nil
    @Published var errorMessage: String? = nil
    @Published var permissionGranted: Bool = false

    // MARK: - Internal Audio Engine Components
    private var audioEngine: AVAudioEngine?
    private var fileWriter: AudioRecordingFileWriter?
    private let bufferProcessor: AudioBufferProcessor
    private let sessionManager = AudioSessionManager.shared
    private var sessionStartTime: Date = Date()

    // Maximum in-memory features to prevent unbound memory growth during long recordings
    private let maxStoredFeatures = 3000

    init() {
        let processor = AudioBufferProcessor()
        self.bufferProcessor = processor
        processor.setDelegate(self)

        setupInterruptionHandling()
    }

    // MARK: - Permission Check
    func checkMicrophonePermission() async -> Bool {
        let granted = await sessionManager.requestPermission()
        self.permissionGranted = granted
        if !granted {
            self.errorMessage = "Microphone access is required to perform acoustic recordings."
        }
        return granted
    }

    // MARK: - Start Real Audio Recording
    func startRecording() async -> Bool {
        guard !isRecording else { return true }

        // 1. Verify Permission
        let hasPermission = await checkMicrophonePermission()
        guard hasPermission else { return false }

        // 2. Configure and Activate Audio Session
        do {
            try sessionManager.configureForRecording()
            try sessionManager.activateSession()
        } catch {
            self.errorMessage = "Failed to start audio session: \(error.localizedDescription)"
            return false
        }

        // 3. Reset internal buffers & feature history
        bufferProcessor.reset()
        recordedFeatures.removeAll()
        detectedEvents.removeAll()
        activeEvent = nil
        errorMessage = nil
        detectorState = .calibrating
        sessionStartTime = Date()

        // 4. Create and Configure AVAudioEngine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)

        guard hardwareFormat.sampleRate > 0 else {
            self.errorMessage = "Audio hardware input format is invalid or unavailable."
            sessionManager.deactivateSession()
            return false
        }

        // 5. Initialize WAV file writer
        do {
            self.fileWriter = try AudioRecordingFileWriter(format: hardwareFormat)
        } catch {
            self.errorMessage = "Failed to initialize WAV file: \(error.localizedDescription)"
            sessionManager.deactivateSession()
            return false
        }

        // 6. Install Tap on Input Node
        // Buffer size: 1024 samples (approx 23ms at 44.1kHz)
        let bufferSize: AVAudioFrameCount = 1024
        let startTime = self.sessionStartTime

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Write audio to disk
            self.fileWriter?.write(buffer: buffer)
            // Process buffer for live DSP & event detection
            self.bufferProcessor.process(buffer: buffer, sessionStartTime: startTime)
        }

        // 7. Start Engine
        do {
            engine.prepare()
            try engine.start()
            self.audioEngine = engine
            self.isRecording = true
            return true
        } catch {
            inputNode.removeTap(onBus: 0)
            sessionManager.deactivateSession()
            self.errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Stop Real Audio Recording
    func stopRecording() {
        guard isRecording else { return }

        // 1. Remove Tap & Stop Audio Engine
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            self.audioEngine = nil
        }

        // 2. Deactivate Audio Session
        sessionManager.deactivateSession()

        // 3. Finalize WAV File
        if let writer = fileWriter {
            let finalizedSession = writer.finish()
            self.recordingSession = finalizedSession
            self.fileWriter = nil
        }

        // 4. Finalize Flow Event Detection
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        let (finalEvents, finalNoiseFloor) = bufferProcessor.finalizeDetection(at: elapsed)
        self.detectedEvents = finalEvents
        self.noiseFloorDBFS = finalNoiseFloor
        self.detectorState = .completed

        self.isRecording = false
    }

    // MARK: - Interruption Handling
    private func setupInterruptionHandling() {
        sessionManager.onInterruption = { [weak self] type in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if type == .began && self.isRecording {
                    print("[AudioCaptureService] Audio interrupted — stopping recording.")
                    self.stopRecording()
                    self.errorMessage = "Recording was interrupted by system audio or incoming call."
                }
            }
        }
    }
}

// MARK: - AudioBufferProcessorDelegate Implementation
extension AudioCaptureService: AudioBufferProcessorDelegate {
    nonisolated func didExtractFeature(_ feature: AudioFrameFeature) {
        Task { @MainActor [weak self] in
            guard let self = self, self.isRecording else { return }
            if self.recordedFeatures.count < self.maxStoredFeatures {
                self.recordedFeatures.append(feature)
            }
        }
    }

    nonisolated func didUpdateLiveAcoustics(
        dbFS: Float,
        rms: Float,
        peak: Float,
        waveformPoints: [CGFloat],
        dominantFreq: Float
    ) {
        Task { @MainActor [weak self] in
            guard let self = self, self.isRecording else { return }
            self.currentDBFS = dbFS
            self.currentRMS = rms
            self.currentPeak = peak
            self.liveWaveform = waveformPoints
            self.dominantFrequency = dominantFreq
        }
    }

    nonisolated func didChangeDetectorState(_ state: FlowDetectionState, activeEvent: FlowEvent?) {
        Task { @MainActor [weak self] in
            guard let self = self, self.isRecording else { return }
            self.detectorState = state
            self.activeEvent = activeEvent
        }
    }
}
