"""
inference.py - Deterministic Offline Inference Pipeline
======================================================
Part of Urosonic Phase 5 (Acoustic-to-Flow Machine Learning Pipeline).

Guarantees:
- Ingestion of raw AudioFrameFeature sequences.
- Reproduces identical temporal windowing and scaler transformation.
- Returns PredictedFlowPoint sequence with timestamps and estimated flow rate (mL/s).
- Non-negative clipping (flow >= 0.0) applied as documented post-processing constraint.
- Preserves raw predictions alongside optional smoothed predictions.
"""

from __future__ import annotations
import argparse
import csv
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

import joblib
import numpy as np

from features import FeaturePipeline, build_session_temporal_features


class PredictedFlowPoint:
    """Individual predicted uroflow measurement point."""
    
    def __init__(self, timestamp: float, flow_rate_ml_per_s: float):
        self.timestamp = float(timestamp)
        self.flow_rate_ml_per_s = float(flow_rate_ml_per_s)

    def to_dict(self) -> Dict[str, float]:
        return {
            "timestamp": round(self.timestamp, 4),
            "flow_rate_ml_per_s": round(self.flow_rate_ml_per_s, 4)
        }


def moving_median_smooth(values: List[float], window_size: int = 3) -> List[float]:
    """Apply non-destructive 1D moving median smoothing across a series."""
    if len(values) <= window_size or window_size <= 1:
        return list(values)
    smoothed = []
    half = window_size // 2
    for i in range(len(values)):
        start = max(0, i - half)
        end = min(len(values), i + half + 1)
        sub = values[start:end]
        smoothed.append(float(np.median(sub)))
    return smoothed


class FlowInferenceEngine:
    """Encapsulates model artifact loading and deterministic inference execution."""
    
    def __init__(self, model_bundle_path: str):
        if not os.path.exists(model_bundle_path):
            raise FileNotFoundError(f"Model artifact not found at {model_bundle_path}")
            
        bundle = joblib.load(model_bundle_path)
        self.model = bundle["model"]
        self.pipeline = FeaturePipeline.from_dict(bundle["pipeline_state"])
        self.metadata = bundle.get("metadata", {})

    def predict_session(
        self,
        raw_frames: List[Dict[str, float]],
        apply_smoothing: bool = False,
        smoothing_window: int = 3
    ) -> Dict[str, Any]:
        """
        Execute deterministic inference over a sequence of acoustic frame features.
        
        Args:
            raw_frames: Chronological list of frame dicts with rms, peak, dbfs, etc.
            apply_smoothing: If True, computes a smoothed flow curve in addition to raw.
            smoothing_window: Size of moving median filter (odd integer >= 3).
            
        Returns:
            Dictionary containing:
            - raw_points: List of PredictedFlowPoint dictionaries.
            - smoothed_points: Optional List of PredictedFlowPoint dictionaries.
            - predicted_qmax_ml_s: Peak flow rate.
            - predicted_avg_flow_ml_s: Mean flow rate.
            - total_frames: Count of processed frames.
        """
        if not raw_frames:
            return {
                "raw_points": [],
                "smoothed_points": None,
                "predicted_qmax_ml_s": 0.0,
                "predicted_avg_flow_ml_s": 0.0,
                "total_frames": 0
            }

        # 1. Build temporal feature matrix within this single session
        X, _, timestamps = build_session_temporal_features(raw_frames, self.pipeline.config, targets=None)
        
        if len(X) == 0:
            return {
                "raw_points": [],
                "smoothed_points": None,
                "predicted_qmax_ml_s": 0.0,
                "predicted_avg_flow_ml_s": 0.0,
                "total_frames": 0
            }

        # 2. Scale features using saved training scaler
        X_scaled = self.pipeline.transform(X)

        # 3. Model inference
        raw_pred_array = self.model.predict(X_scaled)

        # 4. Post-processing non-negative clipping
        # Flow cannot physically be negative in unidirectional micturition
        clipped_preds = np.clip(raw_pred_array, 0.0, None).tolist()

        raw_points = [
            PredictedFlowPoint(t, flow).to_dict()
            for t, flow in zip(timestamps, clipped_preds)
        ]

        smoothed_points = None
        if apply_smoothing:
            smoothed_vals = moving_median_smooth(clipped_preds, window_size=smoothing_window)
            smoothed_points = [
                PredictedFlowPoint(t, flow).to_dict()
                for t, flow in zip(timestamps, smoothed_vals)
            ]

        eval_series = smoothed_vals if apply_smoothing else clipped_preds
        qmax = float(np.max(eval_series)) if eval_series else 0.0
        avg_flow = float(np.mean(eval_series)) if eval_series else 0.0

        return {
            "raw_points": raw_points,
            "smoothed_points": smoothed_points,
            "predicted_qmax_ml_s": round(qmax, 4),
            "predicted_avg_flow_ml_s": round(avg_flow, 4),
            "total_frames": len(raw_points),
            "model_version": self.metadata.get("model_version", "1.0.0"),
            "model_type": self.metadata.get("model_type", "Unknown")
        }


