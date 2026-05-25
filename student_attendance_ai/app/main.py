from flask import Flask
from app.database.db_config import init_db
from app.routes.attendance_routes import attendance_bp
from app.routes.student_routes import student_bp
from app.routes.auth_routes import auth_bp

def create_app():
    app = Flask(__name__)
    app.secret_key = 'super_secret_attendance_key' # Needed for Flask sessions
    
    # Initialize DB
    init_db()
    
    # Register Blueprints
    app.register_blueprint(attendance_bp)
    app.register_blueprint(student_bp)
    app.register_blueprint(auth_bp)
    
    return app
