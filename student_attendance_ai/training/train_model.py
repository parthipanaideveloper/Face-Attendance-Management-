import sys
import os

# Add parent directory to sys path so we can import 'app' modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.auto_training_service import AutoTrainingService

if __name__ == '__main__':
    print("="*50)
    print("Initiating Full Dataset Retraining...")
    print("="*50)
    
    # Triggers the AutoTrainingService to scan the entire DB
    # and recalculate/overwrite the embeddings cache.
    AutoTrainingService.retrain_embeddings()
    
    print("="*50)
    print("Training Complete!")
