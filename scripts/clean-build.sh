#!/bin/bash

# HomeGuard Build Cleanup Script
# Removes all temporary build files and compiled binaries

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧹 HomeGuard Build Cleanup"
echo "=========================="
echo ""

print_info "Project directory: $PROJECT_DIR"
echo ""

# List of directories and files to clean
CLEANUP_TARGETS=(
    "build/"
    "firmware/*.bin"
    "firmware/*.hex" 
    "firmware/*.elf"
    "temp/"
    "tmp/"
    ".build/"
    "UPLOAD_INSTRUCTIONS.md"
)

cleaned_count=0
total_size=0

for target in "${CLEANUP_TARGETS[@]}"; do
    full_path="$PROJECT_DIR/$target"
    
    if [[ "$target" == *"*"* ]]; then
        # Handle wildcards
        found_files=$(find "$(dirname "$full_path")" -name "$(basename "$target")" 2>/dev/null)
        if [ -n "$found_files" ]; then
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    size=$(stat -f%z "$file" 2>/dev/null || echo 0)
                    total_size=$((total_size + size))
                    print_info "Removing file: $file"
                    rm -f "$file"
                    ((cleaned_count++))
                fi
            done <<< "$found_files"
        fi
    else
        # Handle directories and regular files
        if [ -d "$full_path" ]; then
            size=$(du -sb "$full_path" 2>/dev/null | cut -f1 || echo 0)
            total_size=$((total_size + size))
            print_info "Removing directory: $full_path"
            rm -rf "$full_path"
            ((cleaned_count++))
        elif [ -f "$full_path" ]; then
            size=$(stat -f%z "$full_path" 2>/dev/null || echo 0)
            total_size=$((total_size + size))
            print_info "Removing file: $full_path"
            rm -f "$full_path"
            ((cleaned_count++))
        fi
    fi
done

# Clean Python cache files
if [ -d "$PROJECT_DIR" ]; then
    python_cache=$(find "$PROJECT_DIR" -name "__pycache__" -type d 2>/dev/null)
    if [ -n "$python_cache" ]; then
        while IFS= read -r cache_dir; do
            print_info "Removing Python cache: $cache_dir"
            rm -rf "$cache_dir"
            ((cleaned_count++))
        done <<< "$python_cache"
    fi
fi

# Convert bytes to human readable
if [ $total_size -gt 1048576 ]; then
    size_str="$(echo "scale=1; $total_size / 1048576" | bc)MB"
elif [ $total_size -gt 1024 ]; then
    size_str="$(echo "scale=1; $total_size / 1024" | bc)KB"  
else
    size_str="${total_size}B"
fi

echo ""
if [ $cleaned_count -gt 0 ]; then
    print_success "Cleanup completed!"
    print_success "Removed $cleaned_count items (${size_str})"
else
    print_info "No build files found to clean"
fi

echo ""
print_info "Build artifacts that are ignored by Git:"
echo "  ✅ build/ - Compilation temporary files"
echo "  ✅ *.bin, *.hex, *.elf - Compiled firmware"
echo "  ✅ __pycache__/ - Python cache files"
echo "  ✅ temp/, tmp/ - Temporary directories"
echo "  ✅ firmware/*.bin - Generated firmware files"
echo ""
print_info "To rebuild firmware:"
echo "  ./scripts/compile-motion-sensors-auto.sh"
echo "  ./scripts/batch-compile-sensors.sh"
