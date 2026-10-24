import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    # ── Flask ──────────────────────────────────────────────
    SECRET_KEY = os.environ.get("SECRET_KEY", "urosonic-secret-key-change-in-prod")
    DEBUG      = os.environ.get("DEBUG", "True") == "True"

    # ── XAMPP MySQL ────────────────────────────────────────
    MYSQL_HOST     = os.environ.get("MYSQL_HOST",     "127.0.0.1")
    MYSQL_PORT     = int(os.environ.get("MYSQL_PORT", "3306"))
    MYSQL_USER     = os.environ.get("MYSQL_USER",     "root")
    MYSQL_PASSWORD = os.environ.get("MYSQL_PASSWORD", "")        # XAMPP default = empty
    MYSQL_DB       = os.environ.get("MYSQL_DB",       "urosonic")

    # ── bcrypt ─────────────────────────────────────────────
    BCRYPT_LOG_ROUNDS = 12

    # ── CORS ───────────────────────────────────────────────
    CORS_ORIGINS = "*"   # tighten in production
