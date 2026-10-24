// AudioBufferProcessor.swift
// Urosonic — Audio Buffer Processing and Live Waveform Downsampling

import AVFoundation
import Accelerate
import Foundation

protocol AudioBufferProcessorDelegate: AnyObject, Sendable {
    func didExtractFeature(_ feature: AudioFrameFeature)
    func didUpdateLiveAcoustics(
        dbFS: Float,
        rms: Float,
        peak: Float,
        waveformPoints: [CGFloat],
        dominantFreq: Float
    )
    func didChangeDetectorState(_ state: FlowDetectionState, activeEvent: FlowEvent?)
}

final class AudioBufferProcessor: @unchecked Sendable {
    private let processingQueue = DispatchQueue(label: "com.urosonic.audio.processor", qos: .userInteractive)
    private let featureExtractor: AudioFeatureExtractor
    private let detector: FlowEventDetector
    private weak var delegate: AudioBufferProcessorDelegate?

    // UI Throttling
    private var lastUIUpdateTime: TimeInterval = 0
    private let minUIUpdateInterval: TimeInterval = 1.0 / 40.0 // ~40 FPS for smooth UI without SwiftUI lag

    // Ring buffer for smooth live waveform display (40 bars / slices)
    private let waveformCapacity = 40
    private var recentWaveformAmplitudes: [CGFloat] = []
    private var totalProcessedSamples: Int64 = 0

    init(
        featureExtractor: AudioFeatureExtractor = AudioFeatureExtractor(fftSize: 1024),
        detector: FlowEventDetector = FlowEventDetector(),
        delegate: AudioBufferProcessorDelegate? = nil
    ) {
        self.featureExtractor = featureExtractor
        self.detector = detector
        self.delegate = delegate
        self.recentWaveformAmplitudes = [CGFloat](repeating: 0.05, count: waveformCapacity)
    }

    func setDelegate(_ delegate: AudioBufferProcessorDelegate?) {
        self.delegate = delegate
    }

    func reset() {
        processingQueue.sync {
            detector.reset()
            recentWaveformAmplitudes = [CGFloat](repeating: 0.05, count: waveformCapacity)
            totalProcessedSamples = 0
            lastUIUpdateTime = 0
        }
    }

    /// Ingest an incoming PCM buffer from AVAudioEngine input tap.
    func process(buffer: AVAudioPCMBuffer, sessionStartTime: Date) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // Copy raw float channel 0 samples
        let rawSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        let sampleRate = Float(buffer.format.sampleRate)

        // Compute sample-accurate physical audio timestamp (hardware accurate, strictly monotonic)
        let sampleOffset = totalProcessedSamples
        totalProcessedSamples += Int64(frameCount)
        let timestamp = sampleRate > 0
            ? Double(sampleOffset) / Double(sampleRate)
            : Date().timeIntervalSince(sessionStartTime)

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Extract physical acoustic features
            let feature = self.featureExtractor.extractFeatures(
                from: rawSamples,
                timestamp: timestamp,
                sampleRate: sampleRate
            )

            // 2. Feed into deterministic flow event detector
            let detectorState = self.detector.process(frame: feature)
            let activeEvent = self.detector.activeEvent

            // Notify feature logging delegate
            self.delegate?.didExtractFeature(feature)
            self.delegate?.didChangeDetectorState(detectorState, activeEvent: activeEvent)

            // 3. Downsample for live visual waveform
            // Convert peak/RMS to normalized [0.0...1.0] visual bar height
            let normalizedAmp = CGFloat(min(max(feature.peak * 2.5, 0.04), 1.0))
            if self.recentWaveformAmplitudes.count >= self.waveformCapacity {
                self.recentWaveformAmplitudes.removeFirst()
            }
            self.recentWaveformAmplitudes.append(normalizedAmp)

            // 4. Throttle UI state dispatch to ~40 updates/sec
            let now = CACurrentMediaTime()
            if (now - self.lastUIUpdateTime) >= self.minUIUpdateInterval {
                self.lastUIUpdateTime = now
                let waveformCopy = self.recentWaveformAmplitudes
                let currentDBFS = feature.dbFS
                let currentRMS = feature.rms
                let currentPeak = feature.peak
                let domFreq = feature.dominantFrequency

                self.delegate?.didUpdateLiveAcoustics(
                    dbFS: currentDBFS,
                    rms: currentRMS,
                    peak: currentPeak,
                    waveformPoints: waveformCopy,
                    dominantFreq: domFreq
                )
            }
        }
    }

    /// Finalize detection when recording stops
    func finalizeDetection(at timestamp: TimeInterval) -> (events: [FlowEvent], noiseFloor: Float) {
        return processingQueue.sync {
            detector.finishRecording(at: timestamp)
            return (detector.completedEvents, detector.noiseFloorDBFS)
        }
    }
}
