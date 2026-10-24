# routes/surgery.py — Surgery Log routes

import json
from flask import Blueprint, request, jsonify
from db import query, execute

surgery_bp = Blueprint("surgery", __name__, url_prefix="/surgery")


def _fmt_surgery(s, team):
    return {
        "id":                s["id"],
        "doctor_id":         s["doctor_id"],
        "surgery_date":      s["surgery_date"].strftime("%Y-%m-%d") if s["surgery_date"] else None,
        "hospital":          s["hospital"],
        "my_role":           s["my_role"],
        "patient_name":      s["patient_name"],
        "patient_id_ref":    s["patient_id_ref"],
        "phone_number":      s["phone_number"],
        "surgery_type":      s["surgery_type"],
        "diagnoses":         _parse_json(s["diagnoses"]),
        "professional_fees": s["professional_fees"],
        "instrument_charges":s["instrument_charges"],
        "total_fees":        (s["professional_fees"] or 0) + (s["instrument_charges"] or 0),
        "payment_status":    s["payment_status"],
        "consumables":       _parse_json(s["consumables"]),
        "rental_name":       s["rental_name"],
        "rental_fees":       s["rental_fees"],
        "stent_type":        s["stent_type"],
        "stent_due_date":    s["stent_due_date"].strftime("%Y-%m-%d") if s["stent_due_date"] else None,
        "stent_status":      s["stent_status"],
        "remarks":           s["remarks"],
        "team":              [_fmt_team(t) for t in team],
    }


def _fmt_team(t):
    return {
        "id":             t["id"],
        "surgery_id":     t["surgery_id"],
        "role":           t["role"],
        "member_name":    t["member_name"],
        "fees":           t["fees"],
        "payment_status": t["payment_status"],
    }


def _parse_json(val):
    if not val:
        return []
    try:
        return json.loads(val)
    except Exception:
        return [val]


# ─────────────────────────────────────────────
# GET /surgery/doctor/<doctor_id> or /surgery/<doctor_id>
# ─────────────────────────────────────────────
@surgery_bp.route("/doctor/<int:doctor_id>", methods=["GET"])
@surgery_bp.route("/<int:doctor_id>", methods=["GET"])
def get_surgeries(doctor_id):
    search = request.args.get("search", "")
    if search:
        rows = query(
            """SELECT * FROM surgery_records
               WHERE doctor_id = %s
                 AND (patient_name LIKE %s OR surgery_type LIKE %s OR hospital LIKE %s)
               ORDER BY surgery_date DESC""",
            (doctor_id, f"%{search}%", f"%{search}%", f"%{search}%")
        )
    else:
        rows = query(
            "SELECT * FROM surgery_records WHERE doctor_id = %s ORDER BY surgery_date DESC",
            (doctor_id,)
        )

    result = []
    for s in rows:
        team = query("SELECT * FROM surgery_team WHERE surgery_id = %s", (s["id"],))
        result.append(_fmt_surgery(s, team))
    return jsonify(result), 200


# ─────────────────────────────────────────────
# GET /surgery/detail/<surgery_id>
# ─────────────────────────────────────────────
@surgery_bp.route("/detail/<int:surgery_id>", methods=["GET"])
def get_surgery(surgery_id):
    s = query("SELECT * FROM surgery_records WHERE id = %s", (surgery_id,), one=True)
    if not s:
        return jsonify({"error": "Not found"}), 404
    team = query("SELECT * FROM surgery_team WHERE surgery_id = %s", (surgery_id,))
    return jsonify(_fmt_surgery(s, team)), 200


