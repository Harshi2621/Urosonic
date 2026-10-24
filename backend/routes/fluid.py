# routes/fluid.py — Fluid intake logger

from flask import Blueprint, request, jsonify
from db import query, execute
from datetime import date

fluid_bp = Blueprint("fluid", __name__, url_prefix="/fluid")

VALID_TYPES = {"Water", "Coffee", "Juice", "Tea", "Electrolytes", "Other"}


def _fmt(e):
    return {
        "id":         e["id"],
        "patient_id": e["patient_id"],
        "drink_type": e["drink_type"],
        "volume_ml":  e["volume_ml"],
        "logged_at":  e["logged_at"],
        "log_date":   e["log_date"].strftime("%Y-%m-%d") if e.get("log_date") else None,
    }


def _fmt_output(e):
    return {
        "id":         e["id"],
        "patient_id": e["patient_id"],
        "volume_ml":  e["volume_ml"],
        "urgency":    e.get("urgency") or "Normal",
        "color":      e.get("color") or "Pale Yellow",
        "source":     e.get("source") or "Manual",
        "logged_at":  e.get("logged_at") or "",
        "log_date":   e["log_date"].strftime("%Y-%m-%d") if e.get("log_date") else None,
        "notes":      e.get("notes") or "",
    }


def _ensure_output_table():
    try:
        execute("""
            CREATE TABLE IF NOT EXISTS urine_output_logs (
                id          INT AUTO_INCREMENT PRIMARY KEY,
                patient_id  INT NOT NULL,
                volume_ml   INT NOT NULL,
                urgency     VARCHAR(50) DEFAULT 'Normal',
                color       VARCHAR(50) DEFAULT 'Pale Yellow',
                source      VARCHAR(50) DEFAULT 'Manual',
                logged_at   VARCHAR(50),
                log_date    DATE,
                notes       TEXT,
                created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB;
        """)
    except Exception:
        pass


# ─────────────────────────────────────────────
# GET /fluid/patient/<patient_id>
# Optional query params: ?date=YYYY-MM-DD
# ─────────────────────────────────────────────
@fluid_bp.route("/patient/<int:patient_id>", methods=["GET"])
def get_fluid_logs(patient_id):
    log_date = request.args.get("date")
    if log_date:
        rows = query(
            "SELECT * FROM fluid_logs WHERE patient_id = %s AND log_date = %s ORDER BY id DESC",
            (patient_id, log_date)
        )
    else:
        rows = query(
            "SELECT * FROM fluid_logs WHERE patient_id = %s ORDER BY id DESC",
            (patient_id,)
        )

    total = sum(r["volume_ml"] for r in rows)
    return jsonify({"entries": [_fmt(r) for r in rows], "total_ml": total}), 200


# ─────────────────────────────────────────────
# POST /fluid
# Body: { patient_id, drink_type, volume_ml, logged_at, log_date? }
# ─────────────────────────────────────────────
@fluid_bp.route("", methods=["POST"])
@fluid_bp.route("/log", methods=["POST"])
def add_fluid_log():
    data = request.get_json(silent=True) or {}
    patient_id = data.get("patient_id")
    drink_type = data.get("drink_type", "Water")
    volume_ml  = data.get("volume_ml")
    logged_at  = data.get("logged_at", "")
    log_date   = data.get("log_date", date.today().strftime("%Y-%m-%d"))

    if not patient_id or volume_ml is None:
        return jsonify({"error": "patient_id and volume_ml are required"}), 400

    if drink_type not in VALID_TYPES:
        drink_type = "Other"

    eid = execute(
        """INSERT INTO fluid_logs (patient_id, drink_type, volume_ml, logged_at, log_date)
           VALUES (%s,%s,%s,%s,%s)""",
        (patient_id, drink_type, volume_ml, logged_at, log_date)
    )
    entry = query("SELECT * FROM fluid_logs WHERE id = %s", (eid,), one=True)
    return jsonify({"message": "Logged", "entry": _fmt(entry)}), 201


# ─────────────────────────────────────────────
# DELETE /fluid/<entry_id>
# ─────────────────────────────────────────────
@fluid_bp.route("/<int:entry_id>", methods=["DELETE"])
@fluid_bp.route("/log/<int:entry_id>", methods=["DELETE"])
def delete_fluid_log(entry_id):
    entry = query("SELECT id FROM fluid_logs WHERE id = %s", (entry_id,), one=True)
    if not entry:
        return jsonify({"error": "Not found"}), 404
    execute("DELETE FROM fluid_logs WHERE id = %s", (entry_id,))
    return jsonify({"message": "Deleted"}), 200


