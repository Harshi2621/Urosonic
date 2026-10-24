"""
adapt_audio_flow_dataset.py - Dataset Adapter for External Audio_FlowDataset
=============================================================================
Part of Urosonic Phase 5 (Acoustic-to-Flow Machine Learning Pipeline).

This adapter transforms the external research dataset:
"Annotated dataset of simulated voiding sound for urine flow estimation"
(M. L. Alvarez et al., 2025) located at `ml/datasets/Audio_FlowDataset/`
into the standardized Urosonic Phase 4 / Phase 5 session architecture.

Guarantees:
1. Parses flow rate from WAV filenames using pattern: [device]_f_[flow]_[duration]s.wav
   (e.g., phone_f_25_60s.wav -> flow = 25.0 mL/s, duration = 60.0 s).
2. Preserves recording and session boundaries strictly (each WAV file = 1 session).
3. Supports all three device folders: Phone_1min, Oppo_1min, Ultramic_1min.
4. Extracts real frame-by-frame acoustic features using Phase 2 DSP algorithms:
   RMS, Peak, dBFS, FFT dominant frequency, spectral centroid, spectral energy.
5. Emits RFC 4180 CSVs (metadata.csv, acoustic_features.csv, ground_truth.csv, synchronized_samples.csv).
6. Makes the dataset immediately consumable by existing train.py, evaluate.py, and prepare_dataset.py.
"""

from __future__ import annotations
import argparse
import csv
import os
import re
import sys
import wave
from typing import Any, Dict, List, Optional, Tuple
import numpy as np


# Filename patterns
# e.g., phone_f_25_60s.wav, oppo_f_0_30s.wav, um_f_10_60s.wav
FILENAME_PATTERN = re.compile(
    r"^([a-zA-Z0-9]+)_f_(\d+(?:\.\d+)?)_(\d+(?:\.\d+)?)s\.wav$",
    re.IGNORECASE
)
ALT_FILENAME_PATTERN = re.compile(
    r"^([a-zA-Z0-9]+)_f_(\d+(?:\.\d+)?)s?\.wav$",
    re.IGNORECASE
)

DEVICE_METADATA = {
    "phone": {
        "device_model": "Phone (Xiaomi Mi A1)",
        "device_category": "Phone",
        "expected_sr": 48000,
        "mic_height_cm": 95.0,
        "mic_height_inches": 37.4,
        "description": "Android smartphone built-in microphone array"
    },
    "oppo": {
        "device_model": "Oppo Smartwatch",
        "device_category": "Oppo",
        "expected_sr": 44100,
        "mic_height_cm": 86.0,
        "mic_height_inches": 33.9,
        "description": "Smartwatch built-in microphone at simulated wrist height"
    },
    "watch": {
        "device_model": "Oppo Smartwatch",
        "device_category": "Oppo",
        "expected_sr": 44100,
        "mic_height_cm": 86.0,
        "mic_height_inches": 33.9,
        "description": "Smartwatch built-in microphone at simulated wrist height"
    },
    "um": {
        "device_model": "Ultramic384k",
        "device_category": "Ultramic",
        "expected_sr": 192000,
        "mic_height_cm": 84.0,
        "mic_height_inches": 33.1,
        "description": "High-bandwidth ultrasonic research microphone"
    }
}


def parse_flow_filename(filename: str) -> Optional[Dict[str, Any]]:
    """
    Parse flow rate and recording duration from filename.
    Matches: [device]_f_[flow]_[duration]s.wav
    """
    m = FILENAME_PATTERN.match(filename)
    if m:
        device_tag, flow_str, dur_str = m.groups()
        return {
            "device_tag": device_tag.lower(),
            "flow_rate_ml_s": float(flow_str),
            "duration_seconds": float(dur_str)
        }
        
    m2 = ALT_FILENAME_PATTERN.match(filename)
    if m2:
        device_tag, flow_str = m2.groups()
        return {
            "device_tag": device_tag.lower(),
            "flow_rate_ml_s": float(flow_str),
            "duration_seconds": 60.0 if float(flow_str) > 0 else 30.0
        }
        
    return None


