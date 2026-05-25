import cv2
import face_recognition
import numpy as np
from app.models.student_model import StudentModel
from app.services.face_detection import FaceDetectionService
from app.services.embedding_service import EmbeddingService
from app.services.attendance_service import AttendanceService
from app.services.auto_training_service import AutoTrainingService

class FaceRecognitionService:
    def __init__(self):
        self.known_face_encodings = []
        self.known_face_register_nos = []
        self.known_face_names = []
        self.is_face_detected = False
        self.load_encodings()

    def load_encodings(self):
        # Use Embedding Service to get cached data
        encodings, reg_nos, names = EmbeddingService.get_known_embeddings()
        students = StudentModel.get_all_students()
        
        # Check if cache is out of date (i.e. new students were added)
        if len(encodings) == len(students) and len(students) > 0:
            print("[INFO] Embeddings are up to date.")
            self.known_face_encodings = encodings
            self.known_face_register_nos = reg_nos
            self.known_face_names = names
            return

        print(f"[INFO] Cache miss or new students detected. Triggering Auto-Trainer...")
        # Use AutoTraining Service to rebuild the cache
        encs, r_nos, nms = AutoTrainingService.retrain_embeddings()
        self.known_face_encodings = encs
        self.known_face_register_nos = r_nos
        self.known_face_names = nms

    def generate_frames(self):
        cap = cv2.VideoCapture(0)
        process_this_frame = True

        while True:
            success, frame = cap.read()
            if not success:
                break
            
            small_frame = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)
            rgb_small_frame = np.ascontiguousarray(small_frame[:, :, ::-1])

            if process_this_frame:
                # Use FaceDetectionService to locate faces
                face_locations = FaceDetectionService.detect_faces(rgb_small_frame)
                
                # Update state so the frontend knows if a face is currently in view
                self.is_face_detected = len(face_locations) > 0
                
                # We still use face_recognition directly here for live speed, 
                # but it could be moved to EmbeddingService if desired.
                face_encodings = face_recognition.face_encodings(rgb_small_frame, face_locations)

                face_names = []
                for face_encoding in face_encodings:
                    matches = face_recognition.compare_faces(self.known_face_encodings, face_encoding)
                    name = "Unknown"

                    if len(self.known_face_encodings) > 0:
                        face_distances = face_recognition.face_distance(self.known_face_encodings, face_encoding)
                        if len(face_distances) > 0:
                            best_match_index = np.argmin(face_distances)
                            if matches[best_match_index]:
                                name = self.known_face_names[best_match_index]
                                register_no = self.known_face_register_nos[best_match_index]
                                
                                # Use AttendanceService to handle the business logic
                                AttendanceService.process_attendance(register_no, name)

                    face_names.append(name)

            process_this_frame = not process_this_frame

            # Draw boxes
            for (top, right, bottom, left), name in zip(face_locations, face_names):
                top *= 4
                right *= 4
                bottom *= 4
                left *= 4

                color = (0, 255, 0) if name != "Unknown" else (0, 0, 255)
                cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
                cv2.rectangle(frame, (left, bottom - 35), (right, bottom), color, cv2.FILLED)
                font = cv2.FONT_HERSHEY_DUPLEX
                cv2.putText(frame, name, (left + 6, bottom - 6), font, 0.7, (255, 255, 255), 1)

            ret, buffer = cv2.imencode('.jpg', frame)
            frame_bytes = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

        cap.release()
