import sqlite3
from datetime import datetime
from sms_service import send_sms

def notify_absentees():
    conn = sqlite3.connect("attendance_system.db")
    cursor = conn.cursor()

    now = datetime.now()
    current_date = now.strftime("%Y-%m-%d")

    # Get all registered students
    cursor.execute("SELECT register_no, name, phone_number FROM students")
    all_students = cursor.fetchall()

    # Get all students who attended today
    cursor.execute("SELECT register_no FROM attendance WHERE date=?", (current_date,))
    attended_today = set(row[0] for row in cursor.fetchall())

    absentees = []
    
    for reg_no, name, phone in all_students:
        if reg_no not in attended_today:
            absentees.append((name, phone))

    if not absentees:
        print(f"[INFO] No absentees for {current_date}. Everyone is present!")
    else:
        print(f"[INFO] Found {len(absentees)} absentees. Sending SMS notifications...")
        for name, phone in absentees:
            message = f"Dear {name}, you have been marked ABSENT for {current_date}."
            success = send_sms(phone, message)
            if success:
                print(f"[SUCCESS] Absent SMS sent to {name}.")
            else:
                print(f"[ERROR] Failed to send Absent SMS to {name}.")

    conn.close()

if __name__ == "__main__":
    # This script should be run at the end of the day to notify absentees.
    print("--- Absentee Notification System ---")
    notify_absentees()
