#!/usr/bin/env python3
"""
HomeGuard Schedule Manager
Python client for managing ESP-01S device schedules via MQTT

Requirements:
- paho-mqtt
- python-dateutil
- pytz

Usage:
    python schedule_manager.py --device homeguard_abc123 --schedule schedule.json
    python schedule_manager.py --list-devices
    python schedule_manager.py --monitor
"""

import json
import time
import argparse
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional

import paho.mqtt.client as mqtt
from dateutil import tz
import pytz

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class HomeGuardScheduleManager:
    def __init__(self, broker_host: str, broker_port: int = 1883, 
                 username: str = None, password: str = None):
        """
        Initialize HomeGuard Schedule Manager
        
        Args:
            broker_host: MQTT broker IP address
            broker_port: MQTT broker port (default: 1883)
            username: MQTT username
            password: MQTT password
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.username = username
        self.password = password
        
        self.client = mqtt.Client()
        self.devices = {}  # Store discovered devices
        self.connected = False
        
        # Setup MQTT callbacks
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message
        
        # Set credentials if provided
        if username and password:
            self.client.username_pw_set(username, password)
    
    def _on_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            self.connected = True
            logger.info("Connected to MQTT broker")
            
            # Subscribe to device discovery topics
            client.subscribe("homeguard/+/heartbeat")
            client.subscribe("homeguard/+/stat")
            
        else:
            logger.error(f"Failed to connect to MQTT broker: {rc}")
    
    def _on_disconnect(self, client, userdata, rc):
        """MQTT disconnection callback"""
        self.connected = False
        logger.info("Disconnected from MQTT broker")
    
    def _on_message(self, client, userdata, msg):
        """MQTT message callback"""
        try:
            topic_parts = msg.topic.split('/')
            if len(topic_parts) >= 3:
                device_id = topic_parts[1]
                message_type = topic_parts[2]
                
                payload = json.loads(msg.payload.decode())
                
                # Update device information
                if device_id not in self.devices:
                    self.devices[device_id] = {
                        'device_id': device_id,
                        'last_seen': datetime.now(),
                        'status': 'unknown'
                    }
                
                self.devices[device_id].update(payload)
                self.devices[device_id]['last_seen'] = datetime.now()
                
                if message_type == 'heartbeat':
                    self.devices[device_id]['status'] = 'online'
                    logger.debug(f"Heartbeat from {device_id}")
                
        except Exception as e:
            logger.error(f"Error processing message: {e}")
    
    def connect(self) -> bool:
        """Connect to MQTT broker"""
        try:
            self.client.connect(self.broker_host, self.broker_port, 60)
            self.client.loop_start()
            
            # Wait for connection
            timeout = 10
            while not self.connected and timeout > 0:
                time.sleep(1)
                timeout -= 1
            
            return self.connected
            
        except Exception as e:
            logger.error(f"Error connecting to broker: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from MQTT broker"""
        self.client.loop_stop()
        self.client.disconnect()
    
    def discover_devices(self, timeout: int = 10) -> Dict:
        """
        Discover HomeGuard devices on the network
        
        Args:
            timeout: Discovery timeout in seconds
            
        Returns:
            Dictionary of discovered devices
        """
        logger.info(f"Discovering devices for {timeout} seconds...")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            time.sleep(1)
        
        # Filter active devices (seen in last 60 seconds)
        active_devices = {}
        cutoff_time = datetime.now() - timedelta(seconds=60)
        
        for device_id, device_info in self.devices.items():
            if device_info['last_seen'] > cutoff_time:
                active_devices[device_id] = device_info
        
        logger.info(f"Found {len(active_devices)} active devices")
        return active_devices
    
    def send_schedule(self, device_id: str, schedule: Dict) -> bool:
        """
        Send schedule to specific device
        
        Args:
            device_id: Target device ID
            schedule: Schedule dictionary
            
        Returns:
            True if schedule was sent successfully
        """
        try:
            # Validate schedule format
            required_fields = ['active', 'hour', 'minute', 'duration', 'action', 'days']
            for field in required_fields:
                if field not in schedule:
                    logger.error(f"Missing required field: {field}")
                    return False
            
            # Validate values
            if not (0 <= schedule['hour'] <= 23):
                logger.error("Hour must be between 0 and 23")
                return False
            
            if not (0 <= schedule['minute'] <= 59):
                logger.error("Minute must be between 0 and 59")
                return False
            
            if schedule['duration'] < 0:
                logger.error("Duration must be positive")
                return False
            
            # Send schedule
            topic = f"homeguard/{device_id}/schedule"
            payload = json.dumps(schedule)
            
            result = self.client.publish(topic, payload)
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"Schedule sent to {device_id}")
                return True
            else:
                logger.error(f"Failed to send schedule: {result.rc}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending schedule: {e}")
            return False
    
    def send_command(self, device_id: str, command: str) -> bool:
        """
        Send direct command to device
        
        Args:
            device_id: Target device ID
            command: Command to send (ON, OFF, STATUS, RESTART)
            
        Returns:
            True if command was sent successfully
        """
        try:
            topic = f"homeguard/{device_id}/cmnd"
            result = self.client.publish(topic, command.upper())
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"Command '{command}' sent to {device_id}")
                return True
            else:
                logger.error(f"Failed to send command: {result.rc}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending command: {e}")
            return False
    
    def monitor_devices(self):
        """Monitor device activity in real-time"""
        logger.info("Monitoring devices... Press Ctrl+C to stop")
        
        try:
            while True:
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Monitoring stopped")

