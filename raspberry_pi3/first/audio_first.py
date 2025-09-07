#!/usr/bin/env python3
"""
HomeGuard Audio Presence Simulator - First Floor
Primeiro Andar: portas, passos, banheiro, chuveiro, quartos
"""

import sys
import os
import threading
import random

# Add shared directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'shared'))

from base_audio_simulator import BaseAudioPresenceSimulator

class FirstFloorAudioSimulator(BaseAudioPresenceSimulator):
    """First floor audio simulation"""
    
    def __init__(self):
        floor_config = {
            'floor': 'first',
            'floor_name': 'Primeiro Andar',
            'config_file': 'first_config.json',
            'audio_categories': {
                'doors': [],     # Portas dos quartos
                'footsteps': [], # Passos no corredor/quartos
                'toilets': [],   # Banheiro
                'shower': [],    # Chuveiro
                'bedroom': [],   # Sons de quarto
                'alerts': []     # Alertas de segurança
            }
        }
        super().__init__(floor_config)

    def get_default_config(self):
        """First floor specific configuration"""
        return {
            "mqtt_broker": "192.168.1.6",
            "mqtt_port": 1883,
            "mqtt_user": "homeguard",
            "mqtt_pass": "pu2clr123456",
            "location": "Primeiro Andar",
            "floor": "first",
            "audio_path": "./audio_files",
            "default_mode": "home",
            "motion_triggered": True,
            "coordination_enabled": True,
            "coordination_probability": 0.7,
            "volume": 0.7,
            
            "schedules": {
                "morning_routine": {
                    "time": "07:15",
                    "sounds": ["shower", "footsteps", "doors"],
                    "duration": 15,
                    "description": "Rotina matinal no primeiro andar",
                    "enabled": True
                },
                "afternoon_rest": {
                    "time": "14:00",
                    "sounds": ["bedroom", "footsteps"],
                    "duration": 30,
                    "description": "Descanso da tarde",
                    "enabled": True
                },
                "evening_routine": {
                    "time": "21:00",
                    "sounds": ["bedroom", "footsteps", "doors"],
                    "duration": 40,
                    "description": "Rotina noturna no primeiro andar",
                    "enabled": True
                },
                "night_bathroom": {
                    "time": "23:30",
                    "sounds": ["toilets", "footsteps"],
                    "duration": 5,
                    "description": "Ida ao banheiro",
                    "enabled": True
                }
            },
            
            "motion_responses": {
                "master_bedroom": ["bedroom", "footsteps", "doors"],
                "bedroom_1": ["bedroom", "footsteps"],
                "bedroom_2": ["bedroom", "footsteps"],
                "hallway": ["footsteps", "doors"],
                "bathroom": ["toilets", "footsteps"],
                "upstairs_bathroom": ["shower", "toilets"],
                "default": ["footsteps", "doors"]
            },
            
            "relay_responses": {
                "bedroom_light": ["bedroom", "footsteps"],
                "hallway_light": ["footsteps"],
                "bathroom_light": ["toilets"],
                "master_bedroom_light": ["bedroom", "doors"],
                "default": ["footsteps"]
            }
        }

    def handle_motion_trigger(self, device_id, location):
        """Handle motion detection for first floor"""
        if not self.motion_triggered_sounds or self.is_playing:
            return
            
        print(f"🚶 Movimento no primeiro andar: {device_id} at {location}")
        
        location_lower = location.lower()
        responses = self.config.get('motion_responses', {})
        
        # Determine appropriate response based on location
        if 'master' in location_lower or 'suite' in location_lower:
            response_sounds = responses.get('master_bedroom', ['bedroom', 'doors'])
        elif 'bedroom' in location_lower or 'quarto' in location_lower:
            response_sounds = responses.get('bedroom_1', ['bedroom', 'footsteps'])
        elif 'hallway' in location_lower or 'corredor' in location_lower:
            response_sounds = responses.get('hallway', ['footsteps', 'doors'])
        elif 'bathroom' in location_lower or 'banheiro' in location_lower:
            if 'upstairs' in location_lower or 'suite' in location_lower:
                response_sounds = responses.get('upstairs_bathroom', ['shower', 'toilets'])
            else:
                response_sounds = responses.get('bathroom', ['toilets', 'footsteps'])
        else:
            response_sounds = responses.get('default', ['footsteps'])
            
        # Play response sound
        available_sounds = [s for s in response_sounds 
                          if s in self.audio_categories and self.audio_categories[s]]
        
        if available_sounds:
            sound_category = random.choice(available_sounds)
            self.is_playing = True
            threading.Thread(target=self._play_sound_thread, 
                           args=(sound_category, 0.5)).start()
            
        self.publish_audio_event("MOTION_RESPONSE", device_id, 
                               f"Primeiro andar response to motion at {location}")

    def handle_relay_trigger(self, device_id, state):
        """Handle relay state changes for first floor"""
        if self.is_playing:
            return
            
        print(f"🔌 Relay primeiro andar: {device_id} = {state}")
        
        if state.upper() == "ON":
            responses = self.config.get('relay_responses', {})
            
            # Determine response based on relay
            device_lower = device_id.lower()
            if 'master' in device_lower or 'suite' in device_lower:
                response_sounds = responses.get('master_bedroom_light', ['bedroom'])
            elif 'bedroom' in device_lower or 'quarto' in device_lower:
                response_sounds = responses.get('bedroom_light', ['bedroom'])
            elif 'hallway' in device_lower or 'corredor' in device_lower:
                response_sounds = responses.get('hallway_light', ['footsteps'])
            elif 'bathroom' in device_lower or 'banheiro' in device_lower:
                response_sounds = responses.get('bathroom_light', ['toilets'])
            else:
                response_sounds = responses.get('default', ['footsteps'])
                
            # Play response
            available_sounds = [s for s in response_sounds 
                              if s in self.audio_categories and self.audio_categories[s]]
            
            if available_sounds:
                sound_category = random.choice(available_sounds)
                self.is_playing = True
                threading.Thread(target=self._play_sound_thread, 
                               args=(sound_category, 0.4)).start()
                
            self.publish_audio_event("RELAY_RESPONSE", device_id, 
                                   f"Primeiro andar response to relay {state}")

def main():
    """Main function for first floor"""
    print("🏠 HomeGuard Audio - Primeiro Andar (First Floor)")
    print("🛏️  Sounds: doors, footsteps, toilets, shower, bedroom")
    
    try:
        simulator = FirstFloorAudioSimulator()
        simulator.run()
        
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        return False

if __name__ == "__main__":
    main()
