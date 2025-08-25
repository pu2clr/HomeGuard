#!/bin/bash
# Fix HomeGuard Audio Dependencies on Raspberry Pi 3

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fixing HomeGuard Audio Dependencies${NC}"
echo "=============================================="

# Check if we're on the Raspberry Pi
if [ ! -f "/etc/rpi-issue" ]; then
    echo -e "${YELLOW}⚠️  Warning: This script is designed for Raspberry Pi${NC}"
fi

# Check current directory
if [ ! -f "audio_presence_simulator.py" ]; then
    echo -e "${RED}❌ Error: Run this script from the raspberry_pi directory${NC}"
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "homeguard-audio-env" ]; then
    echo -e "${YELLOW}📦 Creating virtual environment...${NC}"
    python3 -m venv homeguard-audio-env
    echo -e "${GREEN}✅ Virtual environment created${NC}"
fi

# Activate virtual environment
echo -e "${BLUE}🔄 Activating virtual environment...${NC}"
source homeguard-audio-env/bin/activate

# Update pip
echo -e "${BLUE}📦 Updating pip...${NC}"
pip install --upgrade pip

# Install system dependencies for audio
echo -e "${BLUE}🔊 Installing system audio dependencies...${NC}"
sudo apt-get update -qq
sudo apt-get install -y python3-pygame python3-dev libasound2-dev

# Install Python dependencies
echo -e "${BLUE}📋 Installing Python dependencies...${NC}"
pip install -r requirements.txt

# Test imports
echo -e "${BLUE}🧪 Testing imports...${NC}"

python3 -c "
import pygame
print('✅ pygame imported successfully')

import paho.mqtt.client as mqtt
print('✅ paho-mqtt imported successfully')

import schedule
print('✅ schedule imported successfully')

import json, random, time, threading, os, sys
from datetime import datetime, timedelta
from pathlib import Path
print('✅ All standard modules imported successfully')
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 All dependencies installed successfully!${NC}"
else
    echo -e "${RED}❌ Some imports failed${NC}"
fi

# Test audio system
echo -e "${BLUE}🔊 Testing audio system...${NC}"
python3 -c "
import pygame
pygame.mixer.pre_init(frequency=22050, size=-16, channels=2, buffer=1024)
pygame.mixer.init()
print('✅ Audio system initialized successfully')
pygame.mixer.quit()
"

# Check audio devices
echo -e "${BLUE}🎧 Available audio devices:${NC}"
aplay -l 2>/dev/null | grep "card" || echo "No audio devices found"

# Create test script
cat > test_audio_imports.py << 'EOF'
#!/usr/bin/env python3
"""Test all imports for audio presence simulator"""

try:
    import pygame
    print("✅ pygame: OK")
except ImportError as e:
    print(f"❌ pygame: {e}")

try:
    import json
    print("✅ json: OK") 
except ImportError as e:
    print(f"❌ json: {e}")

try:
    import random
    print("✅ random: OK")
except ImportError as e:
    print(f"❌ random: {e}")

try:
    import time
    print("✅ time: OK")
except ImportError as e:
    print(f"❌ time: {e}")

try:
    import schedule
    print("✅ schedule: OK")
except ImportError as e:
    print(f"❌ schedule: {e}")

try:
    import threading
    print("✅ threading: OK")
except ImportError as e:
    print(f"❌ threading: {e}")

try:
    import os
    print("✅ os: OK")
except ImportError as e:
    print(f"❌ os: {e}")

try:
    import sys
    print("✅ sys: OK")
except ImportError as e:
    print(f"❌ sys: {e}")

try:
    from datetime import datetime, timedelta
    print("✅ datetime: OK")
except ImportError as e:
    print(f"❌ datetime: {e}")

try:
    import paho.mqtt.client as mqtt
    print("✅ paho-mqtt: OK")
except ImportError as e:
    print(f"❌ paho-mqtt: {e}")

try:
    from pathlib import Path
    print("✅ pathlib: OK")
except ImportError as e:
    print(f"❌ pathlib: {e}")

print("\n🧪 Testing pygame audio initialization...")
try:
    pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=1024)
    print("✅ pygame mixer initialized")
    pygame.mixer.quit()
except Exception as e:
    print(f"❌ pygame mixer error: {e}")

print("\n📡 Testing MQTT client...")
try:
    client = mqtt.Client()
    print("✅ MQTT client created")
except Exception as e:
    print(f"❌ MQTT client error: {e}")
EOF

chmod +x test_audio_imports.py

# Run the test
echo -e "${BLUE}🧪 Running comprehensive import test...${NC}"
python3 test_audio_imports.py

echo ""
echo -e "${GREEN}✅ Dependency fix completed!${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Test the audio simulator:"
echo "   source homeguard-audio-env/bin/activate"
echo "   python3 audio_presence_simulator.py"
echo ""
echo "2. Or restart the service:"
echo "   sudo systemctl restart homeguard-audio"
echo ""
echo "3. Check service status:"
echo "   sudo systemctl status homeguard-audio"
