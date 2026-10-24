# routes/followup.py — Follow-up Reminders (Doctor)

from flask import Blueprint, request, jsonify
from db import query, execute
from datetime import date

followup_bp = Blueprint("followup", __name__, url_prefix="/followup")


def _compute_status(due_date_obj) -> str:
    today = date.today()
    if isinstance(due_date_obj, str):
        try:
            due_date_obj = date.fromisoformat(due_date_obj)
        except Exception:
            return "UPCOMING"
    delta = (due_date_obj - today).days
    if delta < 0:
        return "OVERDUE"
    elif delta == 0:
        return "DUE"
    return "UPCOMING"


def _fmt(f):
    due = f["due_date"]
    due_str = due.strftime("%Y-%m-%d") if due else None
    status = f["status"]
    if status != "COMPLETED":
        status = _compute_status(due) if due else "UPCOMING"

    today     = date.today()
    days_left = (due - today).days if due else 0

    return {
        "id":           f["id"],
        "doctor_id":    f["doctor_id"],
        "patient_id":   f["patient_id"],
        "patient_name": f.get("patient_name"),
        "avatar":       f.get("avatar_initials") or "",
        "due_date":     due_str,
        "days_left":    days_left,
        "status":       status,
        "notes":        f["notes"] or "",
    }


# ─────────────────────────────────────────────
# GET /followup/<doctor_id> or /followup/doctor/<doctor_id>
# ─────────────────────────────────────────────
@followup_bp.route("/<int:doctor_id>", methods=["GET"])
@followup_bp.route("/doctor/<int:doctor_id>", methods=["GET"])
def get_followups(doctor_id):
    rows = query(
        """SELECT f.*, u.full_name AS patient_name, u.avatar_initials
           FROM follow_ups f
           JOIN users u ON u.id = f.patient_id
           WHERE f.doctor_id = %s AND f.status != 'COMPLETED'
           ORDER BY f.due_date ASC""",
        (doctor_id,)
    )
    return jsonify([_fmt(r) for r in rows]), 200


# ─────────────────────────────────────────────
# POST /followup
# Body: { doctor_id, patient_id, due_date, notes? }
# ─────────────────────────────────────────────
@followup_bp.route("", methods=["POST"])
def create_followup():
    data       = request.get_json(silent=True) or {}
    doctor_id  = data.get("doctor_id")
    patient_id = data.get("patient_id")
    due_date   = data.get("due_date")
    notes      = data.get("notes", "")

    if not doctor_id or not patient_id or not due_date:
        return jsonify({"error": "doctor_id, patient_id and due_date are required"}), 400

    # Verify patient exists
    p = query("SELECT id FROM users WHERE id = %s AND role = 'patient'", (patient_id,), one=True)
    if not p:
        return jsonify({"error": "Patient not found"}), 404

    fid = execute(
        "INSERT INTO follow_ups (doctor_id, patient_id, due_date, notes) VALUES (%s,%s,%s,%s)",
        (doctor_id, patient_id, due_date, notes)
    )
    row = query(
        """SELECT f.*, u.full_name AS patient_name, u.avatar_initials
           FROM follow_ups f JOIN users u ON u.id = f.patient_id
           WHERE f.id = %s""",
        (fid,), one=True
    )
    return jsonify({"message": "Follow-up created", "followup": _fmt(row)}), 201


# ─────────────────────────────────────────────
# PUT /followup/<followup_id>
# Body: { due_date?, notes?, status? }
# ─────────────────────────────────────────────
@followup_bp.route("/<int:fid>", methods=["PUT"])
def update_followup(fid):
    f = query("SELECT * FROM follow_ups WHERE id = %s", (fid,), one=True)
    if not f:
        return jsonify({"error": "Not found"}), 404

    data     = request.get_json(silent=True) or {}
    due_date = data.get("due_date", f["due_date"])
    notes    = data.get("notes",    f["notes"])
    status   = data.get("status",   f["status"])

    execute(
        "UPDATE follow_ups SET due_date=%s, notes=%s, status=%s WHERE id=%s",
        (due_date, notes, status, fid)
    )
    row = query(
        """SELECT f.*, u.full_name AS patient_name, u.avatar_initials
           FROM follow_ups f JOIN users u ON u.id = f.patient_id
           WHERE f.id = %s""",
        (fid,), one=True
    )
    return jsonify({"message": "Updated", "followup": _fmt(row)}), 200


# ─────────────────────────────────────────────
# DELETE /followup/<followup_id>
# ─────────────────────────────────────────────
@followup_bp.route("/<int:fid>", methods=["DELETE"])
def delete_followup(fid):
    f = query("SELECT id FROM follow_ups WHERE id = %s", (fid,), one=True)
    if not f:
        return jsonify({"error": "Not found"}), 404
    execute("DELETE FROM follow_ups WHERE id = %s", (fid,))
    return jsonify({"message": "Deleted"}), 200


# ─────────────────────────────────────────────
# POST /followup/<fid>/complete
# ─────────────────────────────────────────────
@followup_bp.route("/<int:fid>/complete", methods=["POST", "PUT"])
def complete_followup(fid):
    f = query("SELECT id FROM follow_ups WHERE id = %s", (fid,), one=True)
    if not f:
        return jsonify({"error": "Not found"}), 404
    execute("UPDATE follow_ups SET status = 'COMPLETED' WHERE id = %s", (fid,))
    return jsonify({"message": "Marked as completed"}), 200
