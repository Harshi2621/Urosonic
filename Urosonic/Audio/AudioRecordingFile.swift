// AudioRecordingFile.swift
// Urosonic — WAV Audio Recording File Writer and Session Model

import AVFoundation
import Foundation

struct RecordingSession: Identifiable, Codable, Sendable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var duration: TimeInterval
    let audioFileURL: URL
    let sampleRate: Double
    let channelCount: Int
    var totalFrames: Int64

    var formattedDuration: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        let ms = Int((duration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }

    var fileName: String {
        audioFileURL.lastPathComponent
    }

    var fileSizeString: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: audioFileURL.path),
              let size = attrs[.size] as? Int64 else {
            return "0 KB"
        }
        let kb = Double(size) / 1024.0
        if kb > 1024.0 {
            return String(format: "%.1f MB", kb / 1024.0)
        }
        return String(format: "%.1f KB", kb)
    }
}

final class AudioRecordingFileWriter {
    private(set) var session: RecordingSession
    private var audioFile: AVAudioFile?
    private let writeQueue = DispatchQueue(label: "com.urosonic.audio.filewriter", qos: .utility)
    private var isFinalized = false

    init(format: AVAudioFormat) throws {
        let sessionId = UUID()
        let fileManager = FileManager.default

        // Standard Application Support directory for Urosonic recordings
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "AudioRecordingFileWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access Application Support directory"])
        }

        let recordingsDir = appSupportURL.appendingPathComponent("Urosonic/Recordings", isDirectory: true)
        if !fileManager.fileExists(atPath: recordingsDir.path) {
            try fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: nil)
        }

        let fileURL = recordingsDir.appendingPathComponent("\(sessionId.uuidString).wav")

        // Construct standard WAV file output settings based on hardware input
        // Using PCM Linear 16-bit or 32-bit Float WAV
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100.0
        let channels = format.channelCount > 0 ? format.channelCount : 1

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: outputSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        self.audioFile = audioFile
        self.session = RecordingSession(
            id: sessionId,
            startedAt: Date(),
            endedAt: nil,
            duration: 0,
            audioFileURL: fileURL,
            sampleRate: sampleRate,
            channelCount: Int(channels),
            totalFrames: 0
        )
    }

    /// Write an incoming buffer to the WAV file.
    func write(buffer: AVAudioPCMBuffer) {
        guard !isFinalized, let audioFile = audioFile else { return }
        writeQueue.async { [weak self] in
            guard let self = self, !self.isFinalized else { return }
            do {
                try audioFile.write(from: buffer)
                self.session.totalFrames += Int64(buffer.frameLength)
                let elapsed = Date().timeIntervalSince(self.session.startedAt)
                self.session.duration = elapsed
            } catch {
                print("[AudioRecordingFileWriter] Error writing buffer: \(error.localizedDescription)")
            }
        }
    }

    /// Finalize and close the WAV file.
    func finish() -> RecordingSession {
        writeQueue.sync {
            isFinalized = true
            session.endedAt = Date()
            session.duration = max(0, session.endedAt!.timeIntervalSince(session.startedAt))
            audioFile = nil
        }
        return session
    }
}
