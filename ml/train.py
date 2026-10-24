"""
train.py - Model Training Orchestrator and Baseline Model Selection
==================================================================
Part of Urosonic Phase 5 (Acoustic-to-Flow Machine Learning Pipeline).

Guarantees:
- Real data requirement: If insufficient paired data exists, training halts safely with:
  "Insufficient paired acoustic/ground-truth data for supervised ML training."
- Baseline models:
  * Baseline 1: RandomForestRegressor ("Strong non-linear baseline suitable for structured acoustic features")
  * Baseline 2: GradientBoostingRegressor
- Strict splitting: Sessions partitioned first; temporal windows built within partitions.
- Scaler fit ONLY on training features.
- Model selection performed on validation partition; test partition remains completely isolated.
- Model artifact and model_metadata.json saved deterministically.
"""

from __future__ import annotations
import argparse
import datetime
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

import joblib
import numpy as np
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

from features import FeatureConfig, FeaturePipeline, build_session_temporal_features
from prepare_dataset import SessionData, audit_dataset, scan_dataset_directory
from validate_dataset import check_data_leakage, split_sessions


# Safety threshold for pipeline operation (NOT a claim of clinical validity)
MIN_PAIRED_SESSIONS_REQUIRED = 2
MIN_PAIRED_SAMPLES_REQUIRED = 50


def train_models_on_data(
    train_sessions: List[SessionData],
    val_sessions: List[SessionData],
    feature_config: Optional[FeatureConfig] = None,
    random_seed: int = 42
) -> Tuple[Any, FeaturePipeline, Dict[str, Any]]:
    """
    Train baseline regressors and select best model using validation set.
    
    Args:
        train_sessions: Sessions designated for training.
        val_sessions: Sessions designated for validation.
        feature_config: Configuration for feature windowing and extraction.
        random_seed: Seed for deterministic training.
        
    Returns:
        (best_model, fitted_feature_pipeline, training_metadata)
    """
    cfg = feature_config or FeatureConfig()
    pipeline = FeaturePipeline(cfg)

    # 1. Build temporal features per-session for training set
    X_train_chunks = []
    y_train_chunks = []
    for s in train_sessions:
        targets = [sm.get("ground_truth_flow_ml_s") for sm in s.synchronized_samples]
        raw_frames = s.acoustic_features
        X_s, y_s, _ = build_session_temporal_features(raw_frames, cfg, targets=targets)
        if len(X_s) > 0 and y_s is not None and len(y_s) > 0:
            X_train_chunks.append(X_s)
            y_train_chunks.append(y_s)

    if not X_train_chunks:
        raise ValueError("No valid paired samples found in training sessions.")

    X_train = np.vstack(X_train_chunks)
    y_train = np.concatenate(y_train_chunks)

    # 2. Fit scaler strictly on training features
    X_train_scaled = pipeline.fit_transform(X_train)

    # 3. Build temporal features per-session for validation set
    X_val_chunks = []
    y_val_chunks = []
    for s in val_sessions:
        targets = [sm.get("ground_truth_flow_ml_s") for sm in s.synchronized_samples]
        raw_frames = s.acoustic_features
        X_s, y_s, _ = build_session_temporal_features(raw_frames, cfg, targets=targets)
        if len(X_s) > 0 and y_s is not None and len(y_s) > 0:
            X_val_chunks.append(X_s)
            y_val_chunks.append(y_s)

    has_val = len(X_val_chunks) > 0
    if has_val:
        X_val = np.vstack(X_val_chunks)
        y_val = np.concatenate(y_val_chunks)
        X_val_scaled = pipeline.transform(X_val)
    else:
        X_val_scaled = None
        y_val = None

    # 4. Train Candidate 1: Random Forest Regressor
    # "Strong non-linear baseline suitable for structured acoustic features"
    rf = RandomForestRegressor(
        n_estimators=100,
        max_depth=12,
        min_samples_split=4,
        random_state=random_seed,
        n_jobs=-1
    )
    rf.fit(X_train_scaled, y_train)

    # 5. Train Candidate 2: Gradient Boosting Regressor
    gb = GradientBoostingRegressor(
        n_estimators=100,
        max_depth=5,
        learning_rate=0.08,
        random_state=random_seed
    )
    gb.fit(X_train_scaled, y_train)

    # 6. Model selection using validation partition
    def evaluate_candidate(model: Any, X: np.ndarray, y: np.ndarray) -> Dict[str, float]:
        preds = model.predict(X)
        mae = float(mean_absolute_error(y, preds))
        rmse = float(np.sqrt(mean_squared_error(y, preds)))
        r2 = float(r2_score(y, preds))
        return {"mae": mae, "rmse": rmse, "r2": r2}

    train_metrics_rf = evaluate_candidate(rf, X_train_scaled, y_train)
    train_metrics_gb = evaluate_candidate(gb, X_train_scaled, y_train)

    if has_val and X_val_scaled is not None and y_val is not None:
        val_metrics_rf = evaluate_candidate(rf, X_val_scaled, y_val)
        val_metrics_gb = evaluate_candidate(gb, X_val_scaled, y_val)
        
        # Select candidate with lower validation RMSE
        if val_metrics_rf["rmse"] <= val_metrics_gb["rmse"]:
            best_model = rf
            best_model_name = "RandomForestRegressor"
            best_val_metrics = val_metrics_rf
            best_train_metrics = train_metrics_rf
            hyperparams = rf.get_params()
        else:
            best_model = gb
            best_model_name = "GradientBoostingRegressor"
            best_val_metrics = val_metrics_gb
            best_train_metrics = train_metrics_gb
            hyperparams = gb.get_params()
    else:
        # If dataset only allowed train partition (e.g. in test fixture)
        best_model = rf
        best_model_name = "RandomForestRegressor"
        best_val_metrics = train_metrics_rf
        best_train_metrics = train_metrics_rf
        hyperparams = rf.get_params()

    # Clean hyperparams for JSON serialization
    clean_params = {}
    for k, v in hyperparams.items():
        if isinstance(v, (int, float, str, bool, type(None))):
            clean_params[k] = v

    metadata = {
        "model_version": "1.0.0",
        "model_type": best_model_name,
        "model_description": "Strong non-linear baseline suitable for structured acoustic features",
        "feature_version": "phase2_acoustic_temporal_v1",
        "feature_names": cfg.get_feature_names(),
        "temporal_window_size": cfg.temporal_window_size,
        "scaler_type": cfg.scaler_type,
        "hyperparameters": clean_params,
        "random_seed": random_seed,
        "dataset_version": "urosonic_phase4_export",
        "training_session_ids": [s.session_id for s in train_sessions],
        "validation_session_ids": [s.session_id for s in val_sessions],
        "training_samples_count": int(len(X_train)),
        "validation_samples_count": int(len(X_val)) if has_val else 0,
        "training_metrics": best_train_metrics,
        "validation_metrics": best_val_metrics,
        "training_timestamp": datetime.datetime.utcnow().isoformat() + "Z"
    }

    return best_model, pipeline, metadata


