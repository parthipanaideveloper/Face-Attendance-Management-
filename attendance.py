import cv2
import face_recognition
import sqlite3
import os
import numpy as np
from datetime import datetime

def load_registered_students():
    conn = sqlite3.connect("attendance_system.db")
    cursor = conn.cursor()
    cursor.execute("SELECT register_no, name, image_path FROM students")
    students = cursor.fetchall()
    conn.close()

    known_face_encodings = []
    known_face_register_nos = []
    known_face_names = []

    print("[INFO] Loading registered faces...")
    for reg_no, name, img_path in students:
        if os.path.exists(img_path):
            image = face_recognition.load_image_file(img_path)
            # Ensure the image actually contains a face
            encodings = face_recognition.face_encodings(image)
            if encodings:
                known_face_encodings.append(encodings[0])
                known_face_register_nos.append(reg_no)
                known_face_names.append(name)
            else:
                print(f"[WARNING] No face found in {img_path}. Skipping student {name}.")
        else:
            print(f"[WARNING] Image path not found: {img_path}")

    return known_face_encodings, known_face_register_nos, known_face_names

def log_attendance(register_no, name):
    conn = sqlite3.connect("attendance_system.db")
    cursor = conn.cursor()

    now = datetime.now()
    current_date = now.strftime("%Y-%m-%d")
    current_time = now.strftime("%H:%M:%S")

    # Check if student already marked attendance today
    cursor.execute("SELECT * FROM attendance WHERE register_no=? AND date=?", (register_no, current_date))
    record = cursor.fetchone()

    if record is None:
        # First time seen today -> Mark In-Time
        cursor.execute('''
            INSERT INTO attendance (register_no, date, in_time, out_time, status)
            VALUES (?, ?, ?, ?, ?)
        ''', (register_no, current_date, current_time, current_time, 'Present'))
        conn.commit()
        print(f"[ATTENDANCE] Marked {name} (Reg No: {register_no}) PRESENT at {current_time} (IN-TIME)")
    else:
        # Already seen today -> Update Out-Time
        # We only update out_time so that the last time they are seen is their final out_time
        cursor.execute('''
            UPDATE attendance 
            SET out_time=?
            WHERE register_no=? AND date=?
        ''', (current_time, register_no, current_date))
        conn.commit()

    conn.close()

def main():
    known_face_encodings, known_face_register_nos, known_face_names = load_registered_students()

    if not known_face_encodings:
        print("[ERROR] No registered students found. Please run register.py first.")
        return

    print("\n[INFO] Starting Webcam for Attendance System...")
    print("[INFO] Press 'q' to quit.")

    cap = cv2.VideoCapture(0)

    # Initialize some variables
    face_locations = []
    face_encodings = []
    face_names = []
    process_this_frame = True

    while True:
        ret, frame = cap.read()
        if not ret:
            print("[ERROR] Failed to grab frame")
            break

        # Resize frame of video to 1/4 size for faster face recognition processing
        small_frame = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)

        # Convert the image from BGR color (which OpenCV uses) to RGB color (which face_recognition uses)
        # using deep copy to avoid memory mapping issues
        rgb_small_frame = np.ascontiguousarray(small_frame[:, :, ::-1])

        # Only process every other frame of video to save time
        if process_this_frame:
            # Find all the faces and face encodings in the current frame of video
            face_locations = face_recognition.face_locations(rgb_small_frame)
            face_encodings = face_recognition.face_encodings(rgb_small_frame, face_locations)

            face_names = []
            for face_encoding in face_encodings:
                # See if the face is a match for the known face(s)
                matches = face_recognition.compare_faces(known_face_encodings, face_encoding)
                name = "Unknown"
                register_no = None

                # Use the known face with the smallest distance to the new face
                face_distances = face_recognition.face_distance(known_face_encodings, face_encoding)
                if len(face_distances) > 0:
                    best_match_index = np.argmin(face_distances)
                    if matches[best_match_index]:
                        name = known_face_names[best_match_index]
                        register_no = known_face_register_nos[best_match_index]
                        
                        # Log attendance!
                        log_attendance(register_no, name)

                face_names.append(name)

        process_this_frame = not process_this_frame

        # Display the results
        for (top, right, bottom, left), name in zip(face_locations, face_names):
            # Scale back up face locations since the frame we detected in was scaled to 1/4 size
            top *= 4
            right *= 4
            bottom *= 4
            left *= 4

            # Draw a box around the face
            color = (0, 255, 0) if name != "Unknown" else (0, 0, 255)
            cv2.rectangle(frame, (left, top), (right, bottom), color, 2)

            # Draw a label with a name below the face
            cv2.rectangle(frame, (left, bottom - 35), (right, bottom), color, cv2.FILLED)
            font = cv2.FONT_HERSHEY_DUPLEX
            cv2.putText(frame, name, (left + 6, bottom - 6), font, 0.7, (255, 255, 255), 1)

        cv2.imshow('Live Attendance System', frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
