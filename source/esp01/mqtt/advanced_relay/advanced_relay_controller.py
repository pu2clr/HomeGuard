#!/usr/bin/env python3
"""
HomeGuard Advanced Relay Controller
Python script for controlling and monitoring the ESP-01S advanced relay module

Features:
- Real-time relay control (ON/OFF/TOGGLE)
- Device status monitoring with JSON parsing
- Heartbeat monitoring
- Configuration management (location, heartbeat settings)
- Event logging and history
- Interactive CLI interface
- Automatic reconnection handling

Based on the advanced_relay.ino configuration:
- Broker: 192.168.18.6
- User: homeguard  
- Pass: pu2clr123456
- Device IP: 192.168.18.192

Usage:
    python advanced_relay_controller.py
    python advanced_relay_controller.py --monitor-only
    python advanced_relay_controller.py --device relay_abc123 --location Kitchen
"""

import json
import argparse
import sys
import time
import threading
from datetime import datetime
from typing import Dict, List, Optional
import paho.mqtt.client as mqtt


class AdvancedRelayController:
    def __init__(self, broker_host="192.168.18.6", broker_port=1883, 
                 username="homeguard", password="pu2clr123456", device_prefix="relay1"):
        """
        Initialize Advanced Relay Controller
        
        Args:
            broker_host: MQTT broker IP
            broker_port: MQTT broker port
            username: MQTT username
            password: MQTT password
            device_prefix: Device prefix for MQTT topics (e.g., relay1)
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.username = username
        self.password = password
        self.device_prefix = device_prefix
        
        # MQTT Topics
        self.topics = {
            'cmd': f"home/{device_prefix}/cmnd",
            'status': f"home/{device_prefix}/status",
            'relay': f"home/{device_prefix}/relay",
            'heartbeat': f"home/{device_prefix}/heartbeat",
            'config': f"home/{device_prefix}/config"
        }
        
        # Device state
        self.device_info = {}
        self.relay_state = None
        self.last_heartbeat = None
        self.event_history = []
        self.connected = False
        self.monitoring = False
        
        # MQTT Client setup
        self.client = mqtt.Client()
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message
        self.client.username_pw_set(username, password)
        
        # Threading for CLI
        self.input_thread = None
        self.running = False
        
    def _on_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            self.connected = True
            print(f"✅ Connected to MQTT broker at {self.broker_host}")
            
            # Subscribe to all device topics
            for topic_name, topic in self.topics.items():
                if topic_name != 'cmd':  # Don't subscribe to command topic
                    client.subscribe(topic)
                    print(f"📡 Subscribed to {topic}")
            
            # Request initial status
            self.request_status()
            
        else:
            self.connected = False
            print(f"❌ Failed to connect to MQTT broker: {rc}")
    
    def _on_disconnect(self, client, userdata, rc):
        """MQTT disconnection callback"""
        self.connected = False
        print("📡 Disconnected from MQTT broker")
    
    def _on_message(self, client, userdata, msg):
        """MQTT message callback"""
        try:
            topic = msg.topic
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # Determine message type based on topic
            if topic == self.topics['status']:
                self._handle_status_message(msg.payload.decode(), timestamp)
            elif topic == self.topics['relay']:
                self._handle_relay_event(msg.payload.decode(), timestamp)
            elif topic == self.topics['heartbeat']:
                self._handle_heartbeat(msg.payload.decode(), timestamp)
            elif topic == self.topics['config']:
                self._handle_config_response(msg.payload.decode(), timestamp)
            else:
                print(f"[{timestamp}] Unknown topic {topic}: {msg.payload.decode()}")
                
        except Exception as e:
            print(f"❌ Error processing message: {e}")
    
    def _handle_status_message(self, payload, timestamp):
        """Handle device status messages"""
        try:
            if payload == "ONLINE":
                print(f"🟢 [{timestamp}] Device came online")
                return
            elif payload == "RESETTING":
                print(f"🔄 [{timestamp}] Device is resetting...")
                return
                
            data = json.loads(payload)
            self.device_info = data
            
            device_id = data.get('device_id', 'Unknown')
            location = data.get('location', 'Unknown')
            ip = data.get('ip', 'Unknown')
            mac = data.get('mac', 'Unknown')
            relay_state = data.get('relay_state', 'Unknown')
            last_change = data.get('last_change', 'Unknown')
            uptime = data.get('uptime', 'Unknown')
            heartbeat_enabled = data.get('heartbeat_enabled', 'Unknown')
            heartbeat_interval = data.get('heartbeat_interval', 'Unknown')
            rssi = data.get('rssi', 'Unknown')
            
            self.relay_state = relay_state
            
            print(f"\n📊 [{timestamp}] DEVICE STATUS")
            print(f"   🆔 Device ID: {device_id}")
            print(f"   📍 Location: {location}")
            print(f"   🌐 IP Address: {ip}")
            print(f"   📱 MAC Address: {mac}")
            print(f"   🔌 Relay State: {relay_state}")
            print(f"   🕐 Last Change: {last_change}")
            print(f"   ⏱️  Uptime: {uptime}")
            print(f"   💓 Heartbeat: {heartbeat_enabled} ({heartbeat_interval})")
            print(f"   📶 Signal: {rssi}")
            
        except json.JSONDecodeError:
            print(f"📊 [{timestamp}] Status (non-JSON): {payload}")
    
    def _handle_relay_event(self, payload, timestamp):
        """Handle relay state change events"""
        try:
            data = json.loads(payload)
            device_id = data.get('device_id', 'Unknown')
            location = data.get('location', 'Unknown')
            event = data.get('event', 'Unknown')
            state = data.get('state', 'Unknown')
            reason = data.get('reason', '')
            rssi = data.get('rssi', 'Unknown')
            
            self.relay_state = state
            
            # Add to event history
            event_record = {
                'timestamp': timestamp,
                'device_id': device_id,
                'event': event,
                'state': state,
                'reason': reason,
                'rssi': rssi
            }
            self.event_history.append(event_record)
            
            # Keep only last 50 events
            if len(self.event_history) > 50:
                self.event_history.pop(0)
            
            emoji = "🟢" if state == "ON" else "🔴"
            reason_text = f" ({reason})" if reason else ""
            
            print(f"{emoji} [{timestamp}] RELAY {event} at {location}")
            print(f"   🔌 State: {state}{reason_text}")
            print(f"   📶 Signal: {rssi}")
            
        except json.JSONDecodeError:
            print(f"🔌 [{timestamp}] Relay event (non-JSON): {payload}")
    
    def _handle_heartbeat(self, payload, timestamp):
        """Handle device heartbeat messages"""
        try:
            data = json.loads(payload)
            device_id = data.get('device_id', 'Unknown')
            location = data.get('location', 'Unknown')
            status = data.get('status', 'Unknown')
            relay_state = data.get('relay_state', 'Unknown')
            uptime = data.get('uptime', 'Unknown')
            rssi = data.get('rssi', 'Unknown')
            
            self.last_heartbeat = timestamp
            self.relay_state = relay_state
            
            if self.monitoring:
                print(f"💓 [{timestamp}] HEARTBEAT - {device_id} at {location}")
                print(f"   ✅ Status: {status}, Relay: {relay_state}, Uptime: {uptime}, Signal: {rssi}")
            
        except json.JSONDecodeError:
            print(f"💓 [{timestamp}] Heartbeat (non-JSON): {payload}")
    
    def _handle_config_response(self, payload, timestamp):
        """Handle configuration response messages"""
        print(f"⚙️ [{timestamp}] CONFIG: {payload}")
    
    def send_command(self, command):
        """Send command to the relay"""
        if not self.connected:
            print("❌ Not connected to MQTT broker")
            return False
            
        try:
            self.client.publish(self.topics['cmd'], command)
            print(f"📤 Sent command: {command}")
            return True
        except Exception as e:
            print(f"❌ Error sending command: {e}")
            return False
    
    def relay_on(self):
        """Turn relay ON"""
        return self.send_command("ON")
    
    def relay_off(self):
        """Turn relay OFF"""
        return self.send_command("OFF")
    
    def relay_toggle(self):
        """Toggle relay state"""
        return self.send_command("TOGGLE")
    
    def request_status(self):
        """Request device status"""
        return self.send_command("STATUS")
    
    def set_location(self, location):
        """Set device location"""
        return self.send_command(f"LOCATION_{location}")
    
    def enable_heartbeat(self):
        """Enable heartbeat"""
        return self.send_command("HEARTBEAT_ON")
    
    def disable_heartbeat(self):
        """Disable heartbeat"""
        return self.send_command("HEARTBEAT_OFF")
    
    def set_heartbeat_interval(self, seconds):
        """Set heartbeat interval in seconds"""
        if 10 <= seconds <= 300:
            return self.send_command(f"HEARTBEAT_{seconds}")
        else:
            print("❌ Heartbeat interval must be between 10 and 300 seconds")
            return False
    
    def enable_status_led(self):
        """Enable status LED"""
        return self.send_command("LED_ON")
    
    def disable_status_led(self):
        """Disable status LED"""
        return self.send_command("LED_OFF")
    
    def restart_device(self):
        """Restart the device"""
        print("⚠️ Restarting device...")
        return self.send_command("RESET")
    
    def connect(self):
        """Connect to MQTT broker"""
        try:
            print(f"🔄 Connecting to MQTT broker at {self.broker_host}:{self.broker_port}")
            self.client.connect(self.broker_host, self.broker_port, 60)
            self.client.loop_start()
            return True
        except Exception as e:
            print(f"❌ Connection failed: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from MQTT broker"""
        self.running = False
        if self.input_thread and self.input_thread.is_alive():
            self.input_thread.join(timeout=1)
        self.client.loop_stop()
        self.client.disconnect()
        print("👋 Disconnected from MQTT broker")
    
    def show_device_info(self):
        """Display current device information"""
        if not self.device_info:
            print("❌ No device information available. Try requesting status first.")
            return
            
        print("\n" + "="*50)
        print("📱 ADVANCED RELAY DEVICE INFORMATION")
        print("="*50)
        
        for key, value in self.device_info.items():
            key_formatted = key.replace('_', ' ').title()
            print(f"{key_formatted:20}: {value}")
        
        if self.last_heartbeat:
            print(f"{'Last Heartbeat':20}: {self.last_heartbeat}")
        
        print("="*50)
    
    def show_event_history(self, count=10):
        """Display recent relay events"""
        if not self.event_history:
            print("❌ No events recorded yet")
            return
            
        print(f"\n📜 LAST {min(count, len(self.event_history))} RELAY EVENTS")
        print("-" * 70)
        
        recent_events = self.event_history[-count:]
        for event in recent_events:
            timestamp = event['timestamp']
            event_type = event['event']
            state = event['state']
            reason = event.get('reason', '')
            reason_text = f" ({reason})" if reason else ""
            
            emoji = "🟢" if state == "ON" else "🔴"
            print(f"{emoji} {timestamp} - {event_type}: {state}{reason_text}")
    
    def interactive_cli(self):
        """Run interactive command line interface"""
        self.running = True
        self.monitoring = True
        
        print("\n" + "="*60)
        print("🎛️  HomeGuard Advanced Relay Controller - Interactive Mode")
        print("="*60)
        print("Commands:")
        print("  on/off/toggle  - Control relay")
        print("  status         - Request device status")
        print("  info           - Show device information")
        print("  history [n]    - Show last n events (default: 10)")
        print("  location <name> - Set device location")
        print("  heartbeat on/off - Enable/disable heartbeat")
        print("  heartbeat <sec> - Set heartbeat interval")
        print("  led on/off     - Control status LED")
        print("  restart        - Restart device")
        print("  monitor on/off - Toggle heartbeat monitoring")
        print("  help           - Show this help")
        print("  quit/exit      - Exit program")
        print("-" * 60)
        
        def input_loop():
            while self.running:
                try:
                    command = input("relay> ").strip().lower()
                    
                    if command in ['quit', 'exit', 'q']:
                        self.running = False
                        break
                    elif command == 'on':
                        self.relay_on()
                    elif command == 'off':
                        self.relay_off()
                    elif command == 'toggle':
                        self.relay_toggle()
                    elif command == 'status':
                        self.request_status()
                    elif command == 'info':
                        self.show_device_info()
                    elif command.startswith('history'):
                        parts = command.split()
                        count = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 10
                        self.show_event_history(count)
                    elif command.startswith('location '):
                        location = command[9:].replace(' ', '_')
                        self.set_location(location)
                    elif command == 'heartbeat on':
                        self.enable_heartbeat()
                    elif command == 'heartbeat off':
                        self.disable_heartbeat()
                    elif command.startswith('heartbeat ') and command[10:].isdigit():
                        interval = int(command[10:])
                        self.set_heartbeat_interval(interval)
                    elif command == 'led on':
                        self.enable_status_led()
                    elif command == 'led off':
                        self.disable_status_led()
                    elif command == 'restart':
                        if input("Are you sure you want to restart the device? (y/N): ").lower() == 'y':
                            self.restart_device()
                    elif command == 'monitor on':
                        self.monitoring = True
                        print("📡 Heartbeat monitoring enabled")
                    elif command == 'monitor off':
                        self.monitoring = False
                        print("📡 Heartbeat monitoring disabled")
                    elif command in ['help', 'h']:
                        print("\nAvailable commands: on, off, toggle, status, info, history, location, heartbeat, led, restart, monitor, help, quit")
                    elif command:
                        print(f"❌ Unknown command: {command}. Type 'help' for available commands.")
                        
                except (EOFError, KeyboardInterrupt):
                    self.running = False
                    break
                except Exception as e:
                    print(f"❌ Error: {e}")
        
        self.input_thread = threading.Thread(target=input_loop, daemon=True)
        self.input_thread.start()
        
        try:
            while self.running:
                time.sleep(0.1)
        except KeyboardInterrupt:
            self.running = False
        
        if self.input_thread.is_alive():
            self.input_thread.join(timeout=1)


