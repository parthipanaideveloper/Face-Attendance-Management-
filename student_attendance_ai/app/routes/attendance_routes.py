from flask import Blueprint, render_template, Response, request, redirect, url_for, jsonify
from app.services.face_recognition_service import FaceRecognitionService
from app.services.embedding_service import EmbeddingService
from app.services.face_detection import FaceDetectionService
from app.models.attendance_model import AttendanceModel
from app.models.student_model import StudentModel
import face_recognition
import numpy as np
import base64
import cv2
import os

attendance_bp = Blueprint('attendance_bp', __name__)

# Global service instance to avoid reloading encodings on every request
fr_service = None

@attendance_bp.route('/')
def index():
    return render_template('index.html')

@attendance_bp.route('/attendance')
def attendance():
    return render_template('attendance.html')

@attendance_bp.route('/status')
def status():
    """Returns true if the AI currently sees a face on the webcam feed."""
    global fr_service
    is_detected = fr_service.is_face_detected if fr_service else False
    return jsonify({"face_detected": is_detected})

@attendance_bp.route('/reports', methods=['GET'])
def reports():
    from datetime import datetime
    selected_date = request.args.get('date', datetime.now().strftime("%Y-%m-%d"))
    records = AttendanceModel.get_attendance_by_date(selected_date)
    return render_template('reports.html', records=records, selected_date=selected_date)

@attendance_bp.route('/video_feed')
def video_feed():
    global fr_service
    if fr_service is None:
        fr_service = FaceRecognitionService()
    return Response(fr_service.generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@attendance_bp.route('/dashboard')
def dashboard():
    records = AttendanceModel.get_todays_attendance()
    analytics = AttendanceModel.get_dashboard_analytics()
    return render_template('dashboard.html', records=records, analytics=analytics)

@attendance_bp.route('/api/mobile_scan', methods=['POST'])
def mobile_scan():
    """API for the Flutter app to send camera frames for face recognition."""
    if 'image' not in request.json:
        return jsonify({"success": False, "message": "No image provided"}), 400
        
    base64_data = request.json['image']
    try:
        from PIL import Image, ImageOps
        import io
        image_data = base64.b64decode(base64_data)
        pil_img = Image.open(io.BytesIO(image_data))
        pil_img = ImageOps.exif_transpose(pil_img)
        pil_img = pil_img.convert('RGB')
        rgb_frame = np.array(pil_img)
    except Exception as e:
        return jsonify({"success": False, "message": f"Invalid image: {e}"}), 400

    face_locations = FaceDetectionService.detect_faces(rgb_frame)
    
    if not face_locations:
        return jsonify({"success": False, "message": "No face detected"}), 200
        
    face_encodings = face_recognition.face_encodings(rgb_frame, face_locations)
    
    # Load cached embeddings
    encodings, reg_nos, names = EmbeddingService.get_known_embeddings()
    
    if not encodings:
        return jsonify({"success": False, "message": "No students registered"}), 200
        
    # Check the first face found
    matches = face_recognition.compare_faces(encodings, face_encodings[0])
    face_distances = face_recognition.face_distance(encodings, face_encodings[0])
    
    if len(face_distances) > 0:
        best_match_index = np.argmin(face_distances)
        if matches[best_match_index]:
            name = names[best_match_index]
            reg_no = reg_nos[best_match_index]
            
            # Log attendance and get full details for the Flutter popup
            student_data = AttendanceModel.log_attendance_and_get_details(reg_no, name)
            
            return jsonify({
                "success": True,
                "message": "Student recognized",
                "data": student_data
            }), 200
            
    return jsonify({"success": False, "message": "Face not recognized"}), 200
            
@attendance_bp.route('/api/dashboard_data', methods=['GET'])
def api_dashboard_data():
    """API for the Flutter app to get dashboard attendance logs."""
    date = request.args.get('date')
    if date:
        records = AttendanceModel.get_attendance_by_date(date)
    else:
        records = AttendanceModel.get_todays_attendance()
    analytics = AttendanceModel.get_dashboard_analytics()
    return jsonify({"success": True, "data": records, "analytics": analytics})

@attendance_bp.route('/reports/export', methods=['GET'])
def export_reports():
    """Generates an Excel-compatible CSV report of all attendance logs for a specific month."""
    from datetime import datetime
    import csv
    import io
    
    selected_month = request.args.get('month', datetime.now().strftime("%Y-%m"))
    records = AttendanceModel.get_attendance_by_month(selected_month)
    
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Column Headers for Excel
    writer.writerow(['Date', 'Day', 'Student Name', 'Register No', 'Department', 'In-Time', 'Out-Time', 'Status'])
    
    for r in records:
        try:
            date_obj = datetime.strptime(r['date'], "%Y-%m-%d")
            day_of_week = date_obj.strftime("%A")
        except Exception:
            day_of_week = "Unknown"
            
        writer.writerow([
            r['date'],
            day_of_week,
            r['name'],
            r['register_no'],
            r['dept'],
            r['in_time'],
            r['out_time'] or '--:--:--',
            r['status']
        ])
        
    output.seek(0)
    filename = f"attendance_report_{selected_month}.csv"
    
    return Response(
        output.getvalue(),
        mimetype="text/csv",
        headers={"Content-disposition": f"attachment; filename={filename}"}
    )
