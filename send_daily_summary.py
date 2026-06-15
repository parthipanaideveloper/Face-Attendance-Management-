import sqlite3
import time
from datetime import datetime
from sms_service import send_sms

def send_daily_summary():
    conn = sqlite3.connect("attendance_system.db")
    cursor = conn.cursor()

    now = datetime.now()
    current_date = now.strftime("%Y-%m-%d")

    # Get all registered students
    cursor.execute("SELECT register_no, name, phone_number FROM students")
    all_students = cursor.fetchall()

    # Get attendance for today
    cursor.execute("SELECT register_no, in_time, out_time, status FROM attendance WHERE date=?", (current_date,))
    attendance_records = {row[0]: {"in_time": row[1], "out_time": row[2], "status": row[3]} for row in cursor.fetchall()}

    print(f"[INFO] Preparing daily summary SMS for {len(all_students)} staffs...")

    for reg_no, name, phone in all_students:
        record = attendance_records.get(reg_no)
        
        if record:
            in_time = record.get("in_time")
            out_time = record.get("out_time")
            
            # Format the times correctly. If they only scanned once, out_time might be the same as in_time.
            if out_time and out_time != in_time:
                message = f"Dear {name}, Attendance for {current_date}:\nMorning In: {in_time}\nEvening Out: {out_time}"
            else:
                message = f"Dear {name}, Attendance for {current_date}:\nMorning In: {in_time}\nEvening Out: Missed/Not scanned"
        else:
            message = f"Dear {name}, you were marked ABSENT for {current_date}."
            
        print(f"[INFO] Sending SMS to {name} ({phone})")
        
        # Send SMS
        success = send_sms(phone, message)
        
        if success:
            print(f"[SUCCESS] SMS sent to {name}.")
        else:
            print(f"[ERROR] Failed to send SMS to {name}.")
            
        # Add a delay of 2 seconds between each SMS to avoid API rate limits
        time.sleep(2)

    conn.close()
    print("[INFO] Daily summary process completed.")

if __name__ == "__main__":
    print("--- Daily Attendance Summary System ---")
    send_daily_summary()
