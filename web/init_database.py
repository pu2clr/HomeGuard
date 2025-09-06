#!/usr/bin/env python3
"""
HomeGuard Database Initialization
Creates SQLite database with activity table structure
"""

import sqlite3
import os
from datetime import datetime

# Database configuration - usando caminho relativo ao script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)  # Vai para a pasta pai (HomeGuard)
DB_PATH = os.path.join(PROJECT_ROOT, "db", "homeguard.db")
DB_DIR = os.path.dirname(DB_PATH)

def init_database():
    """Initialize HomeGuard SQLite database with activity table"""
    
    # Create db directory if it doesn't exist
    if not os.path.exists(DB_DIR):
        os.makedirs(DB_DIR)
        print(f"✅ Created directory: {DB_DIR}")
    
    # Connect to database (will create if doesn't exist)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create activity table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS activity (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL DEFAULT (datetime('now', 'utc')),
            topic TEXT,
            message TEXT
        )
    ''')
    
    # Create indexes for better performance
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_activity_created_at ON activity(created_at)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_activity_topic ON activity(topic)')
    
    # Commit changes
    conn.commit()
    
    # Insert initial record
    cursor.execute('''
        INSERT INTO activity (topic, message) 
        VALUES (?, ?)
    ''', ('system/init', 'Database initialized successfully'))
    
    conn.commit()
    
    # Verify table structure
    cursor.execute("PRAGMA table_info(activity)")
    columns = cursor.fetchall()
    
    print("✅ Database initialized successfully!")
    print(f"📁 Database path: {DB_PATH}")
    print("📋 Table structure:")
    for column in columns:
        print(f"   - {column[1]} {column[2]} {'PRIMARY KEY' if column[5] else ''}")
    
    # Show initial record
    cursor.execute("SELECT * FROM activity ORDER BY id DESC LIMIT 1")
    record = cursor.fetchone()
    print(f"📝 Initial record: ID={record[0]}, Time={record[1]}")
    
    conn.close()
    return True

if __name__ == "__main__":
    init_database()
