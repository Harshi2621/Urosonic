# routes/profile.py — User Profile management (Patient & Doctor)

import bcrypt
from flask import Blueprint, request, jsonify
from db import query, execute

profile_bp = Blueprint("profile", __name__, url_prefix="/profile")


def _fmt_patient(u):
    return {
        "id":             u["id"],
        "full_name":      u["full_name"],
        "email":          u["email"],
        "phone":          u["phone"],
        "role":           u["role"],
        "avatar_initials":u["avatar_initials"],
        "age":            u["age"],
        "gender":         u["gender"],
        "condition":      u["condition"],
        "doctor_id":      u["doctor_id"],
    }


def _fmt_doctor(u):
    return {
        "id":              u["id"],
        "full_name":       u["full_name"],
        "email":           u["email"],
        "phone":           u["phone"],
        "role":            u["role"],
        "avatar_initials": u["avatar_initials"],
        "license_number":  u["license_number"],
        "specialization":  u["specialization"],
    }


# ─────────────────────────────────────────────
# GET /profile/<user_id>
# ─────────────────────────────────────────────
@profile_bp.route("/<int:user_id>", methods=["GET"])
def get_profile(user_id):
    u = query("SELECT * FROM users WHERE id = %s AND is_active = 1", (user_id,), one=True)
    if not u:
        return jsonify({"error": "User not found"}), 404
    if u["role"] == "doctor":
        return jsonify(_fmt_doctor(u)), 200
    return jsonify(_fmt_patient(u)), 200


# ─────────────────────────────────────────────
# PUT /profile/<user_id>
# Body: { full_name?, phone?, age?, gender?, condition?,
#         specialization? }
# ─────────────────────────────────────────────
@profile_bp.route("/<int:user_id>", methods=["PUT"])
def update_profile(user_id):
    u = query("SELECT * FROM users WHERE id = %s AND is_active = 1", (user_id,), one=True)
    if not u:
        return jsonify({"error": "User not found"}), 404

    data      = request.get_json(silent=True) or {}
    full_name = data.get("full_name",  u["full_name"])
    phone     = data.get("phone",      u["phone"])

    # Recompute initials if name changed
    parts    = full_name.split()
    initials = "".join(p[0].upper() for p in parts[:2])

    if u["role"] == "patient":
        age       = data.get("age",       u["age"])
        gender    = data.get("gender",    u["gender"])
        condition = data.get("condition", u["condition"])
        doctor_id = data.get("doctor_id", u["doctor_id"])
        if doctor_id == "" or doctor_id == 0 or doctor_id == "0":
            doctor_id = None
        execute(
            """UPDATE users SET full_name=%s, phone=%s, age=%s, gender=%s,
               `condition`=%s, doctor_id=%s, avatar_initials=%s WHERE id=%s""",
            (full_name, phone, age, gender, condition, doctor_id, initials, user_id)
        )
    else:
        spec = data.get("specialization", u["specialization"])
        execute(
            "UPDATE users SET full_name=%s, phone=%s, specialization=%s, avatar_initials=%s WHERE id=%s",
            (full_name, phone, spec, initials, user_id)
        )

    updated = query("SELECT * FROM users WHERE id = %s", (user_id,), one=True)
    if updated["role"] == "doctor":
        return jsonify({"message": "Profile updated", "profile": _fmt_doctor(updated)}), 200
    return jsonify({"message": "Profile updated", "profile": _fmt_patient(updated)}), 200


# ─────────────────────────────────────────────
# PUT /profile/<user_id>/change-password
# Body: { current_password, new_password }
# ─────────────────────────────────────────────
@profile_bp.route("/<int:user_id>/change-password", methods=["PUT"])
def change_password(user_id):
    u = query("SELECT * FROM users WHERE id = %s AND is_active = 1", (user_id,), one=True)
    if not u:
        return jsonify({"error": "User not found"}), 404

    data             = request.get_json(silent=True) or {}
    current_password = data.get("current_password", "")
    new_password     = data.get("new_password",     "")

    if not current_password or not new_password:
        return jsonify({"error": "current_password and new_password are required"}), 400

    stored_pw = u.get("password_hash", "")
    is_valid = (stored_pw == current_password)
    if not is_valid and stored_pw.startswith(("$2a$", "$2b$", "$2y$")):
        try:
            is_valid = bcrypt.checkpw(current_password.encode("utf-8"), stored_pw.encode("utf-8"))
        except Exception:
            is_valid = False

    if not is_valid:
        return jsonify({"error": "Current password is incorrect"}), 401

    execute("UPDATE users SET password_hash = %s WHERE id = %s",
            (new_password, user_id))
    return jsonify({"message": "Password changed successfully"}), 200


