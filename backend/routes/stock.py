# routes/stock.py — Stock Inventory management (Doctor)

from flask import Blueprint, request, jsonify
from db import query, execute

stock_bp = Blueprint("stock", __name__, url_prefix="/stock")

VALID_CATEGORIES = {"Medical Supplies", "PPE", "Consumables", "Equipment"}


def _status(current: int, threshold: int) -> str:
    if threshold == 0:
        return "OK"
    ratio = current / threshold
    if ratio >= 1.0:
        return "OK"
    elif ratio >= 0.5:
        return "LOW"
    return "CRITICAL"


def _fmt(item):
    status = _status(item["current_qty"], item["threshold"])
    pct    = round(min(item["current_qty"] / max(item["threshold"], 1) * 100, 100), 1)
    return {
        "id":          item["id"],
        "doctor_id":   item["doctor_id"],
        "name":        item["name"],
        "category":    item["category"],
        "current_qty": item["current_qty"],
        "threshold":   item["threshold"],
        "unit":        item["unit"],
        "status":      status,
        "percentage":  pct,
    }


# ─────────────────────────────────────────────
# GET /stock/<doctor_id>
# ─────────────────────────────────────────────
@stock_bp.route("/<int:doctor_id>", methods=["GET"])
@stock_bp.route("/doctor/<int:doctor_id>", methods=["GET"])
def get_stock(doctor_id):
    items = query(
        "SELECT * FROM stock_items WHERE doctor_id = %s ORDER BY name",
        (doctor_id,)
    )
    formatted = [_fmt(i) for i in items]
    # Summary counts
    summary = {
        "ok":       sum(1 for i in formatted if i["status"] == "OK"),
        "low":      sum(1 for i in formatted if i["status"] == "LOW"),
        "critical": sum(1 for i in formatted if i["status"] == "CRITICAL"),
    }
    return jsonify({"items": formatted, "summary": summary}), 200


# ─────────────────────────────────────────────
# POST /stock
# Body: { doctor_id, name, category, current_qty, threshold, unit }
# ─────────────────────────────────────────────
@stock_bp.route("", methods=["POST"])
def add_stock():
    data        = request.get_json(silent=True) or {}
    doctor_id   = data.get("doctor_id")
    name        = data.get("name") or ""
    name        = name.strip()
    category    = data.get("category", "Medical Supplies")
    
    try:
        current_qty = int(data.get("current_qty", 0))
        threshold   = int(data.get("threshold", 10))
    except (TypeError, ValueError):
        current_qty = 0
        threshold   = 10
        
    unit        = data.get("unit", "units")

    if not doctor_id or not name:
        return jsonify({"error": "doctor_id and name are required"}), 400

    if category not in VALID_CATEGORIES:
        category = "Medical Supplies"

    iid = execute(
        """INSERT INTO stock_items
           (doctor_id, name, category, current_qty, threshold, unit)
           VALUES (%s,%s,%s,%s,%s,%s)""",
        (doctor_id, name, category, current_qty, threshold, unit)
    )
    item = query("SELECT * FROM stock_items WHERE id = %s", (iid,), one=True)
    return jsonify({"message": "Item added", "item": _fmt(item)}), 201


# ─────────────────────────────────────────────
# PUT /stock/<item_id>
# Body: { name?, category?, current_qty?, threshold?, unit? }
# ─────────────────────────────────────────────
@stock_bp.route("/<int:item_id>", methods=["PUT"])
def update_stock(item_id):
    item = query("SELECT * FROM stock_items WHERE id = %s", (item_id,), one=True)
    if not item:
        return jsonify({"error": "Item not found"}), 404

    data = request.get_json(silent=True) or {}
    name        = data.get("name")
    name        = name.strip() if name else item["name"]
    category    = data.get("category", item["category"])
    if category not in VALID_CATEGORIES:
        category = "Medical Supplies"
        
    try:
        current_qty = int(data.get("current_qty", item["current_qty"]))
        threshold   = int(data.get("threshold", item["threshold"]))
    except (TypeError, ValueError):
        current_qty = item["current_qty"]
        threshold   = item["threshold"]
        
    unit        = data.get("unit", item["unit"])

    execute(
        """UPDATE stock_items
           SET name=%s, category=%s, current_qty=%s, threshold=%s, unit=%s
           WHERE id=%s""",
        (name, category, current_qty, threshold, unit, item_id)
    )
    updated = query("SELECT * FROM stock_items WHERE id = %s", (item_id,), one=True)
    return jsonify({"message": "Updated", "item": _fmt(updated)}), 200


# ─────────────────────────────────────────────
# DELETE /stock/<item_id>
# ─────────────────────────────────────────────
@stock_bp.route("/<int:item_id>", methods=["DELETE"])
def delete_stock(item_id):
    item = query("SELECT id FROM stock_items WHERE id = %s", (item_id,), one=True)
    if not item:
        return jsonify({"error": "Item not found"}), 404
    execute("DELETE FROM stock_items WHERE id = %s", (item_id,))
    return jsonify({"message": "Deleted"}), 200


# ─────────────────────────────────────────────
# POST /stock/<item_id>/restock
# Body: { quantity }  — adds to current_qty
# ─────────────────────────────────────────────
@stock_bp.route("/<int:item_id>/restock", methods=["POST"])
def restock(item_id):
    item = query("SELECT * FROM stock_items WHERE id = %s", (item_id,), one=True)
    if not item:
        return jsonify({"error": "Item not found"}), 404

    data = request.get_json(silent=True) or {}
    try:
        quantity = int(data.get("quantity", 0))
    except (TypeError, ValueError):
        return jsonify({"error": "quantity must be a valid number"}), 400
    if quantity <= 0:
        return jsonify({"error": "quantity must be positive"}), 400

    new_qty = item["current_qty"] + quantity
    execute("UPDATE stock_items SET current_qty = %s WHERE id = %s", (new_qty, item_id))
    updated = query("SELECT * FROM stock_items WHERE id = %s", (item_id,), one=True)
    return jsonify({"message": f"Restocked +{quantity}", "item": _fmt(updated)}), 200
