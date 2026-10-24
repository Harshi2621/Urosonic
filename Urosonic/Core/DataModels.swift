// DataModels.swift — All data models for UroFlow iOS app

import Foundation

// MARK: - Shared Status Types
enum MeasurementStatus: String, CaseIterable {
    case normal     = "NORMAL"
    case borderline = "BORDERLINE"
    case abnormal   = "ABNORMAL"
}

enum StockStatus: String {
    case ok       = "OK"
    case low      = "LOW"
    case critical = "CRITICAL"
}

enum FollowUpStatus: String {
    case upcoming = "UPCOMING"
    case due      = "DUE"
    case overdue  = "OVERDUE"
}

// MARK: - Measurement / Uroflow
struct UroflowMeasurement: Identifiable, Hashable {
    let id: Int
    let date: String
    let qmax: String
    let volume: String
    let voidTime: String
    let status: MeasurementStatus
}

struct UroflowResult {
    let qmax: Double
    let volume: Int
    let voidTime: Int
    let avgFlow: Double
    let date: String
    let status: MeasurementStatus
}

struct MeasurementGroup: Identifiable {
    let id = UUID()
    let month: String
    let measurements: [UroflowMeasurement]
}

// MARK: - Fluid Logger
struct FluidEntry: Identifiable {
    let id: String
    let type: String
    let icon: FluidIcon
    let volume: Int
    let time: String

    enum FluidIcon { case water, coffee, juice }
}

// MARK: - Messages
enum MessageSender { case patient, doctor }

struct ChatMessage: Identifiable {
    let id: Int
    let sender: MessageSender
    let text: String
    let time: String
}

struct Conversation: Identifiable {
    let id: String
    let name: String
    let avatar: String
    let lastMessage: String
    let time: String
    let unread: Int
}

// MARK: - Doctor / Patient
struct Patient: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: String
    let lastMeasurement: String
    let qmax: String
    let status: MeasurementStatus
    let isFlagged: Bool
}

struct PatientDetail {
    let name: String
    let age: Int
    let gender: String
    let condition: String
    let patientId: String
    let latestResult: UroflowResult
    let history: [UroflowMeasurement]
}

struct StockItem: Identifiable {
    let id: String
    var name: String
    var category: String
    var current: Int
    var threshold: Int
    var unit: String
    var status: StockStatus

    var percentage: Double { min(Double(current) / Double(threshold) * 100, 100) }
}

enum PaymentStatus: String {
    case paid    = "Paid"
    case pending = "Pending"
    case partial = "Partial"
}

enum StentStatus: String {
    case inPlace = "In Place"
    case removed = "Removed"
    case na      = "N/A"
}

struct TeamMember: Identifiable {
    let id: String
    var role: String
    var name: String
    var fees: Int
    var paymentStatus: PaymentStatus
}

struct SurgeryRecord: Identifiable {
    let id: String
    var date: String
    var hospital: String
    var myRole: String
    var patientName: String
    var patientId: String
    var phoneNumber: String
    var diagnoses: [String]
    var surgery: String
    var myProfessionalFees: Int
    var myInstrumentCharges: Int
    var paymentStatus: PaymentStatus
    var consumables: [String]
    var rentalName: String
    var rentalFees: Int
    var team: [TeamMember]
    var stentType: String
    var stentDueDate: String
    var stentStatus: StentStatus
    var remarks: String

    var avatar: String {
        String(patientName.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }.joined()).uppercased()
    }
    var surgeryDate: String { date }
    var surgeryType: String { surgery }
    var notes: String { remarks }
}

struct FollowUp: Identifiable {
    let id: String
    let name: String
    let avatar: String
    let dueDate: String
    let daysLeft: Int
    let status: FollowUpStatus
}

struct PendingReview: Identifiable {
    let id = UUID()
    let name: String
    let avatar: String
    let qmax: String
    let time: String
}

// MARK: - Sample Data
struct SampleData {
    static let recentMeasurements: [UroflowMeasurement] = [
        .init(id: 1, date: "Today, 9:30 AM",       qmax: "18.4 mL/s", volume: "280 mL", voidTime: "24s", status: .normal),
        .init(id: 2, date: "Yesterday, 7:15 PM",   qmax: "16.2 mL/s", volume: "245 mL", voidTime: "28s", status: .borderline),
        .init(id: 3, date: "Dec 18, 10:00 AM",     qmax: "14.8 mL/s", volume: "310 mL", voidTime: "32s", status: .abnormal)
    ]

