// CalibrationSessionManager.swift
// Urosonic — Calibration Session Persistence, Validation Engine, and Quality Monitoring

import Foundation
import Combine
import SwiftUI

@MainActor
final class CalibrationSessionManager: ObservableObject {
    static let shared = CalibrationSessionManager()

    @Published var sessions: [CalibrationSession] = []
    @Published var qualityReport: DatasetQualityReport?
    @Published var lastExportURL: URL?
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let storageURL: URL

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Urosonic/CalibrationSessions", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.storageURL = dir.appendingPathComponent("calibration_sessions.json")

        loadSessions()
        recalculateQualityReport()
    }

    // MARK: - Persistence
    func loadSessions() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([CalibrationSession].self, from: data)
            self.sessions = decoded
            recalculateQualityReport()
        } catch {
            print("[CalibrationSessionManager] Error loading sessions: \(error.localizedDescription)")
        }
    }

    func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: storageURL, options: .atomic)
            recalculateQualityReport()
        } catch {
            self.errorMessage = "Failed to save calibration sessions: \(error.localizedDescription)"
        }
    }

    // MARK: - Session Management
    func addSession(
        recordingSession: RecordingSession,
        metadata: ExperimentalMetadata,
        features: [AudioFrameFeature],
        events: [FlowEvent],
        noiseFloor: Float
    ) -> CalibrationSession {
        let primaryEvent = events.first
        let codableFeatures = features.map { AudioFrameFeatureCodable(from: $0) }

        var session = CalibrationSession(
            recordingSessionId: recordingSession.id,
            audioFileURL: recordingSession.audioFileURL,
            status: .draft,
            metadata: metadata,
            eventStartTime: primaryEvent?.startTime,
            eventEndTime: primaryEvent?.endTime,
            eventDuration: primaryEvent?.duration,
            noiseFloorDBFS: noiseFloor,
            peakDBFS: primaryEvent?.peakDBFS,
            averageDBFS: primaryEvent?.averageDBFS,
            groundTruth: nil,
            acousticFeatures: codableFeatures
        )

        // Run validation
        session.status = validateSessionStatus(session)

        sessions.insert(session, at: 0)
        saveSessions()
        return session
    }

    func updateGroundTruth(sessionId: UUID, groundTruth: GroundTruthFlowSession) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].groundTruth = groundTruth
        sessions[index].status = validateSessionStatus(sessions[index])
        saveSessions()
    }

    func updateMetadata(sessionId: UUID, metadata: ExperimentalMetadata) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].metadata = metadata
        sessions[index].status = validateSessionStatus(sessions[index])
        saveSessions()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll(where: { $0.id == id })
        saveSessions()
    }

    // MARK: - Validation Engine
    func validateSessionStatus(_ session: CalibrationSession) -> CalibrationStatus {
        // 1. WAV File Existence & Valid Duration
        guard fileManager.fileExists(atPath: session.audioFileURL.path) else {
            return .incomplete
        }

        // 2. Acoustic Feature Frames
        guard !session.acousticFeatures.isEmpty else {
            return .incomplete
        }

        // 3. Ground Truth Data
        guard let gt = session.groundTruth else {
            return .draft
        }

        // 4. Volumetric and Timing Validation
        guard gt.totalVolumeML > 0 else { return .incomplete }
        guard gt.endTime > gt.startTime else { return .incomplete }
        guard gt.duration > 0 else { return .incomplete }

        // 5. Point-by-point Validation (if curve was recorded)
        if !gt.flowPoints.isEmpty {
            // Check ordered timestamps and non-negative flow rates
            var prevTime: TimeInterval = -1.0
            for pt in gt.flowPoints {
                if pt.timestamp < prevTime { return .incomplete } // Must be monotonically non-decreasing
                if pt.flowRateMLPerSecond < 0 { return .incomplete } // Non-negative flow
                prevTime = pt.timestamp
            }
        }

        // 6. Metadata Validation
        guard !session.metadata.deviceModel.isEmpty, session.metadata.sampleRate > 0 else {
            return .incomplete
        }

        return .valid
    }

    // MARK: - Quality Report
    func recalculateQualityReport() {
        let total = sessions.count
        var valid = 0
        var incomplete = 0
        var draft = 0
        var exported = 0
        var totalDur: TimeInterval = 0
        var flowCurves = 0
        var volumeOnly = 0
        var missingAudio = 0
        var missingFeat = 0

        for s in sessions {
            let status = validateSessionStatus(s)
            switch status {
            case .valid:       valid += 1
            case .incomplete:  incomplete += 1
            case .draft:       draft += 1
            case .exported:    exported += 1
            }

            if let gt = s.groundTruth {
                if !gt.flowPoints.isEmpty { flowCurves += 1 }
                else { volumeOnly += 1 }
            }

            if !fileManager.fileExists(atPath: s.audioFileURL.path) {
                missingAudio += 1
            }
            if s.acousticFeatures.isEmpty {
                missingFeat += 1
            }

            if let dur = s.eventDuration {
                totalDur += dur
            }
        }

        let avgDur = total > 0 ? (totalDur / Double(total)) : 0.0

        self.qualityReport = DatasetQualityReport(
            totalSessions: total,
            validSessions: valid,
            incompleteSessions: incomplete,
            draftSessions: draft,
            exportedSessions: exported,
            averageRecordingDuration: avgDur,
            sessionsWithFlowCurves: flowCurves,
            sessionsWithTotalVolumeOnly: volumeOnly,
            missingAudioFilesCount: missingAudio,
            missingFeaturesCount: missingFeat,
            missingMetadataCount: 0
        )
    }

    // MARK: - Export
    func exportAllSessions() throws -> URL {
        let url = try DatasetExporter.shared.exportDataset(sessions: sessions)
        self.lastExportURL = url
        // Mark valid sessions as exported
        for i in 0..<sessions.count {
            if sessions[i].status == .valid {
                sessions[i].status = .exported
            }
        }
        saveSessions()
        return url
    }
}
