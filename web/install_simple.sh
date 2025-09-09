#!/bin/bash
"""
Simple Raspberry Pi Installation - System Packages Only
"""

echo "🍓 HomeGuard MQTT Logger - Simple Setup"
echo "======================================="

echo "📦 Installing system packages..."
sudo apt update
sudo apt install -y python3-paho-mqtt python3-full

echo ""
echo "🧪 Testing installation..."
python3 -c "import paho.mqtt.client as mqtt; print('✅ paho-mqtt: OK')" || {
    echo "❌ paho-mqtt not available via system packages"
    echo "   Try the full installation script: ./install_raspberry.sh"
    exit 1
}

python3 -c "import sqlite3; print('✅ sqlite3: OK')"
python3 -c "import json; print('✅ json: OK')"

echo ""
echo "✅ System packages installed successfully!"
echo ""
echo "🚀 Ready to run:"
echo "   python3 test_system.py"
echo "   python3 init_database.py"
echo "   python3 mqtt_service.py start"