def main():
    parser = argparse.ArgumentParser(description='HomeGuard Advanced Relay Controller')
    parser.add_argument('--broker', default='192.168.18.6', help='MQTT broker IP address')
    parser.add_argument('--port', type=int, default=1883, help='MQTT broker port')
    parser.add_argument('--username', default='homeguard', help='MQTT username')
    parser.add_argument('--password', default='pu2clr123456', help='MQTT password')
    parser.add_argument('--device', default='relay1', help='Device prefix for MQTT topics')
    parser.add_argument('--monitor-only', action='store_true', help='Monitor only mode (no interactive control)')
    parser.add_argument('--command', help='Single command to execute and exit')
    parser.add_argument('--location', help='Set device location')
    
    args = parser.parse_args()
    
    # Create controller instance
    controller = AdvancedRelayController(
        broker_host=args.broker,
        broker_port=args.port,
        username=args.username,
        password=args.password,
        device_prefix=args.device
    )
    
    # Connect to MQTT broker
    if not controller.connect():
        print("❌ Failed to connect to MQTT broker")
        sys.exit(1)
    
    # Wait for connection
    time.sleep(2)
    
    try:
        # Set location if specified
        if args.location:
            controller.set_location(args.location)
            time.sleep(1)
        
        # Execute single command if specified
        if args.command:
            if args.command.lower() == 'on':
                controller.relay_on()
            elif args.command.lower() == 'off':
                controller.relay_off()
            elif args.command.lower() == 'toggle':
                controller.relay_toggle()
            elif args.command.lower() == 'status':
                controller.request_status()
            else:
                controller.send_command(args.command)
            time.sleep(2)  # Wait for response
        
        # Monitor only mode
        elif args.monitor_only:
            print("📡 Monitor-only mode. Press Ctrl+C to exit.")
            controller.monitoring = True
            while True:
                time.sleep(1)
        
        # Interactive mode
        else:
            controller.interactive_cli()
    
    except KeyboardInterrupt:
        print("\n👋 Shutting down...")
    
    finally:
        controller.disconnect()


if __name__ == "__main__":
    main()
