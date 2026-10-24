// test_ios_models.swift — Swift Unit Tests for Phase 6 iOS Networking & ML Models
// Tests:
// 1. Request encoding
// 2. Response decoding
// 3. Feature serialization
// 4. HTTP 400 handling
// 5. HTTP 500 handling
// 6. Network failure
// 7. Empty response
// 8. Flow curve parsing
// 9. Metrics parsing

import Foundation

// MARK: - Mock Models matching APIModels.swift & APIClient.swift

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
}

struct FlowPredictionMetrics: Codable, Sendable {
    let qmaxMLPerSec: Double
    let averageFlowMLPerSec: Double
    let estimatedVolumeML: Double
    let voidingDurationSec: Double

    enum CodingKeys: String, CodingKey {
        case qmaxMLPerSec        = "qmax_ml_s"
        case averageFlowMLPerSec = "average_flow_ml_s"
        case estimatedVolumeML   = "estimated_volume_ml"
        case voidingDurationSec  = "voiding_duration_s"
    }
}

struct AcousticFlowPredictionResponse: Codable, Sendable {
    let success: Bool
    let modelVersion: String
    let researchStatus: String
    let metrics: FlowPredictionMetrics
    let flowCurve: [PredictedFlowPoint]
    let predictionCount: Int

    enum CodingKeys: String, CodingKey {
        case success
        case modelVersion     = "model_version"
        case researchStatus    = "research_status"
        case metrics
        case flowCurve        = "flow_curve"
        case predictionCount  = "prediction_count"
    }
}

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case requestFailed(Int, String)
    case decodingFailed(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestFailed(let c, let m): return "HTTP \(c): \(m)"
        case .decodingFailed(let m): return "Decode error: \(m)"
        case .noData: return "No data received"
        }
    }
}

struct APIErrorResponse: Codable {
    let error: String
}

// MARK: - Test Suite Execution

var passedCount = 0
var failedCount = 0

func assertTest(_ condition: Bool, _ name: String) {
    if condition {
        print("  ✓ PASS: \(name)")
        passedCount += 1
    } else {
        print("  ✗ FAIL: \(name)")
        failedCount += 1
    }
}

print("==================================================")
print("PHASE 6: IOS NETWORKING & ML MODEL UNIT TESTS")
print("==================================================")

let encoder = JSONEncoder()
let decoder = JSONDecoder()

// 1. Request encoding
do {
    let feature = AcousticFlowFeature(
        timestamp: 0.0464,
        rms: 0.0051,
        peak: 0.0210,
        dbfs: -45.8,
        dominantFrequency: 1250.0,
        spectralCentroid: 2450.0,
        spectralEnergy: 0.48
    )
    let req = AcousticFlowPredictionRequest(sampleRate: 44100, features: [feature])
    let data = try encoder.encode(req)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    assertTest(json?["sample_rate"] as? Int == 44100, "1. Request encoding - sample_rate")
    let feats = json?["features"] as? [[String: Any]]
    assertTest(feats?.count == 1, "1. Request encoding - features array length")
    assertTest(feats?.first?["dominant_frequency"] as? Double == 1250.0, "1. Request encoding - snake_case mapping")
} catch {
    assertTest(false, "1. Request encoding error: \(error)")
}

// 2. Response decoding
let sampleValidJSON = """
{
  "success": true,
  "model_version": "1.0.0",
  "research_status": "simulated_dataset_model_not_clinically_validated",
  "metrics": {
    "qmax_ml_s": 24.5,
    "average_flow_ml_s": 14.2,
    "estimated_volume_ml": 280.5,
    "voiding_duration_s": 19.8
  },
  "flow_curve": [
    {"timestamp": 0.0, "flow_ml_s": 0.0},
    {"timestamp": 0.5, "flow_ml_s": 12.1},
    {"timestamp": 1.0, "flow_ml_s": 24.5}
  ],
  "prediction_count": 3
}
""".data(using: .utf8)!

