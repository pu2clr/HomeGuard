#!/usr/bin/env python3
"""
HomeGuard JSON Data Analyzer
Analyzes structured JSON data from MQTT messages
"""

import sqlite3
import json
import argparse
import os
from datetime import datetime, timedelta
from collections import defaultdict
import statistics

# Database configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DB_PATH = os.path.join(PROJECT_ROOT, 'db', 'homeguard.db')

def get_connection():
    """Get database connection"""
    return sqlite3.connect(DB_PATH)

def analyze_temperature_data(device_id=None, hours=24):
    """Analyze temperature data from DHT sensors"""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Build query based on device filter
    if device_id:
        query = """
            SELECT created_at, topic, message 
            FROM activity 
            WHERE topic LIKE ? 
            AND message LIKE '%temperature%'
            AND created_at >= datetime('now', '-{} hours')
            ORDER BY created_at DESC
        """.format(hours)
        cursor.execute(query, (f'%{device_id}%',))
    else:
        query = """
            SELECT created_at, topic, message 
            FROM activity 
            WHERE topic LIKE '%temperature%/data'
            AND message LIKE '%temperature%'
            AND created_at >= datetime('now', '-{} hours')
            ORDER BY created_at DESC
        """.format(hours)
        cursor.execute(query)
    
    records = cursor.fetchall()
    
    print(f"🌡️  Temperature Analysis - Last {hours} hours")
    print("=" * 60)
    
    if not records:
        print("❌ No temperature data found")
        conn.close()
        return
    
    # Parse JSON data
    temp_data = []
    devices = defaultdict(list)
    
    for created_at, topic, message in records:
        try:
            data = json.loads(message)
            if 'temperature' in data and 'device_id' in data:
                temp_info = {
                    'timestamp': created_at,
                    'device_id': data['device_id'],
                    'name': data.get('name', 'Unknown'),
                    'location': data.get('location', 'Unknown'),
                    'sensor_type': data.get('sensor_type', 'Unknown'),
                    'temperature': float(data['temperature']),
                    'unit': data.get('unit', '°C'),
                    'rssi': data.get('rssi', 0),
                    'uptime': data.get('uptime', 0)
                }
                temp_data.append(temp_info)
                devices[data['device_id']].append(temp_info)
        except (json.JSONDecodeError, ValueError, KeyError) as e:
            continue
    
    if not temp_data:
        print("❌ No valid temperature JSON data found")
        conn.close()
        return
    
    # Overall statistics
    all_temps = [d['temperature'] for d in temp_data]
    print(f"📊 Overall Statistics:")
    print(f"   Total readings: {len(all_temps)}")
    print(f"   Average temperature: {statistics.mean(all_temps):.1f}°C")
    print(f"   Min temperature: {min(all_temps):.1f}°C")
    print(f"   Max temperature: {max(all_temps):.1f}°C")
    if len(all_temps) > 1:
        print(f"   Standard deviation: {statistics.stdev(all_temps):.2f}°C")
    print()
    
    # Per device analysis
    print("🏠 Per Device Analysis:")
    print("-" * 40)
    
    for device, readings in devices.items():
        temps = [r['temperature'] for r in readings]
        latest = readings[0]  # Most recent (ordered DESC)
        
        print(f"Device: {device}")
        print(f"   Name: {latest['name']}")
        print(f"   Location: {latest['location']}")
        print(f"   Sensor: {latest['sensor_type']}")
        print(f"   Readings: {len(readings)}")
        print(f"   Current: {latest['temperature']:.1f}°C")
        print(f"   Average: {statistics.mean(temps):.1f}°C")
        print(f"   Min: {min(temps):.1f}°C")
        print(f"   Max: {max(temps):.1f}°C")
        print(f"   RSSI: {latest['rssi']} dBm")
        print(f"   Uptime: {latest['uptime']} seconds")
        print(f"   Last update: {latest['timestamp']}")
        print()
    
    conn.close()

