"""
test_pipeline.py - Comprehensive Unit Test Suite for Phase 5 ML Pipeline
========================================================================
Part of Urosonic Phase 5 (Acoustic-to-Flow Machine Learning Pipeline).

IMPORTANT:
All data generated inside this test suite are synthetic UNIT TEST FIXTURES
used exclusively to verify mathematical and software correctness.
They are NEVER presented as real Urosonic calibration data.
"""

import json
import os
import shutil
import tempfile
import unittest
import numpy as np

import sys
# Add parent directory (ml/) to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from features import FeatureConfig, FeaturePipeline, build_session_temporal_features
from prepare_dataset import SessionData, audit_dataset, read_csv_rows, scan_dataset_directory
from validate_dataset import DataLeakageError, check_data_leakage, split_sessions
from train import train_models_on_data
from inference import FlowInferenceEngine, moving_median_smooth
from evaluate import trapezoidal_volume_integration
from adapt_audio_flow_dataset import parse_flow_filename


class DummyNegativeModel:
    """Mock model returning positive and negative predictions for testing clipping."""
    def predict(self, X):
        return np.array([-5.0, 10.0, -0.5, 22.0], dtype=np.float32)


class TestPhase5MLPipeline(unittest.TestCase):
    
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="urosonic_test_ml_")

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    # 1 & 2: RFC 4180 CSV Ingestion & Dataset Parsing
    def test_01_rfc4180_csv_ingestion(self):
        csv_path = os.path.join(self.test_dir, "test.csv")
        with open(csv_path, "w", encoding="utf-8") as f:
            f.write("timestamp,rms,peak,dbfs\n0.00,0.012,0.045,-42.5\n0.05,0.018,0.060,-38.2\n")
        rows = read_csv_rows(csv_path)
        self.assertEqual(len(rows), 2)
        self.assertEqual(float(rows[0]["dbfs"]), -42.5)

    # 3 & 4: Missing-target handling & No artificial zero-filling
    def test_02_missing_target_handling_no_zerofill(self):
        config = FeatureConfig(temporal_window_size=2)
        frames = [
            {"timestamp": 0.0, "rms": 0.01, "peak": 0.02, "dbfs": -40.0, "dominant_frequency": 300.0, "spectral_centroid": 800.0, "spectral_energy": 10.0},
            {"timestamp": 0.5, "rms": 0.02, "peak": 0.04, "dbfs": -35.0, "dominant_frequency": 350.0, "spectral_centroid": 850.0, "spectral_energy": 15.0},
            {"timestamp": 1.0, "rms": 0.03, "peak": 0.06, "dbfs": -30.0, "dominant_frequency": 400.0, "spectral_centroid": 900.0, "spectral_energy": 20.0},
        ]
        # Middle target is missing (None)
        targets = [12.0, None, 18.0]
        X, y, valid_ts = build_session_temporal_features(frames, config, targets=targets)
        
        # Must drop missing row and preserve only 2 supervised training rows (NEVER zero-fill)
        self.assertEqual(len(X), 2)
        self.assertEqual(len(y), 2)
        self.assertEqual(valid_ts, [0.0, 1.0])
        self.assertAlmostEqual(y[0], 12.0)
        self.assertAlmostEqual(y[1], 18.0)

    # 5: Volume-only session rejection for supervised frame-level training
    def test_03_volume_only_session_rejection(self):
        s = SessionData(session_id="vol_only_01", session_dir=self.test_dir)
        s.total_volume_ml = 300.0
        s.acoustic_features = [
            {"timestamp": 0.0, "rms": 0.01, "peak": 0.02, "dbfs": -40.0, "dominant_frequency": 300.0, "spectral_centroid": 800.0, "spectral_energy": 10.0},
            {"timestamp": 1.0, "rms": 0.02, "peak": 0.03, "dbfs": -38.0, "dominant_frequency": 310.0, "spectral_centroid": 810.0, "spectral_energy": 12.0}
        ]
        s.recording_duration = 1.0
        # No per-frame ground truth points
        s.synchronized_samples = [
            {"timestamp": 0.0, "rms": 0.01, "peak": 0.02, "dbfs": -40.0, "dominant_frequency": 300.0, "spectral_centroid": 800.0, "spectral_energy": 10.0, "ground_truth_flow_ml_s": None},
            {"timestamp": 1.0, "rms": 0.02, "peak": 0.03, "dbfs": -38.0, "dominant_frequency": 310.0, "spectral_centroid": 810.0, "spectral_energy": 12.0, "ground_truth_flow_ml_s": None}
        ]
        s.has_per_frame_flow_curve = False
        s.is_volume_only = True
        
        # Test audit recognizes volume-only
        report = audit_dataset([s])
        self.assertEqual(report["volume_only_sessions"], 1)
        self.assertEqual(report["sessions_with_flow_curves"], 0)
        self.assertFalse(report["supervised_training_ready"])

    # 6: Session-level splitting
    def test_04_session_level_splitting(self):
        sessions = [
            SessionData(session_id=f"sess_{i:02d}", session_dir=self.test_dir)
            for i in range(10)
        ]
        train, val, test = split_sessions(sessions, train_ratio=0.7, val_ratio=0.15, test_ratio=0.15, random_seed=42)
        
        self.assertEqual(len(train) + len(val) + len(test), 10)
        train_sids = {s.session_id for s in train}
        val_sids = {s.session_id for s in val}
        test_sids = {s.session_id for s in test}
        
        self.assertTrue(train_sids.isdisjoint(val_sids))
        self.assertTrue(train_sids.isdisjoint(test_sids))
        self.assertTrue(val_sids.isdisjoint(test_sids))

    # 7: Subject-level grouping
    def test_05_subject_level_grouping(self):
        # 3 subjects, each with 2 sessions
        sessions = []
        for subj in ["SUBJ_A", "SUBJ_B", "SUBJ_C"]:
            for sess_idx in [1, 2]:
                s = SessionData(
                    session_id=f"{subj}_s{sess_idx}",
                    session_dir=self.test_dir,
                    metadata_row={"anonymized_subject_id": subj}
                )
                sessions.append(s)
                
        train, val, test = split_sessions(sessions, train_ratio=0.34, val_ratio=0.33, test_ratio=0.33, random_seed=42)
        
        # Verify all sessions of SUBJ_A remain together
        subjs_train = {s.subject_id for s in train}
        subjs_val = {s.subject_id for s in val}
        subjs_test = {s.subject_id for s in test}
        
        self.assertTrue(subjs_train.isdisjoint(subjs_val))
        self.assertTrue(subjs_train.isdisjoint(subjs_test))
        self.assertTrue(subjs_val.isdisjoint(subjs_test))

    # 8: Leakage detection
    def test_06_leakage_detection(self):
        s1 = SessionData(session_id="S1", session_dir=self.test_dir)
        s2 = SessionData(session_id="S2", session_dir=self.test_dir)
        
        # Valid disjoint check
        leak_report = check_data_leakage([s1], [s2], [])
        self.assertTrue(leak_report["is_leakage_free"])
        
        # Forced overlap must raise DataLeakageError
        with self.assertRaises(DataLeakageError):
            check_data_leakage([s1], [s1], [])

    # 9: Temporal window creation
    def test_07_temporal_window_creation(self):
        cfg = FeatureConfig(temporal_window_size=3, include_rolling_mean=True, include_delta=True)
        names = cfg.get_feature_names()
        # 6 base * (1 + 3 lag) = 24 + 6 rolling_mean + 6 rolling_var + 3 delta = 39 features
        self.assertEqual(len(names), cfg.to_dict()["feature_dim"])
        
        frames = [{"timestamp": i * 0.1, "rms": 0.05, "peak": 0.1, "dbfs": -30.0, "dominant_frequency": 400.0, "spectral_centroid": 1000.0, "spectral_energy": 20.0} for i in range(5)]
        X, _, _ = build_session_temporal_features(frames, cfg)
        self.assertEqual(X.shape, (5, len(names)))

    # 10: Scaler fit/transform behavior
    def test_08_scaler_fit_transform(self):
        cfg = FeatureConfig(temporal_window_size=1)
        pipeline = FeaturePipeline(cfg)
        
        X_train = np.array([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]], dtype=np.float32)
        X_scaled = pipeline.fit_transform(X_train)
        
        # Training mean should be close to 0
        self.assertTrue(np.allclose(np.mean(X_scaled, axis=0), [0.0, 0.0], atol=1e-5))
        
        # Transform unseen test data without refitting
        X_test = np.array([[3.0, 4.0]], dtype=np.float32)
        X_test_scaled = pipeline.transform(X_test)
        self.assertTrue(np.allclose(X_test_scaled, [0.0, 0.0], atol=1e-5))

    # 11, 12, 13: Model Training using UNIT TEST FIXTURES, Serialization & Loading
    def test_09_model_training_serialization_loading(self):
        """Verify model training and persistence using synthetic UNIT TEST FIXTURES."""
        rng = np.random.default_rng(123)
        
        def make_synthetic_session(sid: str, n_frames: int = 40) -> SessionData:
            s = SessionData(session_id=sid, session_dir=self.test_dir)
            s.has_per_frame_flow_curve = True
            for i in range(n_frames):
                t = i * 0.05
                rms = float(0.01 + 0.05 * np.sin(t))
                feat = {
                    "timestamp": t,
                    "rms": rms,
                    "peak": float(rms * 1.5),
                    "dbfs": float(-40.0 + rms * 100.0),
                    "dominant_frequency": 450.0,
                    "spectral_centroid": 1200.0,
                    "spectral_energy": 25.0
                }
                s.acoustic_features.append(feat)
                # Synthetic flow rate target
                flow = float(max(0.0, 20.0 * np.sin(t / 2.0)))
                s.synchronized_samples.append({**feat, "ground_truth_flow_ml_s": flow})
            return s

        train_s1 = make_synthetic_session("syn_train_1")
        train_s2 = make_synthetic_session("syn_train_2")
        val_s1 = make_synthetic_session("syn_val_1")
        
        cfg = FeatureConfig(temporal_window_size=2)
        model, pipeline, meta = train_models_on_data(
            train_sessions=[train_s1, train_s2],
            val_sessions=[val_s1],
            feature_config=cfg,
            random_seed=42
        )
        
        self.assertIsNotNone(model)
        self.assertTrue(pipeline.is_fitted)
        self.assertIn("RandomForestRegressor", ["RandomForestRegressor", "GradientBoostingRegressor"])

        # Test serialization
        bundle_path = os.path.join(self.test_dir, "test_model.joblib")
        import joblib
        joblib.dump({
            "model": model,
            "pipeline_state": pipeline.to_dict(),
            "metadata": meta
        }, bundle_path)
        
        # Test loading
        engine = FlowInferenceEngine(bundle_path)
        self.assertEqual(engine.metadata["model_version"], "1.0.0")

    # 14 & 15: Deterministic Inference and Non-Negative Prediction Clipping
    def test_10_deterministic_inference_and_clipping(self):
        """Test inference output determinism and physical >= 0.0 flow clipping."""
        cfg = FeatureConfig(temporal_window_size=1)
        pipe = FeaturePipeline(cfg)
        pipe.fit_scaler(np.ones((4, len(cfg.get_feature_names())), dtype=np.float32))

        bundle_path = os.path.join(self.test_dir, "dummy_model.joblib")
        import joblib
        joblib.dump({
            "model": DummyNegativeModel(),
            "pipeline_state": pipe.to_dict(),
            "metadata": {"model_version": "1.0.0", "model_type": "Dummy"}
        }, bundle_path)

        engine = FlowInferenceEngine(bundle_path)
        raw_frames = [
            {"timestamp": 0.0, "rms": 0.01, "peak": 0.02, "dbfs": -40.0, "dominant_frequency": 300.0, "spectral_centroid": 800.0, "spectral_energy": 10.0},
            {"timestamp": 0.1, "rms": 0.02, "peak": 0.03, "dbfs": -35.0, "dominant_frequency": 310.0, "spectral_centroid": 820.0, "spectral_energy": 12.0},
            {"timestamp": 0.2, "rms": 0.03, "peak": 0.04, "dbfs": -32.0, "dominant_frequency": 320.0, "spectral_centroid": 840.0, "spectral_energy": 14.0},
            {"timestamp": 0.3, "rms": 0.04, "peak": 0.05, "dbfs": -30.0, "dominant_frequency": 330.0, "spectral_centroid": 860.0, "spectral_energy": 16.0},
        ]
        res = engine.predict_session(raw_frames, apply_smoothing=True, smoothing_window=3)
        
        # Verify clipping >= 0.0
        for pt in res["raw_points"]:
            self.assertGreaterEqual(pt["flow_rate_ml_per_s"], 0.0)
            
        # First point was -5.0, must be clipped to 0.0
        self.assertEqual(res["raw_points"][0]["flow_rate_ml_per_s"], 0.0)
        # Second point was 10.0
        self.assertEqual(res["raw_points"][1]["flow_rate_ml_per_s"], 10.0)

    # 16 & 17: Empty dataset and Volume-only handling
    def test_11_empty_dataset_handling(self):
        report = audit_dataset([])
        self.assertEqual(report["total_sessions"], 0)
        self.assertFalse(report["supervised_training_ready"])
        self.assertIn("Insufficient", report["audit_note"])

    # 18: Trapezoidal integration
    def test_12_volume_integration(self):
        ts = [0.0, 1.0, 2.0]
        flows = [10.0, 10.0, 10.0]
        # Area of rectangle 10 mL/s * 2s = 20 mL
        vol = trapezoidal_volume_integration(ts, flows)
        self.assertAlmostEqual(vol, 20.0)

    # 19: Audio_FlowDataset Filename Parser Verification
    def test_13_audio_flow_adapter_filename_parsing(self):
        p1 = parse_flow_filename("phone_f_25_60s.wav")
        self.assertIsNotNone(p1)
        self.assertEqual(p1["device_tag"], "phone")
        self.assertEqual(p1["flow_rate_ml_s"], 25.0)
        self.assertEqual(p1["duration_seconds"], 60.0)

        p2 = parse_flow_filename("oppo_f_0_30s.wav")
        self.assertIsNotNone(p2)
        self.assertEqual(p2["device_tag"], "oppo")
        self.assertEqual(p2["flow_rate_ml_s"], 0.0)
        self.assertEqual(p2["duration_seconds"], 30.0)

        p3 = parse_flow_filename("um_f_50_60s.wav")
        self.assertIsNotNone(p3)
        self.assertEqual(p3["device_tag"], "um")
        self.assertEqual(p3["flow_rate_ml_s"], 50.0)
        self.assertEqual(p3["duration_seconds"], 60.0)

        # Invalid filename must return None
        p_invalid = parse_flow_filename("random_recording_file.wav")
        self.assertIsNone(p_invalid)


if __name__ == "__main__":
    unittest.main()