    static let measurementGroups: [MeasurementGroup] = [
        .init(month: "December 2024", measurements: [
            .init(id: 1, date: "Dec 22, 9:30 AM",  qmax: "18.4 mL/s", volume: "280 mL", voidTime: "24s", status: .normal),
            .init(id: 2, date: "Dec 21, 7:15 PM",  qmax: "16.2 mL/s", volume: "245 mL", voidTime: "28s", status: .borderline),
            .init(id: 3, date: "Dec 18, 10:00 AM", qmax: "14.8 mL/s", volume: "310 mL", voidTime: "32s", status: .abnormal)
        ]),
        .init(month: "November 2024", measurements: [
            .init(id: 4, date: "Nov 28, 8:45 AM",  qmax: "17.5 mL/s", volume: "260 mL", voidTime: "25s", status: .normal),
            .init(id: 5, date: "Nov 15, 2:30 PM",  qmax: "15.1 mL/s", volume: "220 mL", voidTime: "29s", status: .borderline)
        ])
    ]

    static let fluidEntries: [FluidEntry] = [
        .init(id: "1", type: "Water",  icon: .water,  volume: 500, time: "9:30 AM"),
        .init(id: "2", type: "Coffee", icon: .coffee, volume: 300, time: "11:00 AM"),
        .init(id: "3", type: "Juice",  icon: .juice,  volume: 250, time: "2:15 PM"),
        .init(id: "4", type: "Water",  icon: .water,  volume: 400, time: "4:30 PM"),
        .init(id: "5", type: "Water",  icon: .water,  volume: 350, time: "6:45 PM")
    ]

    static let patientConversations: [Conversation] = [
        .init(id: "dr-kumar",  name: "Dr. Kumar",               avatar: "DK", lastMessage: "Your recent Qmax shows good improvement. Keep up with the fluid intake.", time: "10:30 AM", unread: 1),
        .init(id: "dr-sharma", name: "Dr. Sharma (Urology Clinic)", avatar: "DS", lastMessage: "Please remember to fast before your ultrasound tomorrow.", time: "Yesterday", unread: 0)
    ]

    static let doctorConversations: [Conversation] = [
        .init(id: "p1", name: "Rajan Kumar", avatar: "RK", lastMessage: "Thank you Dr. Kumar. I have been drinking 2L of water daily as advised.", time: "10:45 AM", unread: 1),
        .init(id: "p2", name: "Amit Patel",  avatar: "AP", lastMessage: "Is it normal to feel slight discomfort after the measurement?", time: "Yesterday", unread: 0),
        .init(id: "p3", name: "Suresh Reddy",avatar: "SR", lastMessage: "I will schedule the follow-up for next week.", time: "Mon", unread: 0)
    ]

    static let chatMessages: [ChatMessage] = [
        .init(id: 1, sender: .doctor,  text: "Hello Rajan, I reviewed your uroflow results from this morning.", time: "10:25 AM"),
        .init(id: 2, sender: .doctor,  text: "Your recent Qmax shows good improvement. Keep up with the fluid intake.", time: "10:30 AM"),
        .init(id: 3, sender: .patient, text: "Thank you Dr. Kumar. I have been drinking 2L of water daily as advised.", time: "10:45 AM")
    ]

    static let patients: [Patient] = [
        .init(id: "1", name: "Rajan Kumar",  avatar: "RK", lastMeasurement: "Today, 9:30 AM",    qmax: "18.4 mL/s", status: .normal,     isFlagged: false),
        .init(id: "2", name: "Priya Sharma", avatar: "PS", lastMeasurement: "Yesterday, 7:15 PM", qmax: "14.2 mL/s", status: .borderline,  isFlagged: true),
        .init(id: "3", name: "Amit Patel",   avatar: "AP", lastMeasurement: "Dec 18, 10:00 AM",   qmax: "16.8 mL/s", status: .normal,     isFlagged: false),
        .init(id: "4", name: "Suresh Reddy", avatar: "SR", lastMeasurement: "Dec 15, 2:30 PM",    qmax: "12.1 mL/s", status: .abnormal,   isFlagged: true)
    ]

