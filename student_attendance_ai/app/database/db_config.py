import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'database', 'database.db')

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    # Students Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            register_no TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            dept TEXT NOT NULL DEFAULT 'Unknown',
            gender TEXT NOT NULL DEFAULT 'Male',
            image_path TEXT NOT NULL
        )
    ''')

    # Attendance Table
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
    print("[INFO] Database Initialized at", DB_PATH)
