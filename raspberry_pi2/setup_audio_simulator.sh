#!/bin/bash

# HomeGuard Audio System Setup - Raspberry Pi 2 (First Floor)
# Sets up audio presence simulation system for the first floor

echo "🏠 HomeGuard Audio Setup - Raspberry Pi 2 (First Floor)"
echo "======================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo -e "${YELLOW}⚠️  This script is designed for Raspberry Pi hardware${NC}"
    echo "   Continuing anyway for development/testing..."
fi

echo -e "${BLUE}📋 Step 1: Installing System Dependencies${NC}"

# Update system
sudo apt update && sudo apt upgrade -y

# Install audio system dependencies  
sudo apt install -y python3-pip python3-venv python3-dev
sudo apt install -y alsa-utils pulseaudio pulseaudio-utils
sudo apt install -y mpg123 sox ffmpeg
sudo apt install -y git wget curl

echo -e "${BLUE}📋 Step 2: Setting up Python Environment${NC}"

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python packages
pip install --upgrade pip
pip install pygame==2.5.2
pip install paho-mqtt==1.6.1  
pip install schedule==1.2.0
pip install pyaudio
pip install numpy
pip install requests

echo -e "${BLUE}📋 Step 3: Audio System Configuration${NC}"

# Set audio output (if on Pi)
if command -v amixer &> /dev/null; then
    # Set audio to maximum volume
    amixer set Master 80%
    
    # Set default audio output to analog (3.5mm jack)
    sudo raspi-config nonint do_audio 1
    
    echo "🔊 Audio output configured"
fi

# Create audio directories if they don't exist
mkdir -p audio_files/{dogs,footsteps,toilets,doors,shower,tv_radio,bedroom,alerts}

echo -e "${BLUE}📋 Step 4: MQTT Configuration Test${NC}"

# Test MQTT connection
echo "Testing MQTT connection to HomeGuard broker..."
python3 -c "
import paho.mqtt.client as mqtt
import json
import time

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print('✅ MQTT connection successful')
        client.publish('homeguard/audio/first/status', json.dumps({
            'device_id': 'audio_presence_rpi2_first_floor',
            'status': 'SETUP_TEST',
            'timestamp': str(time.time())
        }))
    else:
        print(f'❌ MQTT connection failed: {rc}')
    client.disconnect()

client = mqtt.Client()
client.username_pw_set('homeguard', 'pu2clr123456')
client.on_connect = on_connect

try:
    client.connect('192.168.18.6', 1883, 60)
    client.loop_forever(timeout=5)
except Exception as e:
    print(f'⚠️  MQTT test failed: {e}')
    print('   Check if MQTT broker is running on 192.168.18.6')
"

echo -e "${BLUE}📋 Step 5: Creating System Service${NC}"

# Create systemd service for auto-start
cat > /tmp/homeguard-audio-first.service << 'EOF'
[Unit]
Description=HomeGuard Audio Presence Simulator - First Floor
After=network.target sound.target
Wants=network.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/HomeGuard/raspberry_pi2
Environment=PATH=/home/pi/HomeGuard/raspberry_pi2/venv/bin
ExecStart=/home/pi/HomeGuard/raspberry_pi2/venv/bin/python audio_presence_simulator.py
Restart=always
RestartSec=10

# Audio access
SupplementaryGroups=audio

[Install]
WantedBy=multi-user.target
EOF

# Install service (with user confirmation)
read -p "Install as system service for auto-start? (y/n): " install_service
if [ "$install_service" = "y" ] || [ "$install_service" = "Y" ]; then
    sudo cp /tmp/homeguard-audio-first.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable homeguard-audio-first.service
    echo -e "${GREEN}✅ System service installed${NC}"
    echo "   Start with: sudo systemctl start homeguard-audio-first"
    echo "   Status: sudo systemctl status homeguard-audio-first"
else
    echo "⏭️  Service installation skipped"
fi

echo -e "${BLUE}📋 Step 6: Sample Audio Files${NC}"

# Create sample sound files for testing (if not exist)
if [ ! -f "audio_files/footsteps/test_footstep.wav" ]; then
    echo "Creating test audio files..."
    
    # Generate simple test tones using sox (if available)
    if command -v sox &> /dev/null; then
        # Footsteps - short low frequency tones
        sox -n audio_files/footsteps/test_footstep.wav synth 0.5 sine 200
        
        # Door - higher frequency with quick fade
        sox -n audio_files/doors/test_door.wav synth 0.3 sine 400 fade 0 0.3 0.1
        
        # Toilet - longer lower tone
        sox -n audio_files/toilets/test_toilet.wav synth 1.5 sine 150
        
        echo "✅ Test audio files created"
    else
        echo "⚠️  Install 'sox' to generate test audio files"
    fi
fi

echo -e "${BLUE}📋 Step 7: Audio Download Helper${NC}"

# Create script to help download audio files
cat > download_audio_files.sh << 'EOF'
#!/bin/bash

# HomeGuard Audio Files Download Helper - First Floor
# Downloads appropriate audio files for upstairs simulation

echo "🎵 HomeGuard Audio Files Download - First Floor"
echo "==============================================" 

