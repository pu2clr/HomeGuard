#!/usr/bin/env python3
"""
HomeGuard Audio Presence Simulator for Raspberry Pi 3
Simulates presence in house with various audio effects

Features:
- Dog barking simulation
- Footsteps inside house  
- Toilet flushing sounds
- TV/Radio background noise
- Door opening/closing
- MQTT integration with HomeGuard system
- Schedule-based automation
- Motion-triggered responses

Hardware Requirements:
- Raspberry Pi 3
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

class AudioPresenceSimulator:
    def __init__(self, config_file="audio_config.json"):
        """Initialize the Audio Presence Simulator"""
        
        # Load configuration
        self.config = self.load_config(config_file)
        
        # MQTT Configuration
        self.mqtt_broker = self.config.get('mqtt_broker', '192.168.18.198')
        self.mqtt_port = self.config.get('mqtt_port', 1883)
        self.mqtt_user = self.config.get('mqtt_user', 'homeguard')
        self.mqtt_pass = self.config.get('mqtt_pass', 'pu2clr123456')
        
        # Device info
        self.device_id = "audio_presence_rpi3_ground_floor"
        self.device_location = self.config.get('location', 'Ground Floor')
        self.floor = "ground"
        
        # MQTT Topics - Ground Floor Audio System
        self.topics = {
            'cmd': 'home/audio/ground/cmnd',
            'status': 'home/audio/ground/status', 
            'events': 'home/audio/ground/events',
            'heartbeat': 'home/audio/ground/heartbeat',
            'motion_trigger': 'homeguard/motion/+/detected',  # Listen to all motion sensors
            'relay_trigger': 'homeguard/relay/+/status',      # Listen to relay events
            'audio_control': 'home/audio/ground/control', # Direct audio control
            'emergency': 'homeguard/emergency/+',             # Emergency triggers
        }
        
        # Audio system
        pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=1024)
        
        # Audio files paths
        self.audio_base_path = Path(self.config.get('audio_path', './audio_files'))
        self.audio_categories = {
            'dogs': [],
            'footsteps': [],
            'toilets': [],
            'tv_radio': [],
            'doors': [],
            'background': [],
            'alerts': []
        }
        
        # State variables
        self.presence_mode = self.config.get('default_mode', 'home')  # home, away, night, vacation
        self.is_playing = False
        self.current_schedule = None
        self.motion_triggered_sounds = self.config.get('motion_triggered', True)
        self.background_playing = False
        
        # Load audio files
        self.load_audio_files()
        
        # MQTT Client
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message
        self.mqtt_client.username_pw_set(self.mqtt_user, self.mqtt_pass)
        
        # Scheduling
        self.setup_schedules()
        
        print(f"🎵 Audio Presence Simulator initialized")
        print(f"📍 Location: {self.device_location}")
        print(f"🎧 Audio files loaded: {sum(len(cat) for cat in self.audio_categories.values())}")
        print(f"📡 MQTT Broker: {self.mqtt_broker}")
    
    def load_config(self, config_file):
        """Load configuration from JSON file"""
        default_config = {
            "mqtt_broker": "192.168.18.198",
            "mqtt_port": 1883,
            "mqtt_user": "homeguard",
            "mqtt_pass": "pu2clr123456",
            "location": "Living Room",
            "audio_path": "./audio_files",
            "default_mode": "home",
            "motion_triggered": True,
            "schedules": {
                "morning_routine": {"time": "07:00", "sounds": ["toilets", "footsteps", "doors"]},
                "evening_routine": {"time": "18:30", "sounds": ["doors", "footsteps", "tv_radio"]},
                "random_activity": {"interval": 30, "sounds": ["footsteps", "doors"]}
            },
            "volume_levels": {
                "dogs": 0.8,
                "footsteps": 0.6,
                "toilets": 0.7,
                "tv_radio": 0.4,
                "doors": 0.6,
                "background": 0.3,
                "alerts": 0.9
            }
        }
        
        try:
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    config = json.load(f)
                    # Merge with defaults
                    for key, value in default_config.items():
                        if key not in config:
                            config[key] = value
                    return config
            else:
                # Create default config
                with open(config_file, 'w') as f:
                    json.dump(default_config, f, indent=4)
                return default_config
        except Exception as e:
            print(f"❌ Error loading config: {e}. Using defaults.")
            return default_config
    
    def load_audio_files(self):
        """Load audio files from directories"""
        try:
            self.audio_base_path.mkdir(parents=True, exist_ok=True)
            
            for category in self.audio_categories.keys():
                category_path = self.audio_base_path / category
                category_path.mkdir(exist_ok=True)
                
                # Load audio files (mp3, wav, ogg)
                for ext in ['*.mp3', '*.wav', '*.ogg']:
                    self.audio_categories[category].extend(category_path.glob(ext))
                
                print(f"📁 {category}: {len(self.audio_categories[category])} files")
        
        except Exception as e:
            print(f"❌ Error loading audio files: {e}")
    
    def play_sound(self, category, volume=None, random_select=True):
        """Play sound from category"""
        try:
            if category not in self.audio_categories:
                print(f"❌ Unknown category: {category}")
                return False
            
            if not self.audio_categories[category]:
                print(f"❌ No audio files in category: {category}")
                return False
            
            # Select audio file
            if random_select:
                audio_file = random.choice(self.audio_categories[category])
            else:
                audio_file = self.audio_categories[category][0]
            
            # Set volume
            if volume is None:
                volume = self.config.get('volume_levels', {}).get(category, 0.7)
            
            # Play sound
            pygame.mixer.music.load(str(audio_file))
            pygame.mixer.music.set_volume(volume)
            pygame.mixer.music.play()
            
            # Log event
            self.log_audio_event(category, audio_file.name, volume)
            
            return True
            
        except Exception as e:
            print(f"❌ Error playing sound: {e}")
            return False
    
    def play_sequence(self, categories, delays=None):
        """Play sequence of sounds with delays"""
        def play_seq():
            try:
                for i, category in enumerate(categories):
                    if delays and i < len(delays):
                        time.sleep(delays[i])
                    
                    self.play_sound(category)
                    
                    # Wait for sound to finish
                    while pygame.mixer.music.get_busy():
                        time.sleep(0.1)
                        
            except Exception as e:
                print(f"❌ Error in sound sequence: {e}")
        
        # Run in separate thread
        threading.Thread(target=play_seq, daemon=True).start()
    
    def simulate_presence_routine(self, routine_type="general"):
        """Simulate different presence routines"""
        routines = {
            "morning": {
                "sounds": ["toilets", "footsteps", "doors"],
                "delays": [0, 15, 30],
                "description": "Morning routine"
            },
            "evening": {
                "sounds": ["doors", "footsteps", "tv_radio"],
                "delays": [0, 10, 60],
                "description": "Evening routine"
            },
            "random_activity": {
                "sounds": random.sample(["footsteps", "doors", "toilets"], k=random.randint(1, 3)),
                "delays": [random.randint(5, 30) for _ in range(3)],
                "description": "Random activity"
            },
            "dog_alert": {
                "sounds": ["dogs"] * random.randint(2, 4),
                "delays": [random.randint(1, 5) for _ in range(4)],
                "description": "Dog barking alert"
            }
        }
        
        if routine_type in routines:
            routine = routines[routine_type]
            print(f"🎭 Starting {routine['description']}")
            self.play_sequence(routine["sounds"], routine["delays"])
            
            # Publish event
            self.publish_audio_event("ROUTINE_STARTED", routine_type, routine["description"])
    
    def on_motion_detected(self, device_id, location):
        """Handle motion detection from sensors"""
        if not self.motion_triggered_sounds:
            return
        
        print(f"🚶 Motion detected at {location} - triggering presence sounds")
        
        # Choose appropriate response based on mode
        if self.presence_mode == "away":
            # Simulate someone coming home
            self.play_sequence(["doors", "footsteps", "dogs"], [0, 5, 10])
        elif self.presence_mode == "home":
            # Normal activity
            if random.random() < 0.7:  # 70% chance to respond
                sound_type = random.choice(["footsteps", "doors"])
                self.play_sound(sound_type)
        
        self.publish_audio_event("MOTION_RESPONSE", device_id, f"Response to motion at {location}")
    
    def on_relay_activated(self, device_id, state):
        """Handle relay activation (lights, etc.)"""
        if state == "ON" and self.presence_mode == "away":
            # Light turned on while away - simulate activity
            time.sleep(random.randint(5, 15))  # Delay response
            self.simulate_presence_routine("random_activity")
            
            self.publish_audio_event("RELAY_RESPONSE", device_id, f"Response to relay {state}")
    
    def setup_schedules(self):
        """Setup scheduled routines"""
        schedules_config = self.config.get('schedules', {})
        
        # Morning routine
        if 'morning_routine' in schedules_config:
            time_str = schedules_config['morning_routine']['time']
            schedule.every().day.at(time_str).do(
                lambda: self.simulate_presence_routine("morning")
            )
        
        # Evening routine  
        if 'evening_routine' in schedules_config:
            time_str = schedules_config['evening_routine']['time']
            schedule.every().day.at(time_str).do(
                lambda: self.simulate_presence_routine("evening")
            )
        
        # Random activity
        if 'random_activity' in schedules_config:
            interval = schedules_config['random_activity'].get('interval', 30)
            schedule.every(interval).minutes.do(
                lambda: self.simulate_presence_routine("random_activity") if random.random() < 0.3 else None
            )
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            print("✅ Connected to MQTT broker")
            
            # Subscribe to topics
            for topic_name, topic in self.topics.items():
                client.subscribe(topic)
                print(f"📡 Subscribed to {topic}")
            
            # Announce online
            self.publish_status("ONLINE")
            
        else:
            print(f"❌ MQTT connection failed: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """MQTT message callback"""
        try:
            topic = msg.topic
            payload = msg.payload.decode()
            
            # Command messages
            if topic == self.topics['cmd']:
                self.handle_command(payload)
            
            # Motion sensor messages
            elif 'motion' in topic and payload:
                try:
                    data = json.loads(payload)
                    if data.get('event') == 'MOTION_DETECTED':
                        device_id = data.get('device_id', 'unknown')
                        location = data.get('location', 'unknown')
                        self.on_motion_detected(device_id, location)
                except json.JSONDecodeError:
                    pass
            
            # Relay messages
            elif 'relay' in topic and payload:
                try:
                    data = json.loads(payload)
                    if data.get('event') in ['RELAY_ON', 'RELAY_OFF']:
                        device_id = data.get('device_id', 'unknown')
                        state = data.get('state', 'unknown')
                        self.on_relay_activated(device_id, state)
                except json.JSONDecodeError:
                    pass
                    
        except Exception as e:
            print(f"❌ Error processing MQTT message: {e}")
    
    def handle_command(self, command):
        """Handle MQTT commands"""
        cmd = command.upper().strip()
        
        print(f"📨 Received command: {cmd}")
        
        if cmd == "STATUS":
            self.publish_status("STATUS_REPORT")
        
        elif cmd in ["DOGS", "DOG_BARK"]:
            self.play_sound("dogs")
        
        elif cmd == "FOOTSTEPS":
            self.play_sound("footsteps")
        
        elif cmd == "TOILET":
            self.play_sound("toilets")
        
        elif cmd == "TV":
            self.play_sound("tv_radio")
        
        elif cmd == "DOOR":
            self.play_sound("doors")
        
        elif cmd == "MORNING":
            self.simulate_presence_routine("morning")
        
        elif cmd == "EVENING":
            self.simulate_presence_routine("evening")
        
        elif cmd == "RANDOM":
            self.simulate_presence_routine("random_activity")
        
        elif cmd == "ALERT":
            self.simulate_presence_routine("dog_alert")
        
        elif cmd.startswith("MODE_"):
            new_mode = cmd[5:].lower()
            if new_mode in ["home", "away", "night", "vacation"]:
                self.presence_mode = new_mode
                self.publish_audio_event("MODE_CHANGED", new_mode, f"Presence mode set to {new_mode}")
        
        elif cmd == "STOP":
            pygame.mixer.music.stop()
            self.publish_audio_event("STOPPED", "manual", "Audio playback stopped")
        
        else:
            print(f"❌ Unknown command: {cmd}")
    
    def publish_status(self, status_type="HEARTBEAT"):
        """Publish device status"""
        try:
            status_data = {
                "device_id": self.device_id,
                "location": self.device_location,
                "timestamp": int(time.time()),
                "status": status_type,
                "presence_mode": self.presence_mode,
                "is_playing": pygame.mixer.music.get_busy(),
                "audio_files_loaded": sum(len(cat) for cat in self.audio_categories.values()),
                "motion_triggered": self.motion_triggered_sounds
            }
            
            self.mqtt_client.publish(self.topics['status'], json.dumps(status_data))
            
        except Exception as e:
            print(f"❌ Error publishing status: {e}")
    
    def publish_audio_event(self, event_type, source, description):
        """Publish audio event"""
        try:
            event_data = {
                "device_id": self.device_id,
                "location": self.device_location,
                "timestamp": int(time.time()),
                "event": event_type,
                "source": source,
                "description": description,
                "presence_mode": self.presence_mode
            }
            
            self.mqtt_client.publish(self.topics['events'], json.dumps(event_data))
            
        except Exception as e:
            print(f"❌ Error publishing event: {e}")
    
    def log_audio_event(self, category, filename, volume):
        """Log audio playback event"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"🔊 [{timestamp}] Playing {category}: {filename} (vol: {volume:.1f})")
    
    def run_scheduler(self):
        """Run scheduled tasks"""
        while True:
            try:
                schedule.run_pending()
                time.sleep(1)
            except Exception as e:
                print(f"❌ Scheduler error: {e}")
                time.sleep(60)
    
    def run(self):
        """Main run loop"""
        try:
            # Connect to MQTT
            print("🔄 Connecting to MQTT broker...")
            self.mqtt_client.connect(self.mqtt_broker, self.mqtt_port, 60)
            self.mqtt_client.loop_start()
            
            # Start scheduler in separate thread
            scheduler_thread = threading.Thread(target=self.run_scheduler, daemon=True)
            scheduler_thread.start()
            
            # Publish heartbeat every 60 seconds
            last_heartbeat = 0
            
            print("🎵 Audio Presence Simulator is running...")
            print("📋 Available commands: DOGS, FOOTSTEPS, TOILET, TV, DOOR, MORNING, EVENING, RANDOM, ALERT, MODE_HOME, MODE_AWAY, STOP")
            
            while True:
                current_time = time.time()
                
                # Send heartbeat
                if current_time - last_heartbeat > 60:
                    self.publish_status("HEARTBEAT")
                    last_heartbeat = current_time
                
                time.sleep(1)
                
        except KeyboardInterrupt:
            print("\n👋 Shutting down Audio Presence Simulator...")
        
        except Exception as e:
            print(f"❌ Runtime error: {e}")
        
        finally:
            pygame.mixer.quit()
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()


def main():
    """Main function"""
    print("🎵 HomeGuard Audio Presence Simulator for Raspberry Pi 3")
    print("=" * 60)
    
    simulator = AudioPresenceSimulator()
    simulator.run()


if __name__ == "__main__":
    main()
