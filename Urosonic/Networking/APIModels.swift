// APIModels.swift — Codable structs matching Flask API JSON responses

import Foundation

// ─────────────────────────────────────────────
// MARK: - User
// ─────────────────────────────────────────────
struct APIUser: Codable, Identifiable {
    let id:             Int
    let fullName:       String
    let email:          String
    let phone:          String?
    let role:           String
    let avatarInitials: String?
    let age:            Int?
    let gender:         String?
    let condition:      String?
    let doctorId:       Int?
    let licenseNumber:  String?
    let specialization: String?
    enum CodingKeys: String, CodingKey {
        case id, email, phone, role, age, gender, condition, specialization
        case fullName       = "full_name"
        case avatarInitials = "avatar_initials"
        case doctorId       = "doctor_id"
        case licenseNumber  = "license_number"
    }

    var initials: String { avatarInitials ?? String(fullName.prefix(2)).uppercased() }
}

// ─────────────────────────────────────────────
// MARK: - Measurement
// ─────────────────────────────────────────────
struct APIMeasurement: Codable, Identifiable {
    let id:             Int
    let patientId:      Int
    let qmax:           Double
    let avgFlow:        Double?
    let volume:         Int
    let voidTime:       Int
    let status:         String
    let notes:          String?
    let recordedAt:     String?
    let flowCurve:      [PredictedFlowPoint]?
    let volumeCurve:    [PredictedVolumePoint]?
    let flowStartTime:  Double?
    let maxFlowTime:    Double?
    let startTime:      Double?
    let stopTime:       Double?
    let flowIntervals:  Int?
    let sirokyMaxSD:    Double?
    let sirokyAvgSD:    Double?

    enum CodingKeys: String, CodingKey {
        case id, qmax, volume, status, notes
        case patientId      = "patient_id"
        case avgFlow        = "avg_flow"
        case voidTime       = "void_time"
        case recordedAt     = "recorded_at"
        case flowCurve      = "flow_curve"
        case volumeCurve    = "volume_curve"
        case flowStartTime  = "flow_start_time"
        case maxFlowTime    = "max_flow_time"
        case startTime      = "start_time"
        case stopTime       = "stop_time"
        case flowIntervals  = "flow_intervals"
        case sirokyMaxSD    = "siroky_max_sd"
        case sirokyAvgSD    = "siroky_avg_sd"
    }

    var statusEnum: MeasurementStatus { MeasurementStatus(rawValue: status) ?? .normal }
    var formattedQmax:     String { "\(String(format: "%.1f", qmax)) mL/s" }
    var formattedVolume:   String { "\(volume) mL" }
    var formattedVoidTime: String { "\(voidTime)s" }
    var formattedAvgFlow:  String {
        avgFlow.map { "\(String(format: "%.1f", $0)) mL/s" } ?? "—"
    }
    var displayDate: String {
        guard let raw = recordedAt else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
        if let d = iso.date(from: raw) {
            let f = DateFormatter()
            f.dateStyle = .medium; f.timeStyle = .short
            return f.string(from: d)
        }
        return raw
    }
}

// ─────────────────────────────────────────────
// MARK: - Fluid
// ─────────────────────────────────────────────
struct APIFluidEntry: Codable, Identifiable {
    let id:        Int
    let patientId: Int
    let drinkType: String
    let volumeMl:  Int
    let loggedAt:  String?
    let logDate:   String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case drinkType = "drink_type"
        case volumeMl  = "volume_ml"
        case loggedAt  = "logged_at"
        case logDate   = "log_date"
    }

    var iconName: String {
        switch drinkType {
        case "Coffee": return "cup.and.saucer.fill"
        case "Juice":  return "wineglass.fill"
        default:       return "drop.fill"
        }
    }
}

struct APIFluidSummary: Codable {
    let date:       String
    let totalMl:    Int
    let targetMl:   Int
    let percentage: Double
    let entries:    [APIFluidEntry]