# ─────────────────────────────────────────────
# DELETE /profile/<user_id>  (Account Deletion)
# Query/Body param: mode='deactivate' for soft-delete, default is permanent deletion.
# Optional body: { password?: string } for password confirmation.
# ─────────────────────────────────────────────
@profile_bp.route("/<int:user_id>", methods=["DELETE"])
def delete_account(user_id):
    u = query("SELECT id, role, password_hash FROM users WHERE id = %s", (user_id,), one=True)
    if not u:
        return jsonify({"error": "User not found"}), 404

    data = request.get_json(silent=True) or {}
    password = data.get("password")
    if password:
        stored_pw = u.get("password_hash", "")
        is_valid = (stored_pw == password)
        if not is_valid and stored_pw.startswith(("$2a$", "$2b$", "$2y$")):
            try:
                is_valid = bcrypt.checkpw(password.encode("utf-8"), stored_pw.encode("utf-8"))
            except Exception:
                is_valid = False
        if not is_valid:
            return jsonify({"error": "Incorrect password"}), 401

    mode = request.args.get("mode", data.get("mode", "delete")).lower()
    if mode == "deactivate":
        execute("UPDATE users SET is_active = 0 WHERE id = %s", (user_id,))
        return jsonify({"message": "Account deactivated successfully"}), 200

    # Permanent deletion — ON DELETE CASCADE cleans up all child tables
    execute("DELETE FROM users WHERE id = %s", (user_id,))
    return jsonify({"message": "Account deleted permanently"}), 200


# ─────────────────────────────────────────────
# GET /profile/doctor/<doctor_id>/patients
# List all patients assigned to a doctor
# ─────────────────────────────────────────────
@profile_bp.route("/doctor/<int:doctor_id>/patients", methods=["GET"])
def get_doctor_patients(doctor_id):
    search = request.args.get("search", "")
    if search:
        rows = query(
            """SELECT u.*,
                  (SELECT m.qmax FROM measurements m
                   WHERE m.patient_id = u.id ORDER BY m.recorded_at DESC LIMIT 1) AS latest_qmax,
                  (SELECT m.status FROM measurements m
                   WHERE m.patient_id = u.id ORDER BY m.recorded_at DESC LIMIT 1) AS latest_status,
                  (SELECT m.recorded_at FROM measurements m
                   WHERE m.patient_id = u.id ORDER BY m.recorded_at DESC LIMIT 1) AS last_measurement_at
               FROM users u
               WHERE (u.doctor_id = %s OR u.doctor_id IS NULL) AND u.role = 'patient' AND u.is_active = 1
                 AND u.full_name LIKE %s
               ORDER BY u.full_name""",
            (doctor_id, f"%{search}%")
        )
    else:
        rows = query(
            """SELECT u.*,
                  (SELECT m.qmax FROM measurements m
                   WHERE m.patient_id = u.id ORDER BY m.recorded_at DESC LIMIT 1) AS latest_qmax,
                  (SELECT m.status FROM measurements m
                   WHERE m.patient_id = u.id ORDER BY m.recorded_at DESC LIMIT 1) AS latest_status,
                  (SELECT m.recorded_at FROM measurements m
                   WHERE m.patient_id = u.id ORDER BY m.recorded_at DESC LIMIT 1) AS last_measurement_at
               FROM users u
               WHERE (u.doctor_id = %s OR u.doctor_id IS NULL) AND u.role = 'patient' AND u.is_active = 1
               ORDER BY u.full_name""",
            (doctor_id,)
        )

    result = []
    for r in rows:
        result.append({
            "id":               r["id"],
            "name":             r["full_name"],
            "avatar":           r["avatar_initials"] or "",
            "age":              r["age"],
            "gender":           r["gender"],
            "condition":        r["condition"],
            "latest_qmax":      float(r["latest_qmax"]) if r["latest_qmax"] is not None else None,
            "latest_status":    r["latest_status"],
            "last_measured_at": r["last_measurement_at"].strftime("%Y-%m-%d %H:%M") if r["last_measurement_at"] else None,
        })
    return jsonify(result), 200


