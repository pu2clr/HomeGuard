#!/bin/bash

# HomeGuard Audio Presence Simulator - Raspberry Pi Setup Script
# This script configures a Raspberry Pi 3 as an audio presence simulator

echo "🎵 HomeGuard Audio Presence Simulator Setup"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Warning: This script is designed for Raspberry Pi${NC}"
fi

echo -e "${BLUE}📋 Step 1: System Update${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "${BLUE}📋 Step 2: Installing System Dependencies${NC}"
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    mosquitto-clients \
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    mpg123 \
    sox \
    ffmpeg \
    curl \
    wget

echo -e "${BLUE}📋 Step 3: Audio Configuration${NC}"
# Enable audio
sudo modprobe snd_bcm2835
echo 'snd_bcm2835' | sudo tee -a /etc/modules > /dev/null

# Set audio output to 3.5mm jack by default
sudo amixer cset numid=3 1

# Test audio capability
echo -e "${YELLOW}🔊 Testing audio output...${NC}"
speaker-test -t sine -f 1000 -l 1 -s 1 &
SPEAKER_PID=$!
sleep 2
kill $SPEAKER_PID 2>/dev/null
echo -e "${GREEN}✅ Audio test completed${NC}"

echo -e "${BLUE}📋 Step 4: Python Environment Setup${NC}"
# Create virtual environment
python3 -m venv homeguard-audio-env
source homeguard-audio-env/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt

echo -e "${BLUE}📋 Step 5: Creating Audio Directory Structure${NC}"
mkdir -p audio_files/{dogs,footsteps,toilets,tv_radio,doors,background,alerts}

echo -e "${YELLOW}📁 Created audio file directories:${NC}"
echo "   audio_files/dogs/      - Dog barking sounds"
echo "   audio_files/footsteps/ - Footstep sounds"  
echo "   audio_files/toilets/   - Toilet flush sounds"
echo "   audio_files/tv_radio/  - TV/Radio background"
echo "   audio_files/doors/     - Door open/close sounds"
echo "   audio_files/background/- General background noise"
echo "   audio_files/alerts/    - Alert sounds"

echo -e "${BLUE}📋 Step 6: Downloading Sample Audio Files${NC}"
# Create sample audio download script
cat > download_sample_audio.sh << 'EOF'
#!/bin/bash
# Sample audio files downloader

echo "🎵 Downloading sample audio files..."

# Create directories
mkdir -p audio_files/{dogs,footsteps,toilets,tv_radio,doors,background,alerts}

# Function to download and convert audio
download_audio() {
    local url="$1"
    local filename="$2"
    local category="$3"
    
    echo "📥 Downloading $filename..."
    wget -q "$url" -O "temp_audio.tmp"
    
    if [ $? -eq 0 ]; then
        # Convert to mp3 if needed
        ffmpeg -i "temp_audio.tmp" -acodec libmp3lame "audio_files/$category/$filename" -y -loglevel quiet
        rm "temp_audio.tmp"
        echo "✅ $filename downloaded and converted"
    else
        echo "❌ Failed to download $filename"
    fi
}

# Note: Add your own audio file URLs here or use text-to-speech
echo "⚠️ Please add your own audio files to the directories or use freesound.org"
echo "   Sample formats: MP3, WAV, OGG"
echo "   For text-to-speech: Use espeak or festival"

# Generate sample footstep sound using sox
echo "🎶 Generating sample footstep sound..."
sox -n "audio_files/footsteps/footstep_sample.wav" synth 0.1 noise band -n 1000 2000 tremolo 20 40 fade 0.01 0.1 0.01

# Generate sample door sound
echo "🎶 Generating sample door sound..."  
sox -n "audio_files/doors/door_sample.wav" synth 0.5 noise band -n 500 1500 fade 0.01 0.5 0.01

echo "✅ Sample audio generation completed"
echo "📁 Add more audio files to enhance the presence simulation"
EOF

chmod +x download_sample_audio.sh
./download_sample_audio.sh

