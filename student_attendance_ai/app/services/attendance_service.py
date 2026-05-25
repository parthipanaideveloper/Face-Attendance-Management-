from app.models.attendance_model import AttendanceModel

class AttendanceService:
    @staticmethod
    def process_attendance(register_no, name):
        """
        Business logic layer for marking attendance. 
        Can be expanded later to check for late arrivals, send SMS notifications, etc.
        """
        # print(f"[SERVICE] Validating attendance for {name} ({register_no})")
        AttendanceModel.log_attendance(register_no, name)

    @staticmethod
    def get_daily_report(date_string):
        return AttendanceModel.get_attendance_by_date(date_string)
