import os
import glob
import numpy as np
from app.models.student_model import StudentModel
from app.services.embedding_service import EmbeddingService

class AutoTrainingService:
    @staticmethod
    def retrain_embeddings():
        """
        Scans all registered students in the DB, forces recalculation of 
        their embeddings from stored images, and updates the .pkl cache.
        Supports multi-capture by averaging all images in their folder.
        """
        print("[INFO] Starting Auto-Training Service (Multi-Capture)...")
        students = StudentModel.get_all_students()
        
        encodings = []
        register_nos = []
        names = []

        for student in students:
            reg_no = student['register_no']
            dataset_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'datasets', 'students', reg_no)
            
            image_paths = glob.glob(os.path.join(dataset_dir, '*.jpg')) + glob.glob(os.path.join(dataset_dir, '*.png'))
            if not image_paths and os.path.exists(student['image_path']):
                image_paths = [student['image_path']]
                
            if not image_paths:
                print(f"[WARNING] No images found for {student['name']}")
                continue
                
            encodings_list = []
            for img_path in image_paths:
                enc = EmbeddingService.extract_encoding(img_path)
                if enc is not None:
                    encodings_list.append(enc)
            
            if encodings_list:
                avg_encoding = np.mean(encodings_list, axis=0)
                encodings.append(avg_encoding)
                register_nos.append(reg_no)
                names.append(student['name'])
            else:
                print(f"[WARNING] Could not extract any valid face for {student['name']}")

        # Save to cache
        EmbeddingService.save_known_embeddings(encodings, register_nos, names)
        print(f"[SUCCESS] Auto-Training Complete. Trained {len(encodings)} faces.")
        
        return encodings, register_nos, names
