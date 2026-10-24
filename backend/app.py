# app.py — Main Flask application entry point

from flask import Flask, jsonify
from flask_cors import CORS
from config import Config
import db

# Blueprints
from routes.auth         import auth_bp
from routes.measurements import measurements_bp
from routes.fluid        import fluid_bp
from routes.messages     import messages_bp
from routes.feedback     import feedback_bp
from routes.stock        import stock_bp
from routes.surgery      import surgery_bp
from routes.followup     import followup_bp
from routes.profile      import profile_bp
from routes.ai_flow      import ai_flow_bp


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # ── CORS (allow requests from iOS simulator / device) ──
    CORS(app, resources={r"/*": {"origins": "*"}})

    # ── DB teardown ────────────────────────────────────────
    db.init_app(app)

    # ── Register blueprints ────────────────────────────────
    app.register_blueprint(auth_bp)
    app.register_blueprint(measurements_bp)
    app.register_blueprint(fluid_bp)
    app.register_blueprint(messages_bp)
    app.register_blueprint(messages_bp, name="chat_bp", url_prefix="/chat")
    app.register_blueprint(feedback_bp)
    app.register_blueprint(stock_bp)
    app.register_blueprint(surgery_bp)
    app.register_blueprint(followup_bp)
    app.register_blueprint(followup_bp, name="followups_alias_bp", url_prefix="/followups")
    app.register_blueprint(profile_bp)
    app.register_blueprint(ai_flow_bp)

    # ── Pre-load ML inference model at startup ──────────
    try:
        from ml_inference_service import MLInferenceService
        MLInferenceService.get_instance()
        app.logger.info("Acoustic ML model pre-loaded successfully.")
    except Exception as e:
        app.logger.warning("ML model could not be pre-loaded at startup: %s", str(e))

    # ── Health check ───────────────────────────────────────
    @app.route("/", methods=["GET"])
    def root():
        return jsonify({
            "message": "Urosonic API Server is running",
            "version": "1.0.0"
        }), 200

    @app.route("/health", methods=["GET"])
    def health():
        try:
            db.query("SELECT 1", one=True)
            db_status = "connected"
        except Exception as e:
            db_status = f"error: {str(e)}"

        try:
            from ml_inference_service import MLInferenceService
            svc = MLInferenceService.get_instance()
            ml_status = f"loaded (v{svc.metadata.get('model_version', '1.0.0')})" if svc.is_loaded else "unloaded"
        except Exception as e:
            ml_status = f"error: {str(e)}"

        return jsonify({
            "status":    "ok",
            "db":        db_status,
            "ml_model":  ml_status,
            "version":   "1.0.0",
            "app":       "Urosonic API",
        }), 200

    # ── Global error handlers ──────────────────────────────
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"error": "Endpoint not found"}), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return jsonify({"error": "Method not allowed"}), 405

    @app.errorhandler(500)
    def internal_error(e):
        return jsonify({"error": "Internal server error"}), 500

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(
        host="0.0.0.0",
        port=5001,
        debug=Config.DEBUG
    )
