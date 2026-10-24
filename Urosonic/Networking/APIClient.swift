// APIClient.swift — Centralised async/await HTTP client for the Urosonic backend

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(Int, String)
    case decodingFailed(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Invalid URL"
        case .requestFailed(let c, let m): return "HTTP \(c): \(m)"
        case .decodingFailed(let m):    return "Decode error: \(m)"
        case .noData:                   return "No data received"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    // ── Base URL Configuration ──
    static let baseURL = "http://180.235.121.245:8072"

    var base: String {
        Self.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func testConnection() async -> (success: Bool, message: String) {
        guard let url = URL(string: "\(base)/health") else {
            return (false, "Invalid URL format")
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return (false, "Invalid response from server")
            }
            if (200...299).contains(http.statusCode) {
                return (true, "Connected successfully (HTTP \(http.statusCode))")
            } else {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                return (false, "Server error: \(msg)")
            }
        } catch {
            return (false, "Cannot connect to \(base): \(error.localizedDescription)")
        }
    }

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 8
        cfg.timeoutIntervalForResource = 15
        return URLSession(configuration: cfg)
    }()

    private init() {
        UserDefaults.standard.removeObject(forKey: "backend_base_url")
    }

    // ── Core request with automatic fallback ───────────────────────────────
    private func request<T: Decodable>(
        path:   String,
        method: String = "GET",
        body:   [String: Any]? = nil
    ) async throws -> T {
        do {
            return try await executeRequest(path: path, method: method, body: body, baseURL: base)
        } catch let err as URLError where err.code == .timedOut || err.code == .cannotConnectToHost || err.code == .networkConnectionLost {
            throw APIError.requestFailed(0, "Unable to connect to server: \(err.localizedDescription)")
        }
    }

    private func executeRequest<T: Decodable>(
        path:   String,
        method: String,
        body:   [String: Any]?,
        baseURL: String
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }

        var req        = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await SessionManager.shared.getAuthToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let uid = await SessionManager.shared.currentUserId {
            req.setValue("\(uid)", forHTTPHeaderField: "X-User-ID")
        }

        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: req)
        let http = response as! HTTPURLResponse

        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 && !path.contains("/auth/login") {
                await SessionManager.shared.endSession()
            }
            let msg = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.requestFailed(http.statusCode, msg)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    // ── Convenience wrappers ───────────────────────────────────────────────
    func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(path: path)
    }
    func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        try await request(path: path, method: "POST", body: body)
    }
    func put<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        try await request(path: path, method: "PUT", body: body)
    }
    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request(path: path, method: "DELETE")
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — AUTH
    // ════════════════════════════════════════════════════════════════════════
    func login(email: String, password: String, role: String) async throws -> APIUser {
        struct Resp: Decodable { let user: APIUser }
        let r: Resp = try await post("/auth/login", body: ["email": email, "password": password, "role": role])
        return r.user
    }

    func register(
        fullName: String, email: String, phone: String,
        password: String, role: String,
        licenseNumber: String = "", specialization: String = "Urology",
        age: Int? = nil, gender: String = "", condition: String = ""
    ) async throws -> APIUser {
        struct Resp: Decodable { let user: APIUser }
        var body: [String: Any] = [
            "full_name": fullName, "email": email, "phone": phone,
            "password": password, "role": role
        ]
        if role == "doctor" {
            body["license_number"]  = licenseNumber
            body["specialization"]  = specialization
        } else {
            if let a = age { body["age"] = a }
            body["gender"]    = gender
            body["condition"] = condition
        }
        let r: Resp = try await post("/auth/register", body: body)
        return r.user
    }

    func forgotPassword(email: String) async throws -> String {
        struct Resp: Decodable { let message: String; let resetToken: String?
            enum CodingKeys: String, CodingKey { case message; case resetToken = "reset_token" } }
        let r: Resp = try await post("/auth/forgot-password", body: ["email": email])
        return r.resetToken ?? r.message
    }

    func resetPassword(token: String, newPassword: String) async throws {
        let _: APIMessageResponse = try await post("/auth/reset-password",
            body: ["token": token, "new_password": newPassword])
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — PROFILE
    // ════════════════════════════════════════════════════════════════════════
    func getProfile(userId: Int) async throws -> APIUser {
        try await get("/profile/\(userId)")
    }

    func updateProfile(userId: Int, body: [String: Any]) async throws -> APIUser {
        struct Resp: Decodable { let profile: APIUser }
        let r: Resp = try await put("/profile/\(userId)", body: body)
        return r.profile
    }

    func changePassword(userId: Int, current: String, new: String) async throws {
        let _: APIMessageResponse = try await put(
            "/profile/\(userId)/change-password",
            body: ["current_password": current, "new_password": new]
        )
    }

    func deleteAccount(userId: Int) async throws {
        let _: APIMessageResponse = try await delete("/profile/\(userId)")
    }

    func getDashboard(doctorId: Int) async throws -> APIDashboard {
        try await get("/profile/doctor/\(doctorId)/dashboard")
    }

    func getDoctorPatients(doctorId: Int, search: String = "") async throws -> [APIPatientListItem] {
        let path = search.isEmpty
            ? "/profile/doctor/\(doctorId)/patients"
            : "/profile/doctor/\(doctorId)/patients?search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        return try await get(path)
    }

    func getDoctors() async throws -> [APIDoctorItem] {
        try await get("/profile/doctors")
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — MEASUREMENTS
    // ════════════════════════════════════════════════════════════════════════
    func getMeasurements(patientId: Int) async throws -> [APIMeasurement] {
        try await get("/measurements/patient/\(patientId)")
    }

    func getLatestMeasurement(patientId: Int) async throws -> APIMeasurement {
        try await get("/measurements/patient/\(patientId)/latest")
    }

    func saveMeasurement(
        patientId: Int,
        qmax: Double,
        volume: Int,
        voidTime: Int,
        avgFlow: Double?,
        flowCurve: [PredictedFlowPoint]? = nil,
        volumeCurve: [PredictedVolumePoint]? = nil,
        flowStartTime: Double? = nil,
        maxFlowTime: Double? = nil,
        flowIntervals: Int? = nil,
        sirokyMaxSD: Double? = nil,
        sirokyAvgSD: Double? = nil
    ) async throws -> APIMeasurement {
        struct Resp: Decodable { let measurement: APIMeasurement }
        var body: [String: Any] = [
            "patient_id": patientId,
            "qmax": qmax,
            "volume": volume,
            "void_time": voidTime
        ]
        if let af = avgFlow { body["avg_flow"] = af }

        var curvePayload: [String: Any] = [:]
        if let fc = flowCurve, !fc.isEmpty {
            curvePayload["flow_curve"] = fc.map { ["timestamp": $0.timestamp, "flow_ml_s": $0.flowMLPerSec] }
        }
        if let vc = volumeCurve, !vc.isEmpty {
            curvePayload["volume_curve"] = vc.map { ["timestamp": $0.timestamp, "volume_ml": $0.volumeML] }
        }
        if let fst = flowStartTime { curvePayload["flow_start_time_s"] = fst }
        if let mft = maxFlowTime { curvePayload["max_flow_time_s"] = mft }
        if let fi = flowIntervals { curvePayload["flow_intervals"] = fi }
        if let smsd = sirokyMaxSD { curvePayload["siroky_max_sd"] = smsd }
        if let sasd = sirokyAvgSD { curvePayload["siroky_avg_sd"] = sasd }

        if !curvePayload.isEmpty {
            body["flow_curve"] = curvePayload
        }

        let r: Resp = try await post("/measurements", body: body)
        return r.measurement
    }

    func deleteMeasurement(id: Int) async throws {
        let _: APIMessageResponse = try await delete("/measurements/\(id)")
    }

    func linkDoctor(patientId: Int, doctorId: Int) async throws -> APIUser {
        try await updateProfile(userId: patientId, body: ["doctor_id": doctorId])
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — FLUID
    // ════════════════════════════════════════════════════════════════════════
    func getFluidSummary(patientId: Int) async throws -> APIFluidSummary {
        try await get("/fluid/patient/\(patientId)/today-summary")
    }

    func getFluidLogs(patientId: Int, date: String? = nil) async throws -> (entries: [APIFluidEntry], total: Int) {
        struct Resp: Decodable { let entries: [APIFluidEntry]; let totalMl: Int
            enum CodingKeys: String, CodingKey { case entries; case totalMl = "total_ml" } }
        let path = date == nil ? "/fluid/patient/\(patientId)" : "/fluid/patient/\(patientId)?date=\(date!)"
        let r: Resp = try await get(path)
        return (r.entries, r.totalMl)
    }

    func addFluidLog(patientId: Int, drinkType: String, volumeMl: Int, loggedAt: String, logDate: String? = nil) async throws -> APIFluidEntry {
        struct Resp: Decodable { let entry: APIFluidEntry }
        var body: [String: Any] = [
            "patient_id": patientId, "drink_type": drinkType,
            "volume_ml": volumeMl, "logged_at": loggedAt
        ]
        if let ld = logDate { body["log_date"] = ld }
        let r: Resp = try await post("/fluid", body: body)
        return r.entry
    }

    func deleteFluidLog(id: Int) async throws {
        let _: APIMessageResponse = try await delete("/fluid/\(id)")
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — URINE OUTPUT LOGS
    // ════════════════════════════════════════════════════════════════════════
    func getUrineOutputLogs(patientId: Int, date: String? = nil) async throws -> (entries: [APIUrineOutputEntry], total: Int) {
        struct Resp: Decodable { let entries: [APIUrineOutputEntry]; let totalMl: Int
            enum CodingKeys: String, CodingKey { case entries; case totalMl = "total_ml" } }
        let path = date == nil ? "/fluid/patient/\(patientId)/output" : "/fluid/patient/\(patientId)/output?date=\(date!)"
        let r: Resp = try await get(path)
        return (r.entries, r.totalMl)
    }

    func addUrineOutputLog(
        patientId: Int,
        volumeMl: Int,
        urgency: String? = nil,
        color: String? = nil,
        source: String? = nil,
        loggedAt: String,
        logDate: String? = nil,
        notes: String? = nil
    ) async throws -> APIUrineOutputEntry {
        struct Resp: Decodable { let entry: APIUrineOutputEntry }
        var body: [String: Any] = [
            "patient_id": patientId,
            "volume_ml": volumeMl,
            "logged_at": loggedAt
        ]
        if let u = urgency { body["urgency"] = u }
        if let c = color { body["color"] = c }
        if let s = source { body["source"] = s }
        if let ld = logDate { body["log_date"] = ld }
        if let n = notes { body["notes"] = n }
        let r: Resp = try await post("/fluid/output", body: body)
        return r.entry
    }

    func deleteUrineOutputLog(id: Int) async throws {
        let _: APIMessageResponse = try await delete("/fluid/output/\(id)")
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — SURGERY
    // ════════════════════════════════════════════════════════════════════════
    func getSurgeries(doctorId: Int) async throws -> [APISurgeryRecord] {
        try await get("/surgery/doctor/\(doctorId)")
    }

    func addSurgery(body: [String: Any]) async throws -> APISurgeryRecord {
        struct Resp: Decodable { let surgery: APISurgeryRecord }
        let r: Resp = try await post("/surgery", body: body)
        return r.surgery
    }

    func updateSurgery(id: Int, body: [String: Any]) async throws -> APISurgeryRecord {
        struct Resp: Decodable { let surgery: APISurgeryRecord }
        let r: Resp = try await put("/surgery/\(id)", body: body)
        return r.surgery
    }

    func deleteSurgery(id: Int) async throws {
        let _: APIMessageResponse = try await delete("/surgery/\(id)")
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — STOCK
    // ════════════════════════════════════════════════════════════════════════
    func getStock(doctorId: Int) async throws -> APIStockResponse {
        try await get("/stock/\(doctorId)")
    }

    func addStockItem(doctorId: Int, name: String, category: String, currentQty: Int, threshold: Int, unit: String) async throws -> APIStockItem {
        struct Resp: Decodable { let item: APIStockItem }
        let r: Resp = try await post("/stock", body: [
            "doctor_id": doctorId, "name": name,
            "category": category, "current_qty": currentQty,
            "threshold": threshold, "unit": unit
        ])
        return r.item
    }

    func updateStockItem(id: Int, body: [String: Any]) async throws -> APIStockItem {
        struct Resp: Decodable { let item: APIStockItem }
        let r: Resp = try await put("/stock/\(id)", body: body)
        return r.item
    }

    func restockItem(id: Int, quantity: Int) async throws -> APIStockItem {
        struct Resp: Decodable { let item: APIStockItem }
        let r: Resp = try await post("/stock/\(id)/restock", body: ["quantity": quantity])
        return r.item
    }

    func deleteStockItem(id: Int) async throws {
        let _: APIMessageResponse = try await delete("/stock/\(id)")
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — FOLLOW-UPS
    // ════════════════════════════════════════════════════════════════════════
    func getFollowUps(doctorId: Int) async throws -> [APIFollowUp] {
        try await get("/followup/doctor/\(doctorId)")
    }

    func addFollowUp(doctorId: Int, patientId: Int, dueDate: String, notes: String) async throws -> APIFollowUp {
        struct Resp: Decodable {
            let followUp: APIFollowUp
            enum CodingKeys: String, CodingKey {
                case followUp = "followup"
                case followUpAlt = "follow_up"
            }
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let f = try? container.decode(APIFollowUp.self, forKey: .followUp) {
                    self.followUp = f
                } else {
                    self.followUp = try container.decode(APIFollowUp.self, forKey: .followUpAlt)
                }
            }
        }
        let r: Resp = try await post("/followup", body: [
            "doctor_id": doctorId, "patient_id": patientId,
            "due_date": dueDate, "notes": notes
        ])
        return r.followUp
    }

    func completeFollowUp(id: Int) async throws {
        let _: APIMessageResponse = try await post("/followup/\(id)/complete", body: [:])
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — FEEDBACK
    // ════════════════════════════════════════════════════════════════════════
    func getFeedback(patientId: Int) async throws -> [APIFeedback] {
        try await get("/feedback/patient/\(patientId)")
    }

    func submitFeedback(
        measurementId: Int,
        doctorId: Int,
        patientId: Int,
        interpretation: String,
        notes: String = "",
        prescription: String? = nil,
        followUpDate: String? = nil
    ) async throws -> APIFeedback {
        struct Resp: Decodable { let feedback: APIFeedback }
        var body: [String: Any] = [
            "measurement_id": measurementId,
            "doctor_id":      doctorId,
            "patient_id":     patientId,
            "interpretation": interpretation,
            "clinical_notes": notes
        ]
        if let p = prescription, !p.isEmpty { body["prescription"] = p }
        if let f = followUpDate, !f.isEmpty { body["follow_up_date"] = f }
        let r: Resp = try await post("/feedback", body: body)
        return r.feedback
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — CHAT
    // ════════════════════════════════════════════════════════════════════════
    func getConversations(userId: Int) async throws -> [APIConversation] {
        try await get("/messages/conversations/\(userId)")
    }

    func getThread(userA: Int, userB: Int) async throws -> [APIChatMessage] {
        try await get("/messages/thread/\(userA)/\(userB)")
    }

    func sendMessage(senderId: Int, receiverId: Int, text: String) async throws -> APIChatMessage {
        struct Resp: Decodable {
            let chatMessage: APIChatMessage
            enum CodingKeys: String, CodingKey {
                case chatMessage = "chat_message"
                case messageAlt = "message"
            }
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let cm = try? container.decode(APIChatMessage.self, forKey: .chatMessage) {
                    self.chatMessage = cm
                } else {
                    self.chatMessage = try container.decode(APIChatMessage.self, forKey: .messageAlt)
                }
            }
        }
        let r: Resp = try await post("/messages", body: [
            "sender_id": senderId, "receiver_id": receiverId, "message": text
        ])
        return r.chatMessage
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: — AI / PREDICTION (Real-time Flow Curve Inference)
    // ════════════════════════════════════════════════════════════════════════

    /// Sends high-density acoustic frames extracted via vDSP to the Python
    /// Random Forest regression service. The returned flow curve is used to render
    /// the milliliter-per-second graph and calculate Qmax/Qavg.
    ///
    /// - Parameters:
    ///   - features: Acoustic features array extracted during active recording.
    ///   - sampleRate: Hardware audio sample rate (typically 44100 Hz).
    /// - Returns: Complete `AcousticFlowPredictionResponse` with instantaneous flow points and summary statistics.
    func predictFlow(
        features: [AudioFrameFeature],
        sampleRate: Int
    ) async throws -> AcousticFlowPredictionResponse {
        let convertedFeatures = features.enumerated().map { index, frame -> AcousticFlowFeature in
            var f = AcousticFlowFeature(from: frame)
            if f.timestamp.isNaN || f.timestamp.isInfinite || f.timestamp < 0 {
                f = AcousticFlowFeature(
                    timestamp: Double(index) * 0.1,
                    rms: f.rms,
                    peak: f.peak,
                    dbfs: f.dbfs,
                    dominantFrequency: f.dominantFrequency,
                    spectralCentroid: f.spectralCentroid,
                    spectralEnergy: f.spectralEnergy
                )
            }
            return f
        }

        let requestBody = AcousticFlowPredictionRequest(
            sampleRate: sampleRate,
            features: convertedFeatures
        )

        guard let url = URL(string: "\(base)/api/v1/ai/predict-flow") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error
                ?? String(data: data, encoding: .utf8) ?? "Server error (\(http.statusCode))"
            throw APIError.requestFailed(http.statusCode, msg)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AcousticFlowPredictionResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }
}
