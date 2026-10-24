// DatasetExporter.swift
// Urosonic — Phase 4 Calibration Dataset Serializer, CSV Generator, and Export Packager

import Foundation

final class DatasetExporter {
    static let shared = DatasetExporter()

    private let fileManager = FileManager.default

    // MARK: - Export Destination Directory
    var exportBaseURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("UrosonicDataset", isDirectory: true)
    }

    // MARK: - Build Dataset Package
    func exportDataset(sessions: [CalibrationSession]) throws -> URL {
        let exportDir = exportBaseURL
        if fileManager.fileExists(atPath: exportDir.path) {
            try fileManager.removeItem(at: exportDir)
        }
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let sessionsDir = exportDir.appendingPathComponent("sessions", isDirectory: true)
        try fileManager.createDirectory(at: sessionsDir, withIntermediateDirectories: true)

        // 1. Generate Master metadata.csv
        let metadataCSV = generateMetadataCSV(sessions: sessions)
        let metadataURL = exportDir.appendingPathComponent("metadata.csv")
        try metadataCSV.write(to: metadataURL, atomically: true, encoding: .utf8)

        // 2. Generate Sessions
        for (idx, session) in sessions.enumerated() {
            let sessionSubdirName = "session_\(String(format: "%03d", idx + 1))_\(session.id.uuidString.prefix(8))"
            let sessionDir = sessionsDir.appendingPathComponent(sessionSubdirName, isDirectory: true)
            try fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)

            // A. Copy audio.wav if available
            if fileManager.fileExists(atPath: session.audioFileURL.path) {
                let destWAV = sessionDir.appendingPathComponent("audio.wav")
                try? fileManager.copyItem(at: session.audioFileURL, to: destWAV)
            }

            // B. Export acoustic_features.csv
            let featuresCSV = generateAcousticFeaturesCSV(features: session.acousticFeatures)
            let featuresURL = sessionDir.appendingPathComponent("acoustic_features.csv")
            try featuresCSV.write(to: featuresURL, atomically: true, encoding: .utf8)

            // C. Export ground_truth.csv
            let gtCSV = generateGroundTruthCSV(session: session)
            let gtURL = sessionDir.appendingPathComponent("ground_truth.csv")
            try gtCSV.write(to: gtURL, atomically: true, encoding: .utf8)

            // D. Export synchronized_samples.csv (ML training ready)
            let syncSamples = synchronizeFeaturesWithGroundTruth(session: session)
            let syncCSV = generateSynchronizedSamplesCSV(samples: syncSamples)
            let syncURL = sessionDir.appendingPathComponent("synchronized_samples.csv")
            try syncCSV.write(to: syncURL, atomically: true, encoding: .utf8)
        }

        // 3. Generate README.txt
        let readmeText = generateDatasetREADME(totalSessions: sessions.count)
        let readmeURL = exportDir.appendingPathComponent("README.txt")
        try readmeText.write(to: readmeURL, atomically: true, encoding: .utf8)

        return exportDir
    }

    // MARK: - CSV Generators
    private func generateMetadataCSV(sessions: [CalibrationSession]) -> String {
        var csv = "session_id,created_at,status,subject_id,device_model,os_version,sample_rate,channel_count,distance_inches,orientation,environment,toilet_type,water_level,noise_notes,operator_notes,event_start_time,event_end_time,event_duration,noise_floor_dbfs,peak_dbfs,avg_dbfs,gt_method,gt_volume_ml,gt_start_time,gt_end_time,gt_duration,gt_points_count\n"

        for s in sessions {
            let m = s.metadata
            let gt = s.groundTruth

            let row: [String] = [
                escapeCSV(s.id.uuidString),
                escapeCSV(ISO8601DateFormatter().string(from: s.createdAt)),
                escapeCSV(s.status.rawValue),
                escapeCSV(m.anonymizedSubjectId ?? "ANONYMOUS"),
                escapeCSV(m.deviceModel),
                escapeCSV(m.osVersion),
                String(format: "%.0f", m.sampleRate),
                "\(m.channelCount)",
                m.recordingDistanceInches != nil ? String(format: "%.1f", m.recordingDistanceInches!) : "",
                escapeCSV(m.phoneOrientation),
                escapeCSV(m.environment),
                escapeCSV(m.toiletType),
                escapeCSV(m.waterLevelDescription ?? ""),
                escapeCSV(m.backgroundNoiseNotes ?? ""),
                escapeCSV(m.operatorNotes ?? ""),
                s.eventStartTime != nil ? String(format: "%.3f", s.eventStartTime!) : "",
                s.eventEndTime != nil ? String(format: "%.3f", s.eventEndTime!) : "",
                s.eventDuration != nil ? String(format: "%.3f", s.eventDuration!) : "",
                s.noiseFloorDBFS != nil ? String(format: "%.1f", s.noiseFloorDBFS!) : "",
                s.peakDBFS != nil ? String(format: "%.1f", s.peakDBFS!) : "",
                s.averageDBFS != nil ? String(format: "%.1f", s.averageDBFS!) : "",
                gt != nil ? escapeCSV(gt!.method.rawValue) : "",
                gt != nil ? String(format: "%.1f", gt!.totalVolumeML) : "",
                gt != nil ? String(format: "%.3f", gt!.startTime) : "",
                gt != nil ? String(format: "%.3f", gt!.endTime) : "",
                gt != nil ? String(format: "%.3f", gt!.duration) : "",
                gt != nil ? "\(gt!.flowPoints.count)" : "0"
            ]
            csv.append(row.joined(separator: ",") + "\n")
        }
        return csv
    }

    private func generateAcousticFeaturesCSV(features: [AudioFrameFeatureCodable]) -> String {
        var csv = "timestamp,rms,peak,dbFS,dominant_frequency_hz,spectral_centroid_hz,spectral_energy\n"
        for f in features {
            let row = String(
                format: "%.4f,%.6f,%.6f,%.2f,%.1f,%.1f,%.4f",
                f.timestamp,
                f.rms,
                f.peak,
                f.dbFS,
                f.dominantFrequency,
                f.spectralCentroid,
                f.spectralEnergy
            )
            csv.append(row + "\n")
        }
        return csv
    }

    private func generateGroundTruthCSV(session: CalibrationSession) -> String {
        guard let gt = session.groundTruth else {
            return "status,notes\nNO_GROUND_TRUTH,Independent ground-truth measurement has not been attached to this session.\n"
        }

        var csv = "# Ground Truth Measurement Metadata\n"
        csv.append("# Method: \(gt.method.rawValue)\n")
        csv.append("# Total Volume: \(String(format: "%.1f mL", gt.totalVolumeML))\n")
        csv.append("# Flow Duration: \(String(format: "%.2f s (%.2fs to %.2fs)", gt.duration, gt.startTime, gt.endTime))\n")
        if let measuredBy = gt.measuredBy { csv.append("# Operator: \(measuredBy)\n") }
        if let equip = gt.equipmentModel { csv.append("# Equipment: \(equip)\n") }
        csv.append("\ntimestamp,flow_rate_ml_s\n")

        if gt.flowPoints.isEmpty {
            csv.append("# Note: Point-by-point flow curve not recorded; session-level volume and duration only.\n")
        } else {
            for pt in gt.flowPoints.sorted(by: { $0.timestamp < $1.timestamp }) {
                csv.append(String(format: "%.3f,%.2f\n", pt.timestamp, pt.flowRateMLPerSecond))
            }
        }
        return csv
    }

    // MARK: - Feature / Ground-Truth Time Alignment
    func synchronizeFeaturesWithGroundTruth(session: CalibrationSession) -> [CalibrationSample] {
        let sortedGT = (session.groundTruth?.flowPoints ?? []).sorted(by: { $0.timestamp < $1.timestamp })

        return session.acousticFeatures.map { feat in
            var matchedFlow: Double? = nil

            // If point-by-point ground truth exists, align nearest sample within ±0.05s window
            if !sortedGT.isEmpty {
                if let match = sortedGT.first(where: { abs($0.timestamp - feat.timestamp) <= 0.04 }) {
                    matchedFlow = match.flowRateMLPerSecond
                }
            }

            return CalibrationSample(
                timestamp: feat.timestamp,
                audioRMS: feat.rms,
                peak: feat.peak,
                dbFS: feat.dbFS,
                dominantFrequency: feat.dominantFrequency,
                spectralCentroid: feat.spectralCentroid,
                spectralEnergy: feat.spectralEnergy,
                groundTruthFlowRate: matchedFlow
            )
        }
    }

    private func generateSynchronizedSamplesCSV(samples: [CalibrationSample]) -> String {
        var csv = "timestamp,audio_rms,peak,dbFS,dominant_frequency_hz,spectral_centroid_hz,spectral_energy,ground_truth_flow_ml_s\n"
        for s in samples {
            let gtString = s.groundTruthFlowRate != nil ? String(format: "%.2f", s.groundTruthFlowRate!) : ""
            let line = String(
                format: "%.4f,%.6f,%.6f,%.2f,%.1f,%.1f,%.4f,%@\n",
                s.timestamp,
                s.audioRMS,
                s.peak,
                s.dbFS,
                s.dominantFrequency,
                s.spectralCentroid,
                s.spectralEnergy,
                gtString
            )
            csv.append(line)
        }
        return csv
    }

    // MARK: - README Generator
    private func generateDatasetREADME(totalSessions: Int) -> String {
        return """
        ================================================================================
        UROSONIC RESEARCH CALIBRATION DATASET
        ================================================================================
        Total Sessions: \(totalSessions)
        Generated: \(ISO8601DateFormatter().string(from: Date()))
        Platform: iOS AVFoundation Native Audio Engine (44.1 kHz, 16-bit Mono WAV)

        1. PURPOSE & RESEARCH SCOPE
        This dataset pairs real smartphone microphone acoustic recordings with independent
        ground-truth volumetric/flow measurements for digital urological research.

        SCIENTIFIC PRINCIPLE:
        - Acoustic amplitude (dBFS) does NOT directly equal flow rate in mL/s.
        - Audio features are candidate inputs for subsequent supervised machine learning.
        - Ground truth is obtained independently from calibrated reference equipment.

        2. DATASET DIRECTORY STRUCTURE
        UrosonicDataset/
        ├── metadata.csv                     (Global index of all sessions with experimental setup)
        ├── README.txt                       (This document)
        └── sessions/
            └── session_001_<uuid>/
                ├── audio.wav                (Raw 44.1 kHz 16-bit uncompressed WAV recording)
                ├── acoustic_features.csv    (Frame-by-frame RMS, Peak, dBFS, FFT Centroid/Freq)
                ├── ground_truth.csv         (Independent reference uroflow / volumetric data)
                └── synchronized_samples.csv (Time-aligned features + ground truth for ML training)

        3. CSV COLUMN SPECIFICATIONS

        A. acoustic_features.csv
        - timestamp: Time in seconds relative to the start of the recording session (t = 0.0000).
        - rms: Root Mean Square signal amplitude.
        - peak: Absolute peak amplitude in frame.
        - dbFS: Decibels relative to Full Scale [20 * log10(max(rms, 1e-5))], range: -100 to 0 dBFS.
        - dominant_frequency_hz: Peak spectral bin frequency in Hz from real-time Accelerate FFT.
        - spectral_centroid_hz: Spectral center of mass in Hz.
        - spectral_energy: Sum of squared FFT magnitude bins.

        B. ground_truth.csv
        - timestamp: Normalized time from recording start (s).
        - flow_rate_ml_s: True measured flow rate in mL/s (if reference uroflowmeter was used).
        * If only total volume (mL) was measured, it is stored in session metadata.

        C. synchronized_samples.csv
        - Formatted for direct loading into Pandas / NumPy / PyTorch.
        - Note: ground_truth_flow_ml_s is left blank (not zero-filled) when ground truth
          is not available at a specific timestamp, preventing artificial bias.

        4. ML DATASET SPLITTING GUIDELINES
        IMPORTANT:
        Do NOT randomly split individual time frames into Train/Test sets. Doing so will
        cause extreme temporal autocorrelation and data leakage.
        Splits MUST be performed at the SESSION or SUBJECT level (using subject_id or session_id).

        5. DISCLAIMER
        This dataset is collected for experimental research and calibration only.
        It does not constitute clinical diagnosis or medical device validation.
        ================================================================================
        """
    }

    private func escapeCSV(_ str: String) -> String {
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            return "\"\(str.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return str
    }
}
