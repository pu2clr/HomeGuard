#!/usr/bin/env python3
"""
HomeGuard Motion Monitor
Python script for monitoring motion detection events from ESP-01S motion detector

Based on the working MQTT configuration:
- Broker: 192.168.18.236
- User: homeguard  
- Pass: pu2clr123456

Usage:
    python motion_monitor.py
    python motion_monitor.py --log-file motion.log
    python motion_monitor.py --device motion_abc123
"""

import json
import time
import argparse
import logging
from datetime import datetime
from typing import Dict, List

import paho.mqtt.client as mqtt

class MotionMonitor:
    def __init__(self, broker_host="192.168.18.236", broker_port=1883, 
                 username="homeguard", password="pu2clr123456"):
        """
        Initialize Motion Monitor
        
        Args:
            broker_host: MQTT broker IP
            broker_port: MQTT broker port  
            username: MQTT username
            password: MQTT password
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.username = username
        self.password = password
        
        self.client = mqtt.Client()
        self.connected = False
        self.devices = {}
        
        # Setup MQTT callbacks
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message
        
        # Set credentials
        self.client.username_pw_set(username, password)
    
    def _on_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            self.connected = True
            print(f"✅ Connected to MQTT broker at {self.broker_host}")
            
            # Subscribe to all motion detector topics
            client.subscribe("home/motion1/#")
            client.subscribe("home/+/motion")  # Support multiple motion detectors
            client.subscribe("home/+/status")
            client.subscribe("home/+/heartbeat")
            
            print("📡 Subscribed to motion detector topics")
            
        else:
            print(f"❌ Failed to connect to MQTT broker: {rc}")
    
    def _on_disconnect(self, client, userdata, rc):
        """MQTT disconnection callback"""
        self.connected = False
        print("📡 Disconnected from MQTT broker")
    
    def _on_message(self, client, userdata, msg):
        """MQTT message callback"""
        try:
            topic_parts = msg.topic.split('/')
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            if len(topic_parts) >= 3:
                device_type = topic_parts[1]  # motion1, motion2, etc.
                message_type = topic_parts[2]  # motion, status, heartbeat, etc.
                
                # Handle different message types
                if message_type == "motion":
                    self._handle_motion_event(msg.payload.decode(), timestamp, device_type)
                elif message_type == "status":
                    self._handle_status_message(msg.payload.decode(), timestamp, device_type)
                elif message_type == "heartbeat":
                    self._handle_heartbeat(msg.payload.decode(), timestamp, device_type)
                elif message_type == "config":
                    self._handle_config_message(msg.payload.decode(), timestamp, device_type)
                else:
                    print(f"[{timestamp}] {msg.topic}: {msg.payload.decode()}")
                    
        except Exception as e:
            print(f"❌ Error processing message: {e}")
    
    def _handle_motion_event(self, payload, timestamp, device):
        """Handle motion detection events"""
        try:
            data = json.loads(payload)
            location = data.get('location', 'Unknown')
            event = data.get('event', 'Unknown')
            device_id = data.get('device_id', device)
            
            # Update device tracking
            if device_id not in self.devices:
                self.devices[device_id] = {
                    'location': location,
                    'last_motion': None,
                    'motion_count': 0
                }
            
            if event == "MOTION_DETECTED":
                self.devices[device_id]['last_motion'] = timestamp
                self.devices[device_id]['motion_count'] += 1
                
                print(f"🚶 [{timestamp}] MOTION DETECTED at {location} (Device: {device_id})")
                
                # Log additional details if available
                if 'rssi' in data:
                    print(f"   📶 Signal: {data['rssi']}")
                    
            elif event == "MOTION_CLEARED":
                duration = data.get('duration', 'Unknown')
                print(f"✅ [{timestamp}] MOTION CLEARED at {location} (Duration: {duration})")
                
        except json.JSONDecodeError:
            print(f"⚠️ [{timestamp}] Motion event (non-JSON): {payload}")
    
    def _handle_status_message(self, payload, timestamp, device):
        """Handle device status messages"""
        try:
            data = json.loads(payload)
            device_id = data.get('device_id', device)
            location = data.get('location', 'Unknown')
            ip = data.get('ip', 'Unknown')
            motion_status = data.get('motion', 'Unknown')
            uptime = data.get('uptime', 'Unknown')
            rssi = data.get('rssi', 'Unknown')
            
            print(f"📊 [{timestamp}] STATUS - {device_id} at {location}")
            print(f"   🌐 IP: {ip}")
            print(f"   👁️ Motion: {motion_status}")
            print(f"   ⏱️ Uptime: {uptime}")
            print(f"   📶 RSSI: {rssi}")
            
            # Update device info
            if device_id not in self.devices:
                self.devices[device_id] = {}
            
            self.devices[device_id].update({
                'location': location,
                'ip': ip,
                'motion_status': motion_status,
                'last_status': timestamp
            })
            
        except json.JSONDecodeError:
            print(f"📊 [{timestamp}] Status (non-JSON): {payload}")
    
    def _handle_heartbeat(self, payload, timestamp, device):
        """Handle device heartbeat messages"""
        try:
            data = json.loads(payload)
            device_id = data.get('device_id', device)
            location = data.get('location', 'Unknown')
            status = data.get('status', 'Unknown')
            
            print(f"💓 [{timestamp}] HEARTBEAT - {device_id} at {location} ({status})")
            
            # Update device tracking
            if device_id not in self.devices:
                self.devices[device_id] = {}
            
            self.devices[device_id].update({
                'location': location,
                'status': status,
                'last_heartbeat': timestamp
            })
            
        except json.JSONDecodeError:
            print(f"💓 [{timestamp}] Heartbeat (non-JSON): {payload}")
    
    def _handle_config_message(self, payload, timestamp, device):
        """Handle configuration confirmation messages"""
        print(f"⚙️ [{timestamp}] CONFIG - {device}: {payload}")
    
    def connect(self):
        """Connect to MQTT broker"""
        try:
            print(f"🔗 Connecting to MQTT broker {self.broker_host}:{self.broker_port}...")
            self.client.connect(self.broker_host, self.broker_port, 60)
            return True
        except Exception as e:
            print(f"❌ Connection failed: {e}")
            return False
    
    def start_monitoring(self):
        """Start monitoring motion events"""
        print("🎯 Starting motion monitoring...")
        print("📋 Commands you can use in another terminal:")
        print(f"   Status: mosquitto_pub -h {self.broker_host} -t home/motion1/cmnd -m 'STATUS' -u {self.username} -P {self.password}")
        print(f"   High Sens: mosquitto_pub -h {self.broker_host} -t home/motion1/cmnd -m 'SENSITIVITY_HIGH' -u {self.username} -P {self.password}")
        print(f"   Set Location: mosquitto_pub -h {self.broker_host} -t home/motion1/cmnd -m 'LOCATION_Kitchen' -u {self.username} -P {self.password}")
        print("")
        print("👁️ Monitoring motion events (Press Ctrl+C to stop)...")
        print("=" * 80)
        
        try:
            self.client.loop_forever()
        except KeyboardInterrupt:
            print("\n🛑 Monitoring stopped by user")
        except Exception as e:
            print(f"\n❌ Monitoring error: {e}")
    
    def send_command(self, device, command):
        """Send command to motion detector"""
        topic = f"home/{device}/cmnd"
        self.client.publish(topic, command)
        print(f"📤 Sent command '{command}' to {device}")
    
    def show_device_summary(self):
        """Show summary of discovered devices"""
        print("\n📊 DEVICE SUMMARY")
        print("=" * 50)
        
        if not self.devices:
            print("No devices discovered yet")
            return
            
        for device_id, info in self.devices.items():
            print(f"\n🔹 Device: {device_id}")
            print(f"   📍 Location: {info.get('location', 'Unknown')}")
            print(f"   🌐 IP: {info.get('ip', 'Unknown')}")
            print(f"   👁️ Motion Status: {info.get('motion_status', 'Unknown')}")
            print(f"   🕐 Last Motion: {info.get('last_motion', 'Never')}")
            print(f"   💓 Last Heartbeat: {info.get('last_heartbeat', 'Never')}")
            print(f"   📊 Motion Count: {info.get('motion_count', 0)}")

def main():
    parser = argparse.ArgumentParser(description='HomeGuard Motion Monitor')
    parser.add_argument('--broker', default='192.168.18.236', help='MQTT broker IP')
    parser.add_argument('--port', type=int, default=1883, help='MQTT broker port')
    parser.add_argument('--username', default='homeguard', help='MQTT username')
    parser.add_argument('--password', default='pu2clr123456', help='MQTT password')
    parser.add_argument('--device', help='Send command to specific device')
    parser.add_argument('--command', help='Command to send (STATUS, SENSITIVITY_HIGH, etc.)')
    parser.add_argument('--log-file', help='Log events to file')
    parser.add_argument('--summary', action='store_true', help='Show device summary after 10 seconds')
    
    args = parser.parse_args()
    
    # Setup logging if requested
    if args.log_file:
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(message)s',
            handlers=[
                logging.FileHandler(args.log_file),
                logging.StreamHandler()
            ]
        )
    
    # Initialize monitor
    monitor = MotionMonitor(
        broker_host=args.broker,
        broker_port=args.port,
        username=args.username,
        password=args.password
    )
    
    # Connect to broker
    if not monitor.connect():
        return
    
    # Start monitoring
    monitor.client.loop_start()
    
    # Send command if specified
    if args.device and args.command:
        time.sleep(1)  # Wait for connection
        monitor.send_command(args.device, args.command)
        time.sleep(2)  # Wait for response
        monitor.client.loop_stop()
        return
    
    # Show summary if requested
    if args.summary:
        time.sleep(10)  # Collect data for 10 seconds
        monitor.show_device_summary()
        monitor.client.loop_stop()
        return
    
    try:
        monitor.start_monitoring()
    finally:
        monitor.client.loop_stop()

if __name__ == '__main__':
    main()