    enum CodingKeys: String, CodingKey {
        case date, percentage, entries
        case totalMl  = "total_ml"
        case targetMl = "target_ml"
    }
}

struct APIUrineOutputEntry: Codable, Identifiable {
    let id:        Int
    let patientId: Int
    let volumeMl:  Int
    let urgency:   String?
    let color:     String?
    let source:    String?
    let loggedAt:  String?
    let logDate:   String?
    let notes:     String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case volumeMl  = "volume_ml"
        case urgency, color, source, notes
        case loggedAt  = "logged_at"
        case logDate   = "log_date"
    }

    var displayUrgency: String { urgency ?? "Normal" }
    var displayColor: String { color ?? "Pale Yellow" }
    var isTestMeasurement: Bool { source?.lowercased().contains("test") == true }
}

struct APIFluidBalanceSummary: Codable {
    let date:           String
    let intakeTotalMl:  Int
    let outputTotalMl:  Int
    let netBalanceMl:   Int
    let intakeTargetMl: Int
    let voidCount:      Int
    let intakeEntries:  [APIFluidEntry]
    let outputEntries:  [APIUrineOutputEntry]

    enum CodingKeys: String, CodingKey {
        case date
        case intakeTotalMl  = "intake_total_ml"
        case outputTotalMl  = "output_total_ml"
        case netBalanceMl   = "net_balance_ml"
        case intakeTargetMl = "intake_target_ml"
        case voidCount      = "void_count"
        case intakeEntries  = "intake_entries"
        case outputEntries  = "output_entries"
    }
}

// ─────────────────────────────────────────────
// MARK: - Messages
// ─────────────────────────────────────────────
struct APIChatMessage: Codable, Identifiable {
    let id:         Int
    let senderId:   Int
    let receiverId: Int
    let message:    String
    let isRead:     Bool
    let sentAt:     String?

    enum CodingKeys: String, CodingKey {
        case id, message
        case senderId   = "sender_id"
        case receiverId = "receiver_id"
        case isRead     = "is_read"
        case sentAt     = "sent_at"
    }
}

struct APIConversation: Codable, Identifiable {
    let userId:       Int
    let name:         String
    let avatar:       String
    let role:         String
    let lastMessage:  String?
    let lastTime:     String?
    let unreadCount:  Int
    let lastSenderId: Int?
    let lastIsRead:   Bool?

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case name, avatar, role
        case userId       = "user_id"
        case lastMessage  = "last_message"
        case lastTime     = "last_time"
        case unreadCount  = "unread_count"
        case lastSenderId = "last_sender_id"
        case lastIsRead   = "last_is_read"
    }
}

// ─────────────────────────────────────────────
// MARK: - Feedback
// ─────────────────────────────────────────────
struct APIFeedback: Codable, Identifiable {
    let id:             Int
    let measurementId:  Int
    let doctorId:       Int
    let patientId:      Int
    let doctorName:     String?
    let interpretation: String
    let clinicalNotes:  String
    let prescription:   String?
    let followUpDate:   String?
    let createdAt:      String?

    enum CodingKeys: String, CodingKey {
        case id, interpretation
        case measurementId = "measurement_id"
        case doctorId      = "doctor_id"
        case patientId     = "patient_id"
        case doctorName    = "doctor_name"
        case clinicalNotes = "clinical_notes"
        case prescription
        case followUpDate  = "follow_up_date"
        case createdAt     = "created_at"
    }
}

// ─────────────────────────────────────────────
// MARK: - Stock
// ─────────────────────────────────────────────
struct APIStockItem: Codable, Identifiable {
    let id:          Int
    let doctorId:    Int
    let name:        String
    let category:    String
    let currentQty:  Int
    let threshold:   Int
    let unit:        String
    let status:      String
    let percentage:  Double

    enum CodingKeys: String, CodingKey {
        case id, name, category, unit, status, percentage
        case doctorId   = "doctor_id"
        case currentQty = "current_qty"
        case threshold
    }

