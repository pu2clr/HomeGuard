#!/bin/zsh

# HomeGuard Motion Sensor Compiler and Uploader
# Automated compilation and upload for ESP-01S devices using arduino-cli
# Supports 5 different motion sensor locations with unique IPs and MQTT topics
# ZSH-compatible version

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKETCH_TEMPLATE="$PROJECT_DIR/source/esp01/mqtt/motion_detector/motion_detector_template.ino"
BUILD_DIR="$PROJECT_DIR/build"
FQBN="esp8266:esp8266:generic"

# Sensor configurations (ZSH compatible)
SENSOR_1="Garagem,201,motion_garagem"
SENSOR_2="Area_Servico,202,motion_area_servico"
SENSOR_3="Varanda,203,motion_varanda"
SENSOR_4="Mezanino,204,motion_mezanino"
SENSOR_5="Ad_Hoc,205,motion_adhoc"

# Function to get sensor configuration
get_sensor_config() {
    local choice="$1"
    case "$choice" in
        1) echo "$SENSOR_1" ;;
        2) echo "$SENSOR_2" ;;
        3) echo "$SENSOR_3" ;;
        4) echo "$SENSOR_4" ;;
        5) echo "$SENSOR_5" ;;
        *) echo "" ;;
    esac
}

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

# Function to check if arduino-cli is installed
check_arduino_cli() {
    if ! command -v arduino-cli &> /dev/null; then
        print_error "arduino-cli is not installed or not in PATH"
        echo ""
        echo "To install arduino-cli:"
        echo "  macOS: brew install arduino-cli"
        echo "  Linux: curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh"
        echo "  Manual: https://arduino.github.io/arduino-cli/latest/installation/"
        echo ""
        echo "Or run the setup script: ./scripts/setup-dev-environment.sh"
        exit 1
    fi
    print_success "arduino-cli found: $(arduino-cli version | head -n1)"
}

# Function to check and install ESP8266 core
check_esp8266_core() {
    print_info "Checking ESP8266 core installation..."
    
    if ! arduino-cli core list | grep -q "esp8266:esp8266"; then
        print_warning "ESP8266 core not found. Installing..."
        
        # Add ESP8266 board manager URL if not already added
        arduino-cli config add board_manager.additional_urls https://arduino.esp8266.com/stable/package_esp8266com_index.json
        
        # Update index and install ESP8266 core
        arduino-cli core update-index
        arduino-cli core install esp8266:esp8266
        
        print_success "ESP8266 core installed"
    else
        print_success "ESP8266 core already installed"
    fi
}

# Function to check and install required libraries
check_libraries() {
    print_info "Checking required libraries..."
    
    local required_libs=("PubSubClient")
    
    for lib in $required_libs; do
        if arduino-cli lib list | grep -q "$lib"; then
            print_success "Library $lib is installed"
        else
            print_warning "Installing library: $lib"
            arduino-cli lib install "$lib"
        fi
    done
}

