# routes/feedback.py — Doctor Feedback on uroflow measurements

from flask import Blueprint, request, jsonify
from db import query, execute

feedback_bp = Blueprint("feedback", __name__, url_prefix="/feedback")

VALID_INTERPRETATIONS = {"Normal", "Borderline", "Abnormal", "Needs Follow-up"}


def _fmt(f):
    return {
        "id":             f["id"],
        "measurement_id": f["measurement_id"],
        "doctor_id":      f["doctor_id"],
        "patient_id":     f["patient_id"],
        "doctor_name":    f.get("doctor_name"),
        "interpretation": f["interpretation"],
        "clinical_notes": f["clinical_notes"],
        "prescription":   f["prescription"],
        "follow_up_date": f["follow_up_date"].strftime("%Y-%m-%d") if f.get("follow_up_date") else None,
        "created_at":     f["created_at"].strftime("%Y-%m-%d %H:%M:%S") if f.get("created_at") else None,
    }


# ─────────────────────────────────────────────
# GET /feedback/measurement/<measurement_id>
# ─────────────────────────────────────────────
@feedback_bp.route("/measurement/<int:measurement_id>", methods=["GET"])
def get_feedback_for_measurement(measurement_id):
    rows = query(
        """SELECT fb.*, u.full_name AS doctor_name
           FROM feedback fb
           JOIN users u ON u.id = fb.doctor_id
           WHERE fb.measurement_id = %s
           ORDER BY fb.created_at DESC""",
        (measurement_id,)
    )
    return jsonify([_fmt(r) for r in rows]), 200


# ─────────────────────────────────────────────
# GET /feedback/patient/<patient_id>
# All feedback a patient has received
# ─────────────────────────────────────────────
@feedback_bp.route("/patient/<int:patient_id>", methods=["GET"])
def get_patient_feedback(patient_id):
    rows = query(
        """SELECT fb.*, u.full_name AS doctor_name
           FROM feedback fb
           JOIN users u ON u.id = fb.doctor_id
           WHERE fb.patient_id = %s
           ORDER BY fb.created_at DESC""",
        (patient_id,)
    )
    return jsonify([_fmt(r) for r in rows]), 200


# ─────────────────────────────────────────────
# GET /feedback/doctor/<doctor_id>
# All feedback a doctor has written
# ─────────────────────────────────────────────
@feedback_bp.route("/doctor/<int:doctor_id>", methods=["GET"])
def get_doctor_feedback(doctor_id):
    rows = query(
        """SELECT fb.*, u.full_name AS doctor_name
           FROM feedback fb
           JOIN users u ON u.id = fb.doctor_id
           WHERE fb.doctor_id = %s
           ORDER BY fb.created_at DESC""",
        (doctor_id,)
    )
    return jsonify([_fmt(r) for r in rows]), 200


# ─────────────────────────────────────────────
# POST /feedback
# Body: { measurement_id, doctor_id, patient_id,
#         interpretation, clinical_notes,
#         prescription?, follow_up_date? }
# ─────────────────────────────────────────────
@feedback_bp.route("", methods=["POST"])
def create_feedback():
    data           = request.get_json(silent=True) or {}
    measurement_id = data.get("measurement_id")
    doctor_id      = data.get("doctor_id")
    patient_id     = data.get("patient_id")
    interpretation = data.get("interpretation", "Normal")
    clinical_notes = data.get("clinical_notes", "").strip()
    prescription   = data.get("prescription", "")
    follow_up_date = data.get("follow_up_date")    # YYYY-MM-DD or None

    if not measurement_id or not doctor_id or not patient_id or not clinical_notes:
        return jsonify({
            "error": "measurement_id, doctor_id, patient_id and clinical_notes are required"
        }), 400

    if interpretation not in VALID_INTERPRETATIONS:
        interpretation = "Normal"

    fid = execute(
        """INSERT INTO feedback
           (measurement_id, doctor_id, patient_id, interpretation,
            clinical_notes, prescription, follow_up_date)
           VALUES (%s,%s,%s,%s,%s,%s,%s)""",
        (measurement_id, doctor_id, patient_id, interpretation,
         clinical_notes, prescription, follow_up_date or None)
    )

    # Auto-create follow-up reminder if date provided
    if follow_up_date:
        execute(
            """INSERT INTO follow_ups (doctor_id, patient_id, due_date, notes)
               VALUES (%s,%s,%s,%s)""",
            (doctor_id, patient_id, follow_up_date,
             f"Follow-up from feedback #{fid}: {clinical_notes[:100]}")
        )

    row = query(
        """SELECT fb.*, u.full_name AS doctor_name
           FROM feedback fb
           JOIN users u ON u.id = fb.doctor_id
           WHERE fb.id = %s""",
        (fid,), one=True
    )
    return jsonify({"message": "Feedback sent", "feedback": _fmt(row)}), 201


# ─────────────────────────────────────────────
# DELETE /feedback/<feedback_id>
# ─────────────────────────────────────────────
@feedback_bp.route("/<int:fid>", methods=["DELETE"])
def delete_feedback(fid):
    f = query("SELECT id FROM feedback WHERE id = %s", (fid,), one=True)
    if not f:
        return jsonify({"error": "Not found"}), 404
    execute("DELETE FROM feedback WHERE id = %s", (fid,))
    return jsonify({"message": "Deleted"}), 200