    var stockStatus: StockStatus { StockStatus(rawValue: status) ?? .ok }
}

struct APIStockResponse: Codable {
    let items:   [APIStockItem]
    let summary: APIStockSummary
}
struct APIStockSummary: Codable {
    let ok: Int; let low: Int; let critical: Int
}

// ─────────────────────────────────────────────
// MARK: - Surgery
// ─────────────────────────────────────────────
struct APISurgeryRecord: Codable, Identifiable {
    let id:                Int
    let doctorId:          Int
    let surgeryDate:       String?
    let hospital:          String?
    let myRole:            String?
    let patientName:       String
    let patientIdRef:      String?
    let phoneNumber:       String?
    let surgeryType:       String
    let diagnoses:         [String]
    let professionalFees:  Int
    let instrumentCharges: Int
    let totalFees:         Int
    let paymentStatus:     String
    let consumables:       [String]
    let rentalName:        String?
    let rentalFees:        Int
    let stentType:         String?
    let stentDueDate:      String?
    let stentStatus:       String?
    let remarks:           String?
    let team:              [APITeamMember]

    enum CodingKeys: String, CodingKey {
        case id, hospital, diagnoses, consumables, remarks, team
        case doctorId          = "doctor_id"
        case surgeryDate       = "surgery_date"
        case myRole            = "my_role"
        case patientName       = "patient_name"
        case patientIdRef      = "patient_id_ref"
        case phoneNumber       = "phone_number"
        case surgeryType       = "surgery_type"
        case professionalFees  = "professional_fees"
        case instrumentCharges = "instrument_charges"
        case totalFees         = "total_fees"
        case paymentStatus     = "payment_status"
        case rentalName        = "rental_name"
        case rentalFees        = "rental_fees"
        case stentType         = "stent_type"
        case stentDueDate      = "stent_due_date"
        case stentStatus       = "stent_status"
    }

    var paymentStatusEnum: PaymentStatus { PaymentStatus(rawValue: paymentStatus) ?? .pending }
    var avatar: String {
        String(patientName.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }.joined()).uppercased()
    }
}

struct APITeamMember: Codable, Identifiable {
    var id:            Int
    var surgeryId:     Int
    var role:          String?
    var memberName:    String?
    var fees:          Int
    var paymentStatus: String

    enum CodingKeys: String, CodingKey {
        case id, role, fees
        case surgeryId     = "surgery_id"
        case memberName    = "member_name"
        case paymentStatus = "payment_status"
    }
}

// ─────────────────────────────────────────────
// MARK: - Follow-up
// ─────────────────────────────────────────────
struct APIFollowUp: Codable, Identifiable {
    let id:          Int
    let doctorId:    Int
    let patientId:   Int
    let patientName: String?
    let avatar:      String?
    let dueDate:     String?
    let daysLeft:    Int
    let status:      String
    let notes:       String?

    enum CodingKeys: String, CodingKey {
        case id, avatar, status, notes
        case doctorId    = "doctor_id"
        case patientId   = "patient_id"
        case patientName = "patient_name"
        case dueDate     = "due_date"
        case daysLeft    = "days_left"
    }

    var followUpStatus: FollowUpStatus { FollowUpStatus(rawValue: status) ?? .upcoming }
}

// ─────────────────────────────────────────────
// MARK: - Dashboard
// ─────────────────────────────────────────────
struct APIDashboard: Codable {
    let totalPatients:  Int
    let pendingReviews: Int
    let lowStockCount:  Int
    let followupsDue:   Int

    enum CodingKeys: String, CodingKey {
        case totalPatients  = "total_patients"
        case pendingReviews = "pending_reviews"
        case lowStockCount  = "low_stock_count"
        case followupsDue   = "followups_due"
    }
}

// ─────────────────────────────────────────────
// MARK: - Patient List Item
// ─────────────────────────────────────────────
struct APIDoctorItem: Codable, Identifiable {
    let id:             Int
    let fullName:       String
    let specialization: String?
    let avatarInitials: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName       = "full_name"
        case specialization
        case avatarInitials = "avatar_initials"
    }
}

