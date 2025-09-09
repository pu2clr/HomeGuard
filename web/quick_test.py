#!/usr/bin/env python3
"""
Simple test script for MQTT Activity Logger
Tests imports and basic functionality without starting the full service
"""

import sys
import os

def test_imports():
    """Test all required imports"""
    print("🔧 Testing imports...")
    
    try:
        import sqlite3
        print("✅ sqlite3: OK")
    except ImportError as e:
        print(f"❌ sqlite3: {e}")
        return False
    
    try:
        import paho.mqtt.client as mqtt
        print("✅ paho-mqtt: OK")
    except ImportError as e:
        print(f"❌ paho-mqtt: {e}")
        print("   Install with: sudo apt install python3-paho-mqtt")
        return False
    
    try:
        from mqtt_activity_logger import MQTTActivityLogger
        print("✅ MQTTActivityLogger: OK")
    except ImportError as e:
        print(f"❌ MQTTActivityLogger: {e}")
        return False
    
    return True

def test_database():
    """Test database functionality"""
    print("\n🗄️  Testing database...")
    
    try:
        from init_database import init_database
        result = init_database()
        if result:
            print("✅ Database initialization: OK")
        else:
            print("❌ Database initialization: Failed")
            return False
    except Exception as e:
        print(f"❌ Database error: {e}")
        return False
    
    return True

def test_mqtt_class():
    """Test MQTT class instantiation"""
    print("\n📡 Testing MQTT class...")
    
    try:
        from mqtt_activity_logger import MQTTActivityLogger
        logger = MQTTActivityLogger()
        print("✅ MQTTActivityLogger instantiation: OK")
        return True
    except Exception as e:
        print(f"❌ MQTTActivityLogger error: {e}")
        return False

def test_service_commands():
    """Test service command functionality"""
    print("\n🔧 Testing service commands...")
    
    try:
        # Test status command (should return "not running")
        import subprocess
        result = subprocess.run([sys.executable, "mqtt_service.py", "status"], 
                              capture_output=True, text=True)
        
        if "not running" in result.stdout.lower() or result.returncode == 1:
            print("✅ Service status command: OK (service not running)")
        else:
            print(f"⚠️  Service status unexpected: {result.stdout}")
        
        return True
    except Exception as e:
        print(f"❌ Service command error: {e}")
        return False

def main():
    print("🧪 HomeGuard MQTT Logger - Quick Test")
    print("=====================================")
    
    all_good = True
    
    # Test imports
    if not test_imports():
        all_good = False
    
    # Test database
    if not test_database():
        all_good = False
    
    # Test MQTT class
    if not test_mqtt_class():
        all_good = False
    
    # Test service commands
    if not test_service_commands():
        all_good = False
    
    print("\n" + "="*50)
    
    if all_good:
        print("🎉 ALL TESTS PASSED!")
        print("")
        print("✅ System is ready to run")
        print("")
        print("📋 Next steps:")
        print("   python3 mqtt_service.py start     # Start MQTT logger")
        print("   python3 mqtt_service.py status    # Check status")
        print("   python3 db_query.py --stats       # View statistics")
        print("   python3 mqtt_service.py stop      # Stop service")
    else:
        print("❌ SOME TESTS FAILED!")
        print("")
        print("🔧 Please fix the issues above before starting the service")
    
    return all_good

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
