#!/usr/bin/env python3
"""
HomeGuard Motion-Activated Light Controller
Integrates motion detector with relay control for automatic lighting

Features:
- Turns light ON when motion is detected
- Turns light OFF when motion is cleared
- Monitors both motion sensor and relay status
- Configurable delay and retry logic
- Automatic reconnection

Usage:
    python motion_light_controller.py
    python motion_light_controller.py --light-delay 10  # Keep light on 10s extra after motion cleared
"""

import json
import time
import argparse
import threading
from datetime import datetime, timedelta

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("❌ paho-mqtt not installed. Install with: pip install paho-mqtt")
    exit(1)

class MotionLightController:
    def __init__(self, broker_host="192.168.18.198", broker_port=1883, 
                 username="homeguard", password="pu2clr123456", 
                 light_delay=5):
        """
        Initialize Motion Light Controller
        
        Args:
            broker_host: MQTT broker IP
            broker_port: MQTT broker port  
            username: MQTT username
            password: MQTT password
            light_delay: Extra seconds to keep light on after motion cleared
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.username = username
        self.password = password
        self.light_delay = light_delay
        
        # MQTT Topics
        self.motion_topic = "home/motion1/motion"
        self.motion_status_topic = "home/motion1/status"
        self.relay_cmd_topic = "home/relay1/cmnd"
        self.relay_status_topic = "home/relay1/stat"
        
        # State tracking
        self.motion_detected = False
        self.light_on = False
        self.last_motion_time = None
        self.light_timer = None
        self.connected = False
        
        # Statistics
        self.motion_count = 0
        self.light_activations = 0
        self.start_time = datetime.now()
        
        # Setup MQTT client
        try:
            self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        except (AttributeError, TypeError):
            self.client = mqtt.Client()
        
        self.client.username_pw_set(username, password)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
    
    def on_connect(self, client, userdata, flags, rc, properties=None):
        """MQTT connection callback"""
        if rc == 0:
            self.connected = True
            print(f"✅ Connected to MQTT broker at {self.broker_host}")
            
            # Subscribe to motion and relay topics
            topics = [
                self.motion_topic,
                self.motion_status_topic,
                self.relay_status_topic,
                "home/motion1/heartbeat",
                "home/motion1/config"
            ]
            
            for topic in topics:
                client.subscribe(topic)
            
            print("📡 Subscribed to motion and relay topics")
            print("💡 Motion-activated light controller is ready!")
            print("=" * 60)
            
        else:
            print(f"❌ Failed to connect: {rc}")
    
    def on_disconnect(self, client, userdata, rc, properties=None):
        """MQTT disconnection callback"""
        self.connected = False
        print("📡 Disconnected from MQTT broker")
    
    def on_message(self, client, userdata, msg):
        """MQTT message callback"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            if topic == self.motion_topic:
                self.handle_motion_event(payload, timestamp)
            elif topic == self.relay_status_topic:
                self.handle_relay_status(payload, timestamp)
            elif topic == self.motion_status_topic:
                self.handle_motion_status(payload, timestamp)
            elif "heartbeat" in topic:
                self.handle_heartbeat(payload, timestamp)
            elif "config" in topic:
                print(f"⚙️ [{timestamp}] Motion sensor config: {payload}")
                
        except Exception as e:
            print(f"❌ Error processing message: {e}")
    
    def handle_motion_event(self, payload, timestamp):
        """Handle motion detection events"""
        try:
            data = json.loads(payload)
            event = data.get('event', 'Unknown')
            location = data.get('location', 'Unknown')
            device_id = data.get('device_id', 'Unknown')
            
            if event == "MOTION_DETECTED":
                self.motion_detected = True
                self.last_motion_time = datetime.now()
                self.motion_count += 1
                
                print(f"🚶 [{timestamp}] MOTION DETECTED at {location}")
                print(f"   Device: {device_id}")
                
                # Cancel any pending light-off timer
                if self.light_timer:
                    self.light_timer.cancel()
                    self.light_timer = None
                    print("   ⏰ Cancelled light-off timer")
                
                # Turn light ON if not already on
                if not self.light_on:
                    self.turn_light_on()
                else:
                    print("   💡 Light already ON")
                    
            elif event == "MOTION_CLEARED":
                self.motion_detected = False
                duration = data.get('duration', 'Unknown')
                
                print(f"✅ [{timestamp}] MOTION CLEARED at {location} (Duration: {duration})")
                
                # Start delayed light-off timer
                self.start_light_off_timer()
                
        except json.JSONDecodeError:
            print(f"🚶 [{timestamp}] Motion event (non-JSON): {payload}")
    
    def handle_relay_status(self, payload, timestamp):
        """Handle relay status updates"""
        status = payload.strip().upper()
        old_status = self.light_on
        
        if status == "ON":
            self.light_on = True
            if not old_status:
                print(f"💡 [{timestamp}] Light turned ON")
        elif status == "OFF":
            self.light_on = False
            if old_status:
                print(f"🌙 [{timestamp}] Light turned OFF")
        
        # Update statistics
        if self.light_on and not old_status:
            self.light_activations += 1
    
    def handle_motion_status(self, payload, timestamp):
        """Handle motion sensor status"""
        try:
            data = json.loads(payload)
            device_id = data.get('device_id', 'Unknown')
            location = data.get('location', 'Unknown')
            motion_status = data.get('motion', 'Unknown')
            
            print(f"📊 [{timestamp}] Motion sensor status: {motion_status} at {location}")
            
        except json.JSONDecodeError:
            print(f"📊 [{timestamp}] Motion status (non-JSON): {payload}")
    
    def handle_heartbeat(self, payload, timestamp):
        """Handle device heartbeat"""
        try:
            data = json.loads(payload)
            device_id = data.get('device_id', 'Unknown')
            status = data.get('status', 'Unknown')
            
            print(f"💓 [{timestamp}] Heartbeat: {device_id} ({status})")
            
        except json.JSONDecodeError:
            pass  # Ignore malformed heartbeats
    
    def turn_light_on(self):
        """Turn the light ON via relay"""
        if self.connected:
            self.client.publish(self.relay_cmd_topic, "ON")
            print("   📤 Sent command: Light ON")
        else:
            print("   ❌ Cannot send command: Not connected to MQTT")
    
    def turn_light_off(self):
        """Turn the light OFF via relay"""
        if self.connected:
            self.client.publish(self.relay_cmd_topic, "OFF")
            print("   📤 Sent command: Light OFF")
        else:
            print("   ❌ Cannot send command: Not connected to MQTT")
    
    def start_light_off_timer(self):
        """Start timer to turn light off after delay"""
        if self.light_timer:
            self.light_timer.cancel()
        
        if self.light_delay > 0:
            print(f"   ⏰ Starting {self.light_delay}s timer to turn light OFF")
            self.light_timer = threading.Timer(self.light_delay, self.delayed_light_off)
            self.light_timer.start()
        else:
            # Turn off immediately if no delay
            self.turn_light_off()
    
    def delayed_light_off(self):
        """Called by timer to turn light off"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Double-check no new motion was detected
        if not self.motion_detected:
            print(f"⏰ [{timestamp}] Timer expired - turning light OFF")
            self.turn_light_off()
        else:
            print(f"⏰ [{timestamp}] Timer expired but motion still detected - keeping light ON")
        
        self.light_timer = None
    
    def show_status(self):
        """Show current system status"""
        uptime = datetime.now() - self.start_time
        
        print("\n" + "=" * 60)
        print("📊 MOTION LIGHT CONTROLLER STATUS")
        print("=" * 60)
        print(f"🔗 MQTT Connected: {'✅ Yes' if self.connected else '❌ No'}")
        print(f"🚶 Motion Detected: {'✅ Yes' if self.motion_detected else '❌ No'}")
        print(f"💡 Light Status: {'🟢 ON' if self.light_on else '🔴 OFF'}")
        print(f"⏰ Light Delay: {self.light_delay} seconds")
        print(f"📈 Motion Events: {self.motion_count}")
        print(f"💡 Light Activations: {self.light_activations}")
        print(f"⏱️ Uptime: {str(uptime).split('.')[0]}")
        
        if self.last_motion_time:
            time_since_motion = datetime.now() - self.last_motion_time
            print(f"🕐 Last Motion: {str(time_since_motion).split('.')[0]} ago")
        
        if self.light_timer:
            print("⏰ Light-off timer: ACTIVE")
        
        print("=" * 60)
    
    def start_controller(self):
        """Start the motion light controller"""
        print("🔗 Connecting to MQTT broker...")
        print(f"💡 Light delay configured: {self.light_delay} seconds")
        print("📋 Available commands:")
        print(f"   Motion Status: mosquitto_pub -h {self.broker_host} -t home/motion1/cmnd -m 'STATUS' -u {self.username} -P {self.password}")
        print(f"   Manual Light ON: mosquitto_pub -h {self.broker_host} -t {self.relay_cmd_topic} -m 'ON' -u {self.username} -P {self.password}")
        print(f"   Manual Light OFF: mosquitto_pub -h {self.broker_host} -t {self.relay_cmd_topic} -m 'OFF' -u {self.username} -P {self.password}")
        print("")
        
        try:
            # Connect to broker
            self.client.connect(self.broker_host, self.broker_port, 60)
            
            # Start status display timer
            def show_periodic_status():
                while True:
                    time.sleep(30)  # Show status every 30 seconds
                    if self.connected:
                        self.show_status()
            
            status_thread = threading.Thread(target=show_periodic_status, daemon=True)
            status_thread.start()
            
            # Start main loop
            self.client.loop_forever()
            
        except KeyboardInterrupt:
            print("\n🛑 Motion light controller stopped by user")
            self.show_status()
        except Exception as e:
            print(f"❌ Error: {e}")
        finally:
            if self.light_timer:
                self.light_timer.cancel()
            self.client.disconnect()

def main():
    parser = argparse.ArgumentParser(description='HomeGuard Motion-Activated Light Controller')
    parser.add_argument('--broker', default='192.168.18.198', help='MQTT broker IP')
    parser.add_argument('--port', type=int, default=1883, help='MQTT broker port')
    parser.add_argument('--username', default='homeguard', help='MQTT username')
    parser.add_argument('--password', default='pu2clr123456', help='MQTT password')
    parser.add_argument('--light-delay', type=int, default=5, 
                       help='Seconds to keep light on after motion cleared (default: 5)')
    
    args = parser.parse_args()
    
    print("🏠 HomeGuard Motion-Activated Light Controller")
    print("=" * 50)
    
    controller = MotionLightController(
        broker_host=args.broker,
        broker_port=args.port,
        username=args.username,
        password=args.password,
        light_delay=args.light_delay
    )
    
    controller.start_controller()

if __name__ == '__main__':
    main()
