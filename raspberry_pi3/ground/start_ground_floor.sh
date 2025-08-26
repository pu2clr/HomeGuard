#!/bin/bash
# Start Ground Floor Audio Simulator

echo "🏠 HomeGuard Audio - Starting Ground Floor Simulator"

# Navigate to ground floor directory
cd "$(dirname "$0")"

# Check Python environment
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found. Please install Python 3."
    exit 1
fi

# Check required dependencies
python3 -c "import pygame, paho.mqtt.client as mqtt, schedule" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  Missing dependencies. Installing..."
    pip3 install pygame paho-mqtt schedule
fi

# Set PYTHONPATH to include shared directory
export PYTHONPATH="${PYTHONPATH}:../shared"

# Create log directory
mkdir -p ../logs

# Start the ground floor simulator
echo "🚀 Starting Ground Floor Audio Presence Simulator..."
python3 audio_ground.py 2>&1 | tee ../logs/ground_floor_$(date +%Y%m%d_%H%M%S).log

echo "✅ Ground floor simulator started successfully"
