#!/usr/bin/env python3
"""
HomeGuard Audio Presence Simulator - Base Class
Shared functionality for both ground and first floor systems
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

class BaseAudioPresenceSimulator:
    """Base class for audio presence simulation"""
    
    def __init__(self, floor_config):
        """Initialize the base audio simulator"""
        
        # Floor configuration (ground/first)
        self.floor = floor_config['floor']
        self.floor_name = floor_config['floor_name']
        self.device_id = f"audio_presence_rpi3_{self.floor}"
        
        # Load configuration
        self.config = self.load_config(floor_config['config_file'])
        
        # MQTT Configuration
        self.mqtt_broker = self.config.get('mqtt_broker', '192.168.1.102')
        self.mqtt_port = self.config.get('mqtt_port', 1883)
        self.mqtt_user = self.config.get('mqtt_user', 'homeguard')
        self.mqtt_pass = self.config.get('mqtt_pass', 'pu2clr123456')
        
        # MQTT Topics
        self.topics = {
            'cmd': f'homeguard/audio/{self.floor}/cmnd',
            'status': f'homeguard/audio/{self.floor}/status',
            'events': f'homeguard/audio/{self.floor}/events',
            'heartbeat': f'homeguard/audio/{self.floor}/heartbeat',
            'coordination': 'homeguard/audio/coordination',
            'motion_trigger': 'homeguard/motion/+/detected',
            'relay_trigger': 'homeguard/relay/+/status',
            'emergency': 'homeguard/emergency/+'
        }
        
        # Audio system
        pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=1024)
        
        # Audio files paths
        self.audio_base_path = Path(self.config.get('audio_path', './audio_files'))
        self.audio_categories = floor_config['audio_categories']
        
        # State variables
        self.presence_mode = self.config.get('default_mode', 'home')
        self.is_playing = False
        self.current_schedule = None
        self.motion_triggered_sounds = self.config.get('motion_triggered', True)
        self.coordination_enabled = self.config.get('coordination_enabled', True)
        
        # Load audio files
        self.load_audio_files()
        
        # Initialize MQTT client
        self.mqtt_client = None
        self.running = True
        self.start_time = None
        
        print(f"🏠 HomeGuard Audio - {self.floor_name} (Raspberry Pi 3)")
        print(f"🔧 Device ID: {self.device_id}")

    def load_config(self, config_file):
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
                print(f"✅ Configuration loaded: {config_file}")
                return config
        except FileNotFoundError:
            print(f"⚠️  Configuration file {config_file} not found, using defaults")
            return self.get_default_config()
        except json.JSONDecodeError:
            print(f"❌ Invalid JSON in {config_file}, using defaults")
            return self.get_default_config()

    def get_default_config(self):
        """Get default configuration - to be overridden by subclasses"""
        return {
            "mqtt_broker": "192.168.1.102",
            "mqtt_port": 1883,
            "mqtt_user": "homeguard",
            "mqtt_pass": "pu2clr123456",
            "default_mode": "home",
            "motion_triggered": True,
            "coordination_enabled": True,
            "volume": 0.7
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
                if self.audio_categories[category]:
                    print(f"📁 {category}: {len(self.audio_categories[category])} files")
            else:
                print(f"⚠️  Directory {category_path} not found")
                self.audio_categories[category] = []

    def play_sound_category(self, category, volume=None):
        """Play random sound from category"""
        if volume is None:
            volume = self.config.get('volume', 0.7)
            
        if category not in self.audio_categories:
            print(f"❌ Category {category} not found")
            return False
            
        files = self.audio_categories[category]
        if not files:
            print(f"⚠️  No files in category {category}")
            return False
            
        try:
            sound_file = random.choice(files)
            print(f"🔊 Playing {category}: {Path(sound_file).name} ({self.floor_name})")
            
            pygame.mixer.music.load(sound_file)
            pygame.mixer.music.set_volume(volume)
            pygame.mixer.music.play()
            
            # Wait for sound to finish
            while pygame.mixer.music.get_busy():
                time.sleep(0.1)
                
            self.publish_audio_event("SOUND_PLAYED", category, Path(sound_file).name)
            return True
            
        except Exception as e:
            print(f"❌ Error playing sound: {e}")
            return False

    def connect_mqtt(self):
        """Connect to MQTT broker"""
        try:
            self.mqtt_client = mqtt.Client()
            self.mqtt_client.username_pw_set(self.mqtt_user, self.mqtt_pass)
            
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_message = self.on_mqtt_message
            self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
            
            print(f"🔗 Connecting to MQTT: {self.mqtt_broker}:{self.mqtt_port}")
            self.mqtt_client.connect(self.mqtt_broker, self.mqtt_port, 60)
            self.mqtt_client.loop_start()
            return True
            
        except Exception as e:
            print(f"❌ MQTT connection failed: {e}")
            return False

    def on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback when MQTT connection is established"""
        if rc == 0:
            print(f"✅ Connected to MQTT broker")
            
            for topic_name, topic in self.topics.items():
                client.subscribe(topic)
                print(f"📡 Subscribed: {topic}")
                
            self.publish_status("ONLINE")
            
        else:
            print(f"❌ MQTT connection failed: {rc}")

    def on_mqtt_message(self, client, userdata, msg):
        """Handle incoming MQTT messages"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            if topic == self.topics['cmd']:
                self.handle_command(payload)
            elif 'motion' in topic and payload:
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
                cmd_data = json.loads(command)
                action = cmd_data.get('action', '').upper()
                
                if action == 'PLAY':
                    category = cmd_data.get('category')
                    volume = cmd_data.get('volume', self.config.get('volume', 0.7))
                    if category and not self.is_playing:
                        self.is_playing = True
                        threading.Thread(target=self._play_sound_thread, 
                                       args=(category, volume)).start()
                        
                elif action == 'ROUTINE':
                    routine_type = cmd_data.get('routine')
                    if routine_type:
                        threading.Thread(target=self.play_routine, 
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
                command_lower = command.lower()
                if command_lower in self.audio_categories and not self.is_playing:
                    self.is_playing = True
                    threading.Thread(target=self._play_sound_thread, 
                                   args=(command_lower,)).start()
                elif command.upper() == 'STOP':
                    pygame.mixer.music.stop()
                    self.is_playing = False
                    
        except Exception as e:
            print(f"❌ Error handling command: {e}")

    def _play_sound_thread(self, category, volume=None):
        """Thread wrapper for playing sounds"""
        self.play_sound_category(category, volume)
        self.is_playing = False

    def handle_motion_trigger(self, device_id, location):
        """Handle motion detection - to be implemented by subclasses"""
        pass

    def handle_relay_trigger(self, device_id, state):
        """Handle relay state changes - to be implemented by subclasses"""
        pass

    def handle_emergency(self, emergency_type, details):
        """Handle emergency situations"""
        print(f"🚨 EMERGENCY: {emergency_type} - {self.floor_name}")
        
        # All floors respond to emergencies immediately
        emergency_sounds = ['alerts']
        if 'security' in emergency_type.lower():
            emergency_sounds.append('dogs')
            
        for sound_category in emergency_sounds:
            if sound_category in self.audio_categories and self.audio_categories[sound_category]:
                self.play_sound_category(sound_category, 1.0)  # Maximum volume
                
        self.publish_audio_event("EMERGENCY_RESPONSE", emergency_type, f"{self.floor_name} emergency response")

    def handle_coordination_message(self, message):
        """Handle coordination messages between floors"""
        try:
            coord_data = json.loads(message)
            source_floor = coord_data.get('floor')
            action = coord_data.get('action')
            
            if source_floor != self.floor and self.coordination_enabled:
                if action == 'ROUTINE_START':
                    routine_type = coord_data.get('routine_type')
                    print(f"🤝 Coordinating with {source_floor} floor: {routine_type}")
                    
                    # Delayed response (2-5 minutes)
                    delay = random.randint(120, 300)
                    threading.Timer(delay, self.play_coordinated_routine, 
                                  args=(routine_type,)).start()
                                  
        except Exception as e:
            print(f"❌ Error handling coordination: {e}")

    def play_routine(self, routine_type):
        """Play scheduled routine"""
        if routine_type not in self.config.get('schedules', {}):
            print(f"❌ Routine {routine_type} not found")
            return
            
        routine = self.config['schedules'][routine_type]
        print(f"🎵 Starting {self.floor_name} routine: {routine.get('description', routine_type)}")
        
        # Publish coordination message
        if self.coordination_enabled:
            self.publish_coordination_message("ROUTINE_START", routine_type)
        
        # Play routine sounds
        end_time = datetime.now() + timedelta(minutes=routine.get('duration', 10))
        
        while datetime.now() < end_time and self.running:
            if not self.is_playing:
                available_sounds = [s for s in routine.get('sounds', []) 
                                  if s in self.audio_categories and self.audio_categories[s]]
                if available_sounds:
                    sound_category = random.choice(available_sounds)
                    self.is_playing = True
                    self.play_sound_category(sound_category)
                    self.is_playing = False
                    
            pause_time = random.randint(15, 60)  # 15 seconds to 1 minute
            time.sleep(pause_time)
            
        print(f"✅ Routine '{routine_type}' completed ({self.floor_name})")

    def play_coordinated_routine(self, routine_type):
        """Play routine in coordination with other floor"""
        probability = self.config.get('coordination_probability', 0.8)
        if random.random() < probability:
            print(f"🎯 Coordinated response: {routine_type} ({self.floor_name})")
            self.play_routine(routine_type)
        else:
            print(f"⏭️  Skipped coordinated routine: {routine_type} ({self.floor_name})")

    def publish_status(self, status):
        """Publish device status"""
        if self.mqtt_client:
            status_data = {
                "device_id": self.device_id,
                "floor": self.floor,
                "status": status,
                "timestamp": datetime.now().isoformat(),
                "mode": self.presence_mode,
                "location": self.floor_name
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
                "location": self.floor_name
            }
            self.mqtt_client.publish(self.topics['events'], json.dumps(event_data))

    def publish_coordination_message(self, action, routine_type):
        """Publish coordination messages"""
        if self.mqtt_client:
            coord_data = {
                "action": action,
                "routine_type": routine_type,
                "floor": self.floor,
                "device_id": self.device_id,
                "timestamp": datetime.now().isoformat()
            }
            self.mqtt_client.publish(self.topics['coordination'], json.dumps(coord_data))

    def on_mqtt_disconnect(self, client, userdata, rc):
        """Handle MQTT disconnection"""
        print(f"📡 MQTT disconnected: {rc}")

    def start_scheduler(self):
        """Start the schedule system"""
        schedule.clear()
        
        schedules_config = self.config.get('schedules', {})
        for routine_name, routine_config in schedules_config.items():
            if routine_config.get('enabled', True):
                schedule_time = routine_config.get('time')
                if schedule_time:
                    schedule.every().day.at(schedule_time).do(
                        lambda r=routine_name: threading.Thread(
                            target=self.play_routine, args=(r,)
                        ).start()
                    )
                    print(f"⏰ Scheduled {routine_name} at {schedule_time}")
        
        # Heartbeat every 5 minutes
        schedule.every(5).minutes.do(self.publish_heartbeat)
        
        def schedule_runner():
            while self.running:
                schedule.run_pending()
                time.sleep(30)
                
        threading.Thread(target=schedule_runner, daemon=True).start()
        print("⏰ Schedule system started")

    def publish_heartbeat(self):
        """Publish heartbeat"""
        if self.mqtt_client and self.start_time:
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
        
        print(f"🎵 HomeGuard Audio System - {self.floor_name}")
        print("=" * 50)
        
        if not self.connect_mqtt():
            print("❌ Failed to connect to MQTT broker")
            return False
            
        self.start_scheduler()
        
        print(f"✅ {self.floor_name} audio system running...")
        print("📡 MQTT Topics:")
        for name, topic in self.topics.items():
            print(f"   {name}: {topic}")
        print("=" * 50)
        
        try:
            while self.running:
                time.sleep(1)
                
        except KeyboardInterrupt:
            print(f"\n⏹️  Shutting down {self.floor_name} audio system...")
            self.running = False
            
            self.publish_status("OFFLINE")
            pygame.mixer.quit()
            
            if self.mqtt_client:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
                
            print(f"✅ {self.floor_name} audio system stopped")
            return True
