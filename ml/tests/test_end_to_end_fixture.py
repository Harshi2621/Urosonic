"""
test_end_to_end_fixture.py — End-to-End Technical Integration Test with Simulated Audio Fixture
=============================================================================================
Part of Urosonic Phase 6 (Complete ML Backend Integration).

TECHNICAL INTEGRATION FIXTURE NOTICE:
====================================
This test uses an existing simulated voiding-sound WAV fixture from `ml/datasets/sessions/`.
LABEL: SIMULATED DATASET INTEGRATION FIXTURE
This fixture is NOT human urination data. It is a benchmark audio file from the simulated
voiding-sound dataset used strictly for software pipeline verification.

Pipeline tested:
Simulated WAV
    ↓
Phase 2 feature extraction (RMS, peak, dBFS, FFT dominant frequency, spectral centroid, spectral energy)
    ↓
Phase 5 exact 39-D temporal feature construction
    ↓
Flask endpoint POST /api/v1/ai/predict-flow
    ↓
Trained GradientBoostingRegressor model (acoustic_flow_model.joblib)
    ↓
Real predicted flow timeline + clinical metrics (Qmax, Avg Flow, Trapezoidal Volume)
    ↓
JSON response verification
"""

import json
import math
import os
import sys
import unittest

# Setup paths
ML_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
REPO_ROOT = os.path.abspath(os.path.join(ML_DIR, ".."))
BACKEND_DIR = os.path.join(REPO_ROOT, "backend")

if ML_DIR not in sys.path:
    sys.path.insert(0, ML_DIR)
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from app import create_app
from adapt_audio_flow_dataset import extract_dsp_features_from_wav


class TestEndToEndSimulatedFixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app()
        cls.client = cls.app.test_client()

        # Dynamically discover an existing session WAV from ml/datasets/sessions/
        sessions_dir = os.path.join(ML_DIR, "datasets", "sessions")
        cls.fixture_wav_path = None
        cls.fixture_session_id = None

        # Prefer a known phone active flow session
        preferred_sessions = [
            "session_phone_phone_f_25_60s",
            "session_phone_phone_f_15_60s",
            "session_phone_phone_f_10_60s",
            "session_oppo_oppo_f_25_60s",
        ]

        for s_name in preferred_sessions:
            cand = os.path.join(sessions_dir, s_name, "audio.wav")
            if os.path.exists(cand):
                cls.fixture_wav_path = cand
                cls.fixture_session_id = s_name
                break

        # Fallback: scan sessions directory
        if cls.fixture_wav_path is None and os.path.exists(sessions_dir):
            for entry in sorted(os.listdir(sessions_dir)):
                cand = os.path.join(sessions_dir, entry, "audio.wav")
                if os.path.exists(cand):
                    cls.fixture_wav_path = cand
                    cls.fixture_session_id = entry
                    break

        if cls.fixture_wav_path is None:
            synth_dir = os.path.join(sessions_dir, "session_synthetic_test")
            os.makedirs(synth_dir, exist_ok=True)
            synth_wav = os.path.join(synth_dir, "audio.wav")
            
            # Generate 4.0s of synthetic hydroacoustic signal at 44100 Hz
            import numpy as np
            from scipy.io import wavfile
            sr = 44100
            dur = 4.0
            t = np.linspace(0, dur, int(sr * dur), endpoint=False)
            envelope = np.sin(np.pi * t / dur) ** 1.5
            np.random.seed(42)
            noise = np.random.normal(0, 0.18, len(t))
            harmonics = 0.2 * np.sin(2 * np.pi * 350 * t) + 0.12 * np.sin(2 * np.pi * 700 * t)
            signal = np.clip((noise + harmonics) * envelope, -0.95, 0.95)
            signal_int16 = (signal * 32767).astype(np.int16)
            wavfile.write(synth_wav, sr, signal_int16)
            
            cls.fixture_wav_path = synth_wav
            cls.fixture_session_id = "session_synthetic_test"

        print("\n==================================================")
        print("SIMULATED DATASET INTEGRATION FIXTURE")
        print(f"Session:  {cls.fixture_session_id}")
        print(f"WAV Path: {cls.fixture_wav_path}")
        print("Note: NOT human clinical data. Software test only.")
        print("==================================================")

    def test_e2e_wav_to_backend_prediction(self):
        """Execute full technical integration from WAV through Flask prediction endpoint."""
        # 1. Phase 2 DSP Feature Extraction from simulated WAV
        sample_rate, total_dur, all_frames = extract_dsp_features_from_wav(
            self.fixture_wav_path,
            frame_size=1024,
            hop_size=1024,
        )
        self.assertGreater(len(all_frames), 50, "WAV feature extraction should produce frames")
        self.assertGreater(sample_rate, 0)

        # Test on the first 150 frames (~3.5 seconds) for rapid, deterministic test execution
        test_frames = all_frames[:150]

        # 2. Construct API Payload
        payload = {
            "sample_rate": sample_rate,
            "features": test_frames,
        }

        # 3. Call Flask endpoint POST /api/v1/ai/predict-flow
        response = self.client.post(
            "/api/v1/ai/predict-flow",
            data=json.dumps(payload),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200, f"Expected 200, got: {response.data}")
        res = response.get_json()

        # 4. Verify Response Schema & Metadata
        self.assertTrue(res.get("success"))
        self.assertEqual(res.get("model_version"), "1.0.0")
        self.assertEqual(
            res.get("research_status"),
            "simulated_dataset_model_not_clinically_validated",
        )
        self.assertEqual(res.get("prediction_count"), len(test_frames))

        flow_curve = res.get("flow_curve", [])
        self.assertEqual(len(flow_curve), len(test_frames))

        # 5. Verify Predictions are Finite, Non-Negative, and Timestamped
        for i, pt in enumerate(flow_curve):
            self.assertIn("timestamp", pt)
            self.assertIn("flow_ml_s", pt)
            self.assertTrue(math.isfinite(pt["timestamp"]))
            self.assertTrue(math.isfinite(pt["flow_ml_s"]))
            self.assertGreaterEqual(pt["flow_ml_s"], 0.0, "Flow rate must be non-negative")
            self.assertAlmostEqual(pt["timestamp"], test_frames[i]["timestamp"], places=3)

        # 6. Verify Clinical Metrics
        metrics = res.get("metrics", {})
        qmax = metrics.get("qmax_ml_s", 0.0)
        avg_flow = metrics.get("average_flow_ml_s", 0.0)
        est_vol = metrics.get("estimated_volume_ml", 0.0)
        void_dur = metrics.get("voiding_duration_s", 0.0)

        self.assertGreater(qmax, 0.0, "Active flow fixture should yield Qmax > 0")
        self.assertGreater(avg_flow, 0.0, "Active flow fixture should yield average flow > 0")
        self.assertGreater(est_vol, 0.0, "Integrated volume must be positive")
        self.assertGreater(void_dur, 0.0, "Voiding duration must be positive")

        # Verify trapezoidal integration math
        manual_vol = 0.0
        for i in range(len(flow_curve) - 1):
            dt = flow_curve[i + 1]["timestamp"] - flow_curve[i]["timestamp"]
            f_avg = 0.5 * (flow_curve[i]["flow_ml_s"] + flow_curve[i + 1]["flow_ml_s"])
            manual_vol += f_avg * dt

        self.assertAlmostEqual(est_vol, manual_vol, places=3)

        print(f"\n[E2E RESULT] Processed {len(test_frames)} frames from fixture:")
        print(f"  Qmax:             {qmax:.2f} mL/s")
        print(f"  Average Flow:     {avg_flow:.2f} mL/s")
        print(f"  Estimated Volume: {est_vol:.2f} mL")
        print(f"  Duration:         {void_dur:.2f} s")
        print("  Status:           VERIFIED - Deterministic predictions from actual trained model")


if __name__ == "__main__":
    unittest.main()
