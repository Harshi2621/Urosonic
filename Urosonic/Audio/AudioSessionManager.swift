// AudioSessionManager.swift
// Urosonic — Audio Session Management for Acoustic Recording

import AVFoundation
import Foundation

enum AudioSessionError: LocalizedError {
    case permissionDenied
    case configurationFailed(String)
    case activationFailed(String)
    case deviceUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission was denied. Please allow microphone access in Settings."
        case .configurationFailed(let msg):
            return "Failed to configure audio session: \(msg)"
        case .activationFailed(let msg):
            return "Failed to activate audio session: \(msg)"
        case .deviceUnavailable:
            return "No audio recording input device is available."
        }
    }
}

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private let audioSession = AVAudioSession.sharedInstance()
    private var interruptionObserver: NSObjectProtocol?

    var onInterruption: ((AVAudioSession.InterruptionType) -> Void)?

    private init() {
        setupInterruptionObserver()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Permission Handling
    func checkPermission() -> AVAudioApplication.recordPermission {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission
        } else {
            switch audioSession.recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                return .undetermined
            @unknown default:
                return .undetermined
            }
        }
    }

    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Audio Session Configuration
    func configureForRecording() throws {
        let permission = checkPermission()
        guard permission != .denied else {
            throw AudioSessionError.permissionDenied
        }

        do {
            // Configure for clinical acoustic measurement
            try audioSession.setCategory(
                .record,
                mode: .measurement,
                options: []
            )

            // Prefer 44.1 kHz sample rate if hardware supports it
            try audioSession.setPreferredSampleRate(44100.0)
            // Low latency / appropriate buffer duration (approx 20ms)
            try audioSession.setPreferredIOBufferDuration(0.02)
        } catch {
            throw AudioSessionError.configurationFailed(error.localizedDescription)
        }
    }

    func activateSession() throws {
        do {
            try audioSession.setActive(true)
        } catch {
            throw AudioSessionError.activationFailed(error.localizedDescription)
        }
    }

    func deactivateSession() {
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("[AudioSessionManager] Deactivation warning: \(error.localizedDescription)")
        }
    }

    // MARK: - Interruption Handling
    private func setupInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            self?.onInterruption?(type)
        }
    }
}
