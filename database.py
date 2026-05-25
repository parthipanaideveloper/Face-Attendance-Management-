import sqlite3
import os

def init_db():
    # Connect to SQLite Database (it will create the file if it doesn't exist)
    conn = sqlite3.connect("attendance_system.db")
    cursor = conn.cursor()

    # Create Students Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            register_no TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            image_path TEXT NOT NULL
        )
    ''')

    # Create Attendance Table
    # status will be 'Present' if they are scanned. 
    # in_time is the first time they are seen today.
    # out_time is the latest time they are seen today.
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            register_no TEXT NOT NULL,
            date TEXT NOT NULL,
            in_time TEXT,
            out_time TEXT,
            status TEXT,
            FOREIGN KEY(register_no) REFERENCES students(register_no)
        )
    ''')

    conn.commit()
    conn.close()
    print("Database Initialized Successfully!")

if __name__ == "__main__":
    init_db()
