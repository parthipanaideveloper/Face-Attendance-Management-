import sqlite3
import csv
import os

def export_attendance_to_csv():
    conn = sqlite3.connect("attendance_system.db")
    cursor = conn.cursor()

    # Join the attendance and students tables to get the name along with the details
    query = '''
        SELECT 
            a.date,
            a.register_no,
            s.name,
            a.in_time,
            a.out_time,
            a.status
        FROM attendance a
        JOIN students s ON a.register_no = s.register_no
        ORDER BY a.date DESC, a.in_time DESC
    '''
    
    cursor.execute(query)
    records = cursor.fetchall()
    conn.close()

    if not records:
        print("No attendance records found.")
        return

    csv_filename = "Attendance_Report.csv"
    
    with open(csv_filename, mode='w', newline='') as file:
        writer = csv.writer(file)
        # Write headers
        writer.writerow(["Date", "Register No", "Name", "In-Time", "Out-Time", "Status"])
        
        # Write rows
        for row in records:
            writer.writerow(row)

    print(f"\n[SUCCESS] Attendance report exported successfully to: {os.path.abspath(csv_filename)}")
    
    # Print it to the console as well for quick viewing
    print("\n" + "-"*80)
    print(f"{'Date':<15} | {'Register No':<15} | {'Name':<20} | {'In-Time':<10} | {'Out-Time':<10} | {'Status'}")
    print("-" * 80)
    for row in records:
        print(f"{row[0]:<15} | {row[1]:<15} | {row[2]:<20} | {row[3]:<10} | {row[4]:<10} | {row[5]}")
    print("-" * 80)

if __name__ == "__main__":
    export_attendance_to_csv()
