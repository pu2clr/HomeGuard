#!/bin/bash
"""
Install dependencies for HomeGuard MQTT Logger
"""

echo "🔧 Installing HomeGuard MQTT Logger Dependencies"
echo "================================================"

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 not found. Please install Python3 and pip3 first."
    exit 1
fi

echo "📦 Installing paho-mqtt..."
pip3 install paho-mqtt

echo "📦 Installing additional dependencies..."
pip3 install sqlite3 || echo "✅ sqlite3 is built-in to Python"

echo ""
echo "✅ Dependencies installed successfully!"
echo ""
echo "🧪 Testing installation..."
python3 -c "import paho.mqtt.client as mqtt; print('✅ paho-mqtt: OK')"
python3 -c "import sqlite3; print('✅ sqlite3: OK')"
python3 -c "import json; print('✅ json: OK')"

echo ""
echo "🎉 All dependencies are ready!"
echo ""
echo "Next steps:"
echo "1. python3 web/test_system.py    # Test the system"
echo "2. python3 web/init_database.py  # Initialize database"
echo "3. python3 web/mqtt_service.py start  # Start MQTT logger"
