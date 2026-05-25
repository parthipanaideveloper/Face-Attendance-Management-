import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.embedding_service import EmbeddingService
from app.models.student_model import StudentModel

def update_single_student(register_no):
    """Updates the embedding for a single student without retraining the entire dataset."""
    students = StudentModel.get_all_students()
    student = next((s for s in students if s['register_no'] == register_no), None)
    
    if not student:
        print(f"[ERROR] Student with Register No {register_no} not found in database.")
        return

    print(f"[INFO] Updating embedding for {student['name']} ({register_no})...")
    
    new_encoding = EmbeddingService.extract_encoding(student['image_path'])
    if new_encoding is None:
        print("[ERROR] Could not extract face encoding from image. Please check the image quality.")
        return

    # Load existing cache
    encodings, reg_nos, names = EmbeddingService.get_known_embeddings()
    
    # Update or append
    if register_no in reg_nos:
        index = reg_nos.index(register_no)
        encodings[index] = new_encoding
        names[index] = student['name']
        print("[INFO] Existing embedding successfully updated.")
    else:
        encodings.append(new_encoding)
        reg_nos.append(register_no)
        names.append(student['name'])
        print("[INFO] New embedding successfully added.")

    # Save cache
    EmbeddingService.save_known_embeddings(encodings, reg_nos, names)
    print("[SUCCESS] Update Complete!")

if __name__ == '__main__':
    print("=== Update Single Embedding ===")
    reg_no = input("Enter Register Number to update: ")
    update_single_student(reg_no)
