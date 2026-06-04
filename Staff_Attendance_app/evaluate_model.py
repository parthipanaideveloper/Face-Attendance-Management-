import os
import glob
import numpy as np
import cv2
import pandas as pd
import mediapipe as mp
import tensorflow as tf

# Configuration
DATASET_PATH = r"D:\Face_Attendance_SMS\DATASET ST MARRYS"
MODEL_PATH = "assets/mobilefacenet.tflite"
THRESHOLD = 0.70

# Initialize MediaPipe Face Detection (matches ML Kit Face Detection)
mp_face_detection = mp.solutions.face_detection
face_detection = mp_face_detection.FaceDetection(model_selection=1, min_detection_confidence=0.5)

def load_tflite_model(model_path):
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    return interpreter, input_details, output_details

def get_face_embedding(image_path, interpreter, input_details, output_details):
    img = cv2.imread(image_path)
    if img is None:
        return None

    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    results = face_detection.process(img_rgb)

    if not results.detections:
        return None  # No face found

    # Get the highest confidence face bounding box
    detection = max(results.detections, key=lambda det: det.score[0])
    bboxC = detection.location_data.relative_bounding_box
    ih, iw, _ = img.shape
    x, y, w, h = int(bboxC.xmin * iw), int(bboxC.ymin * ih), int(bboxC.width * iw), int(bboxC.height * ih)

    # Padding and bounds checking
    x, y = max(0, x), max(0, y)
    x2, y2 = min(iw, x + w), min(ih, y + h)
    
    face_img = img_rgb[y:y2, x:x2]
    if face_img.size == 0:
        return None

    # Preprocess for MobileFaceNet
    face_resized = cv2.resize(face_img, (112, 112))
    face_float = face_resized.astype(np.float32)
    face_normalized = (face_float - 127.5) / 128.0  # Normalize to [-1, 1]
    input_data = np.expand_dims(face_normalized, axis=0)

    # Run inference
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    embedding = interpreter.get_tensor(output_details[0]['index'])[0]

    # Normalize embedding vector
    embedding = embedding / np.linalg.norm(embedding)
    return embedding

def euclidean_distance(emb1, emb2):
    return np.linalg.norm(emb1 - emb2)

def main():
    print("Loading MobileFaceNet model...")
    interpreter, input_details, output_details = load_tflite_model(MODEL_PATH)
    
    print(f"Scanning dataset at {DATASET_PATH}...")
    people = [d for d in os.listdir(DATASET_PATH) if os.path.isdir(os.path.join(DATASET_PATH, d))]
    
    database = {}
    test_images = []
    
    print(f"Found {len(people)} people. Extracting embeddings...")
    for person in people:
        person_dir = os.path.join(DATASET_PATH, person)
        images = glob.glob(os.path.join(person_dir, "*.*"))
        
        if not images:
            continue
            
        # Use first image as the 'Registered' profile embedding
        reg_emb = get_face_embedding(images[0], interpreter, input_details, output_details)
        if reg_emb is not None:
            database[person] = reg_emb
        else:
            print(f"Warning: No face detected in {images[0]} for {person}. Skipping registration.")
            continue
            
        # Save remaining images for testing
        for img_path in images[1:]:
            test_images.append({'person': person, 'path': img_path})
            
    print(f"Successfully registered {len(database)} people.")
    print(f"Testing {len(test_images)} images against the database...")
    
    correct = 0
    false_positives = 0
    false_negatives = 0
    confusions = []
    
    for item in test_images:
        true_person = item['person']
        img_path = item['path']
        
        emb = get_face_embedding(img_path, interpreter, input_details, output_details)
        if emb is None:
            print(f"No face detected in test image: {img_path}")
            continue
            
        min_dist = float('inf')
        predicted_person = None
        
        for db_person, db_emb in database.items():
            dist = euclidean_distance(emb, db_emb)
            if dist < min_dist:
                min_dist = dist
                predicted_person = db_person
                
        if min_dist < THRESHOLD:
            if predicted_person == true_person:
                correct += 1
            else:
                false_positives += 1
                confusions.append((true_person, predicted_person, min_dist, img_path))
        else:
            false_negatives += 1
            
    total_tested = correct + false_positives + false_negatives
    accuracy = (correct / total_tested) * 100 if total_tested > 0 else 0
    
    print("\n" + "="*40)
    print("      MODEL EVALUATION REPORT      ")
    print("="*40)
    print(f"Total Images Tested: {total_tested}")
    print(f"Correctly Identified: {correct}")
    print(f"False Negatives (Rejected): {false_negatives}")
    print(f"False Positives (Confused): {false_positives}")
    print(f"Accuracy: {accuracy:.2f}%")
    print("="*40)
    
    if confusions:
        print("\nConfusions Details (True Person -> Predicted Person):")
        for conf in confusions:
            print(f"Expected: {conf[0]:<20} | Predicted as: {conf[1]:<20} | Distance: {conf[2]:.3f} | File: {os.path.basename(conf[3])}")
            
if __name__ == "__main__":
    main()