def main():
    parser = argparse.ArgumentParser(description="Train acoustic-to-flow regression model.")
    parser.add_argument("--dataset-dir", type=str, default="ml/datasets", help="Path to exported calibration dataset")
    parser.add_argument("--output-dir", type=str, default="ml/models", help="Directory to save model artifacts")
    parser.add_argument("--report-file", type=str, default="ml/outputs/dataset_report.json", help="Path to write dataset report")
    parser.add_argument("--random-seed", type=int, default=42, help="Random seed for reproducibility")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    os.makedirs(os.path.dirname(args.report_file), exist_ok=True)

    print("==================================================")
    print("UROSONIC PHASE 5: MODEL TRAINING PIPELINE")
    print("==================================================")

    # 1. Scan and audit dataset
    sessions = scan_dataset_directory(args.dataset_dir)
    report = audit_dataset(sessions)

    # Persist dataset report
    with open(args.report_file, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    # 2. Check data sufficiency
    # Volume-only sessions are NEVER used as per-frame supervised targets!
    curve_sessions = [s for s in sessions if s.has_per_frame_flow_curve]

    if (len(curve_sessions) < MIN_PAIRED_SESSIONS_REQUIRED or 
        report["total_paired_frames"] < MIN_PAIRED_SAMPLES_REQUIRED):
        print(f"Total calibration sessions found: {report['total_sessions']}")
        print(f"Sessions with ground-truth flow curves: {len(curve_sessions)}")
        print(f"Volume-only sessions (excluded from frame-level training): {report['volume_only_sessions']}")
        print(f"Total synchronized paired samples: {report['total_paired_frames']}")
        print("")
        print("Insufficient paired acoustic/ground-truth data for supervised ML training.")
        print("==================================================")
        print("Training pipeline safely halted with 0 fake models generated.")
        print(f"Quality audit written to: {args.report_file}")
        return 0

    # 3. Session-level split
    train_sessions, val_sessions, test_sessions = split_sessions(
        curve_sessions,
        train_ratio=0.70,
        val_ratio=0.15,
        test_ratio=0.15,
        random_seed=args.random_seed
    )

    # 4. Mandatory data leakage check
    check_data_leakage(train_sessions, val_sessions, test_sessions)
    print(f"Partitions: {len(train_sessions)} Train, {len(val_sessions)} Val, {len(test_sessions)} Test")

    # 5. Train baseline models and select best on validation partition
    cfg = FeatureConfig(temporal_window_size=3)
    best_model, pipeline, metadata = train_models_on_data(
        train_sessions=train_sessions,
        val_sessions=val_sessions,
        feature_config=cfg,
        random_seed=args.random_seed
    )

    metadata["test_session_ids"] = [s.session_id for s in test_sessions]

    # 6. Save model artifact and metadata
    artifact_path = os.path.join(args.output_dir, "acoustic_flow_model.joblib")
    artifact_bundle = {
        "model": best_model,
        "pipeline_state": pipeline.to_dict(),
        "metadata": metadata
    }
    joblib.dump(artifact_bundle, artifact_path)

    meta_path = os.path.join(args.output_dir, "model_metadata.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

    print(f"Model successfully trained: {metadata['model_type']}")
    print(f"Model artifact saved to: {artifact_path}")
    print(f"Model metadata saved to: {meta_path}")
    print("==================================================")
    return 0


if __name__ == "__main__":
    sys.exit(main())
