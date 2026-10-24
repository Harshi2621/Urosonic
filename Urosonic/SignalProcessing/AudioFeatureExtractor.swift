// AudioFeatureExtractor.swift
// Urosonic — Acoustic Feature Extraction Pipeline

import Accelerate
import Foundation

struct AudioFrameFeature: Identifiable, Sendable {
    let id: UUID
    let timestamp: TimeInterval      // Seconds relative to session start
    let rms: Float                  // Root Mean Square amplitude (0.0 to 1.0)
    let peak: Float                 // Peak absolute amplitude (0.0 to 1.0)
    let dbFS: Float                 // Decibels relative to Full Scale (-100 dBFS to 0 dBFS)
    let dominantFrequency: Float    // Dominant frequency in Hz
    let spectralCentroid: Float     // Center of mass of the spectrum in Hz
    let spectralEnergy: Float       // Acoustic energy in window

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        rms: Float,
        peak: Float,
        dbFS: Float,
        dominantFrequency: Float,
        spectralCentroid: Float,
        spectralEnergy: Float
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rms = rms
        self.peak = peak
        self.dbFS = dbFS
        self.dominantFrequency = dominantFrequency
        self.spectralCentroid = spectralCentroid
        self.spectralEnergy = spectralEnergy
    }
}

final class AudioFeatureExtractor {
    private let fftProcessor: FFTProcessor
    private let minDBFS: Float = -100.0

    init(fftSize: Int = 1024) {
        self.fftProcessor = FFTProcessor(fftSize: fftSize)
    }

    /// Extract comprehensive acoustic features from a raw PCM window of float samples.
    func extractFeatures(
        from samples: [Float],
        timestamp: TimeInterval,
        sampleRate: Float
    ) -> AudioFrameFeature {
        guard !samples.isEmpty else {
            return AudioFrameFeature(
                timestamp: timestamp,
                rms: 0.0,
                peak: 0.0,
                dbFS: minDBFS,
                dominantFrequency: 0.0,
                spectralCentroid: 0.0,
                spectralEnergy: 0.0
            )
        }

        let count = vDSP_Length(samples.count)

        // 1. Calculate RMS amplitude using Accelerate
        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, count)

        // 2. Calculate Peak amplitude (absolute maximum) using Accelerate
        var peak: Float = 0.0
        vDSP_maxmgv(samples, 1, &peak, count)

        // 3. Calculate dBFS: 20 * log10(rms / reference), reference = 1.0 full scale float
        // Clamp silence floor at 1e-5 (-100 dBFS) to avoid -infinity
        let safeRMS = max(rms, 1e-5)
        var dbFS = 20.0 * log10(safeRMS)
        if dbFS.isNaN || dbFS.isInfinite {
            dbFS = minDBFS
        } else {
            dbFS = min(max(dbFS, minDBFS), 0.0)
        }

        // 4. Spectral analysis via FFT
        let spectral = fftProcessor.process(samples: samples, sampleRate: sampleRate)

        return AudioFrameFeature(
            timestamp: timestamp,
            rms: rms,
            peak: peak,
            dbFS: dbFS,
            dominantFrequency: spectral.dominantFrequency,
            spectralCentroid: spectral.spectralCentroid,
            spectralEnergy: spectral.spectralEnergy
        )
    }
}