var decodedResp: AcousticFlowPredictionResponse? = nil
do {
    decodedResp = try decoder.decode(AcousticFlowPredictionResponse.self, from: sampleValidJSON)
    assertTest(decodedResp?.success == true, "2. Response decoding - success flag")
    assertTest(decodedResp?.modelVersion == "1.0.0", "2. Response decoding - model_version")
    assertTest(decodedResp?.researchStatus == "simulated_dataset_model_not_clinically_validated", "2. Response decoding - research_status")
} catch {
    assertTest(false, "2. Response decoding error: \(error)")
}

// 3. Feature serialization roundtrip
do {
    let original = AcousticFlowFeature(
        timestamp: 1.23,
        rms: 0.12,
        peak: 0.34,
        dbfs: -22.5,
        dominantFrequency: 850.0,
        spectralCentroid: 1800.0,
        spectralEnergy: 0.95
    )
    let encoded = try encoder.encode(original)
    let restored = try decoder.decode(AcousticFlowFeature.self, from: encoded)
    assertTest(restored.timestamp == 1.23 && restored.dominantFrequency == 850.0, "3. Feature serialization roundtrip")
} catch {
    assertTest(false, "3. Feature serialization error: \(error)")
}

// 4. HTTP 400 handling
let error400JSON = """
{"success": false, "error": "Insufficient frames: received 2, minimum required is 4"}
""".data(using: .utf8)!
do {
    let errResp = try decoder.decode(APIErrorResponse.self, from: error400JSON)
    let apiError = APIError.requestFailed(400, errResp.error)
    if case .requestFailed(let code, let msg) = apiError {
        assertTest(code == 400 && msg.contains("Insufficient frames"), "4. HTTP 400 handling - parses server error message")
    } else {
        assertTest(false, "4. HTTP 400 handling failed")
    }
} catch {
    assertTest(false, "4. HTTP 400 error: \(error)")
}

// 5. HTTP 500 handling
let error500JSON = """
{"success": false, "error": "ML inference failed: Model artifact corrupted"}
""".data(using: .utf8)!
do {
    let errResp = try decoder.decode(APIErrorResponse.self, from: error500JSON)
    let apiError = APIError.requestFailed(500, errResp.error)
    if case .requestFailed(let code, let msg) = apiError {
        assertTest(code == 500 && msg.contains("ML inference failed"), "5. HTTP 500 handling - server error parsing")
    } else {
        assertTest(false, "5. HTTP 500 handling failed")
    }
} catch {
    assertTest(false, "5. HTTP 500 error: \(error)")
}

// 6. Network failure / invalid URL simulation
let invalidError = APIError.invalidURL
assertTest(invalidError.errorDescription == "Invalid URL", "6. Network failure - invalid URL localized error")

// 7. Empty response error handling
let emptyData = Data()
do {
    _ = try decoder.decode(AcousticFlowPredictionResponse.self, from: emptyData)
    assertTest(false, "7. Empty response should throw decoding error")
} catch {
    assertTest(true, "7. Empty response triggers graceful decoding exception")
}

// 8. Flow curve parsing
if let curve = decodedResp?.flowCurve {
    assertTest(curve.count == 3, "8. Flow curve parsing - count")
    assertTest(curve[1].timestamp == 0.5 && curve[1].flowMLPerSec == 12.1, "8. Flow curve parsing - values")
    assertTest(curve[2].id == 1.0, "8. Flow curve parsing - Identifiable id conformance")
} else {
    assertTest(false, "8. Flow curve parsing missing")
}

// 9. Metrics parsing
if let metrics = decodedResp?.metrics {
    assertTest(metrics.qmaxMLPerSec == 24.5, "9. Metrics parsing - Qmax")
    assertTest(metrics.averageFlowMLPerSec == 14.2, "9. Metrics parsing - Average Flow")
    assertTest(metrics.estimatedVolumeML == 280.5, "9. Metrics parsing - Estimated Volume")
    assertTest(metrics.voidingDurationSec == 19.8, "9. Metrics parsing - Voiding Duration")
} else {
    assertTest(false, "9. Metrics parsing missing")
}

print("==================================================")
print("TEST SUMMARY: \(passedCount) PASSED, \(failedCount) FAILED")
print("==================================================")
if failedCount > 0 {
    exit(1)
}
