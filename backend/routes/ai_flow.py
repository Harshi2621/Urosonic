# routes/ai_flow.py — Acoustic-to-Flow ML Inference API Route
# Part of Urosonic Phase 6 (Complete ML Backend Integration)

import logging
import math
import time
from typing import Any, Dict, List, Optional, Tuple
from flask import Blueprint, jsonify, request

from ml_inference_service import MLInferenceService, MIN_REQUIRED_FRAMES

logger = logging.getLogger(__name__)

ai_flow_bp = Blueprint("ai_flow", __name__, url_prefix="/api/v1/ai")

REQUIRED_FRAME_FIELDS = [
    "timestamp",
    "rms",
    "peak",
    "dbfs",
    "dominant_frequency",
    "spectral_centroid",
    "spectral_energy",
]


def validate_prediction_request(
    data: Any
) -> Tuple[Optional[List[Dict[str, float]]], Optional[int], Optional[str]]:
    """
    Validate incoming prediction payload.
    
    Returns:
        (validated_frames, sample_rate, error_message)
    """
    if not isinstance(data, dict):
        return None, None, "Request body must be a JSON object"

    # 1. Sample rate validation
    sample_rate = data.get("sample_rate", 44100)
    if not isinstance(sample_rate, (int, float)) or isinstance(sample_rate, bool):
        return None, None, "Field 'sample_rate' must be a numeric value"
    if not math.isfinite(sample_rate) or sample_rate <= 0:
        return None, None, "Field 'sample_rate' must be a positive finite number"
    sample_rate = int(sample_rate)

    # 2. Features list validation
    if "features" not in data:
        return None, None, "Missing required field: 'features'"

    features = data["features"]
    if not isinstance(features, list):
        return None, None, "Field 'features' must be an array of frame objects"

    if len(features) < MIN_REQUIRED_FRAMES:
        return (
            None,
            None,
            f"Insufficient frames: received {len(features)}, minimum required is {MIN_REQUIRED_FRAMES}",
        )

    validated_frames = []
    prev_timestamp = -1.0

    for idx, frame in enumerate(features):
        if not isinstance(frame, dict):
            return None, None, f"Frame at index {idx} must be a JSON object"

        # Check required fields
        for field in REQUIRED_FRAME_FIELDS:
            if field not in frame:
                return None, None, f"Frame at index {idx} is missing required field: '{field}'"
            val = frame[field]
            if not isinstance(val, (int, float)) or isinstance(val, bool):
                return None, None, f"Frame at index {idx}, field '{field}' must be numeric"
            if not math.isfinite(val):
                return None, None, f"Frame at index {idx}, field '{field}' must be finite (got {val})"

        ts = float(frame["timestamp"])
        if ts < 0.0:
            return None, None, f"Frame at index {idx} has negative timestamp: {ts}"

        # Monotonicity check: strictly increasing
        if idx > 0 and ts <= prev_timestamp:
            if ts < prev_timestamp:
                return (
                    None,
                    None,
                    f"Non-monotonic timestamp at index {idx}: {ts} is not greater than preceding timestamp {prev_timestamp}",
                )
            # Equal timestamp from rapid frame processing: nudge by 1ms
            ts = prev_timestamp + 0.001
        prev_timestamp = ts

        validated_frames.append({
            "timestamp": ts,
            "rms": float(frame["rms"]),
            "peak": float(frame["peak"]),
            "dbfs": float(frame["dbfs"]),
            "dominant_frequency": float(frame["dominant_frequency"]),
            "spectral_centroid": float(frame["spectral_centroid"]),
            "spectral_energy": float(frame["spectral_energy"]),
        })

    return validated_frames, sample_rate, None


@ai_flow_bp.route("/predict-flow", methods=["POST"])
def predict_flow():
    """
    POST /api/v1/ai/predict-flow
    
    Accepts chronological sequence of acoustic features and executes
    deterministic machine learning flow-rate inference using the trained
    GradientBoostingRegressor model.
    """
    start_time = time.time()

    data = request.get_json(silent=True)
    if data is None:
        return jsonify({
            "success": False,
            "error": "Request body must be valid JSON",
        }), 400

    validated_frames, sample_rate, error_msg = validate_prediction_request(data)
    if error_msg is not None:
        logger.warning("predict-flow validation rejected: %s", error_msg)
        return jsonify({
            "success": False,
            "error": error_msg,
        }), 400

    logger.info(
        "predict-flow request received: %d frames, sample_rate=%d Hz",
        len(validated_frames),
        sample_rate,
    )

    try:
        service = MLInferenceService.get_instance()
        result = service.predict_flow(validated_frames, sample_rate=sample_rate)

        elapsed_ms = (time.time() - start_time) * 1000.0
        logger.info(
            "predict-flow completed: model_version=%s, feature_dim=39, frames_in=%d, predictions_out=%d, duration=%.2fms (Qmax: %.2f mL/s, Vol: %.2f mL)",
            result["model_version"],
            len(validated_frames),
            result["prediction_count"],
            elapsed_ms,
            result["metrics"]["qmax_ml_s"],
            result["metrics"]["estimated_volume_ml"],
        )
        return jsonify(result), 200

    except ValueError as ve:
        logger.warning("predict-flow client value error: %s", str(ve))
        return jsonify({
            "success": False,
            "error": str(ve),
        }), 400
    except Exception as e:
        logger.exception("predict-flow internal failure: %s", str(e))
        return jsonify({
            "success": False,
            "error": f"ML inference failed: {str(e)}",
        }), 500
