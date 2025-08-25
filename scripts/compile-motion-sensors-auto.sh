#!/bin/sh

# HomeGuard Motion Sensor Compiler - Shell Detection Wrapper
# Automatically detects the shell and runs the appropriate version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Function to print colored output
print_info() {
    printf "\033[0;34mℹ️  %s\033[0m\n" "$1"
}

print_success() {
    printf "\033[0;32m✅ %s\033[0m\n" "$1"
}

print_error() {
    printf "\033[0;31m❌ %s\033[0m\n" "$1"
}

# Check if Bash is available and supports associative arrays (Bash 4+)
if command -v bash >/dev/null 2>&1; then
    bash_version=$(bash -c 'echo ${BASH_VERSION%%.*}' 2>/dev/null)
    if [ "$bash_version" -ge 4 ] 2>/dev/null; then
        print_info "Running with Bash (version $bash_version)"
        exec bash "$SCRIPT_DIR/compile-motion-sensors.sh" "$@"
    else
        print_info "Bash version $bash_version found, but requires 4+. Using ZSH version..."
    fi
fi

# Check if ZSH is available
if command -v zsh >/dev/null 2>&1; then
    print_info "Running with ZSH"
    exec zsh "$SCRIPT_DIR/compile-motion-sensors-zsh.sh" "$@"
fi

# Fallback error message
print_error "Neither Bash 4+ nor ZSH found!"
echo ""
echo "Please install one of the following:"
echo "  - Bash 4.0 or later"
echo "  - ZSH"
echo ""
echo "On macOS:"
echo "  brew install bash    # For Bash 5+"
echo "  brew install zsh     # For ZSH (usually pre-installed)"
echo ""
echo "Or run directly:"
echo "  bash scripts/compile-motion-sensors.sh      # If you have Bash 4+"
echo "  zsh scripts/compile-motion-sensors-zsh.sh   # If you have ZSH"
exit 1
