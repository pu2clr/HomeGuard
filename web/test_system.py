#!/usr/bin/env python3
"""
Test Script for HomeGuard MQTT Logger
Verifies that all paths are working correctly on any system
"""

import os
import sys

def test_paths():
    """Test all file paths used in the system"""
    
    print("🔍 Testing HomeGuard MQTT Logger Paths")
    print("=" * 50)
    
    # Get script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    
    print(f"📁 Script Directory: {script_dir}")
    print(f"📁 Project Root: {project_root}")
    print()
    
    # Test paths
    paths_to_test = {
        "Database Directory": os.path.join(project_root, "db"),
        "Database File": os.path.join(project_root, "db", "homeguard.db"),
        "Logs Directory": os.path.join(project_root, "logs"),
        "Log File": os.path.join(script_dir, "mqtt_logger.log"),
        "Service Log": os.path.join(project_root, "logs", "mqtt_service.log"),
    }
    
    all_good = True
    
    for name, path in paths_to_test.items():
        exists = os.path.exists(path)
        can_create = True
        
        if not exists:
            # Test if we can create the directory/file
            try:
                parent_dir = os.path.dirname(path)
                if not os.path.exists(parent_dir):
                    os.makedirs(parent_dir, exist_ok=True)
                    print(f"✅ {name}: Created directory {parent_dir}")
                
                # Test write permission
                if name.endswith("File") or name.endswith("Log"):
                    test_file = path + ".test"
                    with open(test_file, 'w') as f:
                        f.write("test")
                    os.remove(test_file)
                    print(f"✅ {name}: {path} (writable)")
                else:
                    print(f"✅ {name}: {path} (accessible)")
                    
            except Exception as e:
                print(f"❌ {name}: {path} - ERROR: {e}")
                can_create = False
                all_good = False
        else:
            print(f"✅ {name}: {path} (exists)")
    
    print()
    
    # Test imports
    print("🔧 Testing Module Imports")
    print("-" * 30)
    
    try:
        import sqlite3
        print("✅ sqlite3: Available")
    except ImportError as e:
        print(f"❌ sqlite3: {e}")
        all_good = False
    
    try:
        import paho.mqtt.client as mqtt
        print("✅ paho-mqtt: Available")
    except ImportError as e:
        print(f"❌ paho-mqtt: {e} - Install with: pip install paho-mqtt")
        all_good = False
    
    try:
        import json
        print("✅ json: Available")
    except ImportError as e:
        print(f"❌ json: {e}")
        all_good = False
    
    print()
    
    # Test Python version
    print("🐍 Python Environment")
    print("-" * 30)
    print(f"✅ Python Version: {sys.version}")
    print(f"✅ Platform: {sys.platform}")
    print(f"✅ Executable: {sys.executable}")
    
    print()
    
    if all_good:
        print("🎉 ALL TESTS PASSED!")
        print("✅ The system is ready to run on this platform")
    else:
        print("⚠️  SOME TESTS FAILED!")
        print("❌ Please fix the issues above before running the system")
    
    return all_good

def test_database_init():
    """Test database initialization"""
    print("\n🗄️  Testing Database Initialization")
    print("-" * 40)
    
    try:
        # Import and run database initialization
        sys.path.append(os.path.dirname(os.path.abspath(__file__)))
        from init_database import init_database
        
        result = init_database()
        if result:
            print("✅ Database initialization successful!")
        else:
            print("❌ Database initialization failed!")
        
        return result
        
    except Exception as e:
        print(f"❌ Database initialization error: {e}")
        return False

if __name__ == "__main__":
    print("🚀 HomeGuard System Test")
    print("=" * 60)
    
    # Test paths
    paths_ok = test_paths()
    
    if paths_ok:
        # Test database
        db_ok = test_database_init()
        
        if db_ok:
            print("\n🎯 SYSTEM READY!")
            print("Next steps:")
            print("1. python3 mqtt_service.py start")
            print("2. python3 db_query.py --stats")
        else:
            print("\n❌ Database setup failed")
    else:
        print("\n❌ Path setup failed")
