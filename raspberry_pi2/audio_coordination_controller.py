#!/usr/bin/env python3
"""
HomeGuard Audio Coordination Controller
Controls and monitors both ground floor (Pi3) and first floor (Pi2) audio systems
"""

import json
import time
import threading
import paho.mqtt.client as mqtt
from datetime import datetime

class AudioCoordinationController:
    def __init__(self):
        """Initialize the coordination controller"""
        
        # MQTT Configuration
        self.mqtt_broker = "192.168.18.236"
        self.mqtt_port = 1883
        self.mqtt_user = "homeguard"
        self.mqtt_pass = "pu2clr123456"
        
        # System topics
        self.topics = {
            # Ground floor (Pi3)
            'ground_cmd': 'home/audio/ground/cmnd',
            'ground_status': 'home/audio/ground/status',
            'ground_events': 'home/audio/ground/events',
            
            # First floor (Pi2)
            'first_cmd': 'home/audio/first/cmnd',
            'first_status': 'home/audio/first/status', 
            'first_events': 'home/audio/first/events',
            
            # Coordination
            'coordination': 'home/audio/coordination',
            'controller': 'home/audio/controller'
        }
        
        # System state
        self.ground_floor_online = False
        self.first_floor_online = False
        self.coordination_enabled = True
        
        # MQTT client
        self.mqtt_client = None
        
    def connect_mqtt(self):
        """Connect to MQTT broker"""
        try:
            self.mqtt_client = mqtt.Client()
            self.mqtt_client.username_pw_set(self.mqtt_user, self.mqtt_pass)
            
            # Set callbacks
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_message = self.on_mqtt_message
            
            print(f"🔗 Connecting to MQTT broker: {self.mqtt_broker}:{self.mqtt_port}")
            self.mqtt_client.connect(self.mqtt_broker, self.mqtt_port, 60)
            
            # Start MQTT loop
            self.mqtt_client.loop_start()
            return True
            
        except Exception as e:
            print(f"❌ MQTT connection failed: {e}")
            return False
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback when MQTT connection is established"""
        if rc == 0:
            print("✅ Audio Coordination Controller connected to MQTT")
            
            # Subscribe to all audio topics
            for topic_name, topic in self.topics.items():
                client.subscribe(topic)
                print(f"📡 Subscribed to {topic}")
                
            # Publish controller online status
            self.publish_controller_status("ONLINE")
            
        else:
            print(f"❌ MQTT connection failed with code {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """Handle incoming MQTT messages"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            # Parse JSON if possible
            try:
                data = json.loads(payload)
            except:
                data = {"message": payload}
            
            # Handle different message types
            if 'ground/status' in topic:
                self.handle_ground_status(data)
            elif 'first/status' in topic:
                self.handle_first_status(data)
            elif 'ground/events' in topic:
                self.handle_ground_event(data)
            elif 'first/events' in topic:
                self.handle_first_event(data)
                
        except Exception as e:
            print(f"❌ Error processing MQTT message: {e}")
    
    def handle_ground_status(self, data):
        """Handle ground floor status updates"""
        status = data.get('status', 'UNKNOWN')
        device_id = data.get('device_id', 'ground_floor')
        
        if status == 'ONLINE':
            self.ground_floor_online = True
            print(f"✅ Ground floor audio system online: {device_id}")
        elif status == 'OFFLINE':
            self.ground_floor_online = False
            print(f"❌ Ground floor audio system offline: {device_id}")
            
    def handle_first_status(self, data):
        """Handle first floor status updates"""
        status = data.get('status', 'UNKNOWN')
        device_id = data.get('device_id', 'first_floor')
        
        if status == 'ONLINE':
            self.first_floor_online = True
            print(f"✅ First floor audio system online: {device_id}")
        elif status == 'OFFLINE':
            self.first_floor_online = False
            print(f"❌ First floor audio system offline: {device_id}")
    
    def handle_ground_event(self, data):
        """Handle ground floor events and coordinate with first floor"""
        event_type = data.get('event_type', 'UNKNOWN')
        
        if event_type == 'ROUTINE_STARTED' and self.coordination_enabled:
            routine = data.get('source', 'unknown_routine')
            print(f"🤝 Coordinating: Ground floor started {routine}")
            
            # Coordinate with first floor (delayed response)
            self.coordinate_routine_response('first', routine, delay=180)  # 3 minute delay
            
    def handle_first_event(self, data):
        """Handle first floor events"""
        event_type = data.get('event_type', 'UNKNOWN')
        print(f"📊 First floor event: {event_type}")
    
    def coordinate_routine_response(self, target_floor, routine, delay=120):
        """Coordinate routine response between floors"""
        def delayed_response():
            time.sleep(delay)
            
            if target_floor == 'first' and self.first_floor_online:
                # Trigger similar routine on first floor
                cmd_data = {
                    "action": "ROUTINE",
                    "routine": routine,
                    "source": "coordination_controller"
                }
                self.mqtt_client.publish(self.topics['first_cmd'], json.dumps(cmd_data))
                print(f"📤 Sent coordinated routine '{routine}' to first floor (delayed {delay}s)")
                
            elif target_floor == 'ground' and self.ground_floor_online:
                # Trigger similar routine on ground floor
                cmd_data = {
                    "action": "ROUTINE", 
                    "routine": routine,
                    "source": "coordination_controller"
                }
                self.mqtt_client.publish(self.topics['ground_cmd'], json.dumps(cmd_data))
                print(f"📤 Sent coordinated routine '{routine}' to ground floor (delayed {delay}s)")
        
        # Start delayed response in separate thread
        threading.Thread(target=delayed_response, daemon=True).start()
    
    def publish_controller_status(self, status):
        """Publish controller status"""
        if self.mqtt_client:
            status_data = {
                "controller": "audio_coordination",
                "status": status,
                "timestamp": datetime.now().isoformat(),
                "ground_floor_online": self.ground_floor_online,
                "first_floor_online": self.first_floor_online,
                "coordination_enabled": self.coordination_enabled
            }
            self.mqtt_client.publish(self.topics['controller'], json.dumps(status_data))
    
    def send_command_to_floor(self, floor, command):
        """Send command to specific floor"""
        if floor.lower() == 'ground' and self.ground_floor_online:
            topic = self.topics['ground_cmd']
        elif floor.lower() == 'first' and self.first_floor_online:
            topic = self.topics['first_cmd']
        else:
            print(f"❌ Floor '{floor}' not available")
            return False
            
        self.mqtt_client.publish(topic, command)
        print(f"📤 Sent command to {floor} floor: {command}")
        return True
    
    def send_command_to_all_floors(self, command):
        """Send command to all online floors"""
        sent_count = 0
        
        if self.ground_floor_online:
            self.mqtt_client.publish(self.topics['ground_cmd'], command)
            sent_count += 1
            
        if self.first_floor_online:
            self.mqtt_client.publish(self.topics['first_cmd'], command)
            sent_count += 1
            
        print(f"📤 Sent command to {sent_count} floors: {command}")
        return sent_count > 0
    
    def emergency_alert(self, alert_type="security_breach"):
        """Send emergency alert to all floors"""
        print(f"🚨 EMERGENCY ALERT: {alert_type}")
        
        emergency_cmd = {
            "action": "EMERGENCY",
            "type": alert_type,
            "source": "coordination_controller",
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_command_to_all_floors(json.dumps(emergency_cmd))
    
    def set_house_mode(self, mode):
        """Set mode for entire house"""
        print(f"🏠 Setting house mode: {mode}")
        
        mode_cmd = {
            "action": "MODE",
            "mode": mode,
            "source": "coordination_controller"
        }
        
        self.send_command_to_all_floors(json.dumps(mode_cmd))
    
    def status_report(self):
        """Print current system status"""
        print("\n🏠 HomeGuard Audio System Status")
        print("=" * 40)
        print(f"Ground Floor (Pi3): {'🟢 Online' if self.ground_floor_online else '🔴 Offline'}")
        print(f"First Floor (Pi2):  {'🟢 Online' if self.first_floor_online else '🔴 Offline'}")
        print(f"Coordination:       {'🟢 Enabled' if self.coordination_enabled else '🔴 Disabled'}")
        print("=" * 40)
    
    def run_interactive_console(self):
        """Run interactive console for manual control"""
        print("\n🎮 HomeGuard Audio Coordination Console")
        print("=" * 45)
        print("Commands:")
        print("  status                    - Show system status")
        print("  ground <cmd>             - Send command to ground floor")
        print("  first <cmd>              - Send command to first floor") 
        print("  all <cmd>                - Send command to all floors")
        print("  mode <home|away|night>   - Set house mode")
        print("  emergency <type>         - Trigger emergency alert")
        print("  coord <on|off>           - Enable/disable coordination")
        print("  quit                     - Exit console")
        print("=" * 45)
        
        while True:
            try:
                cmd = input("\n🎛️  HomeGuard> ").strip().lower()
                
                if cmd == 'quit' or cmd == 'exit':
                    break
                elif cmd == 'status':
                    self.status_report()
                elif cmd.startswith('ground '):
                    command = cmd[7:]
                    self.send_command_to_floor('ground', command)
                elif cmd.startswith('first '):
                    command = cmd[6:]
                    self.send_command_to_floor('first', command)
                elif cmd.startswith('all '):
                    command = cmd[4:]
                    self.send_command_to_all_floors(command)
                elif cmd.startswith('mode '):
                    mode = cmd[5:]
                    if mode in ['home', 'away', 'night', 'vacation']:
                        self.set_house_mode(mode)
                    else:
                        print("❌ Invalid mode. Use: home, away, night, vacation")
                elif cmd.startswith('emergency'):
                    parts = cmd.split()
                    alert_type = parts[1] if len(parts) > 1 else "security_breach"
                    self.emergency_alert(alert_type)
                elif cmd == 'coord on':
                    self.coordination_enabled = True
                    print("✅ Coordination enabled")
                elif cmd == 'coord off':
                    self.coordination_enabled = False
                    print("❌ Coordination disabled")
                elif cmd == 'help' or cmd == '?':
                    print("Available commands listed above ⬆️")
                else:
                    print("❓ Unknown command. Type 'help' for available commands.")
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"❌ Error: {e}")
                
        print("\n👋 Goodbye!")
    
    def run(self):
        """Main run loop"""
        print("🎵 HomeGuard Audio Coordination Controller")
        print("=" * 45)
        
        # Connect to MQTT
        if not self.connect_mqtt():
            print("❌ Failed to connect to MQTT broker")
            return False
        
        # Wait a moment for connections
        time.sleep(2)
        
        # Show initial status
        self.status_report()
        
        # Start interactive console
        self.run_interactive_console()
        
        # Cleanup
        if self.mqtt_client:
            self.publish_controller_status("OFFLINE")
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
            
        print("✅ Audio coordination controller stopped")
        return True

def main():
    """Main function"""
    controller = AudioCoordinationController()
    controller.run()

if __name__ == "__main__":
    main()
