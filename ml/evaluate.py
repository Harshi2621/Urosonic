"""
evaluate.py - Evaluation on Held-Out Test Sessions
==================================================
Part of Urosonic Phase 5 (Acoustic-to-Flow Machine Learning Pipeline).

Guarantees:
- Operates ONLY on held-out test sessions specified in model metadata.
- Frame-level metrics: MAE, RMSE, R².
- Session-level clinical metrics:
  * Qmax (peak flow rate in mL/s)
  * Average flow rate (mL/s)
  * Integrated voided volume: Volume ≈ ∫ Flow(t) dt using trapezoidal integration on actual timestamps.
- Generates real evaluation plots (flow curves, scatter, residuals) under outputs/.
- Reports transparently if test data is insufficient.
"""

from __future__ import annotations
import argparse
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

import joblib
import numpy as np
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except Exception:
    plt = None
    HAS_MATPLOTLIB = False

from features import FeaturePipeline, build_session_temporal_features
from prepare_dataset import SessionData, scan_dataset_directory


def trapezoidal_volume_integration(timestamps: List[float], flow_rates: List[float]) -> float:
    """
    Integrate flow rate curve Flow(t) over actual timestamps to compute voided volume in mL.
    
    Uses standard trapezoidal numerical integration:
    V ≈ ∑ 0.5 * (Flow_i + Flow_{i+1}) * (t_{i+1} - t_i)
    """
    if len(timestamps) < 2 or len(flow_rates) < 2:
        return 0.0
    vol = 0.0
    for i in range(len(timestamps) - 1):
        dt = timestamps[i + 1] - timestamps[i]
        if dt > 0:
            avg_flow = 0.5 * (flow_rates[i] + flow_rates[i + 1])
            vol += avg_flow * dt
    return float(vol)


