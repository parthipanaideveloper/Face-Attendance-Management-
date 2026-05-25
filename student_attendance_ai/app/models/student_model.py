from app.database.db_config import get_db_connection

class StudentModel:
    @staticmethod
    def add_student(register_no, name, dept, gender='Male', image_path=''):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT id FROM students WHERE register_no = ?", (register_no,))
            if cursor.fetchone():
                cursor.execute("UPDATE students SET name = ?, dept = ?, gender = ?, image_path = ? WHERE register_no = ?", 
                               (name, dept, gender, image_path, register_no))
            else:
                cursor.execute("INSERT INTO students (register_no, name, dept, gender, image_path) VALUES (?, ?, ?, ?, ?)", 
                               (register_no, name, dept, gender, image_path))
            conn.commit()
            return True, "Student added successfully"
        except Exception as e:
            return False, str(e)
        finally:
            conn.close()

    @staticmethod
    def get_all_students():
        conn = get_db_connection()
        students = conn.execute("SELECT * FROM students").fetchall()
        conn.close()
        return [{"id": s["id"], "register_no": s["register_no"], "name": s["name"], "dept": s["dept"], "gender": s["gender"], "image_path": s["image_path"]} for s in students]
