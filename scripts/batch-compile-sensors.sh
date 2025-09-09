#!/bin/bash

# HomeGuard Motion Sensor Batch Compiler
# Compiles all 5 motion sensors at once for quick deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKETCH_TEMPLATE="$PROJECT_DIR/source/esp01/mqtt/motion_detector/motion_detector_template.ino"
BUILD_DIR="$PROJECT_DIR/build/batch_compile"
FQBN="esp8266:esp8266:generic"

# Sensor configurations
declare -A SENSORS=(
    ["garagem"]="Garagem,201,motion_garagem"
    ["area_servico"]="Area_Servico,202,motion_area_servico"
    ["varanda"]="Varanda,203,motion_varanda"
    ["mezanino"]="Mezanino,204,motion_mezanino"
    ["adhoc"]="Ad_Hoc,205,motion_adhoc"
)

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v arduino-cli &> /dev/null; then
        print_error "arduino-cli is not installed"
        exit 1
    fi
    
    if [ ! -f "$SKETCH_TEMPLATE" ]; then
        print_error "Template file not found: $SKETCH_TEMPLATE"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to compile single sensor
compile_sensor() {
    local sensor_key="$1"
    IFS=',' read -r location ip topic <<< "${SENSORS[$sensor_key]}"
    
    print_info "Compiling $location (IP: 192.168.18.$ip)..."
    
    # Create sensor-specific directory
    local sensor_dir="$BUILD_DIR/${sensor_key}_motion_sensor"
    mkdir -p "$sensor_dir"
    
    # Copy template and rename
    local sketch_file="$sensor_dir/${sensor_key}_motion_sensor.ino"
    cp "$SKETCH_TEMPLATE" "$sketch_file"
    
    # Build flags
    local build_flags="--build-property compiler.cpp.extra_flags="
    build_flags+="-DDEVICE_LOCATION=$location "
    build_flags+="-DDEVICE_IP_LAST_OCTET=$ip "
    build_flags+="-DMQTT_TOPIC_SUFFIX=$topic"
    
    # Compile
    if arduino-cli compile \
        --fqbn "$FQBN" \
        --build-path "$sensor_dir/build" \
        $build_flags \
        --quiet \
        "$sketch_file" 2>/dev/null; then
        
        print_success "$location compiled successfully"
        
        # Copy the .bin file to a more accessible location
        local bin_file="$sensor_dir/build/${sensor_key}_motion_sensor.ino.bin"
        local firmware_dir="$PROJECT_DIR/firmware"
        mkdir -p "$firmware_dir"
        
        if [ -f "$bin_file" ]; then
            cp "$bin_file" "$firmware_dir/${location}_motion_sensor.bin"
            print_info "Firmware saved: firmware/${location}_motion_sensor.bin"
        fi
        
        return 0
    else
        print_error "$location compilation failed"
        return 1
    fi
}

# Function to create upload instructions
create_upload_instructions() {
    local instructions_file="$PROJECT_DIR/UPLOAD_INSTRUCTIONS.md"
    
    cat > "$instructions_file" << EOF
# HomeGuard Motion Sensors - Upload Instructions

## 📦 Compiled Firmware Files

The following firmware files have been compiled and are ready for upload:

| Location | IP Address | Firmware File | MQTT Topic |
|----------|------------|---------------|------------|
EOF

    for sensor_key in $(echo "${!SENSORS[@]}" | tr ' ' '\n' | sort); do
        IFS=',' read -r location ip topic <<< "${SENSORS[$sensor_key]}"
        echo "| $location | 192.168.18.$ip | firmware/${location}_motion_sensor.bin | home/$topic |" >> "$instructions_file"
    done

    cat >> "$instructions_file" << 'EOF'

## 🔧 Upload Process

### Method 1: Using arduino-cli (Recommended)

For each sensor, follow these steps:

1. **Prepare ESP-01S for programming:**
   - Connect GPIO0 to GND (programming mode)
   - Connect ESP-01S to USB-to-serial adapter
   - Power cycle the device

2. **Upload firmware:**
   ```bash
   # Example for Garagem sensor
   arduino-cli upload \
     --fqbn esp8266:esp8266:generic \
     --port /dev/tty.usbserial-XXXX \
     --input-file firmware/Garagem_motion_sensor.bin
   ```

3. **Exit programming mode:**
   - Disconnect GPIO0 from GND
   - Power cycle the device

### Method 2: Using the interactive script

```bash
./scripts/compile-motion-sensors.sh
```

The script will guide you through:
- Selecting which sensor to upload
- Choosing the USB port
- Automatic compilation and upload

## 📡 Testing After Upload

### Basic connectivity test:
```bash
# Replace motion_garagem with the appropriate topic for your sensor
mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "home/motion_garagem/#" -v
```

### Device status check:
```bash
# Replace motion_garagem with the appropriate topic for your sensor
mosquitto_pub -h 192.168.18.198 -t "home/motion_garagem/cmnd" -m "STATUS" -u homeguard -P pu2clr123456
```

### Network ping test:
```bash
# Replace with the appropriate IP for your sensor
ping 192.168.18.201
```

## 🏠 MQTT Topic Structure

Each sensor publishes to its own topic tree:

```
home/[sensor_topic]/
├── cmnd          # Commands (STATUS, RESET, SENSITIVITY_*, etc.)
├── status        # Device status (JSON)
├── motion        # Motion events (JSON)
├── heartbeat     # Keep-alive messages
└── config        # Configuration confirmations
```

## 🔍 Serial Monitor

To view debug output from any sensor:

```bash
# Replace with your USB port
screen /dev/tty.usbserial-XXXX 115200

# Or using arduino-cli
arduino-cli monitor -p /dev/tty.usbserial-XXXX -c baudrate=115200
```

## 🛠️ Troubleshooting

### Upload Issues:
- ✅ ESP-01S in programming mode (GPIO0 to GND)
- ✅ Correct USB port selected
- ✅ USB-to-serial adapter drivers installed
- ✅ Stable power supply (3.3V)

### Network Issues:
- ✅ WiFi network "YOUR_SSID" available
- ✅ IP address not conflicting with other devices
- ✅ MQTT broker running on 192.168.18.198

### Motion Detection Issues:
- ✅ PIR sensor connected to GPIO2
- ✅ PIR sensor powered (3.3V)
- ✅ PIR sensor calibration period (60 seconds after power-on)

## 📞 Support Commands

### Check all motion sensors:
```bash
for topic in motion_garagem motion_area_servico motion_varanda motion_mezanino motion_adhoc; do
  echo "Checking $topic..."
  mosquitto_pub -h 192.168.18.198 -t "home/$topic/cmnd" -m "STATUS" -u homeguard -P pu2clr123456
  sleep 2
done
```

### Monitor all sensors:
```bash
mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "home/motion_+/+" -v
```

EOF

    print_success "Upload instructions created: UPLOAD_INSTRUCTIONS.md"
}