def analyze_motion_data(device_id=None, hours=24):
    """Analyze motion sensor data"""
    conn = get_connection()
    cursor = conn.cursor()
    
    if device_id:
        query = """
            SELECT created_at, topic, message 
            FROM activity 
            WHERE topic LIKE ? 
            AND message LIKE '%motion%'
            AND created_at >= datetime('now', '-{} hours')
            ORDER BY created_at DESC
        """.format(hours)
        cursor.execute(query, (f'%{device_id}%',))
    else:
        query = """
            SELECT created_at, topic, message 
            FROM activity 
            WHERE topic LIKE '%motion%'
            AND message LIKE '%device_id%'
            AND created_at >= datetime('now', '-{} hours')
            ORDER BY created_at DESC
        """.format(hours)
        cursor.execute(query)
    
    records = cursor.fetchall()
    
    print(f"🚶 Motion Analysis - Last {hours} hours")
    print("=" * 60)
    
    if not records:
        print("❌ No motion data found")
        conn.close()
        return
    
    # Parse motion data
    motion_data = []
    devices = defaultdict(list)
    
    for created_at, topic, message in records:
        try:
            data = json.loads(message)
            if 'device_id' in data:
                motion_info = {
                    'timestamp': created_at,
                    'device_id': data['device_id'],
                    'location': data.get('location', 'Unknown'),
                    'motion_detected': data.get('motion_detected', False),
                    'sensor_type': data.get('sensor_type', 'PIR'),
                    'rssi': data.get('rssi', 0),
                    'uptime': data.get('uptime', 0)
                }
                motion_data.append(motion_info)
                devices[data['device_id']].append(motion_info)
        except (json.JSONDecodeError, KeyError) as e:
            continue
    
    if not motion_data:
        print("❌ No valid motion JSON data found")
        conn.close()
        return
    
    # Overall statistics
    total_detections = sum(1 for d in motion_data if d['motion_detected'])
    print(f"📊 Overall Statistics:")
    print(f"   Total events: {len(motion_data)}")
    print(f"   Motion detections: {total_detections}")
    print(f"   Detection rate: {(total_detections/len(motion_data)*100):.1f}%")
    print()
    
    # Per device analysis
    print("🏠 Per Device Analysis:")
    print("-" * 40)
    
    for device, events in devices.items():
        detections = sum(1 for e in events if e['motion_detected'])
        latest = events[0]
        
        print(f"Device: {device}")
        print(f"   Location: {latest['location']}")
        print(f"   Sensor: {latest['sensor_type']}")
        print(f"   Total events: {len(events)}")
        print(f"   Detections: {detections}")
        print(f"   Detection rate: {(detections/len(events)*100):.1f}%")
        print(f"   Current state: {'🚶 Motion' if latest['motion_detected'] else '🟢 Clear'}")
        print(f"   RSSI: {latest['rssi']} dBm")
        print(f"   Last update: {latest['timestamp']}")
        print()
    
    conn.close()

def analyze_rda5807_data(hours=24):
    """Analyze RDA5807 radio data"""
    conn = get_connection()
    cursor = conn.cursor()
    
    query = """
        SELECT created_at, topic, message 
        FROM activity 
        WHERE topic LIKE '%RDA5807%'
        AND message LIKE '%frequency%'
        AND created_at >= datetime('now', '-{} hours')
        ORDER BY created_at DESC
    """.format(hours)
    cursor.execute(query)
    
    records = cursor.fetchall()
    
    print(f"📻 RDA5807 Radio Analysis - Last {hours} hours")
    print("=" * 60)
    
    if not records:
        print("❌ No RDA5807 data found")
        conn.close()
        return
    
    # Parse radio data
    radio_data = []
    frequencies = defaultdict(int)
    
    for created_at, topic, message in records:
        try:
            data = json.loads(message)
            if 'frequency' in data:
                radio_info = {
                    'timestamp': created_at,
                    'frequency': data.get('frequency', 0),
                    'volume': data.get('volume', 0),
                    'device_info': data.get('device_info', {}),
                    'rssi': data.get('rssi', 0)
                }
                radio_data.append(radio_info)
                frequencies[data['frequency']] += 1
        except (json.JSONDecodeError, KeyError) as e:
            continue
    
    if not radio_data:
        print("❌ No valid RDA5807 JSON data found")
        conn.close()
        return
    
    latest = radio_data[0]
    
    print(f"📊 Radio Statistics:")
    print(f"   Total updates: {len(radio_data)}")
    print(f"   Current frequency: {latest['frequency']:.1f} MHz")
    print(f"   Current volume: {latest['volume']}")
    print(f"   Device info: {latest['device_info']}")
    print(f"   Last update: {latest['timestamp']}")
    print()
    
    print("🎵 Most Used Frequencies:")
    print("-" * 30)
    sorted_freqs = sorted(frequencies.items(), key=lambda x: x[1], reverse=True)
    for freq, count in sorted_freqs[:10]:
        print(f"   {freq:.1f} MHz: {count} times")
    
    conn.close()

