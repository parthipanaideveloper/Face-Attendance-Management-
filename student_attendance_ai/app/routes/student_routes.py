from flask import Blueprint, render_template, request, redirect, url_for, jsonify
from app.models.student_model import StudentModel
from app.services.auto_training_service import AutoTrainingService
import os
import base64
import json

student_bp = Blueprint('student_bp', __name__)

@student_bp.route('/register', methods=['GET', 'POST'])
def register():
    """Route for registering a new student into the system."""
    if request.method == 'POST':
        name = request.form['name']
        reg_no = request.form['register_no']
        dept = request.form.get('dept', 'Unknown')
        gender = request.form.get('gender', 'Male')
        
        # Create dataset directory for student
        BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        dataset_dir = os.path.join(BASE_DIR, 'datasets', 'students', reg_no)
        os.makedirs(dataset_dir, exist_ok=True)
        image_path = os.path.join(dataset_dir, f"{reg_no}.jpg") # fallback path

        # 1. Check if they used the Live Webcam (Multi-Capture)
        if 'webcam_image' in request.form and request.form['webcam_image']:
            try:
                # Load JSON array
                base64_images = json.loads(request.form['webcam_image'])
                for i, b64_str in enumerate(base64_images):
                    base64_data = b64_str.split(',')[1]
                    image_data = base64.b64decode(base64_data)
                    # Save as regNo_0.jpg, regNo_1.jpg, etc.
                    with open(os.path.join(dataset_dir, f"{reg_no}_{i}.jpg"), 'wb') as f:
                        f.write(image_data)
            except json.JSONDecodeError:
                # Fallback if it's a single string instead of array
                base64_data = request.form['webcam_image'].split(',')[1]
                image_data = base64.b64decode(base64_data)
                with open(image_path, 'wb') as f:
                    f.write(image_data)
                
        # 2. Check if they uploaded a file instead
        elif 'image' in request.files and request.files['image'].filename != '':
            file = request.files['image']
            file.save(image_path)
            
        else:
            return "No image provided. Please capture or upload a photo.", 400
        
        # Save to DB
        StudentModel.add_student(reg_no, name, dept, gender, image_path)
        
        # We must trigger retraining so the new face is added to the AI's memory
        print(f"[INFO] New student '{name}' registered. Triggering Auto-Trainer...")
        AutoTrainingService.retrain_embeddings()
            
        return redirect(url_for('attendance_bp.index'))
        
    return render_template('register.html')

@student_bp.route('/api/mobile_register', methods=['POST'])
def mobile_register():
    """API for the Flutter app to register a student remotely."""
    try:
        data = request.json
        name = data.get('name')
        reg_no = data.get('register_no')
        dept = data.get('dept', 'Unknown')
        gender = data.get('gender', 'Male')
        base64_images = data.get('images', [])
        
        if not name or not reg_no or not base64_images:
            return jsonify({"success": False, "message": "Missing fields"}), 400
            
        BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        dataset_dir = os.path.join(BASE_DIR, 'datasets', 'students', reg_no)
        os.makedirs(dataset_dir, exist_ok=True)
        
        for i, b64_str in enumerate(base64_images):
            # Flutter sends raw base64 (no data:image/jpeg;base64, prefix)
            image_data = base64.b64decode(b64_str)
            with open(os.path.join(dataset_dir, f"{reg_no}_{i}.jpg"), 'wb') as f:
                f.write(image_data)
                
        # Save to DB (pass the first image as the main reference)
        image_path = os.path.join(dataset_dir, f"{reg_no}_0.jpg")
        success, msg = StudentModel.add_student(reg_no, name, dept, gender, image_path)
        
        if success:
            AutoTrainingService.retrain_embeddings()
            return jsonify({"success": True, "message": "Student registered successfully!"}), 200
        else:
            return jsonify({"success": False, "message": msg}), 400
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
