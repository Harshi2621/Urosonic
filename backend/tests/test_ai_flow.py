"""
test_ai_flow.py — Comprehensive Unit & Integration Tests for Acoustic Flow ML Endpoint
=====================================================================================
Part of Urosonic Phase 6 (Complete ML Backend Integration).

Tests:
1. Model loading
2. Metadata loading
3. 39-dimensional feature validation
4. Valid inference request
5. Missing feature rejection (HTTP 400)
6. Invalid feature rejection (HTTP 400)
7. NaN/Infinity rejection (HTTP 400)
8. Non-monotonic timestamp rejection (HTTP 400)
9. Insufficient frame rejection (HTTP 400)
10. Finite predictions
11. Non-negative predictions
12. Volume integration
13. Response schema
14. Model-loading failure handling
15. Existing Flask routes still work
"""

import json
import math
import os
import sys
import unittest
from unittest.mock import patch

# Setup paths
BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
REPO_ROOT = os.path.abspath(os.path.join(BACKEND_DIR, ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from app import create_app
from ml_inference_service import (
    MLInferenceService,
    RESEARCH_STATUS_STRING,
    EXPECTED_FEATURE_DIM,
    MIN_REQUIRED_FRAMES,
    DEFAULT_MODEL_PATH,
    DEFAULT_METADATA_PATH,
)


def _generate_valid_frame_sequence(num_frames: int = 10, dt: float = 0.0232):
    """Deterministic fixture generating valid synthetic acoustic frames for testing."""
    frames = []
    for i in range(num_frames):
        frames.append({
            "timestamp": round(i * dt, 4),
            "rms": 0.005 + 0.001 * math.sin(i * 0.1),
            "peak": 0.02 + 0.002 * math.cos(i * 0.1),
            "dbfs": -45.0 + 2.0 * math.sin(i * 0.2),
            "dominant_frequency": 1200.0 + 50.0 * math.sin(i * 0.3),
            "spectral_centroid": 2500.0 + 100.0 * math.cos(i * 0.3),
            "spectral_energy": 0.5 + 0.05 * math.sin(i * 0.1),
        })
    return frames


class TestAcousticFlowBackend(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app()
        cls.client = cls.app.test_client()
        cls.service = MLInferenceService.get_instance()

    # 1. Model loading
    def test_01_model_loading(self):
        self.assertTrue(self.service.is_loaded)
        self.assertIsNotNone(self.service.model)
        self.assertEqual(type(self.service.model).__name__, "GradientBoostingRegressor")

    # 2. Metadata loading
    def test_02_metadata_loading(self):
        self.assertIsInstance(self.service.metadata, dict)
        self.assertEqual(self.service.metadata.get("model_version"), "1.0.0")
        self.assertEqual(self.service.metadata.get("model_type"), "GradientBoostingRegressor")
        self.assertEqual(self.service.metadata.get("scaler_type"), "StandardScaler")

    # 3. 39-dimensional feature validation
    def test_03_feature_dimensions(self):
        feature_names = self.service.metadata.get("feature_names", [])
        self.assertEqual(len(feature_names), EXPECTED_FEATURE_DIM)
        scaler = self.service.pipeline.scaler
        self.assertEqual(getattr(scaler, "n_features_in_", None), EXPECTED_FEATURE_DIM)
        self.assertEqual(len(scaler.mean_), EXPECTED_FEATURE_DIM)
        self.assertEqual(len(scaler.scale_), EXPECTED_FEATURE_DIM)

    # 4. Valid inference request
    def test_04_valid_inference_request(self):
        frames = _generate_valid_frame_sequence(10)
        payload = {"sample_rate": 44100, "features": frames}
        response = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertTrue(data.get("success"))
        self.assertEqual(data.get("prediction_count"), len(frames))
        self.assertEqual(len(data.get("flow_curve", [])), len(frames))

    # 5. Missing feature rejection (HTTP 400)
    def test_05_missing_feature_rejection(self):
        frames = _generate_valid_frame_sequence(6)
        # Drop 'rms' from frame index 2
        del frames[2]["rms"]
        payload = {"sample_rate": 44100, "features": frames}
        response = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertFalse(data.get("success"))
        self.assertIn("missing required field: 'rms'", data.get("error"))

    # 6. Invalid feature rejection (HTTP 400)
    def test_06_invalid_feature_rejection(self):
        frames = _generate_valid_frame_sequence(6)
        # String instead of float
        frames[1]["spectral_energy"] = "not_a_number"
        payload = {"sample_rate": 44100, "features": frames}
        response = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertFalse(data.get("success"))
        self.assertIn("must be numeric", data.get("error"))

    # 7. NaN/Infinity rejection (HTTP 400)
    def test_07_nan_infinity_rejection(self):
        frames_nan = _generate_valid_frame_sequence(6)
        frames_nan[2]["peak"] = float("nan")
        payload_nan = {"sample_rate": 44100, "features": frames_nan}
        # Python json.dumps by default outputs NaN which might be parsed, let's verify
        response_nan = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload_nan),
            content_type="application/json",
        )
        self.assertEqual(response_nan.status_code, 400)
        self.assertIn("must be finite", response_nan.get_json().get("error"))

        frames_inf = _generate_valid_frame_sequence(6)
        frames_inf[3]["dbfs"] = float("inf")
        payload_inf = {"sample_rate": 44100, "features": frames_inf}
        response_inf = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload_inf),
            content_type="application/json",
        )
        self.assertEqual(response_inf.status_code, 400)
        self.assertIn("must be finite", response_inf.get_json().get("error"))

    # 8. Non-monotonic timestamp rejection (HTTP 400)
    def test_08_non_monotonic_timestamp_rejection(self):
        frames = _generate_valid_frame_sequence(6)
        # Set timestamp of frame 3 lower than frame 2
        frames[3]["timestamp"] = frames[1]["timestamp"]
        payload = {"sample_rate": 44100, "features": frames}
        response = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertFalse(data.get("success"))
        self.assertIn("Non-monotonic timestamp", data.get("error"))

    # 9. Insufficient frame rejection (HTTP 400)
    def test_09_insufficient_frame_rejection(self):
        frames = _generate_valid_frame_sequence(MIN_REQUIRED_FRAMES - 1)
        payload = {"sample_rate": 44100, "features": frames}
        response = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertFalse(data.get("success"))
        self.assertIn("Insufficient frames", data.get("error"))

    # 10. Finite predictions
    def test_10_finite_predictions(self):
        frames = _generate_valid_frame_sequence(15)
        res = self.service.predict_flow(frames, 44100)
        for pt in res["flow_curve"]:
            self.assertTrue(math.isfinite(pt["timestamp"]))
            self.assertTrue(math.isfinite(pt["flow_ml_s"]))
        metrics = res["metrics"]
        self.assertTrue(math.isfinite(metrics["qmax_ml_s"]))
        self.assertTrue(math.isfinite(metrics["average_flow_ml_s"]))
        self.assertTrue(math.isfinite(metrics["estimated_volume_ml"]))
        self.assertTrue(math.isfinite(metrics["voiding_duration_s"]))

    # 11. Non-negative predictions
    def test_11_non_negative_predictions(self):
        frames = _generate_valid_frame_sequence(20)
        res = self.service.predict_flow(frames, 44100)
        for pt in res["flow_curve"]:
            self.assertGreaterEqual(pt["flow_ml_s"], 0.0)
        self.assertGreaterEqual(res["metrics"]["qmax_ml_s"], 0.0)
        self.assertGreaterEqual(res["metrics"]["average_flow_ml_s"], 0.0)
        self.assertGreaterEqual(res["metrics"]["estimated_volume_ml"], 0.0)

    # 12. Volume integration
    def test_12_volume_integration(self):
        # Create a controlled frame sequence with 1-second intervals and constant flow
        frames = _generate_valid_frame_sequence(5, dt=1.0)
        res = self.service.predict_flow(frames, 44100)
        pts = res["flow_curve"]
        # Manual trapezoidal integration check
        expected_vol = 0.0
        for i in range(len(pts) - 1):
            dt = pts[i + 1]["timestamp"] - pts[i]["timestamp"]
            f_avg = 0.5 * (pts[i]["flow_ml_s"] + pts[i + 1]["flow_ml_s"])
            expected_vol += f_avg * dt
        self.assertAlmostEqual(res["metrics"]["estimated_volume_ml"], expected_vol, places=3)

    # 13. Response schema
    def test_13_response_schema(self):
        frames = _generate_valid_frame_sequence(8)
        payload = {"sample_rate": 44100, "features": frames}
        response = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn("success", data)
        self.assertIn("model_version", data)
        self.assertIn("research_status", data)
        self.assertEqual(data["research_status"], RESEARCH_STATUS_STRING)
        self.assertIn("metrics", data)
        for m in ["qmax_ml_s", "average_flow_ml_s", "estimated_volume_ml", "voiding_duration_s"]:
            self.assertIn(m, data["metrics"])
        self.assertIn("flow_curve", data)
        self.assertIn("prediction_count", data)

    # 14. Model-loading failure handling
    def test_14_model_loading_failure(self):
        with self.assertRaises(FileNotFoundError):
            MLInferenceService(
                model_path="/path/that/does/not/exist.joblib",
                metadata_path=DEFAULT_METADATA_PATH,
            )

    # 15. Existing Flask routes still work
    def test_15_existing_flask_routes(self):
        # Root endpoint
        r_root = self.client.get("/")
        self.assertEqual(r_root.status_code, 200)
        self.assertIn("Urosonic API Server is running", r_root.get_json().get("message", ""))

        # Health endpoint
        r_health = self.client.get("/health")
        self.assertEqual(r_health.status_code, 200)
        self.assertEqual(r_health.get_json().get("status"), "ok")

    # 16. Silence and pre/post-void gating
    def test_16_silence_and_prepost_void_gating(self):
        # 5 silence frames (pre-void) + 10 urine frames + 5 silence frames (post-void)
        dt = 0.05
        frames = []
        # Pre-void silence at -70 dBFS
        for i in range(5):
            frames.append({
                "timestamp": round(i * dt, 4),
                "rms": 0.0002, "peak": 0.0005, "dbfs": -70.0,
                "dominant_frequency": 60.0, "spectral_centroid": 150.0, "spectral_energy": 0.001
            })
        # Active urination at -42 dBFS (1200 Hz impact resonance)
        for i in range(5, 15):
            frames.append({
                "timestamp": round(i * dt, 4),
                "rms": 0.015, "peak": 0.05, "dbfs": -42.0,
                "dominant_frequency": 1100.0, "spectral_centroid": 1800.0, "spectral_energy": 0.8
            })
        # Post-void silence at -70 dBFS
        for i in range(15, 20):
            frames.append({
                "timestamp": round(i * dt, 4),
                "rms": 0.0002, "peak": 0.0005, "dbfs": -70.0,
                "dominant_frequency": 60.0, "spectral_centroid": 150.0, "spectral_energy": 0.001
            })

        res = self.service.predict_flow(frames, 44100)
        curve = res["flow_curve"]
        # Pre-void silence frames must be 0.0 mL/s
        for idx in range(3):
            self.assertEqual(curve[idx]["flow_ml_s"], 0.0, f"Frame {idx} should be 0.0 mL/s silence")
        # Post-void silence frames must be 0.0 mL/s
        for idx in range(17, 20):
            self.assertEqual(curve[idx]["flow_ml_s"], 0.0, f"Frame {idx} should be 0.0 mL/s silence")
        # Active urination must have positive flow
        max_active_flow = max(c["flow_ml_s"] for c in curve[6:14])
        self.assertGreater(max_active_flow, 0.0, "Urination frames must have positive flow")

    # 17. Handling click / bump rejection
    def test_17_handling_click_rejection(self):
        # A sequence of silence with an impulsive phone handling click (crest factor 12.0)
        dt = 0.05
        frames = []
        for i in range(10):
            if i == 4:
                # Impulse click (sharp spike in 1 frame)
                frames.append({
                    "timestamp": round(i * dt, 4),
                    "rms": 0.003, "peak": 0.045, "dbfs": -50.0,  # Crest factor = 15.0
                    "dominant_frequency": 90.0, "spectral_centroid": 120.0, "spectral_energy": 0.05
                })
            else:
                frames.append({
                    "timestamp": round(i * dt, 4),
                    "rms": 0.0002, "peak": 0.0005, "dbfs": -70.0,
                    "dominant_frequency": 60.0, "spectral_centroid": 100.0, "spectral_energy": 0.001
                })

        res = self.service.predict_flow(frames, 44100)
        curve = res["flow_curve"]
        # The handling click must NOT produce a false urination flow
        self.assertEqual(res["metrics"]["qmax_ml_s"], 0.0, "Click should not trigger uroflow")
        for pt in curve:
            self.assertEqual(pt["flow_ml_s"], 0.0, "All non-urination frames must be 0.0 mL/s")

    # 18. Running faucet water rejection
    def test_18_faucet_high_frequency_rejection(self):
        # High frequency hiss from tap/faucet (> 3500 Hz dominant)
        dt = 0.05
        frames = []
        for i in range(10):
            frames.append({
                "timestamp": round(i * dt, 4),
                "rms": 0.010, "peak": 0.025, "dbfs": -45.0,
                "dominant_frequency": 4200.0, "spectral_centroid": 4500.0, "spectral_energy": 0.6
            })
        res = self.service.predict_flow(frames, 44100)
        # Faucet spray should be suppressed
        self.assertLess(res["metrics"]["qmax_ml_s"], 2.0, "High-frequency faucet should be suppressed")

    # 19. Perfect smooth curve and metrics
    def test_19_perfect_smooth_curve_and_metrics(self):
        # 20 frames of valid urination
        frames = _generate_valid_frame_sequence(20, dt=0.05)
        res = self.service.predict_flow(frames, 44100)
        curve = res["flow_curve"]
        # Smooth curve properties:
        # 1. Non-negative
        for pt in curve:
            self.assertGreaterEqual(pt["flow_ml_s"], 0.0)
        # 2. Qmax is positive and matches max of curve
        curve_max = max(pt["flow_ml_s"] for pt in curve)
        self.assertAlmostEqual(res["metrics"]["qmax_ml_s"], curve_max, places=3)
        # 3. Volume is positive and trapezoidal
        self.assertGreater(res["metrics"]["estimated_volume_ml"], 0.0)
        # 4. Voiding duration is positive
        self.assertGreater(res["metrics"]["voiding_duration_s"], 0.0)

    # 20. Cumulative volume curve and clinical urodynamic metrics
    def test_20_cumulative_volume_and_clinical_metrics(self):
        frames = _generate_valid_frame_sequence(25, dt=0.05)
        res = self.service.predict_flow(frames, 44100)
        self.assertIn("volume_curve", res)
        vol_curve = res["volume_curve"]
        self.assertEqual(len(vol_curve), len(frames))
        
        # Verify volume curve is monotonically non-decreasing
        prev_vol = -1.0
        for pt in vol_curve:
            self.assertGreaterEqual(pt["volume_ml"], prev_vol)
            prev_vol = pt["volume_ml"]
            
        # Final volume matches estimated_volume_ml
        self.assertAlmostEqual(vol_curve[-1]["volume_ml"], res["metrics"]["estimated_volume_ml"], places=2)
        
        # Verify clinical parameters present
        metrics = res["metrics"]
        self.assertIn("flow_start_time_s", metrics)
        self.assertIn("max_flow_time_s", metrics)
        self.assertIn("start_time_s", metrics)
        self.assertIn("stop_time_s", metrics)
        self.assertIn("flow_intervals", metrics)
        self.assertIn("siroky_max_sd", metrics)
        self.assertIn("siroky_avg_sd", metrics)
        self.assertGreaterEqual(metrics["max_flow_time_s"], metrics["flow_start_time_s"])


if __name__ == "__main__":
    unittest.main()