# ─────────────────────────────────────────────
# POST /surgery
# Body: full SurgeryRecord payload + team array
# ─────────────────────────────────────────────
@surgery_bp.route("", methods=["POST"])
def add_surgery():
    data = request.get_json(silent=True) or {}
    doctor_id       = data.get("doctor_id")
    patient_name    = data.get("patient_name", "").strip()
    surgery_type    = data.get("surgery_type", "").strip()
    surgery_date    = data.get("surgery_date")

    if not doctor_id or not patient_name or not surgery_type or not surgery_date:
        return jsonify({"error": "doctor_id, patient_name, surgery_type and surgery_date are required"}), 400

    diagnoses   = json.dumps(data.get("diagnoses",   []))
    consumables = json.dumps(data.get("consumables", []))

    sid = execute(
        """INSERT INTO surgery_records
           (doctor_id, surgery_date, hospital, my_role,
            patient_name, patient_id_ref, phone_number,
            surgery_type, diagnoses, professional_fees, instrument_charges,
            payment_status, consumables, rental_name, rental_fees,
            stent_type, stent_due_date, stent_status, remarks)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
        (
            doctor_id,
            surgery_date,
            data.get("hospital", ""),
            data.get("my_role", "Primary Surgeon"),
            patient_name,
            data.get("patient_id_ref", ""),
            data.get("phone_number", ""),
            surgery_type,
            diagnoses,
            data.get("professional_fees", 0),
            data.get("instrument_charges", 0),
            data.get("payment_status", "Pending"),
            consumables,
            data.get("rental_name", ""),
            data.get("rental_fees", 0),
            data.get("stent_type", ""),
            data.get("stent_due_date") or None,
            data.get("stent_status", "N/A"),
            data.get("remarks", ""),
        )
    )

    # Insert team members
    for member in data.get("team", []):
        if member.get("member_name", "").strip():
            execute(
                """INSERT INTO surgery_team (surgery_id, role, member_name, fees, payment_status)
                   VALUES (%s,%s,%s,%s,%s)""",
                (sid, member.get("role", ""), member["member_name"],
                 member.get("fees", 0), member.get("payment_status", "Pending"))
            )

    s    = query("SELECT * FROM surgery_records WHERE id = %s", (sid,), one=True)
    team = query("SELECT * FROM surgery_team WHERE surgery_id = %s", (sid,))
    return jsonify({"message": "Surgery record saved", "surgery": _fmt_surgery(s, team)}), 201


# ─────────────────────────────────────────────
# PUT /surgery/<surgery_id>
# ─────────────────────────────────────────────
@surgery_bp.route("/<int:surgery_id>", methods=["PUT"])
def update_surgery(surgery_id):
    s = query("SELECT * FROM surgery_records WHERE id = %s", (surgery_id,), one=True)
    if not s:
        return jsonify({"error": "Not found"}), 404

    data = request.get_json(silent=True) or {}
    diagnoses   = json.dumps(data.get("diagnoses",   _parse_json(s["diagnoses"])))
    consumables = json.dumps(data.get("consumables", _parse_json(s["consumables"])))

    execute(
        """UPDATE surgery_records SET
           surgery_date=%s, hospital=%s, my_role=%s,
           patient_name=%s, patient_id_ref=%s, phone_number=%s,
           surgery_type=%s, diagnoses=%s, professional_fees=%s, instrument_charges=%s,
           payment_status=%s, consumables=%s, rental_name=%s, rental_fees=%s,
           stent_type=%s, stent_due_date=%s, stent_status=%s, remarks=%s
           WHERE id=%s""",
        (
            data.get("surgery_date",        s["surgery_date"]),
            data.get("hospital",            s["hospital"]),
            data.get("my_role",             s["my_role"]),
            data.get("patient_name",        s["patient_name"]),
            data.get("patient_id_ref",      s["patient_id_ref"]),
            data.get("phone_number",        s["phone_number"]),
            data.get("surgery_type",        s["surgery_type"]),
            diagnoses,
            data.get("professional_fees",   s["professional_fees"]),
            data.get("instrument_charges",  s["instrument_charges"]),
            data.get("payment_status",      s["payment_status"]),
            consumables,
            data.get("rental_name",         s["rental_name"]),
            data.get("rental_fees",         s["rental_fees"]),
            data.get("stent_type",          s["stent_type"]),
            data.get("stent_due_date",      s["stent_due_date"]),
            data.get("stent_status",        s["stent_status"]),
            data.get("remarks",             s["remarks"]),
            surgery_id,
        )
    )

    # Replace team if provided
    if "team" in data:
        execute("DELETE FROM surgery_team WHERE surgery_id = %s", (surgery_id,))
        for member in data["team"]:
            if member.get("member_name", "").strip():
                execute(
                    """INSERT INTO surgery_team (surgery_id, role, member_name, fees, payment_status)
                       VALUES (%s,%s,%s,%s,%s)""",
                    (surgery_id, member.get("role", ""), member["member_name"],
                     member.get("fees", 0), member.get("payment_status", "Pending"))
                )

    updated = query("SELECT * FROM surgery_records WHERE id = %s", (surgery_id,), one=True)
    team    = query("SELECT * FROM surgery_team WHERE surgery_id = %s", (surgery_id,))
    return jsonify({"message": "Updated", "surgery": _fmt_surgery(updated, team)}), 200


# ─────────────────────────────────────────────
# DELETE /surgery/<surgery_id>
# ─────────────────────────────────────────────
@surgery_bp.route("/<int:surgery_id>", methods=["DELETE"])
def delete_surgery(surgery_id):
    s = query("SELECT id FROM surgery_records WHERE id = %s", (surgery_id,), one=True)
    if not s:
        return jsonify({"error": "Not found"}), 404
    execute("DELETE FROM surgery_records WHERE id = %s", (surgery_id,))
    return jsonify({"message": "Deleted"}), 200
