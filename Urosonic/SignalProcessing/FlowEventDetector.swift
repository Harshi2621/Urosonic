// FlowEventDetector.swift
// Urosonic — Phase 3 Deterministic Urination Acoustic Event Detection with Noise Floor Estimation and Hysteresis

import Foundation

enum FlowDetectionState: String, Sendable {
    case idle        = "READY"
    case calibrating = "Calibrating baseline..."
    case listening   = "Listening..."
    case starting    = "Possible flow detected"
    case active      = "FLOW DETECTED"
    case ending      = "Flow ending..."
    case completed   = "Flow ended"
}

enum FlowEventState: String, Codable, Sendable {
    case starting
    case active
    case ending
    case completed
}

struct FlowEvent: Identifiable, Sendable {
    let id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var duration: TimeInterval {
        max(0, endTime - startTime)
    }
    var peakDBFS: Float
    var averageDBFS: Float
    var confidence: Float
    var state: FlowEventState

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        peakDBFS: Float,
        averageDBFS: Float,
        confidence: Float,
        state: FlowEventState
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.peakDBFS = peakDBFS
        self.averageDBFS = averageDBFS
        self.confidence = confidence
        self.state = state
    }
}

struct DetectorConfig: Sendable {
    var calibrationDuration: TimeInterval = 2.0     // Initial seconds used to determine environmental noise floor
    var startMarginDB: Float = 8.0                  // dB rise above noise floor required to trigger start
    var endMarginDB: Float = 4.0                    // dB drop below noise floor + margin to trigger end (Hysteresis)
    var minimumStartDuration: TimeInterval = 0.5    // Minimum duration above start threshold to enter active flow
    var minimumEndDuration: TimeInterval = 1.0      // Minimum duration below end threshold to confirm flow cessation
    var minimumEventDuration: TimeInterval = 1.5    // Minimum total duration for a valid completed urination event
}

final class FlowEventDetector {
    private let config: DetectorConfig
    private(set) var currentState: FlowDetectionState = .idle
    private(set) var noiseFloorDBFS: Float = -60.0   // Baseline estimated noise floor
    private var calibrationSamples: [Float] = []
    private var isCalibrated: Bool = false

    // State transition timers & accumulators
    private var candidateStartTime: TimeInterval?
    private var candidateEndTime: TimeInterval?
    private var activeEventFrames: [AudioFrameFeature] = []

    // Detected events list
    private(set) var completedEvents: [FlowEvent] = []
    private(set) var activeEvent: FlowEvent?

    init(config: DetectorConfig = DetectorConfig()) {
        self.config = config
    }

    func reset() {
        currentState = .idle
        noiseFloorDBFS = -60.0
        calibrationSamples.removeAll()
        isCalibrated = false
        candidateStartTime = nil
        candidateEndTime = nil
        activeEventFrames.removeAll()
        completedEvents.removeAll()
        activeEvent = nil
    }

    /// Process a new audio frame and advance the deterministic state machine.
    func process(frame: AudioFrameFeature) -> FlowDetectionState {
        let t = frame.timestamp
        let db = frame.dbFS

        // 1. Calibration Phase (First N seconds)
        if !isCalibrated {
            currentState = .calibrating
            calibrationSamples.append(db)

            if t >= config.calibrationDuration && !calibrationSamples.isEmpty {
                // Calculate baseline average dBFS (excluding top 10% outliers)
                let sorted = calibrationSamples.sorted()
                let countToKeep = max(1, Int(Float(sorted.count) * 0.9))
                let kept = sorted.prefix(countToKeep)
                let avg = kept.reduce(0.0, +) / Float(kept.count)

                // Clamp baseline reasonably between -80 dBFS and -25 dBFS
                noiseFloorDBFS = min(max(avg, -80.0), -25.0)
                isCalibrated = true
                currentState = .listening
            }
            return currentState
        }

        let startThreshold = noiseFloorDBFS + config.startMarginDB
        let endThreshold = noiseFloorDBFS + config.endMarginDB

        // 2. State Machine
        switch currentState {
        case .idle, .calibrating:
            // Handled above
            break

        case .listening:
            if db >= startThreshold {
                // Signal rose above start threshold — begin temporal validation
                candidateStartTime = t
                currentState = .starting
            }

        case .starting:
            if db >= startThreshold {
                guard let start = candidateStartTime else {
                    candidateStartTime = t
                    return currentState
                }

                // Check if signal has remained sustained above threshold for minimum start duration
                if (t - start) >= config.minimumStartDuration {
                    currentState = .active
                    activeEvent = FlowEvent(
                        startTime: start,
                        endTime: t,
                        peakDBFS: db,
                        averageDBFS: db,
                        confidence: 0.5,
                        state: .active
                    )
                    activeEventFrames.append(frame)
                }
            } else {
                // Signal dropped before reaching minimum start duration — reject as transient noise (click/cough)
                candidateStartTime = nil
                currentState = .listening
            }

        case .active:
            activeEventFrames.append(frame)
            if var current = activeEvent {
                current.endTime = t
                current.peakDBFS = max(current.peakDBFS, db)
                activeEvent = current
            }

            if db < endThreshold {
                // Signal dropped below hysteresis end threshold — candidate flow end
                candidateEndTime = t
                currentState = .ending
            }

        case .ending:
            activeEventFrames.append(frame)
            if var current = activeEvent {
                current.endTime = t
                activeEvent = current
            }

            if db < endThreshold {
                guard let end = candidateEndTime else {
                    candidateEndTime = t
                    return currentState
                }

                // Check if silence has remained sustained below threshold for minimum end duration
                if (t - end) >= config.minimumEndDuration {
                    // Finalize event
                    finalizeActiveEvent(endTime: end)
                    currentState = .completed
                }
            } else {
                // Flow resumed! Cancel candidate end and return to active
                candidateEndTime = nil
                currentState = .active
            }

        case .completed:
            // Stay completed unless a new sustained rise occurs
            if db >= startThreshold {
                candidateStartTime = t
                currentState = .starting
            }
        }

        return currentState
    }

    /// Explicitly finalize the active event when user taps Stop Recording.
    func finishRecording(at timestamp: TimeInterval) {
        if currentState == .active || currentState == .ending || currentState == .starting {
            let effectiveEnd = candidateEndTime ?? timestamp
            finalizeActiveEvent(endTime: effectiveEnd)
        }
        currentState = .completed
    }

    private func finalizeActiveEvent(endTime: TimeInterval) {
        guard var event = activeEvent else { return }
        event.endTime = endTime
        let duration = max(0, event.endTime - event.startTime)

        // Only keep as a validated event if duration exceeds minimum requirement
        if duration >= config.minimumEventDuration && !activeEventFrames.isEmpty {
            let avgDB = activeEventFrames.map { $0.dbFS }.reduce(0, +) / Float(activeEventFrames.count)
            let peakDB = activeEventFrames.map { $0.dbFS }.max() ?? event.peakDBFS

            // Confidence score: based on duration and margin above noise floor
            let margin = max(0, avgDB - noiseFloorDBFS)
            let confidence = min(1.0, max(0.2, (Float(duration) / 10.0) * 0.5 + (margin / 20.0) * 0.5))

            event.averageDBFS = avgDB
            event.peakDBFS = peakDB
            event.confidence = confidence
            event.state = .completed

            completedEvents.append(event)
        }

        activeEvent = nil
        activeEventFrames.removeAll()
        candidateStartTime = nil
        candidateEndTime = nil
    }
}
