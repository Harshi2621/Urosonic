"""
prepare_dataset.py - Ingest, Validate, and Audit Phase 4 Exported Calibration Datasets
=====================================================================================
Part of Urosonic Phase 5 (Acoustic-to-Flow Machine Learning Pipeline).

Guarantees:
- Discovers and reads standard RFC 4180 CSV exports from Phase 4.
- Distinguishes sessions with per-frame continuous ground truth from volume-only sessions.
- Volume-only sessions are NOT manufactured into fake per-frame flow values.
- Unaligned frames with missing ground truth are preserved as missing (never zero-filled).
- Emits dataset_report.json exposing all quality and distribution statistics.
"""

from __future__ import annotations
import argparse
import csv
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple


def read_csv_rows(filepath: str) -> List[Dict[str, str]]:
    """Read RFC 4180 CSV file into a list of row dictionaries."""
    if not os.path.exists(filepath):
        return []
    rows = []
    with open(filepath, mode="r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows


class SessionData:
    """Encapsulates all data files for an individual calibration session."""
    
    def __init__(
        self,
        session_id: str,
        session_dir: str,
        metadata_row: Optional[Dict[str, str]] = None
    ):
        self.session_id = session_id
        self.session_dir = session_dir
        self.metadata_row = metadata_row or {}
        self.acoustic_features: List[Dict[str, float]] = []
        self.ground_truth_points: List[Dict[str, float]] = []
        self.synchronized_samples: List[Dict[str, Any]] = []
        self.has_per_frame_flow_curve: bool = False
        self.is_volume_only: bool = False
        self.audio_wav_exists: bool = False
        self.subject_id: Optional[str] = self.metadata_row.get("anonymized_subject_id") or None
        self.total_volume_ml: Optional[float] = None
        self.recording_duration: float = 0.0

    def load_and_validate(self) -> Tuple[bool, List[str]]:
        """Load session CSVs and audio, returning (is_valid, validation_errors)."""
        errors = []
        
        # 1. Check audio WAV
        wav_path = os.path.join(self.session_dir, "audio.wav")
        self.audio_wav_exists = os.path.exists(wav_path)
        if not self.audio_wav_exists and not self.acoustic_features:
            errors.append(f"Missing audio.wav in {self.session_dir}")

        # 2. Read acoustic features
        feat_path = os.path.join(self.session_dir, "acoustic_features.csv")
        if not self.acoustic_features:
            raw_feat_rows = read_csv_rows(feat_path)
            if not raw_feat_rows:
                errors.append(f"Missing or empty acoustic_features.csv in {self.session_dir}")
            else:
                prev_t = -1.0
                for r in raw_feat_rows:
                    try:
                        t = float(r.get("timestamp", 0.0))
                        if t < prev_t:
                            errors.append(f"Non-monotonic acoustic feature timestamp: {t} < {prev_t}")
                        prev_t = t
                        
                        frame = {
                            "timestamp": t,
                            "rms": float(r.get("rms", 0.0)),
                            "peak": float(r.get("peak", 0.0)),
                            "dbfs": float(r.get("dbfs", -100.0)),
                            "dominant_frequency": float(r.get("dominant_frequency", 0.0)),
                            "spectral_centroid": float(r.get("spectral_centroid", 0.0)),
                            "spectral_energy": float(r.get("spectral_energy", 0.0))
                        }
                        self.acoustic_features.append(frame)
                    except (ValueError, TypeError) as e:
                        errors.append(f"Corrupt acoustic row: {e}")
                    
        if self.acoustic_features:
            self.recording_duration = self.acoustic_features[-1]["timestamp"] - self.acoustic_features[0]["timestamp"]

        # 3. Read ground truth
        gt_path = os.path.join(self.session_dir, "ground_truth.csv")
        raw_gt_rows = read_csv_rows(gt_path)
        for r in raw_gt_rows:
            t_str = r.get("timestamp", "")
            flow_str = r.get("flow_rate_ml_per_s", "")
            vol_str = r.get("total_volume_ml", "")
            
            if vol_str:
                try:
                    self.total_volume_ml = float(vol_str)
                except ValueError:
                    pass
                    
            if t_str and flow_str:
                try:
                    t = float(t_str)
                    fl = float(flow_str)
                    self.ground_truth_points.append({"timestamp": t, "flow_rate": fl})
                except ValueError:
                    pass

        # 4. Read synchronized samples
        sync_path = os.path.join(self.session_dir, "synchronized_samples.csv")
        raw_sync_rows = read_csv_rows(sync_path)
        paired_count = 0
        for r in raw_sync_rows:
            try:
                t = float(r.get("timestamp", 0.0))
                flow_val_str = r.get("ground_truth_flow_ml_s", "").strip()
                flow_val = float(flow_val_str) if flow_val_str else None
                
                if flow_val is not None:
                    paired_count += 1
                    
                sample = {
                    "timestamp": t,
                    "rms": float(r.get("rms", 0.0)),
                    "peak": float(r.get("peak", 0.0)),
                    "dbfs": float(r.get("dbfs", -100.0)),
                    "dominant_frequency": float(r.get("dominant_frequency", 0.0)),
                    "spectral_centroid": float(r.get("spectral_centroid", 0.0)),
                    "spectral_energy": float(r.get("spectral_energy", 0.0)),
                    "ground_truth_flow_ml_s": flow_val
                }
                self.synchronized_samples.append(sample)
            except (ValueError, TypeError):
                pass

        # Determine if per-frame curve or volume-only
        if paired_count >= 5 or len(self.ground_truth_points) >= 5:
            self.has_per_frame_flow_curve = True
            self.is_volume_only = False
        else:
            self.has_per_frame_flow_curve = False
            self.is_volume_only = True if self.total_volume_ml is not None else False

        is_valid = (len(errors) == 0) and (len(self.acoustic_features) > 0)
        return is_valid, errors


def scan_dataset_directory(dataset_root: str) -> List[SessionData]:
    """Scan root dataset folder for metadata.csv and session subdirectories."""
    sessions = []
    if not os.path.exists(dataset_root):
        return []

    # Read global metadata.csv if present
    metadata_map: Dict[str, Dict[str, str]] = {}
    meta_path = os.path.join(dataset_root, "metadata.csv")
    if os.path.exists(meta_path):
        meta_rows = read_csv_rows(meta_path)
        for r in meta_rows:
            sid = r.get("session_id", "").strip()
            if sid:
                metadata_map[sid] = r

    # Scan sessions/ directory
    sessions_dir = os.path.join(dataset_root, "sessions")
    search_dirs = [sessions_dir] if os.path.exists(sessions_dir) else [dataset_root]

    for s_root in search_dirs:
        for entry in os.listdir(s_root):
            subpath = os.path.join(s_root, entry)
            if os.path.isdir(subpath) and (entry.startswith("session_") or entry in metadata_map):
                sid = entry.replace("session_", "")
                meta_row = metadata_map.get(sid, {})
                s_data = SessionData(session_id=sid, session_dir=subpath, metadata_row=meta_row)
                sessions.append(s_data)

    return sessions


def audit_dataset(sessions: List[SessionData]) -> Dict[str, Any]:
    """Audit collected sessions and compute distribution and readiness statistics."""
    total_sessions = len(sessions)
    valid_sessions = 0
    sessions_with_curves = 0
    volume_only_sessions = 0
    total_sync_samples = 0
    total_paired_frames = 0
    missing_targets_count = 0
    missing_features_count = 0
    
    durations = []
    subject_ids = set()
    all_flow_rates: List[float] = []
    
    feature_accumulator: Dict[str, List[float]] = {
        "rms": [], "peak": [], "dbfs": [],
        "dominant_frequency": [], "spectral_centroid": [], "spectral_energy": []
    }

    for s in sessions:
        is_valid, _ = s.load_and_validate()
        if is_valid:
            valid_sessions += 1
            durations.append(s.recording_duration)
            if s.subject_id:
                subject_ids.add(s.subject_id)
                
            if s.has_per_frame_flow_curve:
                sessions_with_curves += 1
            elif s.is_volume_only:
                volume_only_sessions += 1

            for sample in s.synchronized_samples:
                total_sync_samples += 1
                flow = sample["ground_truth_flow_ml_s"]
                if flow is not None:
                    total_paired_frames += 1
                    all_flow_rates.append(flow)
                else:
                    missing_targets_count += 1
                    
                for feat in feature_accumulator:
                    val = sample.get(feat)
                    if val is not None:
                        feature_accumulator[feat].append(val)
                    else:
                        missing_features_count += 1

    # Feature statistics
    feature_ranges: Dict[str, Dict[str, float]] = {}
    for feat, values in feature_accumulator.items():
        if values:
            feature_ranges[feat] = {
                "min": float(min(values)),
                "max": float(max(values)),
                "mean": float(sum(values) / len(values))
            }
        else:
            feature_ranges[feat] = {"min": 0.0, "max": 0.0, "mean": 0.0}

    # Flow statistics
    if all_flow_rates:
        target_flow_range = {
            "min": float(min(all_flow_rates)),
            "max": float(max(all_flow_rates)),
            "mean": float(sum(all_flow_rates) / len(all_flow_rates)),
            "count": len(all_flow_rates)
        }
    else:
        target_flow_range = {"min": 0.0, "max": 0.0, "mean": 0.0, "count": 0}

    avg_duration = float(sum(durations) / len(durations)) if durations else 0.0

    # Pipeline readiness check
    # MIN_SAMPLES is purely an engineering check, NOT a claim of clinical validity.
    is_ready = (sessions_with_curves >= 2) and (total_paired_frames >= 50)

    report: Dict[str, Any] = {
        "total_sessions": total_sessions,
        "valid_sessions": valid_sessions,
        "sessions_with_flow_curves": sessions_with_curves,
        "volume_only_sessions": volume_only_sessions,
        "total_synchronized_samples": total_sync_samples,
        "total_paired_frames": total_paired_frames,
        "missing_feature_counts": missing_features_count,
        "missing_target_counts": missing_targets_count,
        "distinct_subjects_count": len(subject_ids),
        "average_recording_duration_seconds": avg_duration,
        "feature_ranges": feature_ranges,
        "target_flow_range": target_flow_range,
        "supervised_training_ready": is_ready,
        "audit_note": (
            "Ready for supervised training."
            if is_ready else
            "Insufficient paired acoustic/ground-truth data for supervised ML training. "
            "Real calibration recordings with per-frame ground truth are required."
        )
    }
    return report


def main():
    parser = argparse.ArgumentParser(description="Audit and prepare Urosonic Phase 4 calibration datasets.")
    parser.add_argument("--dataset-dir", type=str, default="ml/datasets", help="Path to exported dataset folder")
    parser.add_argument("--output-report", type=str, default="ml/outputs/dataset_report.json", help="Path for JSON audit report")
    parser.add_argument("--device", type=str, default=None, help="Optional filter by device category (e.g., Phone, Oppo, Ultramic)")
    args = parser.parse_args()

    os.makedirs(os.path.dirname(args.output_report), exist_ok=True)

    print("==================================================")
    print("UROSONIC PHASE 5: DATASET AUDIT & PREPARATION")
    print("==================================================")
    print(f"Scanning dataset directory: {args.dataset_dir}")

    sessions = scan_dataset_directory(args.dataset_dir)
    
    # Check if raw Audio_FlowDataset exists nearby but sessions haven't been adapted yet
    raw_audio_dataset = os.path.join(args.dataset_dir, "Audio_FlowDataset")
    if len(sessions) == 0 and os.path.exists(raw_audio_dataset):
        print(f"Notice: Raw Audio_FlowDataset detected at {raw_audio_dataset}.")
        print("To adapt this dataset into Urosonic sessions, run:")
        print("  python3 ml/adapt_audio_flow_dataset.py")
        print("--------------------------------------------------")

    if args.device:
        dev_filter = args.device.lower()
        sessions = [
            s for s in sessions
            if dev_filter in s.metadata_row.get("device_category", "").lower()
            or dev_filter in s.metadata_row.get("device_model", "").lower()
            or dev_filter in s.session_id.lower()
        ]
        print(f"Filtered by device '{args.device}': {len(sessions)} matching sessions.")

    report = audit_dataset(sessions)
    if args.device:
        report["device_filter"] = args.device

    # Persist report
    with open(args.output_report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(f"Total Sessions Discovered: {report['total_sessions']}")
    print(f"Valid Sessions: {report['valid_sessions']}")
    print(f"Sessions with Ground-Truth Flow Curves: {report['sessions_with_flow_curves']}")
    print(f"Volume-Only Sessions: {report['volume_only_sessions']}")
    print(f"Total Paired Samples: {report['total_paired_frames']}")
    print(f"Distinct Subjects: {report['distinct_subjects_count']}")
    print(f"Supervised Training Ready: {report['supervised_training_ready']}")
    print(f"Status Note: {report['audit_note']}")
    print(f"Audit report saved to: {args.output_report}")
    print("==================================================")

    return 0


if __name__ == "__main__":
    sys.exit(main())
