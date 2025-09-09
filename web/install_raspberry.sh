#!/bin/bash
"""
HomeGuard MQTT Logger - Raspberry Pi Installation Script
Handles externally-managed Python environment properly
"""

echo "🍓 HomeGuard MQTT Logger - Raspberry Pi Setup"
echo "=============================================="

# Check if we're on Raspberry Pi
if [ ! -f /etc/rpi-issue ]; then
    echo "⚠️  This script is designed for Raspberry Pi OS"
    echo "   For other systems, use: pip3 install paho-mqtt"
fi

echo ""
echo "🔍 Checking Python environment..."

# Method 1: Try system package manager first (recommended for Raspberry Pi)
echo "📦 Method 1: Installing via apt (system package manager)"
if command -v apt-get >/dev/null 2>&1; then
    echo "   Installing python3-paho-mqtt via apt..."
    sudo apt update
    sudo apt install -y python3-paho-mqtt python3-full
    
    # Test if it worked
    if python3 -c "import paho.mqtt.client" 2>/dev/null; then
        echo "✅ paho-mqtt installed successfully via apt!"
        echo ""
        echo "🧪 Testing installation..."
        python3 -c "import paho.mqtt.client as mqtt; print('✅ paho-mqtt: OK')"
        python3 -c "import sqlite3; print('✅ sqlite3: OK')"
        python3 -c "import json; print('✅ json: OK')"
        echo ""
        echo "🎉 All dependencies ready!"
        echo ""
        echo "Next steps:"
        echo "1. python3 test_system.py"
        echo "2. python3 init_database.py"
        echo "3. python3 mqtt_service.py start"
        exit 0
    fi
fi

echo ""
echo "📦 Method 2: Creating virtual environment (fallback)"

# Check if python3-venv is installed
if ! python3 -c "import venv" 2>/dev/null; then
    echo "   Installing python3-venv..."
    sudo apt install -y python3-venv python3-full
fi

# Create virtual environment in the project
VENV_PATH="../venv_homeguard"
if [ ! -d "$VENV_PATH" ]; then
    echo "   Creating virtual environment: $VENV_PATH"
    python3 -m venv "$VENV_PATH"
fi

# Activate virtual environment
echo "   Activating virtual environment..."
source "$VENV_PATH/bin/activate"

# Install packages in virtual environment
echo "   Installing paho-mqtt in virtual environment..."
pip install paho-mqtt

# Test installation
echo ""
echo "🧪 Testing virtual environment installation..."
"$VENV_PATH/bin/python" -c "import paho.mqtt.client as mqtt; print('✅ paho-mqtt: OK')"
"$VENV_PATH/bin/python" -c "import sqlite3; print('✅ sqlite3: OK')"
"$VENV_PATH/bin/python" -c "import json; print('✅ json: OK')"

echo ""
echo "✅ Virtual environment setup complete!"
echo ""
echo "📋 To use the virtual environment:"
echo "   source ../venv_homeguard/bin/activate"
echo ""
echo "📋 Or use the Python executable directly:"
echo "   ../venv_homeguard/bin/python test_system.py"
echo "   ../venv_homeguard/bin/python init_database.py"
echo "   ../venv_homeguard/bin/python mqtt_service.py start"

# Create convenience scripts
echo ""
echo "🔧 Creating convenience scripts..."

# Create run_with_venv.sh
cat > run_with_venv.sh << 'EOF'
#!/bin/bash
# Convenience script to run HomeGuard scripts with virtual environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PATH="$SCRIPT_DIR/../venv_homeguard"

if [ ! -d "$VENV_PATH" ]; then
    echo "❌ Virtual environment not found. Run install_raspberry.sh first."
    exit 1
fi

"$VENV_PATH/bin/python" "$@"
EOF

chmod +x run_with_venv.sh

# Create quick commands
cat > quick_start.sh << 'EOF'
#!/bin/bash
# Quick start script for HomeGuard MQTT Logger
echo "🚀 HomeGuard Quick Start"
echo "======================="

# Test system
echo "1. Testing system..."
./run_with_venv.sh test_system.py

# Initialize database
echo ""
echo "2. Initializing database..."
./run_with_venv.sh init_database.py

# Start MQTT service
echo ""
echo "3. Starting MQTT service..."
./run_with_venv.sh mqtt_service.py start

echo ""
echo "✅ HomeGuard MQTT Logger started!"
echo ""
echo "📋 Useful commands:"
echo "   ./run_with_venv.sh mqtt_service.py status    # Check status"
echo "   ./run_with_venv.sh db_query.py --stats       # View statistics"
echo "   ./run_with_venv.sh mqtt_service.py stop      # Stop service"
EOF

chmod +x quick_start.sh

echo ""
echo "✅ Convenience scripts created:"
echo "   ./run_with_venv.sh <script>    # Run any script with venv"
echo "   ./quick_start.sh               # Complete setup and start"

deactivate 2>/dev/null || true
