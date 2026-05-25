import os

dirs = [
    "student_attendance_ai/app/static/css",
    "student_attendance_ai/app/static/js",
    "student_attendance_ai/app/static/images",
    "student_attendance_ai/app/static/uploads",
    "student_attendance_ai/app/templates",
    "student_attendance_ai/app/routes",
    "student_attendance_ai/app/models",
    "student_attendance_ai/app/services",
    "student_attendance_ai/app/database",
    "student_attendance_ai/app/utils",
    "student_attendance_ai/datasets/students",
    "student_attendance_ai/datasets/captured_frames",
    "student_attendance_ai/embeddings",
    "student_attendance_ai/training",
    "student_attendance_ai/attendance_logs",
    "student_attendance_ai/tests"
]

files = [
    "student_attendance_ai/app/templates/index.html",
    "student_attendance_ai/app/templates/register.html",
    "student_attendance_ai/app/templates/attendance.html",
    "student_attendance_ai/app/templates/dashboard.html",
    "student_attendance_ai/app/templates/reports.html",
    "student_attendance_ai/app/routes/__init__.py",
    "student_attendance_ai/app/routes/attendance_routes.py",
    "student_attendance_ai/app/routes/student_routes.py",
    "student_attendance_ai/app/routes/auth_routes.py",
    "student_attendance_ai/app/models/__init__.py",
    "student_attendance_ai/app/models/student_model.py",
    "student_attendance_ai/app/models/attendance_model.py",
    "student_attendance_ai/app/models/embedding_model.py",
    "student_attendance_ai/app/services/__init__.py",
    "student_attendance_ai/app/services/face_detection.py",
    "student_attendance_ai/app/services/face_recognition_service.py",
    "student_attendance_ai/app/services/embedding_service.py",
    "student_attendance_ai/app/services/attendance_service.py",
    "student_attendance_ai/app/services/auto_training_service.py",
    "student_attendance_ai/app/database/__init__.py",
    "student_attendance_ai/app/database/db_config.py",
    "student_attendance_ai/app/utils/__init__.py",
    "student_attendance_ai/app/utils/image_utils.py",
    "student_attendance_ai/app/utils/camera_utils.py",
    "student_attendance_ai/app/utils/logger.py",
    "student_attendance_ai/app/utils/helpers.py",
    "student_attendance_ai/app/main.py",
    "student_attendance_ai/training/train_model.py",
    "student_attendance_ai/training/update_embeddings.py",
    "student_attendance_ai/training/incremental_training.py",
    "student_attendance_ai/requirements.txt",
    "student_attendance_ai/README.md",
    "student_attendance_ai/run.py"
]

for d in dirs:
    os.makedirs(d, exist_ok=True)

for f in files:
    with open(f, 'w') as file:
        pass

print("Directory structure created successfully.")
