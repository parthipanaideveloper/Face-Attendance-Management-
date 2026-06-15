import sqlite3
from datetime import datetime
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os

# Configuration for Email
SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "your_email@gmail.com")
SENDER_PASSWORD = os.environ.get("SENDER_PASSWORD", "your_app_password")
RECEIVER_EMAIL = "parthipan25m@gmail.com"

def get_attendance_summary():
    conn = sqlite3.connect("attendance_system.db")
    cursor = conn.cursor()

    now = datetime.now()
    current_date = now.strftime("%Y-%m-%d")

    # Get all staffs
    cursor.execute("SELECT register_no, name, staff_type FROM students")
    all_staffs = cursor.fetchall()

    # Get today's attendance
    cursor.execute("SELECT register_no, in_time, out_time, status FROM attendance WHERE date=?", (current_date,))
    attendance_records = {row[0]: {"in_time": row[1], "out_time": row[2], "status": row[3]} for row in cursor.fetchall()}

    conn.close()

    summary = {
        "Teaching": {"Present": [], "Absent": [], "Late Entry": []},
        "Non-Teaching": {"Present": [], "Absent": [], "Late Entry": []}
    }

    for reg_no, name, staff_type in all_staffs:
        # Default to Teaching if somehow empty
        if not staff_type:
            staff_type = "Teaching"
            
        record = attendance_records.get(reg_no)
        
        if record:
            status = record.get("status")
            in_time = record.get("in_time")
            out_time = record.get("out_time")
            entry = f"{name} (In: {in_time}, Out: {out_time if out_time and out_time != in_time else 'N/A'})"
            
            if status == "Present":
                summary[staff_type]["Present"].append(entry)
            elif status == "Late Entry":
                summary[staff_type]["Late Entry"].append(entry)
            else:
                summary[staff_type]["Present"].append(entry) # Fallback
        else:
            summary[staff_type]["Absent"].append(name)

    return summary, current_date

def generate_email_body(summary, current_date):
    body = f"Attendance Summary for {current_date}\n\n"
    
    for staff_type in ["Teaching", "Non-Teaching"]:
        body += f"--- {staff_type} Staff ---\n"
        
        present_list = summary[staff_type]["Present"]
        late_list = summary[staff_type]["Late Entry"]
        absent_list = summary[staff_type]["Absent"]
        
        body += f"Total Present: {len(present_list)}\n"
        if present_list:
            body += "Names: " + ", ".join(present_list) + "\n"
            
        body += f"\nTotal Late Entry: {len(late_list)}\n"
        if late_list:
            body += "Names: " + ", ".join(late_list) + "\n"
            
        body += f"\nTotal Absent: {len(absent_list)}\n"
        if absent_list:
            body += "Names: " + ", ".join(absent_list) + "\n"
            
        body += "\n"
        
    return body

def send_email():
    print("[INFO] Generating Attendance Summary...")
    summary, current_date = get_attendance_summary()
    body = generate_email_body(summary, current_date)
    
    print("\n--- Generated Email Body ---")
    print(body)
    print("----------------------------\n")
    
    if SENDER_EMAIL == "your_email@gmail.com":
        print("[WARNING] SENDER_EMAIL and SENDER_PASSWORD are not configured.")
        print("[INFO] To actually send the email, update the variables in send_email_summary.py")
        return

    msg = MIMEMultipart()
    msg['From'] = SENDER_EMAIL
    msg['To'] = RECEIVER_EMAIL
    msg['Subject'] = f"Daily Staff Attendance Summary - {current_date}"
    
    msg.attach(MIMEText(body, 'plain'))
    
    try:
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        text = msg.as_string()
        server.sendmail(SENDER_EMAIL, RECEIVER_EMAIL, text)
        server.quit()
        print(f"[SUCCESS] Email successfully sent to {RECEIVER_EMAIL}")
    except Exception as e:
        print(f"[ERROR] Failed to send email: {e}")

if __name__ == "__main__":
    send_email()
