#!/bin/bash
echo "🧪 Testing HomeGuard Audio System..."

# Test MQTT connection
echo "📡 Testing MQTT connection..."
mosquitto_pub -h 192.168.18.236 -t home/audio/cmnd -m "STATUS" -u homeguard -P pu2clr123456

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
