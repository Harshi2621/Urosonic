"""
features.py - Feature Configuration, Extraction, Windowing, and Normalization
=============================================================================
Part of Urosonic Phase 5 (Acoustic-to-Flow Machine Learning Pipeline).

Guarantees:
- Base acoustic features align with Phase 2 real-time DSP extractors.
- Temporal context windows are generated STRICTLY per-session to prevent cross-session bleeding.
- Scaler is fitted ONLY on training session data, never on validation or test sets.
- Configuration and scaler can be saved and loaded deterministically for offline inference.
"""

from __future__ import annotations
import json
from typing import Any, Dict, List, Optional, Tuple
import numpy as np
from sklearn.preprocessing import StandardScaler


BASE_FEATURE_NAMES = [
    "rms",
    "peak",
    "dbfs",
    "dominant_frequency",
    "spectral_centroid",
    "spectral_energy"
]


class FeatureConfig:
    """Configuration class specifying feature extraction and temporal context parameters."""
    
    def __init__(
        self,
        base_features: Optional[List[str]] = None,
        temporal_window_size: int = 3,
        include_rolling_mean: bool = True,
        include_rolling_var: bool = True,
        include_delta: bool = True,
        scaler_type: str = "StandardScaler"
    ):
        self.base_features = base_features or list(BASE_FEATURE_NAMES)
        self.temporal_window_size = temporal_window_size  # N previous frames (e.g. 3 frames ~ 70ms)
        self.include_rolling_mean = include_rolling_mean
        self.include_rolling_var = include_rolling_var
        self.include_delta = include_delta
        self.scaler_type = scaler_type

    def get_feature_names(self) -> List[str]:
        """Construct deterministic feature names for tabular / tabular regression input."""
        names = []
        # Current frame features (t)
        for f in self.base_features:
            names.append(f"{f}_t0")
            
        # History frame features (t-1, ..., t-N)
        for lag in range(1, self.temporal_window_size + 1):
            for f in self.base_features:
                names.append(f"{f}_t_minus_{lag}")
                
        # Rolling statistics across the window
        if self.include_rolling_mean:
            for f in self.base_features:
                names.append(f"{f}_rolling_mean")
                
        if self.include_rolling_var:
            for f in self.base_features:
                names.append(f"{f}_rolling_var")
                
        # Delta features (t - (t-1))
        if self.include_delta:
            names.append("spectral_centroid_delta")
            names.append("spectral_energy_delta")
            names.append("dbfs_delta")
            
        return names

    def to_dict(self) -> Dict[str, Any]:
        return {
            "base_features": self.base_features,
            "temporal_window_size": self.temporal_window_size,
            "include_rolling_mean": self.include_rolling_mean,
            "include_rolling_var": self.include_rolling_var,
            "include_delta": self.include_delta,
            "scaler_type": self.scaler_type,
            "feature_names": self.get_feature_names(),
            "feature_dim": len(self.get_feature_names())
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> FeatureConfig:
        return cls(
            base_features=data.get("base_features", list(BASE_FEATURE_NAMES)),
            temporal_window_size=data.get("temporal_window_size", 3),
            include_rolling_mean=data.get("include_rolling_mean", True),
            include_rolling_var=data.get("include_rolling_var", True),
            include_delta=data.get("include_delta", True),
            scaler_type=data.get("scaler_type", "StandardScaler")
        )


def build_session_temporal_features(
    raw_frames: List[Dict[str, float]],
    config: FeatureConfig,
    targets: Optional[List[Optional[float]]] = None
) -> Tuple[np.ndarray, Optional[np.ndarray], List[float]]:
    """
    Construct temporal context feature matrix for a SINGLE session.
    
    CRITICAL: This function operates within a single session's boundary.
    It never crosses session boundaries to prevent temporal leakage.
    
    Args:
        raw_frames: Chronologically ordered acoustic frame dictionaries.
        config: FeatureConfig object.
        targets: Optional ground-truth flow rate values aligned with raw_frames.
                 If targets are provided, rows where target is None are dropped
                 from supervised (X, y) output without zero-filling.
                 
    Returns:
        X: 2D numpy array of shape (num_samples, num_features).
        y: 1D numpy array of shape (num_samples,) or None if targets not provided.
        valid_timestamps: List of timestamp floats corresponding to each row in X.
    """
    if not raw_frames:
        feat_dim = len(config.get_feature_names())
        return np.empty((0, feat_dim)), (np.empty(0) if targets is not None else None), []

    T = len(raw_frames)
    base_dim = len(config.base_features)
    
    # Extract base feature matrix of shape (T, base_dim)
    base_matrix = np.zeros((T, base_dim), dtype=np.float32)
    timestamps = []
    for i, frame in enumerate(raw_frames):
        timestamps.append(float(frame.get("timestamp", i * 0.0232)))
        for j, feat in enumerate(config.base_features):
            base_matrix[i, j] = float(frame.get(feat, 0.0))

    X_rows = []
    y_vals = []
    out_timestamps = []
    
    W = config.temporal_window_size
    
    for t in range(T):
        # If supervised training and target is missing, do NOT train on it
        if targets is not None:
            target_val = targets[t]
            if target_val is None or np.isnan(target_val):
                continue

        row_feats = []
        
        # 1. Current frame (t)
        row_feats.extend(base_matrix[t].tolist())
        
        # 2. History frames: t-1 down to t-W (pad with edge frame if t - lag < 0)
        for lag in range(1, W + 1):
            idx = max(0, t - lag)
            row_feats.extend(base_matrix[idx].tolist())
            
        # 3. Rolling window (from max(0, t-W) to t inclusive)
        window_start = max(0, t - W)
        window_slice = base_matrix[window_start : t + 1]
        
        if config.include_rolling_mean:
            mean_vals = np.mean(window_slice, axis=0).tolist()
            row_feats.extend(mean_vals)
            
        if config.include_rolling_var:
            if len(window_slice) > 1:
                var_vals = np.var(window_slice, axis=0).tolist()
            else:
                var_vals = [0.0] * base_dim
            row_feats.extend(var_vals)
            
        # 4. Deltas between t and max(0, t-1)
        if config.include_delta:
            prev_idx = max(0, t - 1)
            # Find indices for spectral centroid, energy, dbfs
            sc_idx = config.base_features.index("spectral_centroid") if "spectral_centroid" in config.base_features else 0
            se_idx = config.base_features.index("spectral_energy") if "spectral_energy" in config.base_features else 0
            db_idx = config.base_features.index("dbfs") if "dbfs" in config.base_features else 0
            
            row_feats.append(float(base_matrix[t, sc_idx] - base_matrix[prev_idx, sc_idx]))
            row_feats.append(float(base_matrix[t, se_idx] - base_matrix[prev_idx, se_idx]))
            row_feats.append(float(base_matrix[t, db_idx] - base_matrix[prev_idx, db_idx]))
            
        X_rows.append(row_feats)
        out_timestamps.append(timestamps[t])
        
        if targets is not None:
            y_vals.append(float(targets[t]))

    if not X_rows:
        feat_dim = len(config.get_feature_names())
        return np.empty((0, feat_dim)), (np.empty(0) if targets is not None else None), []

    X_arr = np.array(X_rows, dtype=np.float32)
    y_arr = np.array(y_vals, dtype=np.float32) if targets is not None else None
    return X_arr, y_arr, out_timestamps


class FeaturePipeline:
    """
    Encapsulates feature configuration and scaler.
    Ensures scaler is fit strictly on training partitions and saved/restored.
    """
    
    def __init__(self, config: Optional[FeatureConfig] = None):
        self.config = config or FeatureConfig()
        self.scaler: Optional[StandardScaler] = None
        self.is_fitted: bool = False

    def fit_scaler(self, X_train: np.ndarray) -> None:
        """Fit scaler strictly on training feature matrix."""
        if len(X_train) == 0:
            raise ValueError("Cannot fit scaler on empty training matrix.")
        self.scaler = StandardScaler()
        self.scaler.fit(X_train)
        self.is_fitted = True

    def transform(self, X: np.ndarray) -> np.ndarray:
        """Transform features using previously fitted scaler."""
        if not self.is_fitted or self.scaler is None:
            raise RuntimeError("FeaturePipeline scaler has not been fitted.")
        if len(X) == 0:
            return X
        return self.scaler.transform(X).astype(np.float32)

    def fit_transform(self, X_train: np.ndarray) -> np.ndarray:
        """Fit on training data and return scaled training features."""
        self.fit_scaler(X_train)
        return self.transform(X_train)

    def to_dict(self) -> Dict[str, Any]:
        """Serialize pipeline state."""
        state: Dict[str, Any] = {
            "config": self.config.to_dict(),
            "is_fitted": self.is_fitted
        }
        if self.is_fitted and self.scaler is not None:
            state["scaler"] = {
                "mean": self.scaler.mean_.tolist(),
                "scale": self.scaler.scale_.tolist(),
                "var": self.scaler.var_.tolist(),
                "n_features_in": int(self.scaler.n_features_in_)
            }
        return state

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> FeaturePipeline:
        """Recreate pipeline state."""
        cfg = FeatureConfig.from_dict(data.get("config", {}))
        pipeline = cls(cfg)
        if data.get("is_fitted", False) and "scaler" in data:
            s_data = data["scaler"]
            scaler = StandardScaler()
            scaler.mean_ = np.array(s_data["mean"], dtype=np.float64)
            scaler.scale_ = np.array(s_data["scale"], dtype=np.float64)
            scaler.var_ = np.array(s_data["var"], dtype=np.float64)
            scaler.n_features_in_ = s_data["n_features_in"]
            pipeline.scaler = scaler
            pipeline.is_fitted = True
        return pipeline