# ─────────────────────────────────────────────
# GET /fluid/patient/<patient_id>/today-summary
# ─────────────────────────────────────────────
@fluid_bp.route("/patient/<int:patient_id>/today-summary", methods=["GET"])
def today_summary(patient_id):
    today = date.today().strftime("%Y-%m-%d")
    rows  = query(
        "SELECT * FROM fluid_logs WHERE patient_id = %s AND log_date = %s",
        (patient_id, today)
    )
    total = sum(r["volume_ml"] for r in rows)
    target = 2000  # mL
    return jsonify({
        "date":       today,
        "total_ml":   total,
        "target_ml":  target,
        "percentage": round(min(total / target * 100, 100), 1),
        "entries":    [_fmt(r) for r in rows],
    }), 200


# ─────────────────────────────────────────────
# URINE OUTPUT (VOIDED FLUID) ROUTES
# ─────────────────────────────────────────────

# ─────────────────────────────────────────────
# GET /fluid/patient/<patient_id>/output
# Optional query params: ?date=YYYY-MM-DD
# ─────────────────────────────────────────────
@fluid_bp.route("/patient/<int:patient_id>/output", methods=["GET"])
def get_urine_output_logs(patient_id):
    _ensure_output_table()
    log_date = request.args.get("date")
    if log_date:
        rows = query(
            "SELECT * FROM urine_output_logs WHERE patient_id = %s AND log_date = %s ORDER BY id DESC",
            (patient_id, log_date)
        )
    else:
        rows = query(
            "SELECT * FROM urine_output_logs WHERE patient_id = %s ORDER BY id DESC",
            (patient_id,)
        )

    entries = [_fmt_output(r) for r in rows]
    total = sum(r["volume_ml"] for r in rows)
    return jsonify({
        "entries": entries,
        "total_ml": total,
        "count": len(entries)
    }), 200


# ─────────────────────────────────────────────
# POST /fluid/output
# Body: { patient_id, volume_ml, urgency?, color?, source?, logged_at?, log_date?, notes? }
# ─────────────────────────────────────────────
@fluid_bp.route("/output", methods=["POST"])
@fluid_bp.route("/patient/<int:url_patient_id>/output", methods=["POST"])
def add_urine_output_log(url_patient_id=None):
    _ensure_output_table()
    data = request.get_json(silent=True) or {}
    patient_id = url_patient_id or data.get("patient_id")
    volume_ml  = data.get("volume_ml")
    urgency    = data.get("urgency", "Normal")
    color      = data.get("color", "Pale Yellow")
    source     = data.get("source", "Manual")
    logged_at  = data.get("logged_at", "")
    log_date   = data.get("log_date", date.today().strftime("%Y-%m-%d"))
    notes      = data.get("notes", "")

    if not patient_id or volume_ml is None:
        return jsonify({"error": "patient_id and volume_ml are required"}), 400

    eid = execute(
        """INSERT INTO urine_output_logs (patient_id, volume_ml, urgency, color, source, logged_at, log_date, notes)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
        (patient_id, volume_ml, urgency, color, source, logged_at, log_date, notes)
    )
    entry = query("SELECT * FROM urine_output_logs WHERE id = %s", (eid,), one=True)
    return jsonify({"message": "Urine output logged", "entry": _fmt_output(entry)}), 201


# ─────────────────────────────────────────────
# DELETE /fluid/output/<entry_id>
# ─────────────────────────────────────────────
@fluid_bp.route("/output/<int:entry_id>", methods=["DELETE"])
def delete_urine_output_log(entry_id):
    _ensure_output_table()
    entry = query("SELECT id FROM urine_output_logs WHERE id = %s", (entry_id,), one=True)
    if not entry:
        return jsonify({"error": "Not found"}), 404
    execute("DELETE FROM urine_output_logs WHERE id = %s", (entry_id,))
    return jsonify({"message": "Deleted"}), 200


# ─────────────────────────────────────────────
# GET /fluid/patient/<patient_id>/balance
# Optional query params: ?date=YYYY-MM-DD
# ─────────────────────────────────────────────
@fluid_bp.route("/patient/<int:patient_id>/balance", methods=["GET"])
def get_fluid_balance(patient_id):
    _ensure_output_table()
    target_date = request.args.get("date") or date.today().strftime("%Y-%m-%d")

    intake_rows = query(
        "SELECT * FROM fluid_logs WHERE patient_id = %s AND log_date = %s ORDER BY id DESC",
        (patient_id, target_date)
    )
    output_rows = query(
        "SELECT * FROM urine_output_logs WHERE patient_id = %s AND log_date = %s ORDER BY id DESC",
        (patient_id, target_date)
    )

    intake_total = sum(r["volume_ml"] for r in intake_rows)
    output_total = sum(r["volume_ml"] for r in output_rows)
    net_balance  = intake_total - output_total
    intake_target = 2000

    return jsonify({
        "date":              target_date,
        "intake_total_ml":   intake_total,
        "output_total_ml":   output_total,
        "net_balance_ml":    net_balance,
        "intake_target_ml":  intake_target,
        "void_count":        len(output_rows),
        "intake_entries":    [_fmt(r) for r in intake_rows],
        "output_entries":    [_fmt_output(r) for r in output_rows],
    }), 200
