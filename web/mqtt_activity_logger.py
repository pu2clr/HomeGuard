#!/usr/bin/env python3
"""
HomeGuard MQTT Activity Logger
Captures all MQTT messages from home/* topics and logs to SQLite database

Equivalent to: mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "home/#" -v

Author: HomeGuard System
Date: September 6, 2025
"""

import paho.mqtt.client as mqtt
import sqlite3
import json
import logging
import signal
import sys
import os
from datetime import datetime
from threading import Lock
import time

# Configuration
MQTT_CONFIG = {
    'host': '192.168.18.198',
    'port': 1883,
    'username': 'homeguard',
    'password': 'pu2clr123456',
    'topic': 'home/#',
    'keepalive': 60
}

# Database configuration - usando caminho relativo
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DB_CONFIG = {
    'path': os.path.join(PROJECT_ROOT, 'db', 'homeguard.db'),
    'timeout': 20.0
}

# Global variables
db_lock = Lock()
message_count = 0
start_time = time.time()

# Setup logging - usando caminho relativo
LOG_FILE = os.path.join(SCRIPT_DIR, 'mqtt_logger.log')
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def log_to_database(topic, message):
    """Insert MQTT message into database"""
    global message_count
    
    try:
        with db_lock:
            conn = sqlite3.connect(DB_CONFIG['path'], timeout=DB_CONFIG['timeout'])
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO activity (topic, message) 
                VALUES (?, ?)
            ''', (topic, message))
            
            conn.commit()
            message_count += 1
            
            # Log every 10 messages or important topics
            if (message_count % 10 == 0 or 
                'status' in topic or 
                'command' in topic or
                message_count <= 5):
                logger.info(f"📝 Logged message #{message_count}: {topic}")
            
            conn.close()
            return True
            
    except sqlite3.Error as e:
        logger.error(f"❌ Database error: {e}")
        return False
    except Exception as e:
        logger.error(f"❌ Unexpected error logging to database: {e}")
        return False

def on_connect(client, userdata, flags, rc):
    """Callback for when the client receives a CONNACK response from the server"""
    if rc == 0:
        logger.info("✅ Connected to MQTT broker successfully")
        client.subscribe(MQTT_CONFIG['topic'])
        logger.info(f"📡 Subscribed to topic: {MQTT_CONFIG['topic']}")
        
        # Log connection to database
        log_to_database('system/mqtt', 'MQTT client connected successfully')
        
    else:
        logger.error(f"❌ Failed to connect to MQTT broker. Return code: {rc}")

def on_disconnect(client, userdata, rc):
    """Callback for when the client disconnects from the server"""
    if rc != 0:
        logger.warning("🔌 Unexpected MQTT disconnection. Will auto-reconnect.")
        log_to_database('system/mqtt', f'MQTT client disconnected unexpectedly: {rc}')
    else:
        logger.info("🔌 MQTT client disconnected gracefully")

def on_message(client, userdata, msg):
    """Callback for when a PUBLISH message is received from the server"""
    try:
        topic = msg.topic
        message = msg.payload.decode('utf-8')
        
        # Log to database
        success = log_to_database(topic, message)
        
        # Console output similar to mosquitto_sub -v
        print(f"{topic} {message}")
        
        # Special handling for JSON messages
        if message.startswith('{') and message.endswith('}'):
            try:
                json_data = json.loads(message)
                device_id = json_data.get('device_id', json_data.get('RELAY_ID', 'unknown'))
                if device_id != 'unknown':
                    logger.debug(f"📊 JSON message from device: {device_id}")
            except json.JSONDecodeError:
                logger.debug(f"⚠️  Invalid JSON in message: {topic}")
        
        if not success:
            logger.warning(f"⚠️  Failed to log message: {topic}")
            
    except Exception as e:
        logger.error(f"❌ Error processing message: {e}")

def signal_handler(signum, frame):
    """Handle interrupt signals gracefully"""
    logger.info(f"\n🛑 Received signal {signum}. Shutting down gracefully...")
    
    # Log shutdown to database
    uptime = time.time() - start_time
    log_to_database('system/mqtt', f'MQTT logger shutdown - Total messages: {message_count}, Uptime: {uptime:.1f}s')
    
    logger.info(f"📊 Final statistics:")
    logger.info(f"   - Total messages captured: {message_count}")
    logger.info(f"   - Uptime: {uptime:.1f} seconds")
    logger.info(f"   - Average rate: {message_count/uptime:.2f} msg/sec")
    
    sys.exit(0)

def main():
    """Main function to start MQTT listener"""
    global start_time
    start_time = time.time()
    
    logger.info("🚀 Starting HomeGuard MQTT Activity Logger")
    logger.info(f"🏠 MQTT Broker: {MQTT_CONFIG['host']}:{MQTT_CONFIG['port']}")
    logger.info(f"📡 Topic filter: {MQTT_CONFIG['topic']}")
    logger.info(f"💾 Database: {DB_CONFIG['path']}")
    
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Create MQTT client
    client = mqtt.Client()
    client.username_pw_set(MQTT_CONFIG['username'], MQTT_CONFIG['password'])
    
    # Set callbacks
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    
    try:
        # Connect to broker
        logger.info("🔌 Connecting to MQTT broker...")
        client.connect(MQTT_CONFIG['host'], MQTT_CONFIG['port'], MQTT_CONFIG['keepalive'])
        
        # Start the loop
        logger.info("👂 Starting to listen for MQTT messages...")
        logger.info("💡 Press Ctrl+C to stop")
        logger.info("-" * 60)
        
        client.loop_forever()
        
    except KeyboardInterrupt:
        logger.info("\n🛑 Keyboard interrupt received")
        signal_handler(signal.SIGINT, None)
        
    except Exception as e:
        logger.error(f"❌ Fatal error: {e}")
        log_to_database('system/error', f'Fatal error in MQTT logger: {str(e)}')
        sys.exit(1)

if __name__ == "__main__":
    main()
