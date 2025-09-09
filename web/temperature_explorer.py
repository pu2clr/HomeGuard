#!/usr/bin/env python3
"""
Temperature Data Explorer
Specific analysis for temperature sensor data like ESP01_DHT22_BRANCO
"""

import sqlite3
import json
import os
from datetime import datetime, timedelta
import statistics
import matplotlib.pyplot as plt
from collections import defaultdict

# Database configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DB_PATH = os.path.join(PROJECT_ROOT, 'db', 'homeguard.db')

def get_temperature_data(device_id="ESP01_DHT22_BRANCO", hours=24):
    """Get temperature data for specific device"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    query = """
        SELECT created_at, topic, message 
        FROM activity 
        WHERE topic = ? 
        AND message LIKE '%temperature%'
        AND created_at >= datetime('now', '-{} hours')
        ORDER BY created_at ASC
    """.format(hours)
    
    topic = f"home/temperature/{device_id}/data"
    cursor.execute(query, (topic,))
    records = cursor.fetchall()
    
    temp_readings = []
    
    for created_at, topic, message in records:
        try:
            data = json.loads(message)
            if 'temperature' in data:
                temp_readings.append({
                    'timestamp': datetime.fromisoformat(created_at.replace('Z', '+00:00')),
                    'temperature': float(data['temperature']),
                    'device_id': data.get('device_id', device_id),
                    'name': data.get('name', 'Unknown'),
                    'location': data.get('location', 'Unknown'),
                    'sensor_type': data.get('sensor_type', 'DHT22'),
                    'unit': data.get('unit', '°C'),
                    'rssi': data.get('rssi', 0),
                    'uptime': data.get('uptime', 0)
                })
        except (json.JSONDecodeError, ValueError, KeyError) as e:
            continue
    
    conn.close()
    return temp_readings

def analyze_temperature_trends(temp_readings):
    """Analyze temperature trends and statistics"""
    if not temp_readings:
        print("❌ No temperature data found")
        return
    
    temps = [r['temperature'] for r in temp_readings]
    latest = temp_readings[-1]
    
    print(f"🌡️  Temperature Analysis: {latest['device_id']}")
    print("=" * 60)
    print(f"📍 Location: {latest['location']} ({latest['name']})")
    print(f"🔧 Sensor: {latest['sensor_type']}")
    print(f"📊 Data points: {len(temps)}")
    print(f"⏰ Time range: {temp_readings[0]['timestamp']} to {temp_readings[-1]['timestamp']}")
    print()
    
    print("📈 Temperature Statistics:")
    print(f"   Current: {latest['temperature']:.1f}{latest['unit']}")
    print(f"   Average: {statistics.mean(temps):.1f}°C")
    print(f"   Minimum: {min(temps):.1f}°C")
    print(f"   Maximum: {max(temps):.1f}°C")
    print(f"   Range: {max(temps) - min(temps):.1f}°C")
    if len(temps) > 1:
        print(f"   Std Dev: {statistics.stdev(temps):.2f}°C")
    print()
    
    print("📡 Device Status:")
    print(f"   RSSI: {latest['rssi']} dBm")
    print(f"   Uptime: {latest['uptime']} seconds ({latest['uptime']/3600:.1f} hours)")
    print()
    
    # Temperature ranges
    print("🌡️  Temperature Ranges:")
    cold = sum(1 for t in temps if t < 20)
    comfortable = sum(1 for t in temps if 20 <= t <= 25)
    warm = sum(1 for t in temps if 25 < t <= 30)
    hot = sum(1 for t in temps if t > 30)
    
    total = len(temps)
    print(f"   Cold (<20°C): {cold} readings ({cold/total*100:.1f}%)")
    print(f"   Comfortable (20-25°C): {comfortable} readings ({comfortable/total*100:.1f}%)")
    print(f"   Warm (25-30°C): {warm} readings ({warm/total*100:.1f}%)")
    print(f"   Hot (>30°C): {hot} readings ({hot/total*100:.1f}%)")
    print()
    
    # Recent trend
    if len(temps) >= 5:
        recent_5 = temps[-5:]
        trend = "📈 Rising" if recent_5[-1] > recent_5[0] else "📉 Falling" if recent_5[-1] < recent_5[0] else "➡️  Stable"
        print(f"🔍 Recent Trend (last 5 readings): {trend}")
        print(f"   Last 5 temperatures: {[f'{t:.1f}' for t in recent_5]}")

def show_hourly_averages(temp_readings):
    """Show hourly temperature averages"""
    if not temp_readings:
        return
    
    hourly_data = defaultdict(list)
    
    for reading in temp_readings:
        hour = reading['timestamp'].strftime('%Y-%m-%d %H:00')
        hourly_data[hour].append(reading['temperature'])
    
    print("\n⏰ Hourly Averages:")
    print("-" * 40)
    
    for hour in sorted(hourly_data.keys()):
        temps = hourly_data[hour]
        avg_temp = statistics.mean(temps)
        min_temp = min(temps)
        max_temp = max(temps)
        count = len(temps)
        
        print(f"{hour} | Avg: {avg_temp:.1f}°C | Min: {min_temp:.1f}°C | Max: {max_temp:.1f}°C | Count: {count}")

def export_temperature_data(temp_readings, filename):
    """Export temperature data to JSON file"""
    if not temp_readings:
        print("❌ No data to export")
        return
    
    # Convert datetime objects to strings for JSON serialization
    export_data = []
    for reading in temp_readings:
        export_reading = reading.copy()
        export_reading['timestamp'] = reading['timestamp'].isoformat()
        export_data.append(export_reading)
    
    with open(filename, 'w') as f:
        json.dump(export_data, f, indent=2)
    
    print(f"✅ Exported {len(export_data)} temperature readings to {filename}")

def plot_temperature_graph(temp_readings, save_file=None):
    """Create temperature plot (requires matplotlib)"""
    try:
        import matplotlib.pyplot as plt
        import matplotlib.dates as mdates
    except ImportError:
        print("⚠️  matplotlib not available for plotting")
        print("   Install with: pip install matplotlib")
        return
    
    if not temp_readings:
        print("❌ No data to plot")
        return
    
    timestamps = [r['timestamp'] for r in temp_readings]
    temperatures = [r['temperature'] for r in temp_readings]
    device_id = temp_readings[0]['device_id']
    location = temp_readings[0]['location']
    
    plt.figure(figsize=(12, 6))
    plt.plot(timestamps, temperatures, 'b-', linewidth=1, markersize=3)
    plt.title(f'Temperature Data - {device_id} ({location})')
    plt.xlabel('Time')
    plt.ylabel('Temperature (°C)')
    plt.grid(True, alpha=0.3)
    
    # Format x-axis
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
    plt.gca().xaxis.set_major_locator(mdates.HourLocator(interval=2))
    plt.xticks(rotation=45)
    
    plt.tight_layout()
    
    if save_file:
        plt.savefig(save_file, dpi=300, bbox_inches='tight')
        print(f"✅ Graph saved to {save_file}")
    else:
        plt.show()

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Temperature Data Explorer')
    parser.add_argument('--device', type=str, default='ESP01_DHT22_BRANCO', 
                       help='Device ID (default: ESP01_DHT22_BRANCO)')
    parser.add_argument('--hours', type=int, default=24, 
                       help='Hours of data to analyze (default: 24)')
    parser.add_argument('--export', type=str, help='Export data to JSON file')
    parser.add_argument('--plot', type=str, help='Save temperature plot to file')
    parser.add_argument('--hourly', action='store_true', help='Show hourly averages')
    
    args = parser.parse_args()
    
    print(f"🔍 Fetching temperature data for {args.device}...")
    temp_readings = get_temperature_data(args.device, args.hours)
    
    if not temp_readings:
        print(f"❌ No temperature data found for device: {args.device}")
        print(f"   Topic searched: home/temperature/{args.device}/data")
        print("\n💡 Available temperature devices:")
        
        # Show available devices
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT DISTINCT topic 
            FROM activity 
            WHERE topic LIKE '%temperature%/data'
            AND message LIKE '%temperature%'
            ORDER BY topic
        """)
        
        topics = cursor.fetchall()
        for (topic,) in topics:
            device_from_topic = topic.split('/')[2]
            print(f"   - {device_from_topic}")
        
        conn.close()
        return
    
    # Analyze the data
    analyze_temperature_trends(temp_readings)
    
    if args.hourly:
        show_hourly_averages(temp_readings)
    
    if args.export:
        export_temperature_data(temp_readings, args.export)
    
    if args.plot:
        plot_temperature_graph(temp_readings, args.plot)

if __name__ == "__main__":
    main()
