#!/usr/bin/env python3
"""
HomeGuard Motion Sensor Monitor - Enhanced with TLS Support
Real-time monitoring of multiple motion sensors with heartbeat, status and motion events

Features:
- Monitor multiple sensors simultaneously
- Display heartbeat status for each location
- Show motion events in real-time
- Track device status and connectivity
- Configurable sensor locations
- MQTT integration with authentication
- TLS/SSL encryption support
- Certificate validation

Usage:
    python motion_sensor_monitor.py
    python motion_sensor_monitor.py --broker 192.168.18.236 --tls --port 8883
    python motion_sensor_monitor.py --locations Garagem,Varanda,Mezanino
"""

import json
import time
import ssl
import argparse
import threading
from datetime import datetime, timedelta
from collections import defaultdict
from pathlib import Path

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("❌ paho-mqtt not installed. Install with: pip install paho-mqtt")
    exit(1)

class MotionSensorMonitor:
    def __init__(self, broker_host="192.168.18.236", broker_port=1883, 
                 username="homeguard", password="pu2clr123456", 
                 locations=None, use_tls=False, ca_cert_path=None, 
                 cert_path=None, key_path=None):
        """
        Initialize Motion Sensor Monitor
        
        Args:
            broker_host: MQTT broker IP
            broker_port: MQTT broker port  
            username: MQTT username
            password: MQTT password
            locations: List of sensor locations to monitor
            use_tls: Enable TLS/SSL encryption
            ca_cert_path: Path to CA certificate file
            cert_path: Path to client certificate file (optional)
            key_path: Path to client key file (optional)
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.username = username
        self.password = password
        self.use_tls = use_tls
        self.ca_cert_path = ca_cert_path
        self.cert_path = cert_path
        self.key_path = key_path
        
        # Default sensor locations if none provided
        if locations is None:
            self.locations = ["Garagem", "Area_Servico", "Varanda", "Mezanino", "Ad_Hoc"]
        else:
            self.locations = locations
        
        # MQTT topic mapping
        self.location_to_topic = {
            "Garagem": "motion_garagem",
            "Area_Servico": "motion_area_servico", 
            "Varanda": "motion_varanda",
            "Mezanino": "motion_mezanino",
            "Ad_Hoc": "motion_adhoc"
        }
        
        # Sensor data storage
        self.sensors = {}
        for location in self.locations:
            self.sensors[location] = {
                "device_id": None,
                "ip": None,
                "mac": None,
                "last_heartbeat": None,
                "last_motion": None,
                "motion_status": "UNKNOWN",
                "online": False,
                "rssi": None,
                "uptime": None,
                "motion_count": 0,
                "last_seen": None,
                "secure": None
            }
        
        # Statistics
        self.start_time = datetime.now()
        self.total_motion_events = 0
        self.connected = False
        
        # Setup MQTT client
        try:
            self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        except (AttributeError, TypeError):
            self.client = mqtt.Client()
        
        self.client.username_pw_set(username, password)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
        
        # Configure TLS if enabled
        if self.use_tls:
            self._setup_tls()
    
    def _setup_tls(self):
        """Configure TLS/SSL settings"""
        try:
            # Create SSL context
            context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
            
            if self.ca_cert_path and Path(self.ca_cert_path).exists():
                print(f"🔐 Loading CA certificate: {self.ca_cert_path}")
                context.load_verify_locations(self.ca_cert_path)
            else:
                print("⚠️ CA certificate not provided - using default system certificates")
                # For development/testing - remove in production
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
            
            # Load client certificates if provided
            if self.cert_path and self.key_path:
                if Path(self.cert_path).exists() and Path(self.key_path).exists():
                    print(f"🔑 Loading client certificates: {self.cert_path}")
                    context.load_cert_chain(self.cert_path, self.key_path)
                else:
                    print("⚠️ Client certificate files not found")
            
            # Set TLS context
            self.client.tls_set_context(context)
            print("✅ TLS/SSL configured")
            
        except Exception as e:
            print(f"❌ TLS setup error: {e}")
            raise
    
    def on_connect(self, client, userdata, flags, rc, properties=None):
        """MQTT connection callback"""
        if rc == 0:
            self.connected = True
            tls_status = "🔐 TLS" if self.use_tls else "🔓 Plain"
            print(f"✅ Connected to MQTT broker at {self.broker_host}:{self.broker_port} ({tls_status})")
            
            # Subscribe to all sensor topics
            for location in self.locations:
                if location in self.location_to_topic:
                    topic_base = f"home/{self.location_to_topic[location]}"
                    topics = [
                        f"{topic_base}/status",
                        f"{topic_base}/motion", 
                        f"{topic_base}/heartbeat",
                        f"{topic_base}/config"
                    ]
                    
                    for topic in topics:
                        client.subscribe(topic)
                        print(f"📡 Subscribed to {topic}")
            
            print("=" * 80)
            print("🏠 HomeGuard Motion Sensor Monitor Started")
            print("=" * 80)
            print(f"📍 Monitoring locations: {', '.join(self.locations)}")
            print(f"🔐 Security: {'TLS/SSL Enabled' if self.use_tls else 'Plain text'}")
            print(f"🕐 Started at: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print("=" * 80)
            
        else:
            error_messages = {
                1: "Connection refused - incorrect protocol version",
                2: "Connection refused - invalid client identifier",
                3: "Connection refused - server unavailable",
                4: "Connection refused - bad username or password",
                5: "Connection refused - not authorized"
            }
            error_msg = error_messages.get(rc, f"Unknown error ({rc})")
            print(f"❌ Failed to connect: {error_msg}")
    
    def on_disconnect(self, client, userdata, rc, properties=None):
        """MQTT disconnection callback"""
        self.connected = False
        if rc != 0:
            print("📡 Unexpected disconnection from MQTT broker")
        else:
            print("📡 Disconnected from MQTT broker")
    
    def on_message(self, client, userdata, msg):
        """MQTT message callback"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            timestamp = datetime.now()
            
            # Parse topic to extract location
            location = self.extract_location_from_topic(topic)
            if not location:
                return
                
            # Handle different message types
            if "/status" in topic:
                self.handle_status_message(location, payload, timestamp)
            elif "/motion" in topic:
                self.handle_motion_message(location, payload, timestamp)
            elif "/heartbeat" in topic:
                self.handle_heartbeat_message(location, payload, timestamp)
            elif "/config" in topic:
                self.handle_config_message(location, payload, timestamp)
                
        except Exception as e:
            print(f"❌ Error processing message: {e}")
    
    def extract_location_from_topic(self, topic):
        """Extract location from MQTT topic"""
        for location, topic_suffix in self.location_to_topic.items():
            if topic_suffix in topic:
                return location
        return None
    
    def handle_status_message(self, location, payload, timestamp):
        """Handle device status messages"""
        try:
            if payload == "ONLINE":
                self.sensors[location]["online"] = True
                self.sensors[location]["last_seen"] = timestamp
                self.print_event("🟢", f"{location} device came ONLINE", timestamp)
                return
                
            data = json.loads(payload)
            sensor = self.sensors[location]
            
            # Update sensor information
            sensor["device_id"] = data.get("device_id")
            sensor["ip"] = data.get("ip")
            sensor["mac"] = data.get("mac")
            sensor["motion_status"] = data.get("motion", "UNKNOWN")
            sensor["online"] = True
            sensor["last_seen"] = timestamp
            sensor["rssi"] = data.get("rssi")
            sensor["uptime"] = data.get("uptime")
            sensor["secure"] = data.get("secure", False)
            
            security_info = "🔐" if sensor["secure"] else "🔓"
            self.print_event("📊", f"{location} status updated {security_info}", timestamp, data)
            
        except json.JSONDecodeError:
            self.print_event("📊", f"{location} status: {payload}", timestamp)
    
    def handle_motion_message(self, location, payload, timestamp):
        """Handle motion detection messages"""
        try:
            data = json.loads(payload)
            event = data.get("event", "UNKNOWN")
            device_id = data.get("device_id", "Unknown")
            rssi = data.get("rssi", "Unknown")
            
            sensor = self.sensors[location]
            sensor["last_motion"] = timestamp
            sensor["last_seen"] = timestamp
            
            if event == "MOTION_DETECTED":
                sensor["motion_status"] = "DETECTED"
                sensor["motion_count"] += 1
                self.total_motion_events += 1
                
                self.print_event("🚶", f"MOTION DETECTED at {location}", timestamp, {
                    "device_id": device_id,
                    "rssi": rssi
                })
                
            elif event == "MOTION_CLEARED":
                sensor["motion_status"] = "CLEAR"
                duration = data.get("duration", "Unknown")
                
                self.print_event("✅", f"MOTION CLEARED at {location}", timestamp, {
                    "device_id": device_id,
                    "duration": duration
                })
                
        except json.JSONDecodeError:
            self.print_event("🚶", f"{location} motion: {payload}", timestamp)
    
    def handle_heartbeat_message(self, location, payload, timestamp):
        """Handle heartbeat messages"""
        try:
            data = json.loads(payload)
            sensor = self.sensors[location]
            
            sensor["last_heartbeat"] = timestamp
            sensor["last_seen"] = timestamp
            sensor["online"] = True
            sensor["secure"] = data.get("secure", False)
            
            device_id = data.get("device_id", "Unknown")
            status = data.get("status", "Unknown")
            rssi = data.get("rssi", "Unknown")
            
            security_icon = "🔐" if sensor["secure"] else "🔓"
            
            self.print_event("💓", f"{location} heartbeat {security_icon}", timestamp, {
                "device_id": device_id,
                "status": status,
                "rssi": rssi
            }, verbose=False)
            
        except json.JSONDecodeError:
            self.print_event("💓", f"{location} heartbeat: {payload}", timestamp, verbose=False)
    
    def handle_config_message(self, location, payload, timestamp):
        """Handle configuration messages"""
        self.print_event("⚙️", f"{location} config: {payload}", timestamp)
    
    def print_event(self, icon, message, timestamp, data=None, verbose=True):
        """Print formatted event message"""
        time_str = timestamp.strftime("%H:%M:%S")
        
        if verbose or not hasattr(self, '_last_heartbeat_time') or \
           (timestamp - getattr(self, '_last_heartbeat_time', timestamp)).seconds >= 30:
            
            print(f"{icon} [{time_str}] {message}")
            
            if data and verbose:
                for key, value in data.items():
                    print(f"   {key}: {value}")
            
            if "heartbeat" in message.lower():
                self._last_heartbeat_time = timestamp
    
    def show_status_summary(self):
        """Show comprehensive status summary"""
        current_time = datetime.now()
        uptime = current_time - self.start_time
        
        print("\n" + "=" * 80)
        print("📊 MOTION SENSOR MONITOR STATUS")
        print("=" * 80)
        print(f"🔗 MQTT Connected: {'✅ Yes' if self.connected else '❌ No'}")
        print(f"🔐 Security: {'TLS/SSL Enabled' if self.use_tls else 'Plain text'}")
        print(f"📡 Broker: {self.broker_host}:{self.broker_port}")
        print(f"⏱️ Monitor Uptime: {str(uptime).split('.')[0]}")
        print(f"📈 Total Motion Events: {self.total_motion_events}")
        print(f"🕐 Current Time: {current_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # Sensor status table
        print("📍 SENSOR STATUS:")
        print("-" * 95)
        print(f"{'Location':<15} {'Status':<8} {'Security':<8} {'Motion':<10} {'Last Seen':<12} {'IP':<15} {'RSSI'}")
        print("-" * 95)
        
        for location in self.locations:
            sensor = self.sensors[location]
            
            # Determine online status
            if sensor["last_seen"]:
                time_since_seen = (current_time - sensor["last_seen"]).seconds
                if time_since_seen < 120:  # 2 minutes
                    status = "🟢 ONLINE"
                elif time_since_seen < 300:  # 5 minutes
                    status = "🟡 STALE"
                else:
                    status = "🔴 OFFLINE"
            else:
                status = "❓ UNKNOWN"
            
            # Security status
            if sensor["secure"] is True:
                security = "🔐 TLS"
            elif sensor["secure"] is False:
                security = "🔓 Plain"
            else:
                security = "❓ Unknown"
            
            # Motion status
            motion = sensor["motion_status"]
            if motion == "DETECTED":
                motion_icon = "🔴 DETECTED"
            elif motion == "CLEAR":
                motion_icon = "🟢 CLEAR"
            else:
                motion_icon = "❓ UNKNOWN"
            
            # Last seen time
            if sensor["last_seen"]:
                last_seen = sensor["last_seen"].strftime("%H:%M:%S")
            else:
                last_seen = "Never"
            
            # IP and RSSI
            ip = sensor["ip"] or "Unknown"
            rssi = sensor["rssi"] or "Unknown"
            
            print(f"{location:<15} {status:<8} {security:<8} {motion_icon:<10} {last_seen:<12} {ip:<15} {rssi}")
        
        print("-" * 95)
        
        # Individual sensor details
        print("\n📋 DETAILED SENSOR INFO:")
        for location in self.locations:
            sensor = self.sensors[location]
            if sensor["device_id"]:
                print(f"\n🏠 {location}:")
                print(f"   Device ID: {sensor['device_id']}")
                print(f"   MAC: {sensor['mac']}")
                print(f"   Security: {'🔐 TLS Enabled' if sensor['secure'] else '🔓 Plain text'}")
                print(f"   Motion Events: {sensor['motion_count']}")
                if sensor["last_heartbeat"]:
                    heartbeat_age = (current_time - sensor["last_heartbeat"]).seconds
                    print(f"   Last Heartbeat: {heartbeat_age}s ago")
                if sensor["last_motion"]:
                    motion_age = (current_time - sensor["last_motion"]).seconds
                    print(f"   Last Motion: {motion_age}s ago")
        
        print("=" * 80)
    
    def request_status_from_all_sensors(self):
        """Request status from all sensors"""
        if not self.connected:
            print("❌ Not connected to MQTT broker")
            return
        
        print("📤 Requesting status from all sensors...")
        for location in self.locations:
            if location in self.location_to_topic:
                topic = f"home/{self.location_to_topic[location]}/cmnd"
                self.client.publish(topic, "STATUS")
                print(f"   📤 Sent STATUS request to {location}")
                time.sleep(0.5)  # Small delay between requests
    
    def start_monitor(self):
        """Start the motion sensor monitor"""
        print("🏠 HomeGuard Motion Sensor Monitor - Enhanced Security")
        print("=" * 60)
        print(f"🔗 Connecting to MQTT broker at {self.broker_host}:{self.broker_port}")
        print(f"🔐 Security: {'TLS/SSL Enabled' if self.use_tls else 'Plain text'}")
        print(f"📍 Monitoring locations: {', '.join(self.locations)}")
        print("📋 Available commands:")
        print("   's' - Show status summary")
        print("   'r' - Request status from all sensors")
        print("   'q' - Quit monitor")
        print("")
        
        try:
            # Connect to broker
            self.client.connect(self.broker_host, self.broker_port, 60)
            
            # Start periodic status updates
            def show_periodic_status():
                while True:
                    time.sleep(120)  # Show status every 2 minutes
                    if self.connected:
                        self.show_status_summary()
            
            status_thread = threading.Thread(target=show_periodic_status, daemon=True)
            status_thread.start()
            
            # Start interactive command handler
            def command_handler():
                while True:
                    try:
                        cmd = input().lower().strip()
                        if cmd == 's':
                            self.show_status_summary()
                        elif cmd == 'r':
                            self.request_status_from_all_sensors()
                        elif cmd == 'q':
                            print("🛑 Stopping monitor...")
                            break
                    except (EOFError, KeyboardInterrupt):
                        break
            
            cmd_thread = threading.Thread(target=command_handler, daemon=True)
            cmd_thread.start()
            
            # Start main MQTT loop
            self.client.loop_forever()
            
        except KeyboardInterrupt:
            print("\n🛑 Motion sensor monitor stopped by user")
            self.show_status_summary()
        except Exception as e:
            print(f"❌ Error: {e}")
        finally:
            self.client.disconnect()

def main():
    parser = argparse.ArgumentParser(description='HomeGuard Motion Sensor Monitor - Enhanced Security')
    parser.add_argument('--broker', default='192.168.18.236', help='MQTT broker IP')
    parser.add_argument('--port', type=int, default=1883, help='MQTT broker port (1883 for plain, 8883 for TLS)')
    parser.add_argument('--username', default='homeguard', help='MQTT username')
    parser.add_argument('--password', default='pu2clr123456', help='MQTT password')
    parser.add_argument('--locations', default=None, 
                       help='Comma-separated list of locations to monitor (default: all)')
    parser.add_argument('--tls', action='store_true', help='Enable TLS/SSL encryption')
    parser.add_argument('--ca-cert', default='/etc/mosquitto/certs/ca.crt', 
                       help='Path to CA certificate file')
    parser.add_argument('--cert', default=None, help='Path to client certificate file')
    parser.add_argument('--key', default=None, help='Path to client key file')
    
    args = parser.parse_args()
    
    # Adjust default port for TLS
    if args.tls and args.port == 1883:
        args.port = 8883
        print("🔐 TLS enabled - switching to port 8883")
    
    # Parse locations if provided
    locations = None
    if args.locations:
        locations = [loc.strip() for loc in args.locations.split(',')]
    
    monitor = MotionSensorMonitor(
        broker_host=args.broker,
        broker_port=args.port,
        username=args.username,
        password=args.password,
        locations=locations,
        use_tls=args.tls,
        ca_cert_path=args.ca_cert if args.tls else None,
        cert_path=args.cert,
        key_path=args.key
    )
    
    monitor.start_monitor()

if __name__ == '__main__':
    main()
