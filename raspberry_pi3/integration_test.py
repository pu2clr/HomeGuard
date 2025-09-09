#!/usr/bin/env python3
"""
HomeGuard Integration Test
Test script to demonstrate integration between motion sensors, relays, and audio system
"""

import time
import json
import threading
import paho.mqtt.client as mqtt

class HomeGuardIntegrationTest:
    def __init__(self):
        self.broker_host = "192.168.1.102"
        self.broker_port = 1883
        self.username = "homeguard"
        self.password = "pu2clr123456"
        
        # Create MQTT client
        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.username_pw_set(self.username, self.password)
        
        self.connected = False
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            self.connected = True
            print("✅ Connected to MQTT broker")
            
            # Subscribe to all HomeGuard topics
            client.subscribe("home/+/+")
            print("📡 Subscribed to all HomeGuard topics")
        else:
            print(f"❌ Connection failed: {rc}")
    
    def on_message(self, client, userdata, msg):
        try:
            topic = msg.topic
            payload = msg.payload.decode()
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
            
            print(f"📨 [{timestamp}] {topic}: {payload}")
            
            # Try to parse JSON
            try:
                data = json.loads(payload)
                if isinstance(data, dict):
                    device_id = data.get('device_id', 'unknown')
                    event = data.get('event', 'unknown')
                    location = data.get('location', 'unknown')
                    
                    print(f"   🔍 Device: {device_id}")
                    print(f"   📍 Location: {location}")
                    print(f"   🎯 Event: {event}")
            except:
                pass
                
        except Exception as e:
            print(f"❌ Error processing message: {e}")
    
    def send_test_commands(self):
        """Send test commands to demonstrate integration"""
        if not self.connected:
            print("❌ Not connected to broker")
            return
        
        test_commands = [
            # Audio system commands
            ("home/audio/cmnd", "STATUS", "🎵 Request audio system status"),
            ("home/audio/cmnd", "MODE_AWAY", "🏠 Set audio to AWAY mode"),
            
            # Wait a bit
            (None, None, "⏳ Waiting 3 seconds..."),
            
            # Relay commands
            ("home/relay1/cmnd", "STATUS", "🔌 Request relay status"),
            ("home/relay1/cmnd", "ON", "💡 Turn relay ON (should trigger audio response)"),
            
            (None, None, "⏳ Waiting 5 seconds..."),
            
            # Motion simulation (if you have motion detector)
            # This would normally come from actual motion sensor
            ("home/motion1/motion", '{"device_id":"motion_test","event":"MOTION_DETECTED","location":"Living Room"}', "🚶 Simulate motion detection"),
            
            (None, None, "⏳ Waiting 3 seconds..."),
            
            # Audio responses
            ("home/audio/cmnd", "DOGS", "🐕 Trigger dog barking"),
            
            (None, None, "⏳ Waiting 5 seconds..."),
            
            ("home/relay1/cmnd", "OFF", "💡 Turn relay OFF"),
            ("home/audio/cmnd", "MODE_HOME", "🏠 Set audio to HOME mode"),
        ]
        
        for topic, command, description in test_commands:
            if topic is None:
                print(f"\n{description}")
                time.sleep(3 if "3 seconds" in description else 5)
            else:
                print(f"\n🚀 {description}")
                print(f"   Topic: {topic}")
                print(f"   Command: {command}")
                
                try:
                    self.client.publish(topic, command)
                    time.sleep(2)  # Short delay between commands
                except Exception as e:
                    print(f"❌ Error sending command: {e}")
    
    def monitor_system(self, duration=60):
        """Monitor the system for specified duration"""
        print(f"\n📡 Monitoring HomeGuard system for {duration} seconds...")
        print("🔍 Watching for motion events, relay changes, and audio responses")
        print("⏹️ Press Ctrl+C to stop monitoring early\n")
        
        start_time = time.time()
        
        try:
            while time.time() - start_time < duration:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n⏹️ Monitoring stopped by user")
    
    def run_integration_test(self):
        """Run complete integration test"""
        print("🧪 HomeGuard Integration Test")
        print("=" * 40)
        
        # Connect to MQTT
        try:
            self.client.connect(self.broker_host, self.broker_port, 60)
            self.client.loop_start()
            
            # Wait for connection
            timeout = 10
            while not self.connected and timeout > 0:
                time.sleep(1)
                timeout -= 1
            
            if not self.connected:
                print("❌ Failed to connect to MQTT broker")
                return
            
            # Run test commands
            print("\n🎯 Phase 1: Sending test commands")
            print("-" * 30)
            self.send_test_commands()
            
            # Monitor system
            print("\n🔍 Phase 2: Monitoring system responses")
            print("-" * 40)
            self.monitor_system(30)  # Monitor for 30 seconds
            
            print("\n✅ Integration test completed!")
            print("\n📋 What to check:")
            print("   🎵 Audio system should respond to motion/relay events")
            print("   📡 All devices should report status via MQTT")
            print("   🔄 Commands should trigger appropriate responses")
            print("   💓 Heartbeat messages should appear regularly")
            
        except Exception as e:
            print(f"❌ Test error: {e}")
        
        finally:
            self.client.loop_stop()
            self.client.disconnect()
    
    def show_system_overview(self):
        """Show system overview"""
        print("🏠 HomeGuard System Overview")
        print("=" * 40)
        print("📡 MQTT Broker: 192.168.1.102:1883")
        print("🔐 Credentials: homeguard / pu2clr123456")
        print()
        print("🎛️ Active Components:")
        print("   📱 ESP-01S Motion Detector (192.168.1.193)")
        print("      Topics: home/motion1/motion, home/motion1/status")
        print()
        print("   🔌 ESP-01S Relay Controller (192.168.1.192)")  
        print("      Topics: home/relay1/cmnd, home/relay1/status")
        print()
        print("   🎵 Raspberry Pi Audio System")
        print("      Topics: home/audio/cmnd, home/audio/events")
        print()
        print("🔄 Integration Flow:")
        print("   Motion Detected → Audio Response (dogs, footsteps)")
        print("   Relay Activated → Audio Activity (when in AWAY mode)")
        print("   Scheduled → Audio Routines (morning, evening)")
        print()


def main():
    """Main function"""
    test = HomeGuardIntegrationTest()
    
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--overview":
        test.show_system_overview()
    elif len(sys.argv) > 1 and sys.argv[1] == "--monitor":
        print("📡 Starting system monitor...")
        test.client.connect(test.broker_host, test.broker_port, 60)
        test.client.loop_start()
        
        timeout = 10
        while not test.connected and timeout > 0:
            time.sleep(1)
            timeout -= 1
        
        if test.connected:
            test.monitor_system(300)  # Monitor for 5 minutes
        
        test.client.loop_stop()
        test.client.disconnect()
    else:
        test.run_integration_test()


if __name__ == "__main__":
    main()
