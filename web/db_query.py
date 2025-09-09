#!/usr/bin/env python3
"""
HomeGuard Database Query Utilities
Provides utilities to query and analyze activity data
"""

import sqlite3
import json
import argparse
import os
from datetime import datetime, timedelta
from collections import Counter

# Database configuration - usando caminho relativo
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DB_PATH = os.path.join(PROJECT_ROOT, 'db', 'homeguard.db')

def get_connection():
    """Get database connection"""
    return sqlite3.connect(DB_PATH)

def show_stats():
    """Show database statistics"""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Total records
    cursor.execute("SELECT COUNT(*) FROM activity")
    total_records = cursor.fetchone()[0]
    
    # Date range
    cursor.execute("SELECT MIN(created_at), MAX(created_at) FROM activity")
    date_range = cursor.fetchone()
    
    # Topic distribution
    cursor.execute("""
        SELECT topic, COUNT(*) as count 
        FROM activity 
        WHERE topic NOT LIKE 'system/%'
        GROUP BY topic 
        ORDER BY count DESC 
        LIMIT 10
    """)
    top_topics = cursor.fetchall()
    
    # Device activity
    cursor.execute("""
        SELECT 
            CASE 
                WHEN topic LIKE 'home/motion/%' THEN substr(topic, 13, instr(substr(topic, 13), '/') - 1)
                WHEN topic LIKE 'home/sensor/%' THEN substr(topic, 13, instr(substr(topic, 13), '/') - 1)
                WHEN topic LIKE 'home/relay/%' THEN substr(topic, 12, instr(substr(topic, 12), '/') - 1)
                WHEN topic LIKE 'home/temperature/%' THEN substr(topic, 18, instr(substr(topic, 18), '/') - 1)
                WHEN topic LIKE 'home/humidity/%' THEN substr(topic, 15, instr(substr(topic, 15), '/') - 1)
                WHEN topic LIKE 'home/RDA5807/%' THEN 'RDA5807'
                ELSE 'other'
            END as device_id,
            COUNT(*) as message_count
        FROM activity 
        WHERE topic LIKE 'home/%'
        GROUP BY device_id
        ORDER BY message_count DESC
    """)
    devices = cursor.fetchall()
    
    print("📊 HomeGuard Database Statistics")
    print("=" * 50)
    print(f"📝 Total Records: {total_records:,}")
    print(f"📅 Date Range: {date_range[0]} to {date_range[1]}")
    print()
    
    print("🔥 Top 10 Topics:")
    for topic, count in top_topics:
        print(f"   {topic:<40} {count:>6} messages")
    print()
    
    print("🏠 Device Activity:")
    for device, count in devices:
        print(f"   {device:<20} {count:>6} messages")
    
    conn.close()

def show_recent(limit=20):
    """Show recent activity"""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT created_at, topic, message 
        FROM activity 
        ORDER BY id DESC 
        LIMIT ?
    """, (limit,))
    
    records = cursor.fetchall()
    
    print(f"📋 Recent {len(records)} Activities:")
    print("=" * 80)
    
    for created_at, topic, message in records:
        # Truncate long messages
        display_msg = message[:60] + "..." if len(message) > 60 else message
        print(f"{created_at} | {topic:<35} | {display_msg}")
    
    conn.close()

def show_device_activity(device_id):
    """Show activity for specific device"""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT created_at, topic, message 
        FROM activity 
        WHERE topic LIKE ?
        ORDER BY id DESC 
        LIMIT 50
    """, (f'%{device_id}%',))
    
    records = cursor.fetchall()
    
    print(f"🔍 Activity for device: {device_id}")
    print("=" * 80)
    
    for created_at, topic, message in records:
        print(f"{created_at} | {topic}")
        if message.startswith('{'):
            try:
                json_data = json.loads(message)
                for key, value in json_data.items():
                    print(f"   {key}: {value}")
            except:
                print(f"   {message}")
        else:
            print(f"   {message}")
        print("-" * 40)
    
    conn.close()

def export_to_json(output_file, hours=24):
    """Export recent data to JSON file"""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Calculate time threshold
    time_threshold = (datetime.now() - timedelta(hours=hours)).strftime('%Y-%m-%d %H:%M:%S')
    
    cursor.execute("""
        SELECT id, created_at, topic, message 
        FROM activity 
        WHERE created_at >= ?
        ORDER BY id DESC
    """, (time_threshold,))
    
    records = cursor.fetchall()
    
    # Convert to list of dictionaries
    data = []
    for record in records:
        row = {
            'id': record[0],
            'created_at': record[1],
            'topic': record[2],
            'message': record[3]
        }
        
        # Try to parse message as JSON
        try:
            if record[3].startswith('{'):
                row['message_json'] = json.loads(record[3])
        except:
            pass
            
        data.append(row)
    
    # Write to file
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"✅ Exported {len(data)} records to {output_file}")
    conn.close()

def main():
    parser = argparse.ArgumentParser(description='HomeGuard Database Query Utilities')
    parser.add_argument('--stats', action='store_true', help='Show database statistics')
    parser.add_argument('--recent', type=int, default=20, help='Show recent N activities')
    parser.add_argument('--device', type=str, help='Show activity for specific device')
    parser.add_argument('--export', type=str, help='Export to JSON file')
    parser.add_argument('--hours', type=int, default=24, help='Hours of data to export')
    
    args = parser.parse_args()
    
    if args.stats:
        show_stats()
    elif args.device:
        show_device_activity(args.device)
    elif args.export:
        export_to_json(args.export, args.hours)
    else:
        show_recent(args.recent)

if __name__ == "__main__":
    main()
