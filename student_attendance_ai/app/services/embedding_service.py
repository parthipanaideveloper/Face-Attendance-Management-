import face_recognition
import os
from app.models.embedding_model import EmbeddingModel

class EmbeddingService:
    @staticmethod
    def extract_encoding(image_path):
        """Extracts the face encoding (math array) from a given image path."""
        if not os.path.exists(image_path):
            return None
        
        try:
            from PIL import Image, ImageOps
            import numpy as np
            
            # Load image and fix Android EXIF rotation
            pil_img = Image.open(image_path)
            pil_img = ImageOps.exif_transpose(pil_img)
            pil_img = pil_img.convert('RGB')
            image = np.array(pil_img)
            
            encodings = face_recognition.face_encodings(image)
            
            if encodings:
                return encodings[0]
        except Exception as e:
            print(f"[ERROR] Extracting encoding: {e}")
        return None

    @staticmethod
    def get_known_embeddings():
        """Loads cached embeddings from the Model."""
        return EmbeddingModel.load_embeddings()

    @staticmethod
    def save_known_embeddings(encodings, register_nos, names):
        """Saves embeddings to the Model cache."""
        EmbeddingModel.save_embeddings(encodings, register_nos, names)
