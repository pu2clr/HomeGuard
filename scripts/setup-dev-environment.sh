#!/bin/bash

# HomeGuard Development Environment Setup
# Installs and configures arduino-cli for ESP8266 development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Function to install arduino-cli
install_arduino_cli() {
    local os=$(detect_os)
    
    if command -v arduino-cli &> /dev/null; then
        print_success "arduino-cli is already installed: $(arduino-cli version | head -n1)"
        return 0
    fi
    
    print_info "Installing arduino-cli..."
    
    case $os in
        "macos")
            if command -v brew &> /dev/null; then
                print_info "Using Homebrew to install arduino-cli..."
                brew install arduino-cli
            else
                print_warning "Homebrew not found. Installing via curl..."
                install_arduino_cli_curl
            fi
            ;;
        "linux")
            install_arduino_cli_curl
            ;;
        *)
            print_error "Unsupported OS. Please install arduino-cli manually."
            print_info "Visit: https://arduino.github.io/arduino-cli/latest/installation/"
            exit 1
            ;;
    esac
    
    if command -v arduino-cli &> /dev/null; then
        print_success "arduino-cli installed successfully"
    else
        print_error "arduino-cli installation failed"
        exit 1
    fi
}

# Function to install arduino-cli via curl
install_arduino_cli_curl() {
    print_info "Installing arduino-cli via official installer..."
    
    local install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"
    
    # Download and run installer
    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR="$install_dir" sh
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$install_dir"; then
        print_info "Adding $install_dir to PATH..."
        
        # Determine shell config file
        if [[ "$SHELL" == *"zsh"* ]]; then
            shell_config="$HOME/.zshrc"
        elif [[ "$SHELL" == *"bash"* ]]; then
            shell_config="$HOME/.bashrc"
        else
            shell_config="$HOME/.profile"
        fi
        
        echo "" >> "$shell_config"
        echo "# Arduino CLI" >> "$shell_config"
        echo "export PATH=\"\$PATH:$install_dir\"" >> "$shell_config"
        
        print_warning "Added $install_dir to PATH in $shell_config"
        print_warning "Please run: source $shell_config or restart your terminal"
        
        # Set PATH for current session
        export PATH="$PATH:$install_dir"
    fi
}

# Function to configure arduino-cli
configure_arduino_cli() {
    print_info "Configuring arduino-cli..."
    
    # Create config if it doesn't exist
    if [ ! -f "$HOME/.arduino15/arduino-cli.yaml" ]; then
        arduino-cli config init
        print_success "arduino-cli config initialized"
    fi
    
    # Add ESP8266 board manager URL
    print_info "Adding ESP8266 board manager URL..."
    arduino-cli config add board_manager.additional_urls https://arduino.esp8266.com/stable/package_esp8266com_index.json
    
    # Update board manager index
    print_info "Updating board manager index..."
    arduino-cli core update-index
    
    # Install ESP8266 core
    print_info "Installing ESP8266 core..."
    if arduino-cli core list | grep -q "esp8266:esp8266"; then
        print_success "ESP8266 core already installed"
    else
        arduino-cli core install esp8266:esp8266
        print_success "ESP8266 core installed"
    fi
    
    # Install required libraries
    print_info "Installing required libraries..."
    
    local libraries=("PubSubClient")
    
    for lib in "${libraries[@]}"; do
        if arduino-cli lib list | grep -q "$lib"; then
            print_success "Library $lib already installed"
        else
            print_info "Installing library: $lib"
            arduino-cli lib install "$lib"
        fi
    done
}

# Function to verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    # Check arduino-cli
    if ! command -v arduino-cli &> /dev/null; then
        print_error "arduino-cli not found in PATH"
        return 1
    fi
    
    # Check ESP8266 core
    if ! arduino-cli core list | grep -q "esp8266:esp8266"; then
        print_error "ESP8266 core not installed"
        return 1
    fi
    
    # Check PubSubClient library
    if ! arduino-cli lib list | grep -q "PubSubClient"; then
        print_error "PubSubClient library not installed"
        return 1
    fi
    
    print_success "All components verified successfully!"
    
    # Show version info
    echo ""
    print_header "📋 Installation Summary"
    print_header "======================"
    arduino-cli version
    echo ""
    arduino-cli core list | grep esp8266 || true
    arduino-cli lib list | grep PubSubClient || true
    
    return 0
}

# Function to show usage instructions
show_usage_instructions() {
    print_header "🚀 HomeGuard Motion Sensor Development Setup Complete!"
    print_header "====================================================="
    echo ""
    print_success "✅ arduino-cli installed and configured"
    print_success "✅ ESP8266 core installed"
    print_success "✅ Required libraries installed"
    echo ""
    print_info "Available scripts:"
    echo ""
    echo "  📝 Interactive sensor compiler and uploader:"
    echo "     ./scripts/compile-motion-sensors.sh"
    echo ""
    echo "  🏭 Batch compile all sensors:"
    echo "     ./scripts/batch-compile-sensors.sh"
    echo ""
    echo "  🧪 Test all deployed sensors:"
    echo "     ./scripts/test-all-motion-sensors.sh"
    echo ""
    print_info "Motion sensor locations:"
    echo "  1. Garagem        (IP: 192.168.18.201)"
    echo "  2. Área Serviço   (IP: 192.168.18.202)"
    echo "  3. Varanda        (IP: 192.168.18.203)"
    echo "  4. Mezanino       (IP: 192.168.18.204)"
    echo "  5. Ad-Hoc         (IP: 192.168.18.205)"
    echo ""
    print_info "Quick start:"
    echo "  1. Connect ESP-01S to USB-to-serial adapter"
    echo "  2. Put ESP-01S in programming mode (GPIO0 to GND)"
    echo "  3. Run: ./scripts/compile-motion-sensors.sh"
    echo "  4. Select sensor and USB port"
    echo "  5. Upload and test!"
}

# Main setup function
main() {
    print_header "🔧 HomeGuard Development Environment Setup"
    print_header "==========================================="
    echo ""
    
    print_info "Setting up development environment for HomeGuard motion sensors..."
    print_info "This will install and configure arduino-cli for ESP8266 development."
    echo ""
    
    # Install arduino-cli
    install_arduino_cli
    
    # Configure arduino-cli
    configure_arduino_cli
    
    # Verify installation
    if verify_installation; then
        show_usage_instructions
    else
        print_error "Setup verification failed"
        exit 1
    fi
}

# Check if this script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
