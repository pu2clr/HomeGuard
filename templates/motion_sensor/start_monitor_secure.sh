#!/bin/bash

# HomeGuard Motion Sensor Monitor Launcher - Enhanced Security
# Script to start the motion sensor monitor with proper Python environment and TLS support

echo "🏠 HomeGuard Motion Sensor Monitor Launcher (Enhanced Security)"
echo "============================================================"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "Please install Python 3 and try again."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create virtual environment."
        exit 1
    fi
fi

# Activate virtual environment
echo "🔧 Activating Python virtual environment..."
source "$VENV_DIR/bin/activate"

# Check if paho-mqtt is installed in venv
if ! python -c "import paho.mqtt.client" &> /dev/null; then
    echo "📦 Installing required dependencies in virtual environment..."
    pip install -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install dependencies."
        echo "Please check your internet connection and try again."
        exit 1
    fi
fi

echo "✅ Dependencies checked"
echo ""

# Default configuration
BROKER="192.168.18.198"
USERNAME="homeguard"
LOCATIONS="Garagem,Area_Servico,Varanda,Mezanino,Ad_Hoc"

# Check for TLS certificates
CA_CERT_PATH="/etc/mosquitto/certs/ca.crt"
USE_TLS="false"
PORT="1883"

if [ -f "$CA_CERT_PATH" ]; then
    USE_TLS="true"
    PORT="8883"
    echo "🔐 TLS certificates found - enabling secure connection"
else
    echo "🔓 TLS certificates not found - using plain text connection"
    echo "   To enable TLS, run: sudo ./scripts/setup-mqtt-security.sh"
fi

echo ""
echo "🔧 Configuration:"
echo "   MQTT Broker: $BROKER"
echo "   Port: $PORT"
echo "   Security: $([ "$USE_TLS" = "true" ] && echo "TLS/SSL Enabled" || echo "Plain text")"
echo "   Username: $USERNAME"
echo "   Locations: $LOCATIONS"
echo "   Python Environment: $VENV_DIR"
if [ "$USE_TLS" = "true" ]; then
    echo "   CA Certificate: $CA_CERT_PATH"
fi
echo ""

echo "🚀 Starting motion sensor monitor..."
echo "   Press 's' + Enter to show status"
echo "   Press 'r' + Enter to request sensor status"
echo "   Press 'q' + Enter to quit"
echo "   Press Ctrl+C to stop"
echo ""

# Build command arguments
MONITOR_ARGS=(
    "--broker" "$BROKER"
    "--port" "$PORT"
    "--username" "$USERNAME"
    "--locations" "$LOCATIONS"
)

# Add TLS arguments if available
if [ "$USE_TLS" = "true" ]; then
    MONITOR_ARGS+=("--tls" "--ca-cert" "$CA_CERT_PATH")
fi

# Start the monitor
python motion_sensor_monitor.py "${MONITOR_ARGS[@]}"
