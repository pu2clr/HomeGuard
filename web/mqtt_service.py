#!/usr/bin/env python3
"""
HomeGuard MQTT Activity Logger Service
Runs as a daemon service to capture all MQTT messages
"""

import os
import sys
import time
import signal
import threading
from datetime import datetime

# Add the parent directory to the path to import mqtt_activity_logger
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from web.mqtt_activity_logger import MQTTActivityLogger

# Service configuration
SERVICE_NAME = "HomeGuard MQTT Logger"
PID_FILE = "/tmp/homeguard_mqtt_logger.pid"
LOG_FILE = "/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/logs/mqtt_service.log"

class MQTTLoggerService:
    def __init__(self):
        self.logger = None
        self.running = False
        
    def start(self):
        """Start the MQTT logger service"""
        # Check if already running
        if os.path.exists(PID_FILE):
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            
            try:
                os.kill(pid, 0)  # Check if process exists
                print(f"❌ Service already running with PID {pid}")
                return False
            except OSError:
                # Process doesn't exist, remove stale PID file
                os.remove(PID_FILE)
        
        # Create logs directory if it doesn't exist
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        
        # Write PID file
        with open(PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
        
        # Set up signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        # Start the logger
        print(f"🚀 Starting {SERVICE_NAME}...")
        print(f"📋 PID: {os.getpid()}")
        print(f"📁 Log file: {LOG_FILE}")
        print("📡 MQTT Broker: 192.168.18.198:1883")
        print("🔧 Press Ctrl+C to stop")
        print("-" * 60)
        
        self.logger = MQTTActivityLogger()
        self.running = True
        
        try:
            self.logger.start()
            
            # Keep the service running
            while self.running:
                time.sleep(1)
                
        except Exception as e:
            print(f"❌ Error: {e}")
            self._cleanup()
            return False
        
        return True
    
    def stop(self):
        """Stop the MQTT logger service"""
        if os.path.exists(PID_FILE):
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            
            try:
                os.kill(pid, signal.SIGTERM)
                print(f"✅ Service stopped (PID {pid})")
                return True
            except OSError:
                print("❌ Service not running")
                os.remove(PID_FILE)
                return False
        else:
            print("❌ Service not running (no PID file)")
            return False
    
    def status(self):
        """Check service status"""
        if os.path.exists(PID_FILE):
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            
            try:
                os.kill(pid, 0)  # Check if process exists
                print(f"✅ Service running (PID {pid})")
                
                # Show recent statistics if database exists
                try:
                    from web.db_query import get_connection
                    conn = get_connection()
                    cursor = conn.cursor()
                    
                    # Get total records
                    cursor.execute("SELECT COUNT(*) FROM activity")
                    total_records = cursor.fetchone()[0]
                    
                    # Get recent activity count (last hour)
                    cursor.execute("""
                        SELECT COUNT(*) FROM activity 
                        WHERE created_at >= datetime('now', '-1 hour')
                    """)
                    recent_count = cursor.fetchone()[0]
                    
                    print(f"📊 Total messages: {total_records:,}")
                    print(f"🕐 Last hour: {recent_count} messages")
                    
                    conn.close()
                except Exception as e:
                    print(f"📊 Database info unavailable: {e}")
                
                return True
            except OSError:
                print("❌ Service not running (stale PID file)")
                os.remove(PID_FILE)
                return False
        else:
            print("❌ Service not running")
            return False
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        print(f"\n🛑 Received signal {signum}, shutting down...")
        self.running = False
        self._cleanup()
    
    def _cleanup(self):
        """Clean up resources"""
        if self.logger:
            self.logger.stop()
        
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        
        print("✅ Cleanup completed")

def main():
    service = MQTTLoggerService()
    
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} {{start|stop|restart|status}}")
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    if command == "start":
        success = service.start()
        sys.exit(0 if success else 1)
        
    elif command == "stop":
        success = service.stop()
        sys.exit(0 if success else 1)
        
    elif command == "restart":
        service.stop()
        time.sleep(2)
        success = service.start()
        sys.exit(0 if success else 1)
        
    elif command == "status":
        success = service.status()
        sys.exit(0 if success else 1)
        
    else:
        print(f"Unknown command: {command}")
        print(f"Usage: {sys.argv[0]} {{start|stop|restart|status}}")
        sys.exit(1)

if __name__ == "__main__":
    main()
