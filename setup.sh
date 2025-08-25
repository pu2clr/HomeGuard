#!/bin/bash

# HomeGuard Setup Script
# This script helps set up the HomeGuard development environment

set -e

echo "=== HomeGuard Setup Script ==="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Python installation
echo "Checking Python installation..."
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    echo "✅ Python 3 found: $PYTHON_VERSION"
else
    echo "❌ Python 3 not found. Please install Python 3.7+ first."
    exit 1
fi

# Check pip installation
echo "Checking pip installation..."
if command_exists pip3; then
    echo "✅ pip3 found"
else
    echo "❌ pip3 not found. Please install pip3 first."
    exit 1
fi

# Create virtual environment
echo ""
echo "Creating Python virtual environment..."
if [ ! -d "homeguard-env" ]; then
    python3 -m venv homeguard-env
    echo "✅ Virtual environment created"
else
    echo "ℹ️ Virtual environment already exists"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source homeguard-env/bin/activate

# Install Python requirements
echo "Installing Python requirements..."
if [ -f "python/requirements.txt" ]; then
    pip install -r python/requirements.txt
    echo "✅ Python requirements installed"
else
    echo "❌ requirements.txt not found"
    exit 1
fi

# Check MQTT broker
echo ""
echo "Checking for MQTT broker..."
if command_exists mosquitto; then
    echo "✅ Mosquitto found"
    
    # Check if mosquitto is running
    if pgrep mosquitto > /dev/null; then
        echo "✅ Mosquitto is running"
    else
        echo "⚠️ Mosquitto is installed but not running"
        echo "   Start it with: sudo systemctl start mosquitto"
    fi
else
    echo "⚠️ Mosquitto not found"
    echo "   Install it with:"
    echo "   Ubuntu/Debian: sudo apt install mosquitto mosquitto-clients"
    echo "   macOS: brew install mosquitto"
    echo "   Windows: Download from https://mosquitto.org/download/"
fi

# Create example configuration
echo ""
echo "Setting up configuration files..."
if [ ! -f "python/config.json" ]; then
    if [ -f "python/config.json.example" ]; then
        cp python/config.json.example python/config.json
        echo "✅ Created config.json from example"
        echo "   Edit python/config.json with your broker settings"
    else
        echo "❌ config.json.example not found"
    fi
else
    echo "ℹ️ config.json already exists"
fi

# Test Python client
echo ""
echo "Testing Python client..."
cd python
if python schedule_manager.py --help > /dev/null 2>&1; then
    echo "✅ Python client working"
else
    echo "❌ Python client test failed"
fi
cd ..

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit python/config.json with your MQTT broker settings"
echo "2. Install and configure Mosquitto MQTT broker"
echo "3. Program your ESP-01S with the HomeGuard sketch"
echo "4. Test device discovery:"
echo "   cd python"
echo "   python schedule_manager.py --broker YOUR_BROKER_IP --list-devices"
echo ""
echo "For detailed instructions, see README.md"

# Deactivate virtual environment
deactivate 2>/dev/null || true