def main():
    parser = argparse.ArgumentParser(description="Run acoustic-to-flow ML inference on acoustic feature CSV.")
    parser.add_argument("--features-csv", type=str, required=True, help="Path to acoustic_features.csv")
    parser.add_argument("--model-artifact", type=str, default="ml/models/acoustic_flow_model.joblib", help="Trained model bundle")
    parser.add_argument("--output-csv", type=str, default="ml/outputs/predicted_flow.csv", help="Destination CSV for predicted curve")
    parser.add_argument("--smooth", action="store_true", help="Include smoothed curve in output")
    args = parser.parse_args()

    print("==================================================")
    print("UROSONIC PHASE 5: OFFLINE INFERENCE")
    print("==================================================")

    if not os.path.exists(args.model_artifact):
        print(f"Error: Model artifact not found at {args.model_artifact}")
        print("Inference cannot proceed until a model has been trained.")
        return 1

    if not os.path.exists(args.features_csv):
        print(f"Error: Features file not found at {args.features_csv}")
        return 1

    # Ingest feature rows
    raw_frames = []
    with open(args.features_csv, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            raw_frames.append({
                "timestamp": float(r.get("timestamp", 0.0)),
                "rms": float(r.get("rms", 0.0)),
                "peak": float(r.get("peak", 0.0)),
                "dbfs": float(r.get("dbfs", -100.0)),
                "dominant_frequency": float(r.get("dominant_frequency", 0.0)),
                "spectral_centroid": float(r.get("spectral_centroid", 0.0)),
                "spectral_energy": float(r.get("spectral_energy", 0.0))
            })

    engine = FlowInferenceEngine(args.model_artifact)
    results = engine.predict_session(raw_frames, apply_smoothing=args.smooth)

    os.makedirs(os.path.dirname(args.output_csv), exist_ok=True)
    with open(args.output_csv, "w", encoding="utf-8", newline="") as f:
        fieldnames = ["timestamp", "predicted_flow_ml_s"]
        if args.smooth:
            fieldnames.append("smoothed_flow_ml_s")
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        
        raw_pts = results["raw_points"]
        smooth_pts = results.get("smoothed_points") or []
        for i, pt in enumerate(raw_pts):
            row = {"timestamp": pt["timestamp"], "predicted_flow_ml_s": pt["flow_rate_ml_per_s"]}
            if args.smooth and i < len(smooth_pts):
                row["smoothed_flow_ml_s"] = smooth_pts[i]["flow_rate_ml_per_s"]
            writer.writerow(row)

    print(f"Processed {results['total_frames']} frames using {results['model_type']}.")
    print(f"Predicted Qmax:     {results['predicted_qmax_ml_s']} mL/s")
    print(f"Predicted Avg Flow: {results['predicted_avg_flow_ml_s']} mL/s")
    print(f"Predicted flow curve saved to: {args.output_csv}")
    print("==================================================")
    return 0


if __name__ == "__main__":
    sys.exit(main())