def evaluate_test_sessions(
    model: Any,
    pipeline: FeaturePipeline,
    test_sessions: List[SessionData],
    output_dir: str = "ml/outputs"
) -> Dict[str, Any]:
    """
    Perform full frame-level and session-level evaluation across test sessions.
    
    Args:
        model: Trained scikit-learn regressor.
        pipeline: Fitted FeaturePipeline with scaler.
        test_sessions: List of SessionData objects reserved for testing.
        output_dir: Directory to store metrics JSON and plots.
        
    Returns:
        Dictionary containing overall and per-session evaluation results.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    all_y_true: List[float] = []
    all_y_pred: List[float] = []
    session_results: List[Dict[str, Any]] = []

    for s in test_sessions:
        targets = [sm.get("ground_truth_flow_ml_s") for sm in s.synchronized_samples]
        raw_frames = s.acoustic_features
        X_s, y_s, valid_ts = build_session_temporal_features(raw_frames, pipeline.config, targets=targets)
        
        if len(X_s) == 0 or y_s is None or len(y_s) == 0:
            continue
            
        X_s_scaled = pipeline.transform(X_s)
        raw_preds = model.predict(X_s_scaled)
        # Non-negative clipping (documented physical constraint)
        clipped_preds = np.clip(raw_preds, 0.0, None)
        
        all_y_true.extend(y_s.tolist())
        all_y_pred.extend(clipped_preds.tolist())

        # Session-level metrics
        gt_qmax = float(np.max(y_s))
        pred_qmax = float(np.max(clipped_preds))
        qmax_abs_error = abs(pred_qmax - gt_qmax)
        
        gt_avg_flow = float(np.mean(y_s))
        pred_avg_flow = float(np.mean(clipped_preds))
        avg_flow_error = abs(pred_avg_flow - gt_avg_flow)

        gt_integrated_vol = trapezoidal_volume_integration(valid_ts, y_s.tolist())
        pred_integrated_vol = trapezoidal_volume_integration(valid_ts, clipped_preds.tolist())
        vol_abs_error = abs(pred_integrated_vol - gt_integrated_vol)

        s_eval = {
            "session_id": s.session_id,
            "sample_count": len(y_s),
            "ground_truth_qmax_ml_s": gt_qmax,
            "predicted_qmax_ml_s": pred_qmax,
            "qmax_error_ml_s": qmax_abs_error,
            "ground_truth_avg_flow_ml_s": gt_avg_flow,
            "predicted_avg_flow_ml_s": pred_avg_flow,
            "avg_flow_error_ml_s": avg_flow_error,
            "ground_truth_integrated_vol_ml": gt_integrated_vol,
            "predicted_integrated_vol_ml": pred_integrated_vol,
            "volume_error_ml": vol_abs_error,
            "measured_total_volume_ml": s.total_volume_ml
        }
        session_results.append(s_eval)

        # Plot per-session flow curve if samples > 5
        if len(valid_ts) >= 5 and HAS_MATPLOTLIB and plt is not None:
            plt.figure(figsize=(9, 4.5))
            plt.plot(valid_ts, y_s, label="Ground Truth Flow", color="#2563EB", linewidth=2.0)
            plt.plot(valid_ts, clipped_preds, label="Predicted Flow", color="#DC2626", linestyle="--", linewidth=1.8)
            plt.title(f"Test Session {s.session_id[:8]} — Flow Curve Comparison")
            plt.xlabel("Time (seconds)")
            plt.ylabel("Flow Rate (mL/s)")
            plt.grid(True, linestyle=":", alpha=0.6)
            plt.legend()
            plot_path = os.path.join(output_dir, f"session_{s.session_id[:8]}_flow_curve.png")
            plt.savefig(plot_path, dpi=150, bbox_inches="tight")
            plt.close()

    if not all_y_true:
        return {
            "evaluation_possible": False,
            "message": "No test sessions with valid paired ground-truth flow were available."
        }

    y_t = np.array(all_y_true)
    y_p = np.array(all_y_pred)
    
    mae = float(mean_absolute_error(y_t, y_p))
    rmse = float(np.sqrt(mean_squared_error(y_t, y_p)))
    r2 = float(r2_score(y_t, y_p))

    if HAS_MATPLOTLIB and plt is not None:
        # Overall Scatter Plot
        plt.figure(figsize=(6, 6))
        plt.scatter(y_t, y_p, alpha=0.5, color="#1D4ED8", edgecolors="none")
        max_val = max(float(np.max(y_t)), float(np.max(y_p)), 10.0)
        plt.plot([0, max_val], [0, max_val], "k--", label="Ideal Unity Line")
        plt.title(f"Ground Truth vs Predicted Flow Rate\nMAE: {mae:.2f} mL/s, RMSE: {rmse:.2f} mL/s, R²: {r2:.2f}")
        plt.xlabel("Ground Truth Flow (mL/s)")
        plt.ylabel("Predicted Flow (mL/s)")
        plt.grid(True, linestyle=":", alpha=0.6)
        plt.legend()
        scatter_path = os.path.join(output_dir, "scatter_gt_vs_pred.png")
        plt.savefig(scatter_path, dpi=150, bbox_inches="tight")
        plt.close()

        # Residual Plot
        residuals = y_p - y_t
        plt.figure(figsize=(7, 4.5))
        plt.scatter(y_t, residuals, alpha=0.5, color="#D97706")
        plt.axhline(0, color="black", linestyle="--")
        plt.title("Residual Error vs Ground Truth Flow")
        plt.xlabel("Ground Truth Flow (mL/s)")
        plt.ylabel("Residual Error (Predicted - Truth) [mL/s]")
        plt.grid(True, linestyle=":", alpha=0.6)
        residual_path = os.path.join(output_dir, "residual_error_plot.png")
        plt.savefig(residual_path, dpi=150, bbox_inches="tight")
        plt.close()

    summary = {
        "evaluation_possible": True,
        "test_sessions_evaluated": len(session_results),
        "total_test_frames": len(y_t),
        "mae_ml_s": mae,
        "rmse_ml_s": rmse,
        "r2_score": r2,
        "session_metrics": session_results
    }
    
    summary_path = os.path.join(output_dir, "evaluation_metrics.json")
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    return summary


def main():
    parser = argparse.ArgumentParser(description="Evaluate trained model on held-out test sessions.")
    parser.add_argument("--model-artifact", type=str, default="ml/models/acoustic_flow_model.joblib", help="Path to trained model")
    parser.add_argument("--dataset-dir", type=str, default="ml/datasets", help="Path to exported calibration dataset")
    parser.add_argument("--output-dir", type=str, default="ml/outputs", help="Directory for evaluation metrics and plots")
    args = parser.parse_args()

    print("==================================================")
    print("UROSONIC PHASE 5: TEST-SET MODEL EVALUATION")
    print("==================================================")

    if not os.path.exists(args.model_artifact):
        print(f"No trained model artifact found at {args.model_artifact}.")
        print("Evaluation cannot be performed because no trained model exists.")
        print("==================================================")
        return 0

    bundle = joblib.load(args.model_artifact)
    model = bundle["model"]
    pipeline = FeaturePipeline.from_dict(bundle["pipeline_state"])
    metadata = bundle["metadata"]
    test_session_ids = set(metadata.get("test_session_ids", []))

    if not test_session_ids:
        print("No test session IDs recorded in model metadata.")
        print("Evaluation cannot proceed without designated held-out test sessions.")
        return 0

    all_sessions = scan_dataset_directory(args.dataset_dir)
    test_sessions = [s for s in all_sessions if s.session_id in test_session_ids]

    if not test_sessions:
        print(f"None of the {len(test_session_ids)} designated test sessions were found in {args.dataset_dir}.")
        return 0

    results = evaluate_test_sessions(model, pipeline, test_sessions, output_dir=args.output_dir)
    if results.get("evaluation_possible"):
        print(f"Evaluated on {results['test_sessions_evaluated']} test sessions ({results['total_test_frames']} frames).")
        print(f"MAE:  {results['mae_ml_s']:.3f} mL/s")
        print(f"RMSE: {results['rmse_ml_s']:.3f} mL/s")
        print(f"R²:   {results['r2_score']:.3f}")
        print(f"Metrics and plots saved to: {args.output_dir}")
    else:
        print(results.get("message", "Evaluation could not be performed."))

    print("==================================================")
    return 0


if __name__ == "__main__":
    sys.exit(main())
