#!/bin/bash

# HomeGuard Motion Detector Test Script
# Baseado na configuração MQTT que está funcionando

BROKER_IP="192.168.1.102"
MQTT_USER="homeguard"
MQTT_PASS="pu2clr123456"

echo "=== HomeGuard Motion Detector Test ==="
echo "Broker: $BROKER_IP"
echo "User: $MQTT_USER"
echo ""

# Function to send MQTT command
send_command() {
    local command=$1
    echo "📤 Sending command: $command"
    mosquitto_pub -h $BROKER_IP -t home/motion1/cmnd -m "$command" -u $MQTT_USER -P $MQTT_PASS
    sleep 1
}

# Function to monitor topic
monitor_topic() {
    local topic=$1
    local duration=${2:-5}
    echo "👁️ Monitoring $topic for ${duration}s..."
    timeout ${duration}s mosquitto_sub -h $BROKER_IP -t "$topic" -v -u $MQTT_USER -P $MQTT_PASS
}

echo "🔧 Testing Motion Detector..."
echo ""

# Test 1: Check if device is online
echo "📡 Test 1: Check device status"
send_command "STATUS"
monitor_topic "home/motion1/status" 3
echo ""

# Test 2: Monitor motion events
echo "👁️ Test 2: Monitor motion events (10 seconds)"
echo "   Move in front of the sensor now..."
monitor_topic "home/motion1/motion" 10
echo ""

# Test 3: Configure sensitivity
echo "⚙️ Test 3: Configure high sensitivity"
send_command "SENSITIVITY_HIGH"
monitor_topic "home/motion1/config" 2
echo ""

# Test 4: Set location
echo "📍 Test 4: Set location to Test_Area"
send_command "LOCATION_Test_Area"
monitor_topic "home/motion1/config" 2
echo ""

# Test 5: Set motion timeout
echo "⏱️ Test 5: Set motion timeout to 15 seconds"
send_command "TIMEOUT_15"
monitor_topic "home/motion1/config" 2
echo ""

# Test 6: Monitor all activity
echo "📊 Test 6: Monitor all activity (15 seconds)"
echo "   This will show status, motion, and heartbeat..."
monitor_topic "home/motion1/#" 15
echo ""

# Test 7: Final status check
echo "✅ Test 7: Final status check"
send_command "STATUS"
monitor_topic "home/motion1/status" 3
echo ""

echo "🎯 Motion Detector Test Complete!"
echo ""
echo "📋 Additional commands you can try:"
echo "   mosquitto_pub -h $BROKER_IP -t home/motion1/cmnd -m 'SENSITIVITY_NORMAL' -u $MQTT_USER -P $MQTT_PASS"
echo "   mosquitto_pub -h $BROKER_IP -t home/motion1/cmnd -m 'TIMEOUT_30' -u $MQTT_USER -P $MQTT_PASS"
echo "   mosquitto_pub -h $BROKER_IP -t home/motion1/cmnd -m 'LOCATION_Living_Room' -u $MQTT_USER -P $MQTT_PASS"
echo ""
echo "🔄 Continuous monitoring:"
echo "   mosquitto_sub -h $BROKER_IP -t 'home/motion1/#' -v -u $MQTT_USER -P $MQTT_PASS"