def search_json_field(field_name, device_filter=None, hours=24, limit=50):
    """Search for specific JSON field across all data"""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Build query
    base_query = """
        SELECT created_at, topic, message 
        FROM activity 
        WHERE message LIKE ? 
        AND created_at >= datetime('now', '-{} hours')
    """.format(hours)
    
    params = [f'%"{field_name}"%']
    
    if device_filter:
        base_query += " AND topic LIKE ?"
        params.append(f'%{device_filter}%')
    
    base_query += " ORDER BY created_at DESC LIMIT ?"
    params.append(limit)
    
    cursor.execute(base_query, params)
    records = cursor.fetchall()
    
    print(f"🔍 JSON Field Search: '{field_name}' - Last {hours} hours")
    print("=" * 60)
    
    if not records:
        print("❌ No data found")
        conn.close()
        return
    
    field_values = []
    
    for created_at, topic, message in records:
        try:
            data = json.loads(message)
            if field_name in data:
                value = data[field_name]
                field_values.append({
                    'timestamp': created_at,
                    'topic': topic,
                    'value': value,
                    'device_id': data.get('device_id', 'Unknown')
                })
        except (json.JSONDecodeError, KeyError) as e:
            continue
    
    if not field_values:
        print(f"❌ No '{field_name}' field found in JSON data")
        conn.close()
        return
    
    print(f"📊 Found {len(field_values)} records with '{field_name}' field")
    print()
    
    # Show recent values
    print("📋 Recent Values:")
    print("-" * 40)
    for item in field_values[:20]:
        print(f"{item['timestamp']} | {item['device_id']:<20} | {item['value']}")
    
    # Analyze numeric values
    try:
        numeric_values = [float(item['value']) for item in field_values if isinstance(item['value'], (int, float, str)) and str(item['value']).replace('.', '').replace('-', '').isdigit()]
        
        if numeric_values:
            print()
            print(f"📈 Numeric Analysis for '{field_name}':")
            print(f"   Count: {len(numeric_values)}")
            print(f"   Average: {statistics.mean(numeric_values):.2f}")
            print(f"   Min: {min(numeric_values):.2f}")
            print(f"   Max: {max(numeric_values):.2f}")
            if len(numeric_values) > 1:
                print(f"   Std Dev: {statistics.stdev(numeric_values):.2f}")
    except:
        pass
    
    conn.close()

def main():
    parser = argparse.ArgumentParser(description='HomeGuard JSON Data Analyzer')
    parser.add_argument('--temperature', action='store_true', help='Analyze temperature sensor data')
    parser.add_argument('--motion', action='store_true', help='Analyze motion sensor data')
    parser.add_argument('--radio', action='store_true', help='Analyze RDA5807 radio data')
    parser.add_argument('--search', type=str, help='Search for specific JSON field')
    parser.add_argument('--device', type=str, help='Filter by device ID')
    parser.add_argument('--hours', type=int, default=24, help='Hours of data to analyze (default: 24)')
    parser.add_argument('--limit', type=int, default=50, help='Limit results (default: 50)')
    
    args = parser.parse_args()
    
    if args.temperature:
        analyze_temperature_data(args.device, args.hours)
    elif args.motion:
        analyze_motion_data(args.device, args.hours)
    elif args.radio:
        analyze_rda5807_data(args.hours)
    elif args.search:
        search_json_field(args.search, args.device, args.hours, args.limit)
    else:
        print("HomeGuard JSON Data Analyzer")
        print("============================")
        print()
        print("Available analyses:")
        print("  --temperature    Analyze DHT22/DHT11 temperature data")
        print("  --motion         Analyze motion sensor data")
        print("  --radio          Analyze RDA5807 radio data")
        print("  --search FIELD   Search for specific JSON field")
        print()
        print("Options:")
        print("  --device ID      Filter by device ID")
        print("  --hours N        Hours of data to analyze (default: 24)")
        print("  --limit N        Limit results (default: 50)")
        print()
        print("Examples:")
        print("  python3 json_analyzer.py --temperature --device ESP01_DHT22_BRANCO")
        print("  python3 json_analyzer.py --search temperature --hours 48")
        print("  python3 json_analyzer.py --motion --hours 12")
        print("  python3 json_analyzer.py --radio")

if __name__ == "__main__":
    main()
