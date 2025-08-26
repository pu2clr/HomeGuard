#!/bin/bash
# HomeGuard Audio System - Initial Setup Script for Dual Pi3 Architecture

echo "🏠 HomeGuard Audio Presence System Setup"
echo "=========================================="

# Function to create directory structure
create_directories() {
    local floor=$1
    echo "📁 Creating $floor floor directories..."
    
    mkdir -p raspberry_pi3/$floor/audio_files/doors
    mkdir -p raspberry_pi3/$floor/audio_files/footsteps
    mkdir -p raspberry_pi3/$floor/audio_files/alerts
    
    if [ "$floor" = "ground" ]; then
        mkdir -p raspberry_pi3/$floor/audio_files/dogs
        mkdir -p raspberry_pi3/$floor/audio_files/tv_radio
    elif [ "$floor" = "first" ]; then
        mkdir -p raspberry_pi3/$floor/audio_files/toilets
        mkdir -p raspberry_pi3/$floor/audio_files/shower
        mkdir -p raspberry_pi3/$floor/audio_files/bedroom
    fi
    
    echo "✅ $floor floor directories created"
}

# Function to install dependencies
install_dependencies() {
    echo "📦 Installing Python dependencies..."
    
    # Check if pip3 is available
    if ! command -v pip3 &> /dev/null; then
        echo "❌ pip3 not found. Please install Python 3 and pip first."
        exit 1
    fi
    
    # Install required packages
    pip3 install pygame paho-mqtt schedule
    
    echo "✅ Dependencies installed"
}

# Function to test MQTT connectivity
test_mqtt() {
    echo "🔌 Testing MQTT connectivity..."
    
    if command -v mosquitto_pub &> /dev/null; then
        mosquitto_pub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
            -t "homeguard/test" -m "Setup test" &>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ MQTT broker connection successful"
        else
            echo "⚠️  MQTT broker connection failed - check credentials"
        fi
    else
        echo "ℹ️  mosquitto-clients not installed - skipping MQTT test"
    fi
}

# Function to create sample audio files info
create_audio_info() {
    echo "🎵 Creating audio files information..."
    
    cat > raspberry_pi3/AUDIO_FILES_NEEDED.md << EOF
# Audio Files Required

## Ground Floor (raspberry_pi3/ground/audio_files/)

### dogs/
- dog_bark_1.wav
- dog_bark_2.wav
- dog_walking.wav
- dog_eating.wav

### doors/
- door_open.wav
- door_close.wav
- door_creak.wav
- lock_sound.wav

### footsteps/
- footsteps_wood.wav
- footsteps_tile.wav
- footsteps_carpet.wav

### tv_radio/
- tv_channel_change.wav
- tv_volume.wav
- radio_static.wav
- news_sound.wav

### alerts/
- security_beep.wav
- low_battery.wav

## First Floor (raspberry_pi3/first/audio_files/)

### doors/
- bedroom_door.wav
- bathroom_door.wav
- closet_door.wav

### footsteps/
- footsteps_hallway.wav
- footsteps_bedroom.wav

### toilets/
- toilet_flush.wav
- sink_water.wav
- bathroom_fan.wav

### shower/
- shower_running.wav
- shower_door.wav

### bedroom/
- bed_creak.wav
- dresser_drawer.wav
- clothes_rustle.wav

### alerts/
- smoke_detector.wav
- security_beep.wav

## File Format Requirements
- Format: WAV, MP3, or OGG
- Quality: 44.1kHz, 16-bit minimum
- Length: 2-10 seconds typical
- Volume: Normalized to prevent clipping
EOF

    echo "✅ Audio files info created: AUDIO_FILES_NEEDED.md"
}

# Main setup process
main() {
    echo "🚀 Starting HomeGuard Audio Setup..."
    
    # Navigate to project directory
    cd "$(dirname "$0")"
    
    # Create base directories
    mkdir -p raspberry_pi3/logs
    
    # Create floor-specific directories
    create_directories "ground"
    create_directories "first"
    
    # Create audio files info
    create_audio_info
    
    # Install dependencies (optional)
    read -p "Install Python dependencies? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_dependencies
    fi
    
    # Test MQTT (optional)
    read -p "Test MQTT connectivity? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_mqtt
    fi
    
    # Make scripts executable
    chmod +x raspberry_pi3/ground/start_ground_floor.sh
    chmod +x raspberry_pi3/first/start_first_floor.sh
    
    echo ""
    echo "🎉 Setup Complete!"
    echo ""
    echo "Next steps:"
    echo "1. Add audio files to respective directories (see AUDIO_FILES_NEEDED.md)"
    echo "2. Configure MQTT broker settings if needed"
    echo "3. Test ground floor: cd raspberry_pi3/ground && ./start_ground_floor.sh"
    echo "4. Test first floor: cd raspberry_pi3/first && ./start_first_floor.sh"
    echo ""
    echo "📖 Full documentation: raspberry_pi3/README.md"
}

# Run main function
main "$@"
