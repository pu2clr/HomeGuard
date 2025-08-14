#!/bin/zsh

# Quick test script for compilation only

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKETCH_TEMPLATE="$PROJECT_DIR/source/esp01/mqtt/motion_detector/motion_detector_template.ino"
BUILD_DIR="$PROJECT_DIR/build"
FQBN="esp8266:esp8266:generic"

# Test configuration
selected_location="Garagem"
selected_ip="201"
selected_topic="motion_garagem"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to create build directory and sketch file
prepare_sketch() {
    print_info "Preparing sketch for $selected_location..." >&2
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    
    # Create sensor-specific directory with proper Arduino structure
    local sketch_name="${selected_location}_motion_sensor"
    local sensor_dir="$BUILD_DIR/$sketch_name"
    mkdir -p "$sensor_dir"
    
    # Copy template and rename - Arduino requires .ino file to match directory name
    local sketch_file="$sensor_dir/$sketch_name.ino"
    cp "$SKETCH_TEMPLATE" "$sketch_file"
    
    print_success "Sketch prepared: $sketch_file" >&2
    echo "$sensor_dir"  # Return directory path for arduino-cli
}

# Function to compile sketch
compile_sketch() {
    local sketch_dir="$1"
    
    print_info "Compiling sketch for $selected_location..."
    print_info "Location: $selected_location"
    print_info "IP: 192.168.18.$selected_ip"
    print_info "MQTT Topic: $selected_topic"
    
    # Build flags for ESP8266
    local build_flags="--build-property"
    local cpp_flags="compiler.cpp.extra_flags=-DDEVICE_LOCATION=$selected_location -DDEVICE_IP_LAST_OCTET=$selected_ip -DMQTT_TOPIC_SUFFIX=$selected_topic"
    
    print_info "Build flags: $cpp_flags"
    
    # Compile the sketch (pass directory to arduino-cli)
    if arduino-cli compile \
        --fqbn "$FQBN" \
        --build-path "$sketch_dir/build" \
        $build_flags "$cpp_flags" \
        --quiet \
        "$sketch_dir"; then
        
        print_success "Compilation successful!"
        
        # Check if binary was created
        local bin_file="$sketch_dir/build/${selected_location}_motion_sensor.ino.bin"
        if [ -f "$bin_file" ]; then
            print_success "Binary created: $bin_file"
            ls -la "$bin_file"
        fi
        
        return 0
    else
        print_error "Compilation failed!"
        return 1
    fi
}

echo "🧪 Testing Garagem sensor compilation..."

# Test the full flow
sketch_dir=$(prepare_sketch)
echo ""
print_info "Sketch directory: $sketch_dir"
echo ""

if compile_sketch "$sketch_dir"; then
    print_success "🎉 Test passed! Compilation system works correctly."
else
    print_error "❌ Test failed!"
fi
