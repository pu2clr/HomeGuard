#!/usr/bin/env python3
"""
HomeGuard Audio Presence Simulator - Ground Floor
Térreo: cachorro, portas, passos, alertas, tv_radio
"""

import sys
import os
import threading
import random

# Add shared directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'shared'))

from base_audio_simulator import BaseAudioPresenceSimulator

class GroundFloorAudioSimulator(BaseAudioPresenceSimulator):
    """Ground floor audio simulation"""
    
    def __init__(self):
        floor_config = {
            'floor': 'ground',
            'floor_name': 'Térreo',
            'config_file': 'ground_config.json',
            'audio_categories': {
                'dogs': [],      # Cachorros
                'footsteps': [], # Passos
                'doors': [],     # Portas
                'tv_radio': [],  # TV/Rádio
                'alerts': [],    # Alertas
                'background': [] # Ruídos de fundo
            }
        }
        super().__init__(floor_config)

    def get_default_config(self):
        """Ground floor specific configuration"""
        return {
            "mqtt_broker": "192.168.1.102",
            "mqtt_port": 1883,
            "mqtt_user": "homeguard",
            "mqtt_pass": "pu2clr123456",
            "location": "Térreo",
            "floor": "ground",
            "audio_path": "./audio_files",
            "default_mode": "home",
            "motion_triggered": True,
            "coordination_enabled": True,
            "coordination_probability": 0.8,
            "volume": 0.8,
            
            "schedules": {
                "morning_routine": {
                    "time": "07:00",
                    "sounds": ["dogs", "footsteps", "doors"],
                    "duration": 20,
                    "description": "Rotina matinal no térreo",
                    "enabled": True
                },
                "afternoon_activity": {
                    "time": "15:30", 
                    "sounds": ["tv_radio", "footsteps"],
                    "duration": 30,
                    "description": "Atividade da tarde",
                    "enabled": True
                },
                "evening_routine": {
                    "time": "19:00",
                    "sounds": ["doors", "footsteps", "tv_radio"],
                    "duration": 45,
                    "description": "Rotina da noite no térreo",
                    "enabled": True
                },
                "night_security": {
                    "time": "22:30",
                    "sounds": ["dogs", "footsteps"],
                    "duration": 10,
                    "description": "Segurança noturna",
                    "enabled": True
                }
            },
            
            "motion_responses": {
                "living_room": ["tv_radio", "footsteps"],
                "kitchen": ["footsteps", "doors"],
                "entrance": ["dogs", "footsteps", "doors"],
                "garage": ["doors", "footsteps"],
                "backyard": ["dogs"],
                "default": ["footsteps", "doors"]
            },
            
            "relay_responses": {
                "living_room_light": ["tv_radio", "footsteps"],
                "kitchen_light": ["footsteps"],
                "entrance_light": ["dogs", "footsteps"],
                "garage_light": ["doors"],
                "default": ["footsteps"]
            }
        }

    def handle_motion_trigger(self, device_id, location):
        """Handle motion detection for ground floor"""
        if not self.motion_triggered_sounds or self.is_playing:
            return
            
        print(f"🚶 Movimento no térreo: {device_id} at {location}")
        
        location_lower = location.lower()
        responses = self.config.get('motion_responses', {})
        
        # Determine appropriate response based on location
        if 'entrance' in location_lower or 'porta' in location_lower:
            response_sounds = responses.get('entrance', ['dogs', 'footsteps'])
        elif 'living' in location_lower or 'sala' in location_lower:
            response_sounds = responses.get('living_room', ['tv_radio', 'footsteps'])
        elif 'kitchen' in location_lower or 'cozinha' in location_lower:
            response_sounds = responses.get('kitchen', ['footsteps', 'doors'])
        elif 'garage' in location_lower or 'garagem' in location_lower:
            response_sounds = responses.get('garage', ['doors', 'footsteps'])
        elif 'backyard' in location_lower or 'quintal' in location_lower:
            response_sounds = responses.get('backyard', ['dogs'])
        else:
            response_sounds = responses.get('default', ['footsteps'])
            
        # Play response sound
        available_sounds = [s for s in response_sounds 
                          if s in self.audio_categories and self.audio_categories[s]]
        
        if available_sounds:
            sound_category = random.choice(available_sounds)
            self.is_playing = True
            threading.Thread(target=self._play_sound_thread, 
                           args=(sound_category, 0.6)).start()
            
        self.publish_audio_event("MOTION_RESPONSE", device_id, 
                               f"Térreo response to motion at {location}")

    def handle_relay_trigger(self, device_id, state):
        """Handle relay state changes for ground floor"""
        if self.is_playing:
            return
            
        print(f"🔌 Relay térreo: {device_id} = {state}")
        
        if state.upper() == "ON":
            responses = self.config.get('relay_responses', {})
            
            # Determine response based on relay
            device_lower = device_id.lower()
            if 'living' in device_lower or 'sala' in device_lower:
                response_sounds = responses.get('living_room_light', ['tv_radio'])
            elif 'kitchen' in device_lower or 'cozinha' in device_lower:
                response_sounds = responses.get('kitchen_light', ['footsteps'])
            elif 'entrance' in device_lower or 'entrada' in device_lower:
                response_sounds = responses.get('entrance_light', ['dogs'])
            elif 'garage' in device_lower or 'garagem' in device_lower:
                response_sounds = responses.get('garage_light', ['doors'])
            else:
                response_sounds = responses.get('default', ['footsteps'])
                
            # Play response
            available_sounds = [s for s in response_sounds 
                              if s in self.audio_categories and self.audio_categories[s]]
            
            if available_sounds:
                sound_category = random.choice(available_sounds)
                self.is_playing = True
                threading.Thread(target=self._play_sound_thread, 
                               args=(sound_category, 0.5)).start()
                
            self.publish_audio_event("RELAY_RESPONSE", device_id, 
                                   f"Térreo response to relay {state}")

def main():
    """Main function for ground floor"""
    print("🏠 HomeGuard Audio - Térreo (Ground Floor)")
    print("🐕 Sounds: dogs, doors, footsteps, tv_radio, alerts")
    
    try:
        simulator = GroundFloorAudioSimulator()
        simulator.run()
        
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        return False

if __name__ == "__main__":
    main()