struct APIPatientListItem: Codable, Identifiable {
    let id:              Int
    let name:            String
    let avatar:          String
    let age:             Int?
    let gender:          String?
    let condition:       String?
    let latestQmax:      Double?
    let latestStatus:    String?
    let lastMeasurement: String?
    let isFlagged:       Bool

    enum CodingKeys: String, CodingKey {
        case id, name, avatar, age, gender, condition
        case latestQmax         = "latest_qmax"
        case latestStatus       = "latest_status"
        case lastMeasurement    = "last_measured_at"
        case lastMeasurementAlt = "last_measurement"
        case isFlagged          = "is_flagged"
    }

    init(
        id: Int,
        name: String,
        avatar: String,
        age: Int? = nil,
        gender: String? = nil,
        condition: String? = nil,
        latestQmax: Double? = nil,
        latestStatus: String? = nil,
        lastMeasurement: String? = nil,
        isFlagged: Bool = false
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.age = age
        self.gender = gender
        self.condition = condition
        self.latestQmax = latestQmax
        self.latestStatus = latestStatus
        self.lastMeasurement = lastMeasurement
        self.isFlagged = isFlagged
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatar = (try? container.decodeIfPresent(String.self, forKey: .avatar)) ?? ""
        age = try? container.decodeIfPresent(Int.self, forKey: .age)
        gender = try? container.decodeIfPresent(String.self, forKey: .gender)
        condition = try? container.decodeIfPresent(String.self, forKey: .condition)
        latestQmax = try? container.decodeIfPresent(Double.self, forKey: .latestQmax)
        latestStatus = try? container.decodeIfPresent(String.self, forKey: .latestStatus)
        lastMeasurement = (try? container.decodeIfPresent(String.self, forKey: .lastMeasurement))
            ?? (try? container.decodeIfPresent(String.self, forKey: .lastMeasurementAlt))
        let flaggedExplicit = try? container.decodeIfPresent(Bool.self, forKey: .isFlagged)
        isFlagged = flaggedExplicit ?? (latestStatus?.uppercased() == "ABNORMAL")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(avatar, forKey: .avatar)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encodeIfPresent(condition, forKey: .condition)
        try container.encodeIfPresent(latestQmax, forKey: .latestQmax)
        try container.encodeIfPresent(latestStatus, forKey: .latestStatus)
        try container.encodeIfPresent(lastMeasurement, forKey: .lastMeasurement)
        try container.encode(isFlagged, forKey: .isFlagged)
    }

    var formattedQmax: String {
        latestQmax.map { "\(String(format: "%.1f", $0)) mL/s" } ?? "—"
    }
    var statusEnum: MeasurementStatus {
        MeasurementStatus(rawValue: latestStatus ?? "") ?? .normal
    }
}

// ─────────────────────────────────────────────
// MARK: - Generic Wrappers
// ─────────────────────────────────────────────
struct APIMessageResponse: Codable { let message: String }
struct APIErrorResponse:   Codable { let error:   String }

// ─────────────────────────────────────────────
// MARK: - Phase 6 Acoustic Flow Prediction Models
// ─────────────────────────────────────────────
struct AcousticFlowFeature: Codable, Sendable {
    let timestamp: Double
    let rms: Double
    let peak: Double
    let dbfs: Double
    let dominantFrequency: Double
    let spectralCentroid: Double
    let spectralEnergy: Double

    enum CodingKeys: String, CodingKey {
        case timestamp, rms, peak, dbfs
        case dominantFrequency = "dominant_frequency"
        case spectralCentroid  = "spectral_centroid"
        case spectralEnergy    = "spectral_energy"
    }