    static let patientDetail = PatientDetail(
        name: "Rajan Kumar", age: 58, gender: "Male", condition: "BPH", patientId: "URO-8821",
        latestResult: .init(qmax: 18.4, volume: 280, voidTime: 24, avgFlow: 11.7, date: "Today, 9:30 AM", status: .normal),
        history: [
            .init(id: 1, date: "Yesterday, 7:15 PM", qmax: "16.2 mL/s", volume: "245 mL", voidTime: "28s", status: .borderline),
            .init(id: 2, date: "Dec 18, 10:00 AM",   qmax: "14.8 mL/s", volume: "310 mL", voidTime: "32s", status: .abnormal),
            .init(id: 3, date: "Nov 28, 8:45 AM",    qmax: "17.5 mL/s", volume: "260 mL", voidTime: "25s", status: .normal)
        ]
    )

    static let stockItems: [StockItem] = [
        .init(id: "1", name: "Uroflow Catheters", category: "Medical Supplies", current: 12,  threshold: 20, unit: "units",   status: .low),
        .init(id: "2", name: "Exam Gloves",        category: "PPE",             current: 8,   threshold: 50, unit: "boxes",   status: .critical),
        .init(id: "3", name: "Sterile Drapes",     category: "Medical Supplies", current: 45, threshold: 10, unit: "units",   status: .ok),
        .init(id: "4", name: "Ultrasound Gel",     category: "Consumables",      current: 6,  threshold: 15, unit: "bottles", status: .low)
    ]

    static let surgeries: [SurgeryRecord] = [
        .init(id: "1", date: "2024-12-20", hospital: "City General Hospital", myRole: "Primary Surgeon", patientName: "Rajan Kumar", patientId: "PID-8821", phoneNumber: "+91 98765 43210", diagnoses: ["BPH"], surgery: "TURP", myProfessionalFees: 50000, myInstrumentCharges: 15000, paymentStatus: .paid, consumables: ["Catheter 16F", "Glycine 3L", "Spinal Needle"], rentalName: "Resectoscope", rentalFees: 5000, team: [
            .init(id: "t1", role: "Assistant", name: "Dr. Sharma", fees: 10000, paymentStatus: .paid),
            .init(id: "t2", role: "Nurse", name: "Sister Mary", fees: 2000, paymentStatus: .paid)
        ], stentType: "N/A", stentDueDate: "", stentStatus: .na, remarks: "Uncomplicated procedure. Patient discharged next day."),
        .init(id: "2", date: "2024-12-22", hospital: "Metro Care Hospital", myRole: "Primary Surgeon", patientName: "Amit Patel", patientId: "PID-9932", phoneNumber: "+91 91234 56789", diagnoses: ["Left Ureteric Calculus", "Hydronephrosis"], surgery: "URSL + DJ Stenting", myProfessionalFees: 40000, myInstrumentCharges: 10000, paymentStatus: .pending, consumables: ["Guidewire", "Ureteric Catheter", "DJ Stent 6F 26cm"], rentalName: "Holmium Laser", rentalFees: 8000, team: [
            .init(id: "t3", role: "Assistant", name: "Dr. Verma", fees: 8000, paymentStatus: .pending),
            .init(id: "t4", role: "Nurse", name: "Sister Anita", fees: 1500, paymentStatus: .pending)
        ], stentType: "Double J 6F 26cm", stentDueDate: "2025-01-22", stentStatus: .inPlace, remarks: "Stone completely fragmented. Stent placed.")
    ]

    static let followUps: [FollowUp] = [
        .init(id: "1", name: "Suresh Reddy", avatar: "SR", dueDate: "Dec 28, 2024", daysLeft: 3,  status: .upcoming),
        .init(id: "2", name: "Kavita Singh", avatar: "KS", dueDate: "Dec 25, 2024", daysLeft: 0,  status: .due)
    ]

    static let pendingReviews: [PendingReview] = [
        .init(name: "Rajan Kumar",  avatar: "RK", qmax: "18.4 mL/s", time: "2h ago"),
        .init(name: "Priya Sharma", avatar: "PS", qmax: "14.2 mL/s", time: "5h ago"),
        .init(name: "Amit Patel",   avatar: "AP", qmax: "16.8 mL/s", time: "1d ago")
    ]

    static let latestResult = UroflowResult(
        qmax: 18.4, volume: 280, voidTime: 24, avgFlow: 11.7,
        date: "Today, 9:30 AM", status: .normal
    )
}