def load_schedule_from_file(filename: str) -> Dict:
    """Load schedule from JSON file"""
    try:
        with open(filename, 'r') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Error loading schedule file: {e}")
        return {}

def create_sample_schedule() -> Dict:
    """Create a sample schedule"""
    return {
        "active": True,
        "hour": 20,      # 8 PM
        "minute": 30,    # 30 minutes past
        "duration": 60,  # 1 hour duration
        "action": True,  # Turn ON
        "days": "1234567"  # Monday to Sunday
    }

def main():
    parser = argparse.ArgumentParser(description='HomeGuard Schedule Manager')
    parser.add_argument('--broker', required=True, help='MQTT broker IP address')
    parser.add_argument('--port', type=int, default=1883, help='MQTT broker port')
    parser.add_argument('--username', help='MQTT username')
    parser.add_argument('--password', help='MQTT password')
    parser.add_argument('--device', help='Target device ID')
    parser.add_argument('--schedule', help='Schedule JSON file')
    parser.add_argument('--command', help='Direct command (ON, OFF, STATUS, RESTART)')
    parser.add_argument('--list-devices', action='store_true', help='List discovered devices')
    parser.add_argument('--monitor', action='store_true', help='Monitor device activity')
    parser.add_argument('--create-sample', help='Create sample schedule file')
    
    args = parser.parse_args()
    
    # Create sample schedule file
    if args.create_sample:
        sample_schedule = create_sample_schedule()
        with open(args.create_sample, 'w') as f:
            json.dump(sample_schedule, f, indent=2)
        logger.info(f"Sample schedule created: {args.create_sample}")
        return
    
    # Initialize manager
    manager = HomeGuardScheduleManager(
        broker_host=args.broker,
        broker_port=args.port,
        username=args.username,
        password=args.password
    )
    
    # Connect to broker
    if not manager.connect():
        logger.error("Failed to connect to MQTT broker")
        return
    
    try:
        # List devices
        if args.list_devices:
            devices = manager.discover_devices()
            print("\nDiscovered Devices:")
            print("-" * 50)
            for device_id, info in devices.items():
                print(f"Device ID: {device_id}")
                print(f"  MAC: {info.get('mac', 'Unknown')}")
                print(f"  IP: {info.get('ip', 'Unknown')}")
                print(f"  Status: {info.get('status', 'Unknown')}")
                print(f"  Last Seen: {info['last_seen']}")
                print()
        
        # Send schedule
        elif args.device and args.schedule:
            schedule = load_schedule_from_file(args.schedule)
            if schedule:
                manager.send_schedule(args.device, schedule)
        
        # Send command
        elif args.device and args.command:
            manager.send_command(args.device, args.command)
        
        # Monitor devices
        elif args.monitor:
            manager.monitor_devices()
        
        else:
            parser.print_help()
    
    finally:
        manager.disconnect()

if __name__ == '__main__':
    main()
