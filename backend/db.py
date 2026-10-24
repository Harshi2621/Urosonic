# db.py — PyMySQL connection helper

import os
import pymysql
import pymysql.cursors
from flask import g, current_app


def get_db():
    """Return the per-request DB connection, creating it if needed."""
    if "db" not in g:
        cfg = current_app.config
        kwargs = {
            "user": cfg["MYSQL_USER"],
            "password": cfg["MYSQL_PASSWORD"],
            "database": cfg["MYSQL_DB"],
            "cursorclass": pymysql.cursors.DictCursor,
            "charset": "utf8mb4",
            "autocommit": False,
        }

        socket_path = cfg.get("MYSQL_UNIX_SOCKET") or os.environ.get("MYSQL_UNIX_SOCKET")
        if socket_path and os.path.exists(socket_path):
            kwargs["unix_socket"] = socket_path
        else:
            kwargs["host"] = cfg["MYSQL_HOST"]
            kwargs["port"] = cfg["MYSQL_PORT"]

        try:
            g.db = pymysql.connect(**kwargs)
        except pymysql.err.OperationalError as e:
            # Fallback to standard macOS XAMPP unix socket if available
            xampp_sock = "/Applications/XAMPP/xamppfiles/var/mysql/mysql.sock"
            if "unix_socket" not in kwargs and os.path.exists(xampp_sock):
                try:
                    fallback_kwargs = dict(kwargs)
                    fallback_kwargs.pop("host", None)
                    fallback_kwargs.pop("port", None)
                    fallback_kwargs["unix_socket"] = xampp_sock
                    g.db = pymysql.connect(**fallback_kwargs)
                    return g.db
                except Exception:
                    pass
            raise e
    return g.db


def close_db(e=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def query(sql, args=(), one=False):
    """Execute a SELECT and return rows (or single row)."""
    db  = get_db()
    cur = db.cursor()
    cur.execute(sql, args)
    rv  = cur.fetchone() if one else cur.fetchall()
    cur.close()
    return rv


def execute(sql, args=()):
    """Execute INSERT / UPDATE / DELETE, commit and return lastrowid."""
    db  = get_db()
    cur = db.cursor()
    cur.execute(sql, args)
    db.commit()
    last_id = cur.lastrowid
    cur.close()
    return last_id


def init_app(app):
    app.teardown_appcontext(close_db)
