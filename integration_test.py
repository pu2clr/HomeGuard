#!/usr/bin/env python3
"""
HomeGuard Audio Integration Test
Tests the complete audio system integration between floors
"""

import paho.mqtt.client as mqtt
import json
import time
import threading
from datetime import datetime

class AudioIntegrationTest:
    def __init__(self):
        self.mqtt_broker = "192.168.1.102" 
        self.mqtt_port = 1883
        self.mqtt_user = "homeguard"
        self.mqtt_pass = "pu2clr123456"
        
        self.client = None
        self.messages_received = []
        self.test_results = {}
        
    def connect_mqtt(self):
        """Connect to MQTT broker"""
        try:
            self.client = mqtt.Client()
            self.client.username_pw_set(self.mqtt_user, self.mqtt_pass)
            self.client.on_connect = self.on_connect
            self.client.on_message = self.on_message
            
            print(f"🔗 Connecting to MQTT broker: {self.mqtt_broker}")
            self.client.connect(self.mqtt_broker, self.mqtt_port, 60)
            self.client.loop_start()
            return True
            
        except Exception as e:
            print(f"❌ MQTT connection failed: {e}")
            return False
    
    def on_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            print("✅ Connected to MQTT broker")
            
            # Subscribe to all audio topics
            topics = [
                'home/audio/ground/+',
                'home/audio/first/+', 
                'home/audio/coordination',
                'homeguard/motion/+/detected',
                'homeguard/relay/+/status'
            ]
            
            for topic in topics:
                client.subscribe(topic)
                print(f"📡 Subscribed to: {topic}")
                
        else:
            print(f"❌ MQTT connection failed: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Handle received messages"""
        timestamp = datetime.now().isoformat()
        message_data = {
            'timestamp': timestamp,
            'topic': msg.topic,
            'payload': msg.payload.decode('utf-8')
        }
        
        self.messages_received.append(message_data)
        print(f"📩 {timestamp} | {msg.topic} | {msg.payload.decode('utf-8')}")
    
    def test_ground_floor_communication(self):
        """Test ground floor communication"""
        print("\n🧪 Testing Ground Floor Communication...")
        
        test_commands = [
            "FOOTSTEPS",
            '{"action":"PLAY","category":"doors"}',
            '{"action":"MODE","mode":"test"}',
            "STOP"
        ]
        
        for cmd in test_commands:
            print(f"📤 Sending to ground floor: {cmd}")
            self.client.publish('home/audio/ground/cmnd', cmd)
            time.sleep(2)
            
        self.test_results['ground_floor'] = 'SENT'
    
    def test_first_floor_communication(self):
        """Test first floor communication"""
        print("\n🧪 Testing First Floor Communication...")
        
        test_commands = [
            "FOOTSTEPS", 
            '{"action":"PLAY","category":"shower"}',
            '{"action":"MODE","mode":"test"}',
            "STOP"
        ]
        
        for cmd in test_commands:
            print(f"📤 Sending to first floor: {cmd}")
            self.client.publish('home/audio/first/cmnd', cmd)
            time.sleep(2)
            
        self.test_results['first_floor'] = 'SENT'
    
    def test_coordination(self):
        """Test coordination between floors"""
        print("\n🧪 Testing Floor Coordination...")
        
        coord_message = {
            "action": "ROUTINE_START",
            "routine_type": "test_routine",
            "floor": "ground",
            "timestamp": datetime.now().isoformat()
        }
        
        print("📤 Sending coordination message...")
        self.client.publish('home/audio/coordination', json.dumps(coord_message))
        time.sleep(3)
        
        self.test_results['coordination'] = 'SENT'
    
    def test_motion_simulation(self):
        """Test motion detection simulation"""
        print("\n🧪 Testing Motion Detection Simulation...")
        
        motion_events = [
            ('homeguard/motion/living_room/detected', 'Motion in living room'),
            ('homeguard/motion/bedroom_1/detected', 'Motion in bedroom 1'), 
            ('homeguard/motion/hallway/detected', 'Motion in hallway')
        ]
        
        for topic, message in motion_events:
            print(f"📤 Simulating motion: {message}")
            self.client.publish(topic, message)
            time.sleep(2)
            
        self.test_results['motion_simulation'] = 'SENT'
    
    def test_relay_simulation(self):
        """Test relay state simulation"""
        print("\n🧪 Testing Relay State Simulation...")
        
        relay_events = [
            ('homeguard/relay/living_room_light/status', 'ON'),
            ('homeguard/relay/bedroom_light/status', 'ON'),
            ('homeguard/relay/living_room_light/status', 'OFF'),
            ('homeguard/relay/bedroom_light/status', 'OFF')
        ]
        
        for topic, state in relay_events:
            print(f"📤 Simulating relay: {state}")
            self.client.publish(topic, state)
            time.sleep(2)
            
        self.test_results['relay_simulation'] = 'SENT'
    
    def test_emergency_alert(self):
        """Test emergency alert system"""
        print("\n🧪 Testing Emergency Alert System...")
        
        emergency_cmd = {
            "action": "EMERGENCY",
            "type": "security_breach", 
            "details": "Integration test emergency",
            "timestamp": datetime.now().isoformat()
        }
        
        print("🚨 Sending emergency alert to both floors...")
        self.client.publish('home/audio/ground/cmnd', json.dumps(emergency_cmd))
        self.client.publish('home/audio/first/cmnd', json.dumps(emergency_cmd))
        time.sleep(3)
        
        self.test_results['emergency'] = 'SENT'
    
    def analyze_results(self):
        """Analyze test results"""
        print("\n📊 Test Results Analysis")
        print("=" * 50)
        
        # Count messages by topic type
        topic_counts = {}
        for msg in self.messages_received:
            topic_parts = msg['topic'].split('/')
            if len(topic_parts) >= 3:
                topic_type = '/'.join(topic_parts[:3])
                topic_counts[topic_type] = topic_counts.get(topic_type, 0) + 1
        
        print("📈 Messages Received by Topic:")
        for topic, count in topic_counts.items():
            print(f"   {topic}: {count} messages")
        
        print(f"\n📊 Total Messages Received: {len(self.messages_received)}")
        
        # Check for expected responses
        ground_responses = any('ground' in msg['topic'] for msg in self.messages_received)
        first_responses = any('first' in msg['topic'] for msg in self.messages_received)
        
        print(f"🏠 Ground Floor Responses: {'✅ Yes' if ground_responses else '❌ No'}")
        print(f"🏠 First Floor Responses: {'✅ Yes' if first_responses else '❌ No'}")
        
        # System health check
        print(f"\n🔍 System Health:")
        if len(self.messages_received) > 0:
            print("✅ MQTT communication working")
        else:
            print("❌ No MQTT messages received")
            
        if ground_responses and first_responses:
            print("✅ Both floors responding")
        else:
            print("⚠️  Check if both audio systems are running")
    
    def run_integration_test(self):
        """Run complete integration test"""
        print("🏠 HomeGuard Audio System Integration Test")
        print("=" * 50)
        
        if not self.connect_mqtt():
            print("❌ Cannot connect to MQTT broker")
            return False
        
        # Wait for connection to stabilize
        print("⏳ Waiting for MQTT connection to stabilize...")
        time.sleep(3)
        
        # Run all tests
        self.test_ground_floor_communication()
        time.sleep(2)
        
        self.test_first_floor_communication()
        time.sleep(2)
        
        self.test_coordination()
        time.sleep(2)
        
        self.test_motion_simulation()
        time.sleep(2)
        
        self.test_relay_simulation()
        time.sleep(2)
        
        self.test_emergency_alert()
        time.sleep(3)
        
        # Wait for all responses
        print("\n⏳ Waiting for system responses...")
        time.sleep(10)
        
        # Analyze results
        self.analyze_results()
        
        # Show recent messages
        if self.messages_received:
            print(f"\n📜 Recent Messages (last 10):")
            for msg in self.messages_received[-10:]:
                print(f"   {msg['timestamp'][:19]} | {msg['topic']} | {msg['payload'][:50]}...")
        
        # Cleanup
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()
        
        print(f"\n✅ Integration test completed")
        print(f"📊 Total messages processed: {len(self.messages_received)}")
        
        return True

def main():
    """Main function"""
    print("Starting HomeGuard Audio Integration Test...")
    
    tester = AudioIntegrationTest()
    success = tester.run_integration_test()
    
    if success:
        print("\n🎉 Integration test completed successfully!")
        print("\n📋 Next Steps:")
        print("   1. Check both audio systems are responding")
        print("   2. Verify coordination between floors")
        print("   3. Test with real motion sensors")
        print("   4. Monitor system in production")
    else:
        print("\n❌ Integration test failed")
        print("\n🔧 Troubleshooting:")
        print("   1. Check MQTT broker is running")
        print("   2. Verify audio systems are started")
        print("   3. Check network connectivity")
        print("   4. Review configuration files")

if __name__ == "__main__":
    main()
