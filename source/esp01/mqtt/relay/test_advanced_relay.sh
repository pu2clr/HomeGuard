#!/bin/bash

# HomeGuard Advanced Relay Test Script
# Test script for the advanced_relay.ino with JSON messaging

# MQTT Configuration
BROKER="192.168.18.198"
USERNAME="homeguard"
PASSWORD="pu2clr123456"
TOPIC_BASE="home/relay1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== HomeGuard Advanced Relay Test Script ===${NC}"
echo "Testing advanced relay controller with JSON messaging"
echo "Broker: $BROKER"
echo "Topic Base: $TOPIC_BASE"
echo ""

# Function to publish command and wait
send_command() {
    local command=$1
    local description=$2
    echo -e "${YELLOW}➤ $description${NC}"
    echo "Command: $command"
    mosquitto_pub -h $BROKER -t $TOPIC_BASE/cmnd -m "$command" -u $USERNAME -P $PASSWORD
    echo "Waiting 2 seconds..."
    sleep 2
    echo ""
}

# Function to monitor topic for specified time
monitor_topic() {
    local topic=$1
    local duration=$2
    local description=$3
    echo -e "${BLUE}📡 $description${NC}"
    echo "Monitoring: $topic for ${duration}s"
    timeout ${duration}s mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t "$topic" -v
    echo ""
}

echo -e "${GREEN}=== Starting Advanced Relay Tests ===${NC}"
echo ""

# Test 1: Monitor all topics to see initial state
echo -e "${BLUE}🔍 Test 1: Monitor initial state${NC}"
monitor_topic "$TOPIC_BASE/#" 5 "Checking initial device state"

# Test 2: Get device status
send_command "STATUS" "Test 2: Request device status (JSON format)"

# Test 3: Basic relay control
send_command "ON" "Test 3: Turn relay ON"
send_command "OFF" "Test 4: Turn relay OFF"
send_command "TOGGLE" "Test 5: Toggle relay state"

# Test 6: Configuration tests
send_command "LOCATION_TestKitchen" "Test 6: Set device location"
send_command "HEARTBEAT_OFF" "Test 7: Disable heartbeat"
send_command "HEARTBEAT_ON" "Test 8: Enable heartbeat"
send_command "HEARTBEAT_30" "Test 9: Set heartbeat to 30 seconds"

# Test 10: LED control
send_command "LED_OFF" "Test 10: Disable status LED"
send_command "LED_ON" "Test 11: Enable status LED"

# Test 12: Get status after configuration changes
send_command "STATUS" "Test 12: Get status after configuration changes"

# Test 13: JSON command test (basic)
send_command '{"relay":"ON","reason":"test"}' "Test 13: JSON command format"

# Test 14: Monitor heartbeat
echo -e "${BLUE}💓 Test 14: Monitor heartbeat messages${NC}"
monitor_topic "$TOPIC_BASE/heartbeat" 35 "Waiting for heartbeat messages (should appear every 30s)"

# Test 15: Monitor relay events
echo -e "${BLUE}🔄 Test 15: Monitor relay events${NC}"
echo "Sending multiple relay commands to test event monitoring..."
(
    sleep 2; mosquitto_pub -h $BROKER -t $TOPIC_BASE/cmnd -m "ON" -u $USERNAME -P $PASSWORD
    sleep 3; mosquitto_pub -h $BROKER -t $TOPIC_BASE/cmnd -m "OFF" -u $USERNAME -P $PASSWORD
    sleep 3; mosquitto_pub -h $BROKER -t $TOPIC_BASE/cmnd -m "TOGGLE" -u $USERNAME -P $PASSWORD
) &
monitor_topic "$TOPIC_BASE/relay" 10 "Monitoring relay events during state changes"

# Test 16: Final status check
send_command "STATUS" "Test 16: Final device status"

echo -e "${GREEN}=== Test Summary ===${NC}"
echo "✅ Basic relay control (ON/OFF/TOGGLE)"
echo "✅ JSON status messages"
echo "✅ Device configuration (location, heartbeat, LED)"
echo "✅ Heartbeat monitoring"
echo "✅ Event monitoring"
echo "✅ JSON command format (basic)"
echo ""

echo -e "${YELLOW}📋 Manual verification checklist:${NC}"
echo "□ JSON messages are properly formatted"
echo "□ Device ID is unique and based on MAC"
echo "□ Location changes are reflected in messages"
echo "□ Heartbeat appears at configured interval"
echo "□ Relay events show proper timestamps and reasons"
echo "□ RSSI and IP information is included"
echo "□ LED status matches relay state (if connected)"
echo ""

echo -e "${BLUE}🔧 Useful monitoring commands:${NC}"
echo "Monitor all topics:"
echo "mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t \"$TOPIC_BASE/#\" -v"
echo ""
echo "Monitor only relay events:"
echo "mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t \"$TOPIC_BASE/relay\" -v"
echo ""
echo "Monitor heartbeat:"
echo "mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t \"$TOPIC_BASE/heartbeat\" -v"
echo ""

echo -e "${GREEN}Advanced Relay Test Complete!${NC}"
