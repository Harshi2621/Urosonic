# routes/messages.py — Chat/Messaging between patients and doctors

from flask import Blueprint, request, jsonify
from db import query, execute

messages_bp = Blueprint("messages", __name__, url_prefix="/messages")


def _fmt_msg(m):
    return {
        "id":          m["id"],
        "sender_id":   m["sender_id"],
        "receiver_id": m["receiver_id"],
        "message":     m["message"],
        "is_read":     bool(m["is_read"]),
        "sent_at":     m["sent_at"].strftime("%Y-%m-%d %H:%M:%S") if m["sent_at"] else None,
    }


def _fmt_conv(row):
    return {
        "user_id":        row["other_id"],
        "name":           row["full_name"],
        "avatar":         row["avatar_initials"] or "",
        "role":           row["role"],
        "last_message":   row["message"],
        "last_time":      row["sent_at"].strftime("%Y-%m-%d %H:%M:%S") if row["sent_at"] else None,
        "unread_count":   row["unread_count"],
        "last_sender_id": row.get("sender_id"),
        "last_is_read":   bool(row.get("is_read", 0)),
    }


# ─────────────────────────────────────────────
# GET /messages/conversations/<user_id>
# Lists all unique chat partners with last message
# ─────────────────────────────────────────────
@messages_bp.route("/conversations/<int:user_id>", methods=["GET"])
def get_conversations(user_id):
    current_user = query("SELECT id, role, doctor_id FROM users WHERE id = %s AND is_active = 1", (user_id,), one=True)
    if not current_user:
        return jsonify([]), 200

    # 1. Get all unique users this person has chatted with, plus last message & unread
    sql = """
        SELECT
            u.id            AS other_id,
            u.full_name,
            u.avatar_initials,
            u.role,
            m.message,
            m.sent_at,
            m.sender_id,
            m.is_read,
            (SELECT COUNT(*) FROM messages m2
             WHERE m2.sender_id = u.id AND m2.receiver_id = %s AND m2.is_read = 0) AS unread_count
        FROM users u
        JOIN messages m ON (
            (m.sender_id   = u.id  AND m.receiver_id = %s) OR
            (m.receiver_id = u.id  AND m.sender_id   = %s)
        )
        WHERE u.id != %s
        AND m.id = (
            SELECT id FROM messages m3
            WHERE (m3.sender_id = u.id AND m3.receiver_id = %s)
               OR (m3.receiver_id = u.id AND m3.sender_id = %s)
            ORDER BY m3.sent_at DESC LIMIT 1
        )
        ORDER BY m.sent_at DESC
    """
    rows = query(sql, (user_id, user_id, user_id, user_id, user_id, user_id))
    existing_ids = {r["other_id"] for r in rows}
    conv_list = [_fmt_conv(r) for r in rows]

    # 2. If patient, ensure assigned or clinic doctor is in list
    if current_user["role"] == "patient":
        doc_id = current_user.get("doctor_id")
        doc = None
        if doc_id:
            doc = query("SELECT id, full_name, avatar_initials, role, specialization FROM users WHERE id = %s AND role='doctor' AND is_active=1", (doc_id,), one=True)
        if not doc:
            doc = query("SELECT id, full_name, avatar_initials, role, specialization FROM users WHERE role='doctor' AND is_active=1 ORDER BY id ASC LIMIT 1", one=True)

        if doc and doc["id"] not in existing_ids:
            conv_list.insert(0, {
                "user_id":        doc["id"],
                "name":           doc["full_name"],
                "avatar":         doc["avatar_initials"] or "DR",
                "role":           "doctor",
                "last_message":   f"Specialist in {doc.get('specialization') or 'Urology'}. Tap to start consultation.",
                "last_time":      None,
                "unread_count":   0,
                "last_sender_id": None,
                "last_is_read":   False,
            })
    # 3. If doctor, ensure all assigned patients are available
    elif current_user["role"] == "doctor":
        pts = query("SELECT id, full_name, avatar_initials, role, `condition` FROM users WHERE doctor_id = %s AND role='patient' AND is_active=1", (user_id,))
        for p in pts:
            if p["id"] not in existing_ids:
                conv_list.append({
                    "user_id":        p["id"],
                    "name":           p["full_name"],
                    "avatar":         p["avatar_initials"] or "PT",
                    "role":           "patient",
                    "last_message":   f"Condition: {p.get('condition') or 'Monitored'}. Start discussion.",
                    "last_time":      None,
                    "unread_count":   0,
                    "last_sender_id": None,
                    "last_is_read":   False,
                })

    return jsonify(conv_list), 200


# ─────────────────────────────────────────────
# GET /messages/thread/<user_a>/<user_b>
# Returns the full conversation thread between two users
# ─────────────────────────────────────────────
@messages_bp.route("/thread/<int:a>/<int:b>", methods=["GET"])
def get_thread(a, b):
    # Mark messages sent TO user_a as read FIRST so returned list reflects is_read = 1
    execute(
        "UPDATE messages SET is_read = 1 WHERE sender_id = %s AND receiver_id = %s AND is_read = 0",
        (b, a)
    )
    rows = query(
        """SELECT * FROM messages
           WHERE (sender_id = %s AND receiver_id = %s)
              OR (sender_id = %s AND receiver_id = %s)
           ORDER BY sent_at ASC""",
        (a, b, b, a)
    )
    return jsonify([_fmt_msg(r) for r in rows]), 200


# ─────────────────────────────────────────────
# POST /messages
# Body: { sender_id, receiver_id, message }
# ─────────────────────────────────────────────
@messages_bp.route("", methods=["POST"])
@messages_bp.route("/send", methods=["POST"])
def send_message():
    data        = request.get_json(silent=True) or {}
    sender_id   = data.get("sender_id")
    receiver_id = data.get("receiver_id")
    message     = (data.get("message") or data.get("text") or "").strip()

    if not sender_id or not receiver_id or not message:
        return jsonify({"error": "sender_id, receiver_id and message are required"}), 400

    # Verify both users exist
    for uid in (sender_id, receiver_id):
        u = query("SELECT id FROM users WHERE id = %s", (uid,), one=True)
        if not u:
            return jsonify({"error": f"User {uid} not found"}), 404

    mid = execute(
        "INSERT INTO messages (sender_id, receiver_id, message) VALUES (%s,%s,%s)",
        (sender_id, receiver_id, message)
    )
    row = query("SELECT * FROM messages WHERE id = %s", (mid,), one=True)
    return jsonify({"message": "Sent", "chat_message": _fmt_msg(row)}), 201


# ─────────────────────────────────────────────
# GET /messages/unread-count/<user_id>
# ─────────────────────────────────────────────
@messages_bp.route("/unread-count/<int:user_id>", methods=["GET"])
def unread_count(user_id):
    row = query(
        "SELECT COUNT(*) AS cnt FROM messages WHERE receiver_id = %s AND is_read = 0",
        (user_id,), one=True
    )
    return jsonify({"unread": row["cnt"] if row else 0}), 200