# ─────────────────────────────────────────────
# GET /profile/doctor/<doctor_id>/dashboard
# Summary metrics for the Doctor Home screen
# ─────────────────────────────────────────────
@profile_bp.route("/doctor/<int:doctor_id>/dashboard", methods=["GET"])
def doctor_dashboard(doctor_id):
    patients_count = query(
        "SELECT COUNT(*) AS cnt FROM users WHERE (doctor_id = %s OR doctor_id IS NULL) AND role='patient' AND is_active=1",
        (doctor_id,), one=True
    )["cnt"]

    # Measurements not yet reviewed (no feedback)
    pending_reviews = query(
        """SELECT COUNT(*) AS cnt FROM measurements m
           WHERE m.patient_id IN (
               SELECT id FROM users WHERE (doctor_id = %s OR doctor_id IS NULL) AND role='patient'
           )
           AND NOT EXISTS (SELECT 1 FROM feedback f WHERE f.measurement_id = m.id)""",
        (doctor_id,), one=True
    )["cnt"]

    low_stock = query(
        """SELECT COUNT(*) AS cnt FROM stock_items
           WHERE doctor_id = %s AND current_qty < threshold""",
        (doctor_id,), one=True
    )["cnt"]

    from datetime import date
    today = date.today()
    followups_due = query(
        """SELECT COUNT(*) AS cnt FROM follow_ups
           WHERE doctor_id = %s AND status != 'COMPLETED'
             AND due_date <= %s""",
        (doctor_id, today), one=True
    )["cnt"]

    return jsonify({
        "total_patients":   patients_count,
        "pending_reviews":  pending_reviews,
        "low_stock_count":  low_stock,
        "followups_due":    followups_due,
    }), 200


# ─────────────────────────────────────────────
# GET /profile/doctors
# List all active doctors (for patient registration)
# ─────────────────────────────────────────────
@profile_bp.route("/doctors", methods=["GET"])
def list_doctors():
    rows = query(
        "SELECT id, full_name, specialization, avatar_initials FROM users WHERE role='doctor' AND is_active=1 ORDER BY full_name"
    )
    return jsonify([{
        "id":             r["id"],
        "full_name":      r["full_name"],
        "specialization": r["specialization"],
        "avatar_initials":r["avatar_initials"],
    } for r in rows]), 200


# ─────────────────────────────────────────────
# GET /profile/patient/<patient_id>/dashboard
# Quick stats for PatientHome screen
# ─────────────────────────────────────────────
@profile_bp.route("/patient/<int:patient_id>/dashboard", methods=["GET"])
def patient_dashboard(patient_id):
    from datetime import date as _date

    # Latest measurement
    latest = query(
        "SELECT * FROM measurements WHERE patient_id = %s ORDER BY recorded_at DESC LIMIT 1",
        (patient_id,), one=True
    )

    # Today's fluid total
    today = _date.today().strftime("%Y-%m-%d")
    fluid_rows = query(
        "SELECT volume_ml FROM fluid_logs WHERE patient_id = %s AND log_date = %s",
        (patient_id, today)
    )
    fluid_today = sum(r["volume_ml"] for r in fluid_rows)

    # Unread messages count
    unread = query(
        "SELECT COUNT(*) AS cnt FROM messages WHERE receiver_id = %s AND is_read = 0",
        (patient_id,), one=True
    )

    # Doctor info
    patient = query("SELECT doctor_id FROM users WHERE id = %s", (patient_id,), one=True)
    doctor  = None
    if patient and patient["doctor_id"]:
        d = query("SELECT full_name, specialization FROM users WHERE id = %s",
                  (patient["doctor_id"],), one=True)
        if d:
            doctor = {"full_name": d["full_name"], "specialization": d["specialization"]}

    return jsonify({
        "fluid_today_ml": fluid_today,
        "fluid_target_ml": 2000,
        "unread_messages": unread["cnt"] if unread else 0,
        "doctor":          doctor,
        "latest_measurement": {
            "qmax":        float(latest["qmax"]) if latest else None,
            "volume":      latest["volume"] if latest else None,
            "status":      latest["status"] if latest else None,
            "recorded_at": latest["recorded_at"].strftime("%Y-%m-%d %H:%M:%S") if latest and latest["recorded_at"] else None,
        } if latest else None,
    }), 200