# Function to list available USB ports
list_usb_ports() {
    print_info "Available USB ports:"
    
    local ports=($(ls /dev/tty.* 2>/dev/null | grep -E "(USB|usbserial|wchusbserial)" | head -10))
    
    if [ ${#ports[@]} -eq 0 ]; then
        ports=($(ls /dev/tty.* 2>/dev/null | grep -v -E "(Bluetooth|console)" | head -10))
    fi
    
    if [ ${#ports[@]} -eq 0 ]; then
        print_warning "No USB ports detected. Common ports to try:"
        echo "  - /dev/tty.usbserial-*"
        echo "  - /dev/tty.SLAB_USBtoUART"
        echo "  - /dev/tty.wchusbserial*"
        echo "  - /dev/ttyUSB0 (Linux)"
        return
    fi
    
    for i in {1..${#ports[@]}}; do
        echo "  $i. ${ports[$i]}"
    done
}

# Function to select USB port
select_usb_port() {
    echo ""
    list_usb_ports
    echo ""
    
    while true; do
        read "usb_port?Enter the USB port (full path, e.g., /dev/tty.usbserial-XXX): "
        
        if [ -z "$usb_port" ]; then
            print_warning "USB port cannot be empty"
            continue
        fi
        
        if [ ! -e "$usb_port" ]; then
            print_warning "Port $usb_port does not exist"
            read "continue_anyway?Do you want to continue anyway? (y/N): "
            if [[ $continue_anyway =~ ^[Yy]$ ]]; then
                break
            fi
            continue
        fi
        
        print_success "Selected USB port: $usb_port"
        break
    done
}

# Function to display sensor menu
show_sensor_menu() {
    print_header "🏠 HomeGuard Motion Sensor Configuration"
    echo ""
    echo "Available sensors:"
    echo ""
    
    local sensors=(
        "1:Garagem:201:motion_garagem"
        "2:Area_Servico:202:motion_area_servico"
        "3:Varanda:203:motion_varanda"
        "4:Mezanino:204:motion_mezanino"
        "5:Ad_Hoc:205:motion_adhoc"
    )
    
    for sensor in $sensors; do
        local key=$(echo $sensor | cut -d: -f1)
        local location=$(echo $sensor | cut -d: -f2)
        local ip=$(echo $sensor | cut -d: -f3)
        local topic=$(echo $sensor | cut -d: -f4)
        printf "  %s. %-15s (IP: 192.168.18.%-3s, Topic: %s)\n" "$key" "$location" "$ip" "$topic"
    done
    
    echo ""
    echo "  6. Custom configuration"
    echo "  q. Quit"
    echo ""
}

# Function to select sensor
select_sensor() {
    while true; do
        show_sensor_menu
        read "choice?Select sensor to compile and upload (1-6, q): "
        
        case $choice in
            [1-5])
                local config=$(get_sensor_config $choice)
                if [[ -n "$config" ]]; then
                    selected_location=$(echo $config | cut -d, -f1)
                    selected_ip=$(echo $config | cut -d, -f2)
                    selected_topic=$(echo $config | cut -d, -f3)
                    print_success "Selected: $selected_location (192.168.18.$selected_ip)"
                    return 0
                fi
                ;;
            6)
                echo ""
                read "selected_location?Enter location name (no spaces, use underscore): "
                read "selected_ip?Enter IP last octet (201-255): "
                read "selected_topic?Enter MQTT topic suffix (e.g., motion_custom): "
                
                if [[ -n "$selected_location" && -n "$selected_ip" && -n "$selected_topic" ]]; then
                    if [[ "$selected_ip" =~ ^[0-9]+$ && "$selected_ip" -ge 201 && "$selected_ip" -le 255 ]]; then
                        print_success "Custom configuration: $selected_location (192.168.18.$selected_ip)"
                        return 0
                    else
                        print_error "Invalid IP octet. Must be between 201-255."
                    fi
                else
                    print_error "All fields are required for custom configuration."
                fi
                ;;
            q|Q)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please select 1-6 or q."
                ;;
        esac
    done
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
    echo "$sensor_dir"  # Return directory path for arduino-cli (only this goes to stdout)
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
        --verbose \
        "$sketch_dir"; then
        
        print_success "Compilation successful!"
        return 0
    else
        print_error "Compilation failed!"
        return 1
    fi
}

# Function to upload sketch
upload_sketch() {
    local sketch_dir="$1"
    local upload_port="$2"
    
    print_info "Uploading sketch to $selected_location via $upload_port..."
    
    # Upload the sketch
    if arduino-cli upload \
        --fqbn "$FQBN" \
        --port "$upload_port" \
        --input-dir "$sketch_dir/build" \
        --verbose \
        "$sketch_dir"; then
        
        print_success "Upload successful!"
        return 0
    else
        print_error "Upload failed!"
        print_warning "Common upload issues:"
        echo "  - ESP-01S not in programming mode (GPIO0 to GND)"
        echo "  - Wrong USB port selected"
        echo "  - USB-to-serial adapter not working"
        echo "  - Power supply issues"
        return 1
    fi
}

# Function to show post-upload instructions
show_post_upload_instructions() {
    print_success "🎉 Device successfully programmed!"
    echo ""
    print_header "📋 Post-Upload Instructions:"
    echo ""
    echo "1. 🔌 Hardware setup:"
    echo "   - Remove GPIO0 connection from GND (exit programming mode)"
    echo "   - Connect PIR sensor:"
    echo "     • VCC → 3.3V"
    echo "     • GND → GND"
    echo "     • OUT → GPIO2"
    echo "   - Power cycle the ESP-01S"
    echo ""
    echo "2. 📡 MQTT Testing:"
    echo "   Monitor all messages:"
    echo "   mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t \"home/$selected_topic/#\" -v"
    echo ""
    echo "   Check device status:"
    echo "   mosquitto_pub -h 192.168.18.236 -t \"home/$selected_topic/cmnd\" -m \"STATUS\" -u homeguard -P pu2clr123456"
    echo ""
    echo "3. 🌐 Network verification:"
    echo "   ping 192.168.18.$selected_ip"
    echo ""
    echo "4. 🏠 Integration with automation:"
    echo "   The device will publish to:"
    echo "   - home/$selected_topic/motion (motion events)"
    echo "   - home/$selected_topic/status (device status)"
    echo "   - home/$selected_topic/heartbeat (keep-alive)"
    echo ""
    print_info "Device: $selected_location"
    print_info "IP: 192.168.18.$selected_ip"
    print_info "MQTT Topic Base: home/$selected_topic"
}

# Function to open serial monitor
open_serial_monitor() {
    local port="$1"
    
    read "open_monitor?Do you want to open serial monitor? (y/N): "
    if [[ $open_monitor =~ ^[Yy]$ ]]; then
        print_info "Opening serial monitor on $port (115200 baud)..."
        print_info "Press Ctrl+C to exit monitor"
        sleep 2
        
        # Try different serial monitor tools
        if command -v screen &> /dev/null; then
            screen "$port" 115200
        elif command -v arduino-cli &> /dev/null; then
            arduino-cli monitor -p "$port" -c baudrate=115200
        else
            print_warning "No serial monitor available. Install 'screen' or use Arduino IDE"
        fi
    fi
}

# Main execution function
main() {
    print_header "🚀 HomeGuard Motion Sensor Builder"
    print_header "===================================="
    echo ""
    
    # Check prerequisites
    check_arduino_cli
    check_esp8266_core
    check_libraries
    
    # Verify template file exists
    if [ ! -f "$SKETCH_TEMPLATE" ]; then
        print_error "Template file not found: $SKETCH_TEMPLATE"
        exit 1
    fi
    
    # Select sensor configuration
    select_sensor
    
    # Prepare sketch first
    sketch_dir=$(prepare_sketch)
    
    # Select USB port
    select_usb_port
    
    # Compile sketch
    if compile_sketch "$sketch_dir"; then
        echo ""
        print_info "Compilation successful! Ready to upload."
        echo ""
        print_warning "⚠️  IMPORTANT: Make sure ESP-01S is in programming mode:"
        print_warning "   - Connect GPIO0 to GND"
        print_warning "   - Power cycle the device"
        print_warning "   - ESP-01S should be connected to USB-to-serial adapter"
        echo ""
        
        read "ready_upload?Is the ESP-01S ready for upload? (y/N): "
        if [[ $ready_upload =~ ^[Yy]$ ]]; then
            if upload_sketch "$sketch_dir" "$usb_port"; then
                show_post_upload_instructions
                open_serial_monitor "$usb_port"
            fi
        else
            print_info "Upload cancelled. You can upload later with:"
            print_info "arduino-cli upload --fqbn $FQBN --port $usb_port --input-dir $sketch_dir/build $sketch_dir"
        fi
    fi
}

# Run main function
main "$@"
