// CalibrationModels.swift
// Urosonic — Phase 4 Research Calibration and Ground-Truth Dataset Models

import Foundation
import UIKit

// MARK: - Calibration Status
enum CalibrationStatus: String, Codable, CaseIterable, Sendable {
    case draft       = "DRAFT"
    case incomplete  = "INCOMPLETE"
    case valid       = "VALID"
    case exported    = "EXPORTED"

    var badgeColorHex: String {
        switch self {
        case .draft:       return "94A3B8" // Slate
        case .incomplete:  return "F59E0B" // Amber
        case .valid:       return "10B981" // Emerald
        case .exported:    return "3B82F6" // Blue
        }
    }
}

// MARK: - Ground Truth Measurement Method
enum GroundTruthMethod: String, Codable, CaseIterable, Sendable {
    case referenceUroflowmeter = "Calibrated Reference Uroflowmeter"
    case controlledContainer   = "Calibrated Container / Graduated Cylinder with Precision Timing"
    case manualTotalVolume     = "Manual Total Volume & Timing (Session-level only)"
}

// MARK: - Ground Truth Flow Data Models
struct GroundTruthFlowPoint: Identifiable, Codable, Sendable {
    let id: UUID
    var timestamp: TimeInterval        // Seconds relative to recording start
    var flowRateMLPerSecond: Double    // True measured flow rate in mL/s

    init(id: UUID = UUID(), timestamp: TimeInterval, flowRateMLPerSecond: Double) {
        self.id = id
        self.timestamp = timestamp
        self.flowRateMLPerSecond = flowRateMLPerSecond
    }
}

struct GroundTruthFlowSession: Identifiable, Codable, Sendable {
    let id: UUID
    let calibrationSessionId: UUID
    var method: GroundTruthMethod
    var totalVolumeML: Double
    var startTime: TimeInterval
    var endTime: TimeInterval
    var duration: TimeInterval {
        max(0, endTime - startTime)
    }
    var flowPoints: [GroundTruthFlowPoint]
    var measuredBy: String?
    var equipmentModel: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        calibrationSessionId: UUID,
        method: GroundTruthMethod = .controlledContainer,
        totalVolumeML: Double,
        startTime: TimeInterval,
        endTime: TimeInterval,
        flowPoints: [GroundTruthFlowPoint] = [],
        measuredBy: String? = nil,
        equipmentModel: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.calibrationSessionId = calibrationSessionId
        self.method = method
        self.totalVolumeML = totalVolumeML
        self.startTime = startTime
        self.endTime = endTime
        self.flowPoints = flowPoints
        self.measuredBy = measuredBy
        self.equipmentModel = equipmentModel
        self.notes = notes
    }
}

// MARK: - Experimental Metadata
struct ExperimentalMetadata: Codable, Sendable {
    var deviceModel: String
    var osVersion: String
    var sampleRate: Double
    var channelCount: Int
    var recordingDistanceInches: Double?
    var phoneOrientation: String
    var environment: String
    var toiletType: String
    var waterLevelDescription: String?
    var backgroundNoiseNotes: String?
    var operatorNotes: String?
    var anonymizedSubjectId: String? // For session-level splitting without participant leakage

    static func currentDeviceDefaults() -> ExperimentalMetadata {
        return ExperimentalMetadata(
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            sampleRate: 44100.0,
            channelCount: 1,
            recordingDistanceInches: 12.0,
            phoneOrientation: "Microphone facing target area, angled 45°",
            environment: "Controlled Research Environment",
            toiletType: "Calibrated Receptacle / Flush Toilet",
            waterLevelDescription: "Standard bowl water level",
            backgroundNoiseNotes: "Ambient indoor background < -55 dBFS",
            operatorNotes: nil,
            anonymizedSubjectId: "SUBJECT_\(String(UUID().uuidString.prefix(6)))"
        )
    }
}

// MARK: - Calibration Session
struct CalibrationSession: Identifiable, Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let recordingSessionId: UUID
    let audioFileURL: URL
    var status: CalibrationStatus
    var metadata: ExperimentalMetadata

    // Acoustic event boundaries detected by FlowEventDetector
    var eventStartTime: TimeInterval?
    var eventEndTime: TimeInterval?
    var eventDuration: TimeInterval?
    var noiseFloorDBFS: Float?
    var peakDBFS: Float?
    var averageDBFS: Float?

    // Independently measured ground truth
    var groundTruth: GroundTruthFlowSession?

    // Extracted acoustic frame features
    var acousticFeatures: [AudioFrameFeatureCodable]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        recordingSessionId: UUID,
        audioFileURL: URL,
        status: CalibrationStatus = .draft,
        metadata: ExperimentalMetadata,
        eventStartTime: TimeInterval? = nil,
        eventEndTime: TimeInterval? = nil,
        eventDuration: TimeInterval? = nil,
        noiseFloorDBFS: Float? = nil,
        peakDBFS: Float? = nil,
        averageDBFS: Float? = nil,
        groundTruth: GroundTruthFlowSession? = nil,
        acousticFeatures: [AudioFrameFeatureCodable] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.recordingSessionId = recordingSessionId
        self.audioFileURL = audioFileURL
        self.status = status
        self.metadata = metadata
        self.eventStartTime = eventStartTime
        self.eventEndTime = eventEndTime
        self.eventDuration = eventDuration
        self.noiseFloorDBFS = noiseFloorDBFS
        self.peakDBFS = peakDBFS
        self.averageDBFS = averageDBFS
        self.groundTruth = groundTruth
        self.acousticFeatures = acousticFeatures
    }
}

// MARK: - Codable Audio Frame Feature for Persistence and ML Export
struct AudioFrameFeatureCodable: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: TimeInterval
    let rms: Float
    let peak: Float
    let dbFS: Float
    let dominantFrequency: Float
    let spectralCentroid: Float
    let spectralEnergy: Float

    init(from feature: AudioFrameFeature) {
        self.id = feature.id
        self.timestamp = feature.timestamp
        self.rms = feature.rms
        self.peak = feature.peak
        self.dbFS = feature.dbFS
        self.dominantFrequency = feature.dominantFrequency
        self.spectralCentroid = feature.spectralCentroid
        self.spectralEnergy = feature.spectralEnergy
    }
}

// MARK: - Synchronized Calibration Sample (Acoustic + Ground Truth Alignment)
struct CalibrationSample: Identifiable, Codable, Sendable {
    var id: TimeInterval { timestamp }
    let timestamp: TimeInterval          // Normalized time from recording start (s)
    let audioRMS: Float
    let peak: Float
    let dbFS: Float
    let dominantFrequency: Float
    let spectralCentroid: Float
    let spectralEnergy: Float
    let groundTruthFlowRate: Double?     // Real independently measured flow rate (mL/s). Optional! Never fabricated.
}

// MARK: - Dataset Quality Report
struct DatasetQualityReport: Sendable {
    let totalSessions: Int
    let validSessions: Int
    let incompleteSessions: Int
    let draftSessions: Int
    let exportedSessions: Int
    let averageRecordingDuration: TimeInterval
    let sessionsWithFlowCurves: Int
    let sessionsWithTotalVolumeOnly: Int
    let missingAudioFilesCount: Int
    let missingFeaturesCount: Int
    let missingMetadataCount: Int
}