echo -e "${BLUE}📋 Step 7: Creating Systemd Service${NC}"
# Create systemd service file
sudo tee /etc/systemd/system/homeguard-audio.service > /dev/null << EOF
[Unit]
Description=HomeGuard Audio Presence Simulator
After=network.target sound.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=$(pwd)
Environment=PATH=$(pwd)/homeguard-audio-env/bin
ExecStart=$(pwd)/homeguard-audio-env/bin/python audio_presence_simulator.py
Restart=always
RestartSec=10

# Audio permissions
SupplementaryGroups=audio

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable homeguard-audio.service

echo -e "${BLUE}📋 Step 8: Audio Permissions${NC}"
# Add user to audio group
sudo usermod -a -G audio pi

echo -e "${BLUE}📋 Step 9: Creating Control Scripts${NC}"

# Create start script
cat > start_audio_simulator.sh << 'EOF'
#!/bin/bash
echo "🎵 Starting HomeGuard Audio Presence Simulator..."
source homeguard-audio-env/bin/activate
python audio_presence_simulator.py
EOF
chmod +x start_audio_simulator.sh

# Create test script  
cat > test_audio_system.sh << 'EOF'
#!/bin/bash
echo "🧪 Testing HomeGuard Audio System..."

# Test MQTT connection
echo "📡 Testing MQTT connection..."
mosquitto_pub -h 192.168.1.102 -t home/audio/cmnd -m "STATUS" -u homeguard -P pu2clr123456

# Test audio playback
echo "🔊 Testing audio playback..."
source homeguard-audio-env/bin/activate
python -c "
import pygame
pygame.mixer.init()
print('✅ Audio system initialized successfully')
pygame.mixer.quit()
"

echo "✅ Audio system test completed"
EOF
chmod +x test_audio_system.sh

# Create MQTT command examples
cat > mqtt_commands_examples.sh << 'EOF'
#!/bin/bash
# MQTT Command Examples for HomeGuard Audio System

BROKER="192.168.1.102"
USERNAME="homeguard" 
PASSWORD="pu2clr123456"
TOPIC="home/audio/cmnd"

echo "🎛️ HomeGuard Audio - MQTT Command Examples"
echo "========================================="

echo "📊 1. Request Status:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'STATUS' -u $USERNAME -P $PASSWORD"

echo "🐕 2. Dog Barking:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'DOGS' -u $USERNAME -P $PASSWORD"

echo "👣 3. Footsteps:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'FOOTSTEPS' -u $USERNAME -P $PASSWORD"

echo "🚽 4. Toilet Flush:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'TOILET' -u $USERNAME -P $PASSWORD"

echo "📺 5. TV Background:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'TV' -u $USERNAME -P $PASSWORD"

echo "🚪 6. Door Sound:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'DOOR' -u $USERNAME -P $PASSWORD"

echo "🌅 7. Morning Routine:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'MORNING' -u $USERNAME -P $PASSWORD"

echo "🌆 8. Evening Routine:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'EVENING' -u $USERNAME -P $PASSWORD"

echo "🎲 9. Random Activity:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'RANDOM' -u $USERNAME -P $PASSWORD"

echo "🏠 10. Set Mode - Home:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'MODE_HOME' -u $USERNAME -P $PASSWORD"

echo "✈️ 11. Set Mode - Away:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'MODE_AWAY' -u $USERNAME -P $PASSWORD"

echo "⏹️ 12. Stop Audio:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'STOP' -u $USERNAME -P $PASSWORD"

echo ""
echo "📡 Monitor all audio events:"
echo "mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t 'home/audio/#' -v"
EOF
chmod +x mqtt_commands_examples.sh

echo -e "${GREEN}✅ Setup completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Add your audio files to the audio_files/ directories"
echo "2. Test the system: ./test_audio_system.sh"
echo "3. Start the service: sudo systemctl start homeguard-audio"
echo "4. Check status: sudo systemctl status homeguard-audio"
echo "5. View logs: sudo journalctl -u homeguard-audio -f"
echo "6. Test MQTT commands: ./mqtt_commands_examples.sh"
echo ""
echo -e "${BLUE}🎵 Audio Presence Simulator is ready!${NC}"
echo "Configuration file: audio_config.json"
echo "Start manually: ./start_audio_simulator.sh"