# Function to create testing script
create_testing_script() {
    local test_script="$PROJECT_DIR/scripts/test-all-motion-sensors.sh"
    
    cat > "$test_script" << 'EOF'
#!/bin/bash

# Test script for all HomeGuard motion sensors

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

BROKER="192.168.18.198"
USERNAME="homeguard"
PASSWORD="pu2clr123456"

declare -A SENSOR_IPS=(
    ["motion_garagem"]="192.168.18.201"
    ["motion_area_servico"]="192.168.18.202"
    ["motion_varanda"]="192.168.18.203"
    ["motion_mezanino"]="192.168.18.204"
    ["motion_adhoc"]="192.168.18.205"
)

echo -e "${BLUE}🧪 Testing all HomeGuard Motion Sensors${NC}"
echo "========================================"

# Test network connectivity
echo ""
echo "📡 Network Connectivity Test:"
for topic in "${!SENSOR_IPS[@]}"; do
    ip="${SENSOR_IPS[$topic]}"
    if ping -c 1 -W 1000 "$ip" >/dev/null 2>&1; then
        echo -e "  ✅ $topic ($ip): ${GREEN}ONLINE${NC}"
    else
        echo -e "  ❌ $topic ($ip): OFFLINE"
    fi
done

# Test MQTT responses
echo ""
echo "📨 MQTT Status Test:"
for topic in "${!SENSOR_IPS[@]}"; do
    echo "  📤 Requesting status from $topic..."
    mosquitto_pub -h "$BROKER" -t "home/$topic/cmnd" -m "STATUS" -u "$USERNAME" -P "$PASSWORD" 2>/dev/null
done

echo ""
echo "📥 Listening for responses (10 seconds)..."
timeout 10 mosquitto_sub -h "$BROKER" -u "$USERNAME" -P "$PASSWORD" -t "home/motion_+/status" -v 2>/dev/null || true

echo ""
echo "🏁 Test completed!"
echo ""
echo "To monitor all sensors continuously:"
echo "mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t \"home/motion_+/+\" -v"
EOF

    chmod +x "$test_script"
    print_success "Testing script created: scripts/test-all-motion-sensors.sh"
}

# Main batch compilation function
main() {
    print_header "🏭 HomeGuard Motion Sensor Batch Compiler"
    print_header "=========================================="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Clean and create build directory
    print_info "Preparing build environment..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Compile all sensors
    local success_count=0
    local total_count=${#SENSORS[@]}
    
    print_info "Compiling $total_count motion sensors..."
    echo ""
    
    for sensor_key in $(echo "${!SENSORS[@]}" | tr ' ' '\n' | sort); do
        if compile_sensor "$sensor_key"; then
            ((success_count++))
        fi
    done
    
    # Summary
    echo ""
    print_header "📊 Compilation Summary"
    print_header "====================="
    print_success "$success_count/$total_count sensors compiled successfully"
    
    if [ $success_count -eq $total_count ]; then
        print_success "🎉 All sensors compiled successfully!"
        
        # Create additional resources
        create_upload_instructions
        create_testing_script
        
        echo ""
        print_info "📁 Firmware files location: firmware/"
        print_info "📖 Upload guide: UPLOAD_INSTRUCTIONS.md"
        print_info "🧪 Test script: scripts/test-all-motion-sensors.sh"
        echo ""
        print_info "To upload a specific sensor interactively:"
        print_info "  ./scripts/compile-motion-sensors.sh"
        echo ""
        print_info "To test all sensors after upload:"
        print_info "  ./scripts/test-all-motion-sensors.sh"
        
    else
        print_error "Some compilations failed. Check the output above."
        exit 1
    fi
}

# Run main function
main "$@"