def extract_dsp_features_from_wav(
    wav_path: str,
    frame_size: int = 1024,
    hop_size: int = 1024
) -> Tuple[int, float, List[Dict[str, float]]]:
    """
    Extract frame-by-frame Phase 2 acoustic features from 16-bit PCM WAV audio.
    
    Features:
    - timestamp: seconds from audio start
    - rms: Root Mean Square linear amplitude
    - peak: absolute maximum amplitude
    - dbfs: 20 * log10(rms), clamped between -100.0 and 0.0 dBFS
    - dominant_frequency: peak magnitude FFT bin frequency in Hz
    - spectral_centroid: spectral center of mass in Hz
    - spectral_energy: sum of squared FFT magnitude bins
    """
    with wave.open(wav_path, "rb") as w:
        sample_rate = w.getframerate()
        n_channels = w.getnchannels()
        sampwidth = w.getsampwidth()
        n_frames = w.getnframes()
        raw_bytes = w.readframes(n_frames)

    # Convert to mono float32 in [-1.0, 1.0]
    if sampwidth == 2:
        samples = np.frombuffer(raw_bytes, dtype=np.int16).astype(np.float32) / 32768.0
    elif sampwidth == 4:
        samples = np.frombuffer(raw_bytes, dtype=np.int32).astype(np.float32) / 2147483648.0
    elif sampwidth == 1:
        samples = (np.frombuffer(raw_bytes, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    else:
        raise ValueError(f"Unsupported sample width: {sampwidth * 8} bits")

    if n_channels > 1:
        samples = samples.reshape(-1, n_channels).mean(axis=1)

    total_duration = float(len(samples)) / float(sample_rate)

    window = np.hanning(frame_size).astype(np.float32)
    half_size = frame_size // 2
    bin_width = float(sample_rate) / float(frame_size)
    freqs = np.arange(half_size, dtype=np.float32) * bin_width

    features_list: List[Dict[str, float]] = []

    for start_idx in range(0, len(samples) - frame_size + 1, hop_size):
        frame = samples[start_idx : start_idx + frame_size]
        t = float(start_idx) / float(sample_rate)

        # 1. RMS
        rms = float(np.sqrt(np.mean(frame ** 2)))

        # 2. Peak
        peak = float(np.max(np.abs(frame)))

        # 3. dBFS
        safe_rms = max(rms, 1e-5)
        dbfs = float(20.0 * np.log10(safe_rms))
        dbfs = float(np.clip(dbfs, -100.0, 0.0))

        # 4. Spectral Analysis via FFT
        windowed = frame * window
        rfft = np.fft.rfft(windowed)[:half_size]
        mags = np.abs(rfft).astype(np.float32)

        # Dominant Frequency
        dom_idx = int(np.argmax(mags))
        dominant_freq = float(dom_idx * bin_width)

        # Spectral Centroid & Energy
        sum_mag = float(np.sum(mags))
        if sum_mag > 1e-6:
            centroid = float(np.sum(freqs * mags) / sum_mag)
        else:
            centroid = 0.0
        energy = float(np.sum(mags ** 2))

        features_list.append({
            "timestamp": t,
            "rms": rms,
            "peak": peak,
            "dbfs": dbfs,
            "dominant_frequency": dominant_freq,
            "spectral_centroid": centroid,
            "spectral_energy": energy
        })

    return sample_rate, total_duration, features_list


def adapt_session(
    source_wav_path: str,
    target_sessions_dir: str,
    parsed_info: Dict[str, Any],
    folder_device_name: str,
    frame_size: int = 1024,
    hop_size: int = 1024,
    use_symlink: bool = True
) -> Dict[str, Any]:
    """
    Process a single WAV recording into a standard Urosonic Phase 4/5 session.
    """
    filename = os.path.basename(source_wav_path)
    base_name = os.path.splitext(filename)[0]
    session_id = f"{folder_device_name.lower()}_{base_name}"
    
    session_dir = os.path.join(target_sessions_dir, f"session_{session_id}")
    os.makedirs(session_dir, exist_ok=True)

    # 1. Audio file link or copy
    target_audio_path = os.path.join(session_dir, "audio.wav")
    if not os.path.exists(target_audio_path):
        if use_symlink:
            try:
                os.symlink(os.path.abspath(source_wav_path), target_audio_path)
            except OSError:
                import shutil
                shutil.copyfile(source_wav_path, target_audio_path)
        else:
            import shutil
            shutil.copyfile(source_wav_path, target_audio_path)

    # 2. Extract acoustic features
    sr, duration, features = extract_dsp_features_from_wav(
        source_wav_path,
        frame_size=frame_size,
        hop_size=hop_size
    )

    flow_rate = parsed_info["flow_rate_ml_s"]
    total_volume = flow_rate * duration

    # 3. Write acoustic_features.csv
    feat_csv_path = os.path.join(session_dir, "acoustic_features.csv")
    with open(feat_csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "timestamp", "rms", "peak", "dbfs",
            "dominant_frequency", "spectral_centroid", "spectral_energy"
        ])
        writer.writeheader()
        for ft in features:
            writer.writerow({
                "timestamp": f"{ft['timestamp']:.4f}",
                "rms": f"{ft['rms']:.6f}",
                "peak": f"{ft['peak']:.6f}",
                "dbfs": f"{ft['dbfs']:.2f}",
                "dominant_frequency": f"{ft['dominant_frequency']:.2f}",
                "spectral_centroid": f"{ft['spectral_centroid']:.2f}",
                "spectral_energy": f"{ft['spectral_energy']:.4f}"
            })

    # 4. Write ground_truth.csv
    gt_csv_path = os.path.join(session_dir, "ground_truth.csv")
    with open(gt_csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "timestamp", "flow_rate_ml_per_s", "total_volume_ml", "duration"
        ])
        writer.writeheader()
        # Discrete points at start and end
        writer.writerow({
            "timestamp": "0.0000",
            "flow_rate_ml_per_s": f"{flow_rate:.2f}",
            "total_volume_ml": f"{total_volume:.2f}",
            "duration": f"{duration:.2f}"
        })
        if duration > 0:
            writer.writerow({
                "timestamp": f"{duration:.4f}",
                "flow_rate_ml_per_s": f"{flow_rate:.2f}",
                "total_volume_ml": f"{total_volume:.2f}",
                "duration": f"{duration:.2f}"
            })

    # 5. Write synchronized_samples.csv
    sync_csv_path = os.path.join(session_dir, "synchronized_samples.csv")
    with open(sync_csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "timestamp", "rms", "peak", "dbfs",
            "dominant_frequency", "spectral_centroid", "spectral_energy",
            "ground_truth_flow_ml_s"
        ])
        writer.writeheader()
        for ft in features:
            writer.writerow({
                "timestamp": f"{ft['timestamp']:.4f}",
                "rms": f"{ft['rms']:.6f}",
                "peak": f"{ft['peak']:.6f}",
                "dbfs": f"{ft['dbfs']:.2f}",
                "dominant_frequency": f"{ft['dominant_frequency']:.2f}",
                "spectral_centroid": f"{ft['spectral_centroid']:.2f}",
                "spectral_energy": f"{ft['spectral_energy']:.4f}",
                "ground_truth_flow_ml_s": f"{flow_rate:.2f}"
            })

    # Device metadata lookup
    tag = parsed_info["device_tag"]
    dev_meta = DEVICE_METADATA.get(tag, {
        "device_model": folder_device_name,
        "device_category": folder_device_name,
        "mic_height_inches": 35.0
    })

    session_metadata = {
        "session_id": session_id,
        "created_at": "2025-01-01T00:00:00Z",
        "device_model": dev_meta["device_model"],
        "device_category": dev_meta["device_category"],
        "sample_rate": sr,
        "channel_count": 1,
        "recording_duration": round(duration, 2),
        "recording_distance_inches": dev_meta.get("mic_height_inches", 35.0),
        "phone_orientation": "Fixed mount at nozzle height facing ceramic toilet bowl",
        "environment": "Controlled bathroom setup with ceramic toilet",
        "toilet_type": "Standard ceramic toilet with water pool",
        "ground_truth_method": "Precision peristaltic pump (L600-1F, cylinder verified)",
        "flow_rate_ml_s": flow_rate,
        "total_volume_ml": round(total_volume, 2),
        "status": "VALID",
        "anonymized_subject_id": "",
        "frame_count": len(features)
    }

    return session_metadata


