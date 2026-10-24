# routes/auth.py — Login, Register, Forgot Password

from flask import Blueprint, request, jsonify
import bcrypt
import secrets
from datetime import datetime, timedelta
from db import query, execute

auth_bp = Blueprint("auth", __name__, url_prefix="/auth")


# ─────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────
def _user_payload(u):
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
        "license_number": u.get("license_number"),
        "specialization": u.get("specialization"),
        "doctor_id":      u.get("doctor_id"),
    }


# ─────────────────────────────────────────────
# POST /auth/register
# Body: { full_name, email, phone, password, role,
#         license_number?, specialization? }
# ─────────────────────────────────────────────
@auth_bp.route("/register", methods=["POST"])
def register():
    data = request.get_json(silent=True) or {}
    full_name = data.get("full_name", "").strip()
    email     = data.get("email",     "").strip().lower()
    phone     = data.get("phone",     "").strip()
    password  = data.get("password",  "")
    role      = data.get("role",      "patient").lower()

    if not full_name or not email or not password:
        return jsonify({"error": "full_name, email and password are required"}), 400

    if role not in ("patient", "doctor"):
        return jsonify({"error": "role must be 'patient' or 'doctor'"}), 400

    # Check duplicate
    existing = query("SELECT id FROM users WHERE email = %s", (email,), one=True)
    if existing:
        return jsonify({"error": "Email already registered"}), 409

    # Avatar initials from name
    parts    = full_name.split()
    initials = "".join(p[0].upper() for p in parts[:2])

    if role == "doctor":
        license_num = data.get("license_number", "")
        spec        = data.get("specialization", "Urology")
        user_id = execute(
            """INSERT INTO users
               (full_name, email, phone, password_hash, role,
                license_number, specialization, avatar_initials)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
            (full_name, email, phone, password,
             "doctor", license_num, spec, initials)
        )
    else:
        age       = data.get("age")
        gender    = data.get("gender", "")
        condition = data.get("condition", "")
        doctor_id = data.get("doctor_id")
        if doctor_id == "" or doctor_id == 0 or doctor_id == "0":
            doctor_id = None

        if not doctor_id:
            default_doc = query("SELECT id FROM users WHERE role = 'doctor' AND is_active = 1 ORDER BY id ASC LIMIT 1", one=True)
            if default_doc:
                doctor_id = default_doc["id"]

        user_id = execute(
            """INSERT INTO users
               (full_name, email, phone, password_hash, role,
                age, gender, `condition`, doctor_id, avatar_initials)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
            (full_name, email, phone, password,
             "patient", age, gender, condition, doctor_id, initials)
        )


    user = query("SELECT * FROM users WHERE id = %s", (user_id,), one=True)
    return jsonify({"message": "Registration successful", "user": _user_payload(user)}), 201


# ─────────────────────────────────────────────
# POST /auth/login
# Body: { email, password, role }
# ─────────────────────────────────────────────
@auth_bp.route("/login", methods=["POST"])
def login():
    data     = request.get_json(silent=True) or {}
    email    = data.get("email",    "").strip().lower()
    password = data.get("password", "")
    role     = data.get("role",     "").lower()

    if not email or not password:
        return jsonify({"error": "email and password are required"}), 400

    user = query("SELECT * FROM users WHERE email = %s AND is_active = 1", (email,), one=True)
    if not user:
        return jsonify({"error": "Invalid credentials"}), 401

    if role and user["role"] != role:
        return jsonify({"error": f"This account is registered as '{user['role']}'"}), 403

    stored_pw = user.get("password_hash", "")
    is_valid = (stored_pw == password)
    if not is_valid and stored_pw.startswith(("$2a$", "$2b$", "$2y$")):
        try:
            is_valid = bcrypt.checkpw(password.encode("utf-8"), stored_pw.encode("utf-8"))
        except Exception:
            is_valid = False

    if not is_valid:
        return jsonify({"error": "Invalid credentials"}), 401

    return jsonify({"message": "Login successful", "user": _user_payload(user)}), 200


# ─────────────────────────────────────────────
# POST /auth/forgot-password
# Body: { email }
# ─────────────────────────────────────────────
@auth_bp.route("/forgot-password", methods=["POST"])
def forgot_password():
    data  = request.get_json(silent=True) or {}
    email = data.get("email", "").strip().lower()
    if not email:
        return jsonify({"error": "email is required"}), 400

    user = query("SELECT id FROM users WHERE email = %s", (email,), one=True)
    # Always return 200 to avoid user enumeration
    if not user:
        return jsonify({"message": "If that email exists, a reset link has been sent"}), 200

    token      = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=1)
    execute(
        "INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES (%s,%s,%s)",
        (user["id"], token, expires_at)
    )
    # In production: send email with token link
    # For now, return the token directly for development
    return jsonify({
        "message": "Reset token generated (send via email in production)",
        "reset_token": token,   # ← Remove this line in production
        "expires_at": expires_at.isoformat()
    }), 200


# ─────────────────────────────────────────────
# POST /auth/reset-password
# Body: { token, new_password }
# ─────────────────────────────────────────────
@auth_bp.route("/reset-password", methods=["POST"])
def reset_password():
    data         = request.get_json(silent=True) or {}
    token        = data.get("token", "")
    new_password = data.get("new_password", "")

    if not token or not new_password:
        return jsonify({"error": "token and new_password are required"}), 400

    rec = query(
        "SELECT * FROM password_reset_tokens WHERE token = %s AND used = 0",
        (token,), one=True
    )
    if not rec:
        return jsonify({"error": "Invalid or expired token"}), 400

    if datetime.utcnow() > rec["expires_at"]:
        return jsonify({"error": "Token has expired"}), 400

    execute("UPDATE users SET password_hash = %s WHERE id = %s",
            (new_password, rec["user_id"]))
    execute("UPDATE password_reset_tokens SET used = 1 WHERE id = %s", (rec["id"],))

    return jsonify({"message": "Password reset successful"}), 200
