// FFTProcessor.swift
// Urosonic — Real-time FFT and Spectral Feature Extraction using Apple Accelerate / vDSP

import Accelerate
import Foundation

struct SpectralFeatures: Sendable {
    let dominantFrequency: Float // Hz
    let spectralCentroid: Float  // Hz
    let spectralEnergy: Float    // Sum of squared magnitudes
    let magnitudes: [Float]      // Half-spectrum magnitudes (0 to Nyquist)
}

final class FFTProcessor {
    let fftSize: Int
    let halfSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private var window: [Float]

    // Pre-allocated split complex buffers for zero-allocation real-time performance
    private var realp: UnsafeMutablePointer<Float>
    private var imagp: UnsafeMutablePointer<Float>
    private var splitComplex: DSPSplitComplex

    init(fftSize: Int = 1024) {
        self.fftSize = fftSize
        self.halfSize = fftSize / 2
        self.log2n = vDSP_Length(log2(Double(fftSize)))

        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to initialize vDSP FFT setup")
        }
        self.fftSetup = setup

        // Precompute Hanning window to mitigate spectral leakage
        var win = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&win, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = win

        // Preallocate split complex memory pointers that outlive init
        self.realp = UnsafeMutablePointer<Float>.allocate(capacity: halfSize)
        self.imagp = UnsafeMutablePointer<Float>.allocate(capacity: halfSize)
        self.realp.initialize(repeating: 0.0, count: halfSize)
        self.imagp.initialize(repeating: 0.0, count: halfSize)
        self.splitComplex = DSPSplitComplex(realp: self.realp, imagp: self.imagp)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
        realp.deinitialize(count: halfSize)
        realp.deallocate()
        imagp.deinitialize(count: halfSize)
        imagp.deallocate()
    }

    /// Process a window of PCM samples and return extracted spectral features.
    func process(samples: [Float], sampleRate: Float) -> SpectralFeatures {
        guard samples.count >= fftSize else {
            return SpectralFeatures(
                dominantFrequency: 0,
                spectralCentroid: 0,
                spectralEnergy: 0,
                magnitudes: [Float](repeating: 0, count: halfSize)
            )
        }

        // 1. Apply Hanning window to the first fftSize samples
        var windowed = [Float](repeating: 0.0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // 2. Pack real samples into even/odd split complex format
        windowed.withUnsafeBufferPointer { winPtr in
            winPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
            }
        }

        // 3. Perform 1D in-place Real FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // 4. Calculate magnitudes
        var magnitudes = [Float](repeating: 0.0, count: halfSize)
        // Magnitudes squared = real^2 + imag^2
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))

        // Scale factor for 1/2 size
        var scale: Float = 0.5
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfSize))

        // Square root to obtain linear magnitude
        var count = Int32(halfSize)
        vvsqrtf(&magnitudes, magnitudes, &count)

        // 5. Calculate Dominant Frequency (peak magnitude index)
        var maxMag: Float = 0.0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(magnitudes, 1, &maxMag, &maxIndex, vDSP_Length(halfSize))

        let binWidth = sampleRate / Float(fftSize)
        let dominantFreq = Float(maxIndex) * binWidth

        // 6. Calculate Spectral Centroid and Spectral Energy
        var totalWeightedFreq: Float = 0.0
        var totalMag: Float = 0.0
        var spectralEnergy: Float = 0.0

        for i in 0..<halfSize {
            let mag = magnitudes[i]
            let freq = Float(i) * binWidth
            totalWeightedFreq += freq * mag
            totalMag += mag
            spectralEnergy += mag * mag
        }

        let centroid = totalMag > 1e-6 ? (totalWeightedFreq / totalMag) : 0.0

        return SpectralFeatures(
            dominantFrequency: dominantFreq,
            spectralCentroid: centroid,
            spectralEnergy: spectralEnergy,
            magnitudes: magnitudes
        )
    }
}
