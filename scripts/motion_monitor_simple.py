#!/usr/bin/env python3
"""
HomeGuard Motion Monitor - Simple Version
Compatible with newer paho-mqtt versions

Usage:
    python motion_monitor_simple.py
"""

import json
import time
from datetime import datetime

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("❌ paho-mqtt not installed. Install with: pip install paho-mqtt")
    exit(1)

class SimpleMotionMonitor:
    def __init__(self):
        self.broker_host = "192.168.1.102"
        self.broker_port = 1883
        self.username = "homeguard"
        self.password = "pu2clr123456"
        
        # Create client with new API if available
        try:
            # Try new API first (paho-mqtt 2.x)
            self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        except (AttributeError, TypeError):
            # Fallback to old API (paho-mqtt 1.x)
            self.client = mqtt.Client()
        
        # Set credentials
        self.client.username_pw_set(self.username, self.password)
        
        # Setup callbacks
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
    
    def on_connect(self, client, userdata, flags, rc, properties=None):
        """Called when client connects to broker"""
        if rc == 0:
            print(f"✅ Connected to MQTT broker at {self.broker_host}")
            
            # Subscribe to motion detector topics
            topics = [
                "home/motion1/#",
                "home/+/motion", 
                "home/+/status",
                "home/+/heartbeat",
                "home/+/config"
            ]
            
            for topic in topics:
                client.subscribe(topic)
            
            print("📡 Subscribed to motion detector topics")
            print("👁️ Monitoring motion events (Press Ctrl+C to stop)...")
            print("=" * 80)
        else:
            print(f"❌ Failed to connect: {rc}")
    
    def on_disconnect(self, client, userdata, rc, properties=None):
        """Called when client disconnects"""
        print("📡 Disconnected from MQTT broker")
    
    def on_message(self, client, userdata, msg):
        """Called when message is received"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # Parse topic
            topic_parts = topic.split('/')
            if len(topic_parts) >= 3:
                device = topic_parts[1]  # motion1, motion2, etc.
                msg_type = topic_parts[2]  # motion, status, heartbeat, etc.
                
                # Handle different message types
                if msg_type == "motion":
                    self.handle_motion_event(payload, timestamp, device)
                elif msg_type == "status":
                    self.handle_status(payload, timestamp, device)
                elif msg_type == "heartbeat":
                    self.handle_heartbeat(payload, timestamp, device)
                elif msg_type == "config":
                    self.handle_config(payload, timestamp, device)
                else:
                    print(f"[{timestamp}] {topic}: {payload}")
            else:
                print(f"[{timestamp}] {topic}: {payload}")
                
        except Exception as e:
            print(f"❌ Error processing message: {e}")
    
    def handle_motion_event(self, payload, timestamp, device):
        """Handle motion detection events"""
        try:
            # Try to parse as JSON
            data = json.loads(payload)
            location = data.get('location', 'Unknown')
            event = data.get('event', 'Unknown')
            device_id = data.get('device_id', device)
            
            if event == "MOTION_DETECTED":
                print(f"🚶 [{timestamp}] MOTION DETECTED at {location} (Device: {device_id})")
                if 'rssi' in data:
                    print(f"   📶 Signal: {data['rssi']}")
                    
            elif event == "MOTION_CLEARED":
                duration = data.get('duration', 'Unknown')
                print(f"✅ [{timestamp}] MOTION CLEARED at {location} (Duration: {duration})")
                
        except json.JSONDecodeError:
            # Handle non-JSON messages
            print(f"🚶 [{timestamp}] Motion event: {payload}")
    
    def handle_status(self, payload, timestamp, device):
        """Handle device status messages"""
        try:
            data = json.loads(payload)
            device_id = data.get('device_id', device)
            location = data.get('location', 'Unknown')
            motion_status = data.get('motion', 'Unknown')
            
            print(f"📊 [{timestamp}] STATUS - {device_id} at {location}")
            print(f"   👁️ Motion: {motion_status}")
            
            # Show other available fields
            for key, value in data.items():
                if key not in ['device_id', 'location', 'motion']:
                    print(f"   {key}: {value}")
                    
        except json.JSONDecodeError:
            print(f"📊 [{timestamp}] Status: {payload}")
    
    def handle_heartbeat(self, payload, timestamp, device):
        """Handle device heartbeat messages"""
        try:
            data = json.loads(payload)
            device_id = data.get('device_id', device)
            location = data.get('location', 'Unknown')
            status = data.get('status', 'Unknown')
            
            print(f"💓 [{timestamp}] HEARTBEAT - {device_id} at {location} ({status})")
            
        except json.JSONDecodeError:
            print(f"💓 [{timestamp}] Heartbeat: {payload}")
    
    def handle_config(self, payload, timestamp, device):
        """Handle configuration messages"""
        print(f"⚙️ [{timestamp}] CONFIG - {device}: {payload}")
    
    def start_monitoring(self):
        """Start monitoring motion events"""
        print("🔗 Connecting to MQTT broker...")
        
        try:
            # Connect to broker
            self.client.connect(self.broker_host, self.broker_port, 60)
            
            # Show helpful commands
            print("📋 Commands you can use in another terminal:")
            print(f"   Status: mosquitto_pub -h {self.broker_host} -t home/motion1/cmnd -m 'STATUS' -u {self.username} -P {self.password}")
            print(f"   High Sens: mosquitto_pub -h {self.broker_host} -t home/motion1/cmnd -m 'SENSITIVITY_HIGH' -u {self.username} -P {self.password}")
            print("")
            
            # Start loop
            self.client.loop_forever()
            
        except KeyboardInterrupt:
            print("\n🛑 Monitoring stopped by user")
        except Exception as e:
            print(f"❌ Error: {e}")
        finally:
            self.client.disconnect()

def main():
    monitor = SimpleMotionMonitor()
    monitor.start_monitoring()

if __name__ == '__main__':
    main()