def adapt_dataset(
    source_dir: str = "ml/datasets/Audio_FlowDataset",
    target_dir: str = "ml/datasets",
    device_filters: Optional[List[str]] = None,
    frame_size: int = 1024,
    hop_size: int = 1024,
    use_symlink: bool = True
) -> Dict[str, Any]:
    """
    Main entry point for adapting Audio_FlowDataset into Urosonic Phase 4/5 format.
    
    Args:
        source_dir: Path to Audio_FlowDataset root containing Phone_1min, Oppo_1min, Ultramic_1min.
        target_dir: Path where metadata.csv and sessions/ directory will be created.
        device_filters: Optional list of folder names to process (e.g. ["Phone_1min", "Oppo_1min"]).
        frame_size: FFT frame size (default 1024).
        hop_size: Hop size (default 1024).
        use_symlink: If True, symlinks WAV files to save space; copies otherwise.
    """
    if not os.path.exists(source_dir):
        raise FileNotFoundError(f"Source dataset directory not found: {source_dir}")

    target_sessions_dir = os.path.join(target_dir, "sessions")
    os.makedirs(target_sessions_dir, exist_ok=True)

    # Locate device subdirectories
    subdirs = [
        d for d in sorted(os.listdir(source_dir))
        if os.path.isdir(os.path.join(source_dir, d)) and not d.startswith(".")
    ]

    target_subdirs = []
    for d in subdirs:
        # Check if device_filters applied
        if device_filters:
            match = any(df.lower() in d.lower() for df in device_filters)
            if not match:
                continue
        target_subdirs.append(d)

    print(f"Adapting Audio_FlowDataset from: {source_dir}")
    print(f"Target directory: {target_dir}")
    print(f"Identified device folders: {target_subdirs}")

    all_metadata: List[Dict[str, Any]] = []
    total_files_processed = 0
    total_frames_extracted = 0

    for folder in target_subdirs:
        folder_path = os.path.join(source_dir, folder)
        wav_files = sorted([f for f in os.listdir(folder_path) if f.endswith(".wav")])
        print(f"\n📁 Processing {folder} ({len(wav_files)} WAV files)...")

        for f in wav_files:
            wav_path = os.path.join(folder_path, f)
            parsed = parse_flow_filename(f)
            if not parsed:
                print(f"  ⚠️ Skipping unrecognized file: {f}")
                continue

            # Determine device category name
            folder_clean = folder.replace("_1min", "")
            s_meta = adapt_session(
                source_wav_path=wav_path,
                target_sessions_dir=target_sessions_dir,
                parsed_info=parsed,
                folder_device_name=folder_clean,
                frame_size=frame_size,
                hop_size=hop_size,
                use_symlink=use_symlink
            )
            all_metadata.append(s_meta)
            total_files_processed += 1
            total_frames_extracted += s_meta["frame_count"]

        print(f"  ✓ Finished {folder}: processed {len(wav_files)} files.")

    # Write global metadata.csv
    meta_csv_path = os.path.join(target_dir, "metadata.csv")
    fieldnames = [
        "session_id", "created_at", "device_model", "device_category",
        "sample_rate", "channel_count", "recording_duration",
        "recording_distance_inches", "phone_orientation", "environment",
        "toilet_type", "ground_truth_method", "flow_rate_ml_s",
        "total_volume_ml", "status", "anonymized_subject_id", "frame_count"
    ]
    with open(meta_csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in all_metadata:
            writer.writerow(row)

    summary = {
        "total_sessions_adapted": total_files_processed,
        "total_frames_extracted": total_frames_extracted,
        "target_directory": target_dir,
        "metadata_file": meta_csv_path,
        "sessions_directory": target_sessions_dir,
        "device_folders_processed": target_subdirs
    }
    return summary


def main():
    parser = argparse.ArgumentParser(description="Adapt Audio_FlowDataset to Urosonic Phase 4/5 ML pipeline.")
    parser.add_argument("--source-dir", type=str, default="ml/datasets/Audio_FlowDataset", help="Root of Audio_FlowDataset")
    parser.add_argument("--target-dir", type=str, default="ml/datasets", help="Destination directory for adapted dataset")
    parser.add_argument("--devices", nargs="+", default=["Phone", "Oppo", "Ultramic"], help="Device folders to include")
    parser.add_argument("--frame-size", type=int, default=1024, help="FFT frame size")
    parser.add_argument("--hop-size", type=int, default=1024, help="FFT hop size")
    parser.add_argument("--no-symlink", action="store_true", help="Copy audio instead of symlinking")
    args = parser.parse_args()

    print("==================================================")
    print("UROSONIC PHASE 5: AUDIO_FLOWDATASET ADAPTER")
    print("==================================================")

    res = adapt_dataset(
        source_dir=args.source_dir,
        target_dir=args.target_dir,
        device_filters=args.devices,
        frame_size=args.frame_size,
        hop_size=args.hop_size,
        use_symlink=not args.no_symlink
    )

    print("\n==================================================")
    print("ADAPTATION COMPLETED SUCCESSFULLY")
    print("==================================================")
    print(f"Total Sessions Adapted: {res['total_sessions_adapted']}")
    print(f"Total Paired Frames:    {res['total_frames_extracted']}")
    print(f"Devices Processed:      {res['device_folders_processed']}")
    print(f"Metadata File:          {res['metadata_file']}")
    print(f"Sessions Directory:     {res['sessions_directory']}")
    print("==================================================")
    return 0


if __name__ == "__main__":
    sys.exit(main())