# URLs for audio files (replace with your sources)
declare -A AUDIO_URLS=(
    ["footsteps"]="https://example.com/audio/upstairs_footsteps.wav"
    ["doors"]="https://example.com/audio/bedroom_door.wav"
    ["shower"]="https://example.com/audio/shower_running.wav"
    ["toilets"]="https://example.com/audio/upstairs_toilet.wav"
)

# Download function
download_audio() {
    local category=$1
    local url=$2
    
    echo "📥 Downloading $category audio..."
    mkdir -p "audio_files/$category"
    
    if wget -q "$url" -O "audio_files/$category/$(basename $url)"; then
        echo "✅ Downloaded: $category"
    else
        echo "❌ Failed to download: $category"
    fi
}

echo "This script helps download audio files for the first floor audio system."
echo "Update the AUDIO_URLS array with your audio file sources."
echo ""
echo "Categories needed:"
echo "  • footsteps - Walking sounds in hallways/bedrooms"
echo "  • doors - Bedroom and bathroom doors opening/closing"  
echo "  • shower - Shower and water sounds"
echo "  • toilets - Upstairs bathroom sounds"
echo "  • tv_radio - Bedroom TV/radio background"
echo "  • dogs - Dogs barking upstairs"
echo ""
echo "You can also manually copy audio files to the audio_files/ directories"

EOF

chmod +x download_audio_files.sh

echo -e "${BLUE}📋 Step 8: Testing Audio System${NC}"

# Create test script
cat > test_first_floor_audio.py << 'EOF'
#!/usr/bin/env python3

import pygame
import json
import time
from pathlib import Path

def test_audio_system():
    """Test the first floor audio system"""
    
    print("🧪 Testing First Floor Audio System")
    print("=" * 40)
    
    # Initialize pygame mixer
    try:
        pygame.mixer.init()
        print("✅ Audio system initialized")
    except Exception as e:
        print(f"❌ Audio system initialization failed: {e}")
        return False
    
    # Check audio files
    audio_base = Path('./audio_files')
    categories = ['footsteps', 'doors', 'toilets', 'shower', 'tv_radio', 'bedroom']
    
    for category in categories:
        category_path = audio_base / category
        if category_path.exists():
            files = list(category_path.glob('*'))
            print(f"📁 {category}: {len(files)} files")
        else:
            print(f"⚠️  {category}: directory missing")
    
    # Test configuration
    try:
        with open('audio_config.json', 'r') as f:
            config = json.load(f)
        print("✅ Configuration file loaded")
        print(f"   Location: {config.get('location', 'Unknown')}")
        print(f"   Floor: {config.get('floor', 'Unknown')}")
        print(f"   MQTT Broker: {config.get('mqtt_broker', 'Unknown')}")
    except Exception as e:
        print(f"❌ Configuration error: {e}")
    
    # Test MQTT topics structure
    print("\n📡 MQTT Topics for First Floor:")
    topics = [
        'homeguard/audio/first/cmnd',
        'homeguard/audio/first/status',
        'homeguard/audio/first/events',
        'homeguard/audio/first/heartbeat',
        'homeguard/audio/coordination'
    ]
    
    for topic in topics:
        print(f"   📻 {topic}")
    
    pygame.mixer.quit()
    print("\n✅ First floor audio system test completed")
    return True

if __name__ == "__main__":
    test_audio_system()
EOF

chmod +x test_first_floor_audio.py

echo -e "${GREEN}✅ HomeGuard Audio Setup Complete - First Floor${NC}"
echo "=============================================="
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo ""
echo "1. ${CYAN}Add Audio Files:${NC}"
echo "   • Copy audio files to audio_files/ subdirectories"
echo "   • Or run: ./download_audio_files.sh (after updating URLs)"
echo ""
echo "2. ${CYAN}Test the System:${NC}"
echo "   • Run: python3 test_first_floor_audio.py"
echo "   • Check audio output and MQTT connectivity"
echo ""
echo "3. ${CYAN}Start Audio System:${NC}"
echo "   • Manual: python3 audio_presence_simulator.py"
echo "   • Service: sudo systemctl start homeguard-audio-first"
echo ""
echo "4. ${CYAN}MQTT Commands (First Floor):${NC}"
echo "   • Topic: homeguard/audio/first/cmnd"
echo "   • Commands: FOOTSTEPS, DOORS, SHOWER, TV_RADIO, TOILETS"
echo "   • JSON: {\"action\":\"PLAY\",\"category\":\"footsteps\"}"
echo ""
echo "5. ${CYAN}Monitor Status:${NC}"
echo "   • Status: homeguard/audio/first/status"
echo "   • Events: homeguard/audio/first/events"
echo "   • Heartbeat: homeguard/audio/first/heartbeat"
echo ""
echo -e "${BLUE}🏠 System Coordination:${NC}"
echo "• First floor coordinates with ground floor (raspberry_pi3)"
echo "• Delays responses by 2-5 minutes for realistic simulation"
echo "• Responds to motion sensors throughout the house"
echo "• Different audio profiles for different times of day"
echo ""
echo -e "${GREEN}🎉 First Floor Audio System Ready!${NC}"
