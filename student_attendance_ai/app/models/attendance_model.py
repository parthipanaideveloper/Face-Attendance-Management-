from app.database.db_config import get_db_connection
from datetime import datetime
class AttendanceModel:
    @staticmethod
    def log_attendance(register_no, name):
        conn = get_db_connection()
        cursor = conn.cursor()

        now = datetime.now()
        current_date = now.strftime("%Y-%m-%d")
        current_time = now.strftime("%H:%M:%S")

        cursor.execute("SELECT * FROM attendance WHERE register_no=? AND date=?", (register_no, current_date))
        record = cursor.fetchone()

        if record is None:
            # First scan of the day - mark In-Time
            cursor.execute('''
                INSERT INTO attendance (register_no, date, in_time, out_time, status)
                VALUES (?, ?, ?, ?, ?)
            ''', (register_no, current_date, current_time, current_time, 'Present'))
        else:
            # Update Out-Time
            cursor.execute('''
                UPDATE attendance 
                SET out_time=?
                WHERE register_no=? AND date=?
            ''', (current_time, register_no, current_date))
            
        conn.commit()
        conn.close()

    @staticmethod
    def log_attendance_and_get_details(register_no, name):
        """Logs attendance and returns the full student details for the mobile popup."""
        AttendanceModel.log_attendance(register_no, name)
        
        conn = get_db_connection()
        today = datetime.now().strftime("%Y-%m-%d")
        query = '''
            SELECT s.name, a.register_no, s.dept, a.in_time, a.out_time, a.status 
            FROM attendance a 
            JOIN students s ON a.register_no = s.register_no 
            WHERE a.register_no = ? AND a.date = ? 
        '''
        record = conn.execute(query, (register_no, today)).fetchone()
        conn.close()
        
        if record:
            return {
                "name": record['name'],
                "register_no": record['register_no'],
                "dept": record['dept'],
                "in_time": record['in_time'],
                "out_time": record['out_time'],
                "status": record['status']
            }
        return None

    @staticmethod
    def get_todays_attendance():
        conn = get_db_connection()
        today = datetime.now().strftime("%Y-%m-%d")
        query = '''
            SELECT s.name, a.register_no, s.dept, s.gender, a.in_time, a.out_time, a.status 
            FROM attendance a 
            JOIN students s ON a.register_no = s.register_no 
            WHERE a.date = ? 
            ORDER BY a.in_time DESC
        '''
        records = conn.execute(query, (today,)).fetchall()
        conn.close()
        return [dict(row) for row in records]

    @staticmethod
    def get_attendance_by_date(target_date):
        conn = get_db_connection()
        query = '''
            SELECT a.date, s.name, a.register_no, a.in_time, a.out_time, a.status 
            FROM attendance a 
            JOIN students s ON a.register_no = s.register_no 
            WHERE a.date = ? 
            ORDER BY a.in_time DESC
        '''
        records = conn.execute(query, (target_date,)).fetchall()
        conn.close()
        return [dict(row) for row in records]

    @staticmethod
    def get_attendance_by_month(year_month):
        """Fetches all attendance records for a target Month (Format: YYYY-MM)"""
        conn = get_db_connection()
        query = '''
            SELECT a.date, s.name, a.register_no, s.dept, a.in_time, a.out_time, a.status 
            FROM attendance a 
            JOIN students s ON a.register_no = s.register_no 
            WHERE a.date LIKE ?
            ORDER BY a.date ASC, a.in_time ASC
        '''
        records = conn.execute(query, (f"{year_month}-%",)).fetchall()
        conn.close()
        return [dict(row) for row in records]

    @staticmethod
    def get_dashboard_analytics():
        """Fetches aggregate data for visual charts and statistical metrics on the dashboard."""
        conn = get_db_connection()
        cursor = conn.cursor()
        
        today = datetime.now().strftime("%Y-%m-%d")
        current_month = datetime.now().strftime("%Y-%m")
        
        # 1. Total Registered Students
        cursor.execute("SELECT COUNT(*) FROM students")
        total_students = cursor.fetchone()[0]
        
        # 2. Total Present Today
        cursor.execute("SELECT COUNT(DISTINCT register_no) FROM attendance WHERE date = ?", (today,))
        present_today = cursor.fetchone()[0]
        absent_today = max(0, total_students - present_today)
        
        # 3. Present Today Gender Split
        cursor.execute('''
            SELECT s.gender, COUNT(DISTINCT a.register_no) 
            FROM attendance a 
            JOIN students s ON a.register_no = s.register_no 
            WHERE a.date = ? 
            GROUP BY s.gender
        ''', (today,))
        gender_split_raw = cursor.fetchall()
        present_gender = {"Male": 0, "Female": 0}
        for row in gender_split_raw:
            if row[0] in present_gender:
                present_gender[row[0]] = row[1]
                
        # 4. Total Registered Students Gender Split (overall)
        cursor.execute("SELECT gender, COUNT(*) FROM students GROUP BY gender")
        registered_gender_raw = cursor.fetchall()
        registered_gender = {"Male": 0, "Female": 0}
        for row in registered_gender_raw:
            if row[0] in registered_gender:
                registered_gender[row[0]] = row[1]
                
        # 5. Monthly Attendance Statistics
        cursor.execute('''
            SELECT COUNT(*) FROM attendance WHERE date LIKE ?
        ''', (f"{current_month}-%",))
        monthly_total_logs = cursor.fetchone()[0]
        
        cursor.execute('''
            SELECT date, COUNT(DISTINCT register_no) 
            FROM attendance 
            WHERE date LIKE ? 
            GROUP BY date
        ''', (f"{current_month}-%",))
        daily_counts = cursor.fetchall()
        
        if total_students > 0 and daily_counts:
            avg_daily_present = sum(row[1] for row in daily_counts) / len(daily_counts)
            monthly_attendance_rate = round((avg_daily_present / total_students) * 100, 1)
        else:
            monthly_attendance_rate = 0.0
            
        conn.close()
        
        return {
            "total_students": total_students,
            "present_today": present_today,
            "absent_today": absent_today,
            "today_attendance_rate": round((present_today / total_students * 100), 1) if total_students > 0 else 0.0,
            "present_gender": present_gender,
            "registered_gender": registered_gender,
            "monthly_total_logs": monthly_total_logs,
            "monthly_attendance_rate": monthly_attendance_rate,
            "current_month_name": datetime.now().strftime("%B %Y")
        }
