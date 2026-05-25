import cv2
import sqlite3
import os

def register_student():
    name = input("Enter Student Name: ")
    register_no = input("Enter Register Number: ")

    # Create students directory if it doesn't exist
    if not os.path.exists("students"):
        os.makedirs("students")

    image_path = f"students/{register_no}.jpg"

    print("\n[INFO] Starting Webcam for Registration...")
    print("[INFO] Press 's' to capture and save the image. Press 'q' to quit.")

    cap = cv2.VideoCapture(0)

    while True:
        ret, frame = cap.read()
        if not ret:
            print("[ERROR] Failed to grab frame")
            break

        cv2.imshow("Registration - Press 's' to save, 'q' to quit", frame)

        key = cv2.waitKey(1) & 0xFF
        if key == ord('s'):
            # Save the image
            cv2.imwrite(image_path, frame)
            print(f"[SUCCESS] Image saved to {image_path}")
            break
        elif key == ord('q'):
            print("[INFO] Registration Cancelled.")
            cap.release()
            cv2.destroyAllWindows()
            return

    cap.release()
    cv2.destroyAllWindows()

    # Save details to database
    try:
        conn = sqlite3.connect("attendance_system.db")
        cursor = conn.cursor()
        cursor.execute("INSERT INTO students (register_no, name, image_path) VALUES (?, ?, ?)", 
                       (register_no, name, image_path))
        conn.commit()
        conn.close()
        print(f"\n[SUCCESS] Student '{name}' registered successfully!")
    except sqlite3.IntegrityError:
        print(f"\n[ERROR] A student with Register Number {register_no} is already registered.")

if __name__ == "__main__":
    register_student()
