#!/bin/bash
# Update HomeGuard devices to use new MQTT broker IP
# Changes from 192.168.18.6 to 192.168.18.236

OLD_IP="192.168.18.6"
NEW_IP="192.168.18.236"
PROJECT_ROOT="/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard"

echo "🔄 Updating HomeGuard devices to use new MQTT broker"
echo "=================================================="
echo "Old IP: $OLD_IP"
echo "New IP: $NEW_IP"
echo ""

# Function to update file
update_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        if grep -q "$OLD_IP" "$file"; then
            sed -i.bak "s/$OLD_IP/$NEW_IP/g" "$file"
            echo "✅ Updated $description: $(basename "$file")"
        else
            echo "ℹ️  No changes needed in $(basename "$file")"
        fi
    else
        echo "⚠️  File not found: $file"
    fi
}

# Update Arduino sketches
echo "📟 Updating Arduino sketches..."
update_file "$PROJECT_ROOT/source/esp01/mqtt/relay/relay.ino" "Relay sketch"
update_file "$PROJECT_ROOT/source/esp01/mqtt/motion_detector/motion_detector.ino" "Motion detector sketch"

# Update Python scripts
echo "🐍 Updating Python scripts..."
update_file "$PROJECT_ROOT/source/esp01/mqtt/motion_detector/motion_monitor.py" "Motion monitor"
update_file "$PROJECT_ROOT/source/esp01/mqtt/motion_detector/motion_monitor_simple.py" "Simple motion monitor"
update_file "$PROJECT_ROOT/source/esp01/mqtt/motion_detector/motion_light_controller.py" "Motion light controller"

# Update shell scripts
echo "📝 Updating shell scripts..."
update_file "$PROJECT_ROOT/source/esp01/mqtt/motion_detector/motion_test.sh" "Motion test script"
update_file "$PROJECT_ROOT/source/esp01/mqtt/motion_detector/test_motion_light.sh" "Motion light test script"

# Update documentation
echo "📚 Updating documentation..."
update_file "$PROJECT_ROOT/source/esp01/mqtt/README.md" "MQTT modules README"
update_file "$PROJECT_ROOT/source/esp01/mqtt/relay/README.md" "Relay README"
update_file "$PROJECT_ROOT/source/esp01/mqtt/motion_detector/README.md" "Motion detector README"
update_file "$PROJECT_ROOT/source/esp01/mqtt/motion_detector/MOTION_LIGHT_README.md" "Motion light README"

echo ""
echo "🧪 Testing new configuration..."

# Test if new broker is reachable
if ping -c 1 "$NEW_IP" >/dev/null 2>&1; then
    echo "✅ New broker IP ($NEW_IP) is reachable"
else
    echo "⚠️  New broker IP ($NEW_IP) is not reachable"
    echo "   Make sure the Raspberry Pi is running and connected"
fi

# Test MQTT connection (if mosquitto-clients is installed)
if command -v mosquitto_pub >/dev/null 2>&1; then
    echo "🔌 Testing MQTT connection..."
    if mosquitto_pub -h "$NEW_IP" -t "test/update" -m "Configuration updated" -u homeguard -P pu2clr123456 >/dev/null 2>&1; then
        echo "✅ MQTT connection test successful"
    else
        echo "⚠️  MQTT connection test failed"
        echo "   Broker might not be configured yet"
    fi
else
    echo "ℹ️  mosquitto-clients not installed, skipping connection test"
fi

echo ""
echo "📋 Summary of changes:"
echo "====================="
echo "Files updated to use broker IP: $NEW_IP"
echo ""
echo "🔧 Next steps:"
echo "1. Copy updated .ino files to Arduino IDE"
echo "2. Upload updated sketches to ESP-01S devices"
echo "3. Restart Python scripts to use new IP"
echo "4. Test device connectivity"
echo ""
echo "💡 Quick test commands:"
echo "mosquitto_sub -h $NEW_IP -u homeguard -P pu2clr123456 -t '#' -v"
echo "mosquitto_pub -h $NEW_IP -t test/hello -m 'Hello from new broker' -u homeguard -P pu2clr123456"
echo ""

# Show backup files created
echo "💾 Backup files created (.bak extension):"
find "$PROJECT_ROOT" -name "*.bak" -type f 2>/dev/null | while read -r backup; do
    echo "   $(basename "$backup")"
done

echo ""
echo "✅ Update process completed!"
