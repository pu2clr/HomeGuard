#!/bin/zsh

# Test script to verify Arduino CLI compilation

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKETCH_TEMPLATE="$PROJECT_DIR/source/esp01/mqtt/motion_detector/motion_detector_template.ino"
BUILD_DIR="$PROJECT_DIR/build/test"
FQBN="esp8266:esp8266:generic"

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

echo "🧪 Testing Arduino CLI compilation..."
echo ""

# Check if template exists
if [ ! -f "$SKETCH_TEMPLATE" ]; then
    print_error "Template file not found: $SKETCH_TEMPLATE"
    exit 1
fi

print_success "Template file found: $SKETCH_TEMPLATE"

# Create test directory with correct name
SKETCH_NAME="test_motion_sensor"
SKETCH_DIR="$BUILD_DIR/$SKETCH_NAME"
mkdir -p "$SKETCH_DIR"
TEST_SKETCH="$SKETCH_DIR/$SKETCH_NAME.ino"

# Copy template
cp "$SKETCH_TEMPLATE" "$TEST_SKETCH"
print_success "Copied template to: $TEST_SKETCH"

# Test compilation
print_info "Testing compilation with arduino-cli..."

# Build flags for test
BUILD_FLAGS="--build-property"
CPP_FLAGS="compiler.cpp.extra_flags=-DDEVICE_LOCATION=Test -DDEVICE_IP_LAST_OCTET=199 -DMQTT_TOPIC_SUFFIX=motion_test"

echo "Command: arduino-cli compile --fqbn $FQBN --build-path $SKETCH_DIR/build $BUILD_FLAGS \"$CPP_FLAGS\" --quiet $SKETCH_DIR"
echo ""

if arduino-cli compile \
    --fqbn "$FQBN" \
    --build-path "$SKETCH_DIR/build" \
    $BUILD_FLAGS "$CPP_FLAGS" \
    --quiet \
    "$SKETCH_DIR"; then
    
    print_success "Compilation successful!"
    
    # Check if .bin file was created
    BIN_FILE="$SKETCH_DIR/build/$SKETCH_NAME.ino.bin"
    if [ -f "$BIN_FILE" ]; then
        print_success "Binary file created: $BIN_FILE"
        ls -la "$BIN_FILE"
    else
        print_error "Binary file not found at expected location"
    fi
else
    print_error "Compilation failed!"
    echo ""
    echo "Trying verbose compilation to see error details..."
    arduino-cli compile \
        --fqbn "$FQBN" \
        --build-path "$SKETCH_DIR/build" \
        $BUILD_FLAGS "$CPP_FLAGS" \
        --verbose \
        "$SKETCH_DIR"
fi

echo ""
print_info "Test completed."
