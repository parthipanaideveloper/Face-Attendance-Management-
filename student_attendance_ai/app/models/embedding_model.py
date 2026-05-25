import pickle
import os

class EmbeddingModel:
    # Path to store the serialized embeddings (pkl file)
    EMBEDDING_FILE = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 
        'embeddings', 
        'face_embeddings.pkl'
    )

    @staticmethod
    def save_embeddings(encodings, register_nos, names):
        """Saves the calculated face encodings to a file for faster loading."""
        data = {
            "encodings": encodings,
            "register_nos": register_nos,
            "names": names
        }
        
        # Ensure the embeddings directory exists
        os.makedirs(os.path.dirname(EmbeddingModel.EMBEDDING_FILE), exist_ok=True)
        
        with open(EmbeddingModel.EMBEDDING_FILE, 'wb') as f:
            pickle.dump(data, f)
        print(f"[INFO] Embeddings successfully saved to {EmbeddingModel.EMBEDDING_FILE}")

    @staticmethod
    def load_embeddings():
        """Loads the saved face encodings from the file."""
        if not os.path.exists(EmbeddingModel.EMBEDDING_FILE):
            return [], [], []
            
        with open(EmbeddingModel.EMBEDDING_FILE, 'rb') as f:
            data = pickle.load(f)
            
        print(f"[INFO] Loaded {len(data.get('encodings', []))} embeddings from storage.")
        return data.get("encodings", []), data.get("register_nos", []), data.get("names", [])
