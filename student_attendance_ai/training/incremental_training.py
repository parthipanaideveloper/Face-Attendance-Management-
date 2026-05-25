import sys
import os
import glob
import numpy as np

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.embedding_service import EmbeddingService
from app.models.student_model import StudentModel

def average_embeddings(register_no):
    """
    Looks in datasets/students/<register_no>/ for ALL images,
    extracts encodings from all of them, and computes the average encoding 
    for higher accuracy recognition.
    """
    dataset_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'datasets', 'students', register_no)
    
    if not os.path.exists(dataset_dir):
        print(f"[ERROR] Directory not found: {dataset_dir}")
        return

    # Find all jpg and png images in the student's folder
    image_paths = glob.glob(os.path.join(dataset_dir, '*.jpg')) + glob.glob(os.path.join(dataset_dir, '*.png'))
    
    if not image_paths:
        print(f"[ERROR] No images found for {register_no} in {dataset_dir}")
        return

    print(f"[INFO] Found {len(image_paths)} images for {register_no}. Processing...")
    
    encodings_list = []
    for img_path in image_paths:
        enc = EmbeddingService.extract_encoding(img_path)
        if enc is not None:
            encodings_list.append(enc)
        else:
            print(f"[WARNING] No face detected in {img_path}")

    if not encodings_list:
        print("[ERROR] Could not extract any valid face encodings.")
        return

    # Compute the average encoding
    avg_encoding = np.mean(encodings_list, axis=0)
    print(f"[SUCCESS] Computed average embedding from {len(encodings_list)} faces.")

    # Save to model
    encodings, reg_nos, names = EmbeddingService.get_known_embeddings()
    
    students = StudentModel.get_all_students()
    student = next((s for s in students if s['register_no'] == register_no), None)
    name = student['name'] if student else "Unknown"

    if register_no in reg_nos:
        index = reg_nos.index(register_no)
        encodings[index] = avg_encoding
        names[index] = name
    else:
        encodings.append(avg_encoding)
        reg_nos.append(register_no)
        names.append(name)

    EmbeddingService.save_known_embeddings(encodings, reg_nos, names)
    print("[SUCCESS] Incremental training saved!")

if __name__ == '__main__':
    print("=== Incremental Training Tool ===")
    print("Use this tool to improve AI accuracy by averaging multiple photos of the same student.")
    print("Note: Place multiple images inside datasets/students/<register_no>/ first.")
    reg_no = input("Enter Register Number to perform incremental training: ")
    average_embeddings(reg_no)
