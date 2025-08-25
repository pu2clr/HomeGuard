#!/usr/bin/env python3
"""
HomeGuard Audio Presence Simulator for Raspberry Pi 2 - First Floor
Simulates presence in the first floor of the house with various audio effects

Features:
- Dog barking simulation (upper floor)
- Footsteps in bedrooms and hallways
- Toilet flushing sounds (upstairs bathrooms)
- TV/Radio background noise (bedrooms)
- Door opening/closing (bedroom doors)
- MQTT integration with HomeGuard system
- Schedule-based automation
- Motion-triggered responses
- Coordination with ground floor audio system

Hardware Requirements:
- Raspberry Pi 2
- Audio output (3.5mm jack, HDMI, or USB speaker)
- Optional: PIR sensor for motion detection

Author: HomeGuard System
"""

import pygame
import json
import random
import time
import schedule
import threading
import os
import sys
from datetime import datetime, timedelta
import paho.mqtt.client as mqtt
from pathlib import Path

class AudioPresenceSimulatorFirstFloor:
    def __init__(self, config_file="audio_config.json"):
        """Initialize the Audio Presence Simulator for First Floor"""
        
        # Load configuration
        self.config = self.load_config(config_file)
        
        # MQTT Configuration
        self.mqtt_broker = self.config.get('mqtt_broker', '192.168.18.236')
        self.mqtt_port = self.config.get('mqtt_port', 1883)
        self.mqtt_user = self.config.get('mqtt_user', 'homeguard')
        self.mqtt_pass = self.config.get('mqtt_pass', 'pu2clr123456')
        
        # Device info - First Floor
        self.device_id = "audio_presence_rpi2_first_floor"
        self.device_location = self.config.get('location', 'First Floor')
        self.floor = "first"
        
        # MQTT Topics - First Floor Audio System
        self.topics = {
            'cmd': 'home/audio/first/cmnd',
            'status': 'home/audio/first/status',
            'events': 'home/audio/first/events', 
            'heartbeat': 'home/audio/first/heartbeat',
            'motion_trigger': 'homeguard/motion/+/detected',   # Listen to all motion sensors
            'relay_trigger': 'homeguard/relay/+/status',       # Listen to relay events
            'audio_control': 'home/audio/first/control',  # Direct audio control
            'emergency': 'homeguard/emergency/+',              # Emergency triggers
            'coordination': 'home/audio/coordination',    # Coordinate with ground floor
        }
        
        # Audio system
        pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=1024)
        
        # Audio files paths
        self.audio_base_path = Path(self.config.get('audio_path', './audio_files'))
        self.audio_categories = {
            'dogs': [],           # Dogs barking upstairs
            'footsteps': [],      # Footsteps in hallways/bedrooms
            'toilets': [],        # Bathroom sounds
            'tv_radio': [],       # TV/radio in bedrooms
            'doors': [],          # Bedroom door sounds
            'background': [],     # Background home sounds
            'alerts': [],         # Security alerts
            'bedroom': [],        # Bedroom-specific sounds
            'hallway': [],        # Hallway sounds
            'shower': []          # Shower sounds
        }
        
        # State variables
        self.presence_mode = self.config.get('default_mode', 'home')  # home, away, night, vacation
        self.is_playing = False
        self.current_schedule = None
        self.motion_triggered_sounds = self.config.get('motion_triggered', True)
        self.background_playing = False
        self.coordinated_mode = self.config.get('coordinated_mode', True)  # Coordinate with ground floor
        
        # Load audio files
        self.load_audio_files()
        
        # Initialize MQTT client
        self.mqtt_client = None
        
        # Schedule system
        self.schedule_thread = None
        self.running = True
        
        print(f"🏠 HomeGuard Audio Presence Simulator - First Floor (Raspberry Pi 2)")
        print(f"📍 Location: {self.device_location}")
        print(f"🔧 Device ID: {self.device_id}")

    def load_config(self, config_file):
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
                print(f"✅ Configuration loaded from {config_file}")
                return config
        except FileNotFoundError:
            print(f"⚠️  Configuration file {config_file} not found, using defaults")
            return self.get_default_config()
        except json.JSONDecodeError:
            print(f"❌ Invalid JSON in {config_file}, using defaults")
            return self.get_default_config()

    def get_default_config(self):
        """Get default configuration for first floor"""
        return {
            "mqtt_broker": "192.168.18.236",
            "mqtt_port": 1883,
            "mqtt_user": "homeguard",
            "mqtt_pass": "pu2clr123456",
            "location": "First Floor",
            "audio_path": "./audio_files",
            "default_mode": "home",
            "motion_triggered": True,
            "coordinated_mode": True,
            "volume": 0.7,
            "schedules": {
                "morning_routine": {
                    "time": "07:00",
                    "sounds": ["shower", "footsteps", "doors"],
                    "duration": 20,
                    "description": "Morning activity upstairs"
                },
                "evening_routine": {
                    "time": "21:00", 
                    "sounds": ["tv_radio", "footsteps"],
                    "duration": 30,
                    "description": "Evening activities in bedrooms"
                },
                "night_routine": {
                    "time": "23:30",
                    "sounds": ["toilets", "footsteps"],
                    "duration": 5,
                    "description": "Late night bathroom visit"
                }
            },
            "motion_responses": {
                "bedroom": ["footsteps", "doors"],
                "hallway": ["footsteps", "doors"], 
                "bathroom": ["toilets", "shower"],
                "default": ["footsteps"]
            },
            "emergency_sounds": {
                "security_breach": ["alerts", "dogs"],
                "fire_alarm": ["alerts"],
                "medical_emergency": ["alerts"]
            }
        }

    def load_audio_files(self):
        """Load audio files from directories"""
        for category in self.audio_categories.keys():
            category_path = self.audio_base_path / category
            if category_path.exists():
                audio_files = []
                for ext in ['*.wav', '*.mp3', '*.m4a', '*.ogg']:
                    audio_files.extend(category_path.glob(ext))
                self.audio_categories[category] = [str(f) for f in audio_files]
                print(f"📁 {category}: {len(self.audio_categories[category])} files")
            else:
                print(f"⚠️  Directory {category_path} not found")

    def play_sound_category(self, category, volume=0.7):
        """Play random sound from category"""
        if category not in self.audio_categories:
            print(f"❌ Category {category} not found")
            return False
            
        files = self.audio_categories[category]
        if not files:
            print(f"❌ No files in category {category}")
            return False
            
        try:
            sound_file = random.choice(files)
            print(f"🔊 Playing {category}: {Path(sound_file).name} (First Floor)")
            
            pygame.mixer.music.load(sound_file)
            pygame.mixer.music.set_volume(volume)
            pygame.mixer.music.play()
            
            # Wait for sound to finish
            while pygame.mixer.music.get_busy():
                time.sleep(0.1)
                
            self.publish_audio_event("SOUND_PLAYED", category, sound_file)
            return True
            
        except Exception as e:
            print(f"❌ Error playing sound: {e}")
            return False

    def play_coordinated_routine(self, routine_type):
        """Play routine coordinated with ground floor"""
        if routine_type not in self.config.get('schedules', {}):
            print(f"❌ Routine {routine_type} not found")
            return
            
        routine = self.config['schedules'][routine_type]
        print(f"🎵 Starting first floor routine: {routine['description']}")
        
        # Notify coordination
        self.publish_coordination_message("ROUTINE_START", routine_type, self.floor)
        
        # Play sounds for specified duration
        end_time = datetime.now() + timedelta(minutes=routine['duration'])
        
        while datetime.now() < end_time and self.running:
            if not self.is_playing:
                sound_category = random.choice(routine['sounds'])
                if self.audio_categories[sound_category]:
                    self.is_playing = True
                    self.play_sound_category(sound_category, self.config.get('volume', 0.7))
                    self.is_playing = False
                    
            # Random pause between sounds (first floor has longer pauses)
            pause_time = random.randint(30, 120)  # 30 seconds to 2 minutes
            time.sleep(pause_time)
            
        print(f"✅ First floor routine '{routine['description']}' completed")
        self.publish_coordination_message("ROUTINE_END", routine_type, self.floor)

    def handle_motion_trigger(self, device_id, location):
        """Handle motion detection from sensors"""
        if not self.motion_triggered_sounds:
            return
            
        print(f"🚶 Motion detected: {device_id} at {location} - First Floor Response")
        
        # Determine response based on location
        location_lower = location.lower()
        response_sounds = self.config.get('motion_responses', {}).get('default', ['footsteps'])
        
        # Location-specific responses
        if 'bedroom' in location_lower:
            response_sounds = self.config.get('motion_responses', {}).get('bedroom', ['footsteps', 'doors'])
        elif 'hallway' in location_lower or 'corridor' in location_lower:
            response_sounds = self.config.get('motion_responses', {}).get('hallway', ['footsteps'])
        elif 'bathroom' in location_lower or 'toilet' in location_lower:
            response_sounds = self.config.get('motion_responses', {}).get('bathroom', ['toilets'])
            
        # Play response sound
        if response_sounds and not self.is_playing:
            sound_category = random.choice(response_sounds)
            threading.Thread(target=self.play_sound_category, 
                           args=(sound_category, 0.5)).start()
            
        self.publish_audio_event("MOTION_RESPONSE", device_id, f"First floor response to motion at {location}")

    def handle_relay_trigger(self, device_id, state):
        """Handle relay state changes"""
        print(f"🔌 Relay trigger: {device_id} = {state} - First Floor Response")
        
        if state.upper() == "ON" and not self.is_playing:
            # Light/relay turned on - simulate person activity upstairs
            response_sounds = ['footsteps', 'doors']
            sound_category = random.choice(response_sounds)
            threading.Thread(target=self.play_sound_category,
                           args=(sound_category, 0.4)).start()
            
            self.publish_audio_event("RELAY_RESPONSE", device_id, f"First floor response to relay {state}")

    def handle_emergency(self, emergency_type, details):
        """Handle emergency situations"""
        print(f"🚨 EMERGENCY: {emergency_type} - First Floor Alert")
        
        emergency_sounds = self.config.get('emergency_sounds', {}).get(emergency_type, ['alerts'])
        
        # Play emergency sound immediately
        for sound_category in emergency_sounds:
            if self.audio_categories[sound_category]:
                self.play_sound_category(sound_category, 1.0)  # Maximum volume
                
        self.publish_audio_event("EMERGENCY_RESPONSE", emergency_type, f"First floor emergency response: {details}")

    def connect_mqtt(self):
        """Connect to MQTT broker"""
        try:
            self.mqtt_client = mqtt.Client()
            self.mqtt_client.username_pw_set(self.mqtt_user, self.mqtt_pass)
            
            # Set callbacks
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_message = self.on_mqtt_message
            self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
            
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
            print("✅ Connected to MQTT broker")
            
            # Subscribe to topics
            for topic_name, topic in self.topics.items():
                client.subscribe(topic)
                print(f"📡 Subscribed to {topic}")
                
            # Publish online status
            self.publish_status("ONLINE")
            
        else:
            print(f"❌ MQTT connection failed with code {rc}")

    def on_mqtt_message(self, client, userdata, msg):
        """Handle incoming MQTT messages"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            print(f"📩 MQTT: {topic} = {payload}")
            
            if topic == self.topics['cmd']:
                self.handle_command(payload)
                
            elif 'motion' in topic and payload:
                # Extract device info from topic and payload
                device_id = topic.split('/')[-2] if '/' in topic else 'unknown'
                self.handle_motion_trigger(device_id, payload)
                
            elif 'relay' in topic:
                device_id = topic.split('/')[-2] if '/' in topic else 'unknown' 
                self.handle_relay_trigger(device_id, payload)
                
            elif 'emergency' in topic:
                emergency_type = topic.split('/')[-1] if '/' in topic else 'unknown'
                self.handle_emergency(emergency_type, payload)
                
            elif topic == self.topics['coordination']:
                self.handle_coordination_message(payload)
                
        except Exception as e:
            print(f"❌ Error processing MQTT message: {e}")

    def handle_command(self, command):
        """Handle direct commands"""
        try:
            if command.startswith('{'):
                # JSON command
                cmd_data = json.loads(command)
                action = cmd_data.get('action', '').upper()
                
                if action == 'PLAY':
                    category = cmd_data.get('category')
                    volume = cmd_data.get('volume', 0.7)
                    if category:
                        self.play_sound_category(category, volume)
                        
                elif action == 'ROUTINE':
                    routine_type = cmd_data.get('routine')
                    if routine_type:
                        threading.Thread(target=self.play_coordinated_routine, 
                                       args=(routine_type,)).start()
                                       
                elif action == 'MODE':
                    mode = cmd_data.get('mode')
                    if mode:
                        self.presence_mode = mode
                        print(f"🏠 Mode changed to: {mode}")
                        self.publish_status(f"MODE_{mode.upper()}")
                        
                elif action == 'STOP':
                    pygame.mixer.music.stop()
                    self.is_playing = False
                    print("⏹️  Audio stopped")
                    
            else:
                # Simple text command
                command = command.upper()
                if command in ['DOGS', 'FOOTSTEPS', 'TOILETS', 'TV_RADIO', 'DOORS']:
                    self.play_sound_category(command.lower())
                elif command == 'STOP':
                    pygame.mixer.music.stop()
                    self.is_playing = False
                    
        except Exception as e:
            print(f"❌ Error handling command: {e}")

    def handle_coordination_message(self, message):
        """Handle coordination messages with ground floor"""
        try:
            coord_data = json.loads(message)
            action = coord_data.get('action')
            source_floor = coord_data.get('floor')
            
            if source_floor != self.floor:  # Only respond to other floors
                if action == 'ROUTINE_START':
                    routine_type = coord_data.get('routine_type')
                    print(f"🤝 Ground floor started {routine_type}, coordinating...")
                    
                    # Delay first floor response by 2-5 minutes
                    delay = random.randint(120, 300)
                    threading.Timer(delay, self.play_coordinated_routine, 
                                  args=(routine_type,)).start()
                                  
        except Exception as e:
            print(f"❌ Error handling coordination: {e}")

    def publish_status(self, status):
        """Publish device status"""
        if self.mqtt_client:
            status_data = {
                "device_id": self.device_id,
                "floor": self.floor,
                "status": status,
                "timestamp": datetime.now().isoformat(),
                "mode": self.presence_mode,
                "location": self.device_location
            }
            self.mqtt_client.publish(self.topics['status'], json.dumps(status_data))

    def publish_audio_event(self, event_type, source, details):
        """Publish audio events"""
        if self.mqtt_client:
            event_data = {
                "device_id": self.device_id,
                "floor": self.floor,
                "event_type": event_type,
                "source": source,
                "details": details,
                "timestamp": datetime.now().isoformat(),
                "location": self.device_location
            }
            self.mqtt_client.publish(self.topics['events'], json.dumps(event_data))

    def publish_coordination_message(self, action, routine_type, floor):
        """Publish coordination messages"""
        if self.mqtt_client:
            coord_data = {
                "action": action,
                "routine_type": routine_type,
                "floor": floor,
                "device_id": self.device_id,
                "timestamp": datetime.now().isoformat()
            }
            self.mqtt_client.publish(self.topics['coordination'], json.dumps(coord_data))

    def on_mqtt_disconnect(self, client, userdata, rc):
        """Handle MQTT disconnection"""
        print(f"📡 MQTT disconnected with code {rc}")

    def start_scheduler(self):
        """Start the schedule system"""
        # Clear any existing schedules
        schedule.clear()
        
        # Setup schedules from config
        schedules_config = self.config.get('schedules', {})
        for routine_name, routine_config in schedules_config.items():
            schedule_time = routine_config.get('time')
            if schedule_time:
                schedule.every().day.at(schedule_time).do(
                    lambda r=routine_name: threading.Thread(
                        target=self.play_coordinated_routine, args=(r,)
                    ).start()
                )
                print(f"⏰ Scheduled {routine_name} at {schedule_time}")
        
        # Heartbeat every 5 minutes
        schedule.every(5).minutes.do(self.publish_heartbeat)
        
        # Schedule runner thread
        def schedule_runner():
            while self.running:
                schedule.run_pending()
                time.sleep(30)  # Check every 30 seconds
                
        self.schedule_thread = threading.Thread(target=schedule_runner, daemon=True)
        self.schedule_thread.start()
        print("⏰ Schedule system started")

    def publish_heartbeat(self):
        """Publish heartbeat"""
        if self.mqtt_client:
            heartbeat_data = {
                "device_id": self.device_id,
                "floor": self.floor,
                "timestamp": datetime.now().isoformat(),
                "status": "alive",
                "uptime": time.time() - self.start_time,
                "mode": self.presence_mode,
                "is_playing": self.is_playing
            }
            self.mqtt_client.publish(self.topics['heartbeat'], json.dumps(heartbeat_data))

    def run(self):
        """Main run loop"""
        self.start_time = time.time()
        
        print("🎵 HomeGuard Audio Presence Simulator - First Floor (Raspberry Pi 2)")
        print("=" * 60)
        
        # Connect to MQTT
        if not self.connect_mqtt():
            print("❌ Failed to connect to MQTT broker")
            return False
            
        # Start scheduler
        self.start_scheduler()
        
        print("✅ First floor audio system running...")
        print("🎮 Commands: DOGS, FOOTSTEPS, TOILETS, TV_RADIO, DOORS, STOP")
        print("🏠 Modes: home, away, night, vacation")
        print("📡 MQTT Topics:")
        for name, topic in self.topics.items():
            print(f"   {name}: {topic}")
        print("=" * 60)
        
        try:
            # Keep running
            while self.running:
                time.sleep(1)
                
        except KeyboardInterrupt:
            print("\n⏹️  Shutting down first floor audio system...")
            self.running = False
            
            # Publish offline status
            self.publish_status("OFFLINE")
            
            # Cleanup
            pygame.mixer.quit()
            if self.mqtt_client:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
                
            print("✅ First floor audio system stopped")
            return True

def main():
    """Main function"""
    try:
        # Create audio simulator
        simulator = AudioPresenceSimulatorFirstFloor()
        
        # Run the system
        simulator.run()
        
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        return False

if __name__ == "__main__":
    main()