    init(
        timestamp: Double,
        rms: Double,
        peak: Double,
        dbfs: Double,
        dominantFrequency: Double,
        spectralCentroid: Double,
        spectralEnergy: Double
    ) {
        self.timestamp = timestamp
        self.rms = rms
        self.peak = peak
        self.dbfs = dbfs
        self.dominantFrequency = dominantFrequency
        self.spectralCentroid = spectralCentroid
        self.spectralEnergy = spectralEnergy
    }

    init(from frame: AudioFrameFeature) {
        self.timestamp = Double(frame.timestamp)
        self.rms = Double(frame.rms)
        self.peak = Double(frame.peak)
        self.dbfs = Double(frame.dbFS)
        self.dominantFrequency = Double(frame.dominantFrequency)
        self.spectralCentroid = Double(frame.spectralCentroid)
        self.spectralEnergy = Double(frame.spectralEnergy)
    }
}

struct AcousticFlowPredictionRequest: Codable, Sendable {
    let sampleRate: Int
    let features: [AcousticFlowFeature]

    enum CodingKeys: String, CodingKey {
        case sampleRate = "sample_rate"
        case features
    }
}

struct PredictedFlowPoint: Codable, Identifiable, Hashable, Sendable {
    var id: Double { timestamp }
    let timestamp: Double
    let flowMLPerSec: Double

    enum CodingKeys: String, CodingKey {
        case timestamp
        case flowMLPerSec = "flow_ml_s"
    }

    init(timestamp: Double, flowMLPerSec: Double) {
        self.timestamp = timestamp
        self.flowMLPerSec = flowMLPerSec
    }
}

struct PredictedVolumePoint: Codable, Identifiable, Hashable, Sendable {
    var id: Double { timestamp }
    let timestamp: Double
    let volumeML: Double

    enum CodingKeys: String, CodingKey {
        case timestamp
        case volumeML = "volume_ml"
    }

    init(timestamp: Double, volumeML: Double) {
        self.timestamp = timestamp
        self.volumeML = volumeML
    }
}

struct FlowPredictionMetrics: Codable, Sendable {
    let qmaxMLPerSec: Double
    let averageFlowMLPerSec: Double
    let estimatedVolumeML: Double
    let voidingDurationSec: Double
    let startTimeSec: Double?
    let stopTimeSec: Double?
    let flowStartTimeSec: Double?
    let maxFlowTimeSec: Double?
    let flowIntervals: Int?
    let sirokyMaxExpectedMLPerSec: Double?
    let sirokyMaxSD: Double?
    let sirokyAvgExpectedMLPerSec: Double?
    let sirokyAvgSD: Double?

    enum CodingKeys: String, CodingKey {
        case qmaxMLPerSec             = "qmax_ml_s"
        case averageFlowMLPerSec      = "average_flow_ml_s"
        case estimatedVolumeML        = "estimated_volume_ml"
        case voidingDurationSec       = "voiding_duration_s"
        case startTimeSec             = "start_time_s"
        case stopTimeSec              = "stop_time_s"
        case flowStartTimeSec         = "flow_start_time_s"
        case maxFlowTimeSec           = "max_flow_time_s"
        case flowIntervals            = "flow_intervals"
        case sirokyMaxExpectedMLPerSec = "siroky_max_expected_ml_s"
        case sirokyMaxSD              = "siroky_max_sd"
        case sirokyAvgExpectedMLPerSec = "siroky_avg_expected_ml_s"
        case sirokyAvgSD              = "siroky_avg_sd"
    }
}

struct AcousticFlowPredictionResponse: Codable, Sendable {
    let success: Bool
    let modelVersion: String
    let researchStatus: String
    let metrics: FlowPredictionMetrics
    let flowCurve: [PredictedFlowPoint]
    let volumeCurve: [PredictedVolumePoint]?
    let predictionCount: Int

    enum CodingKeys: String, CodingKey {
        case success
        case modelVersion     = "model_version"
        case researchStatus    = "research_status"
        case metrics
        case flowCurve        = "flow_curve"
        case volumeCurve      = "volume_curve"
        case predictionCount  = "prediction_count"
    }
}
