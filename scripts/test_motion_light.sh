#!/bin/bash
"""
Test script for Motion-Activated Light Controller
Tests the integration between motion detector and relay control
"""

BROKER="192.168.1.102"
USERNAME="homeguard"
PASSWORD="pu2clr123456"

echo "🧪 Testing Motion-Activated Light Controller"
echo "============================================"

echo "📋 Available test commands:"
echo ""

echo "1. Monitor all activity:"
echo "   mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t '#' -v"
echo ""

echo "2. Check motion sensor status:"
echo "   mosquitto_pub -h $BROKER -t home/motion1/cmnd -m 'STATUS' -u $USERNAME -P $PASSWORD"
echo ""

echo "3. Simulate motion detection (if you want to test manually):"
echo "   mosquitto_pub -h $BROKER -t home/motion1/motion -m '{\"device_id\":\"test\",\"location\":\"Test Area\",\"event\":\"MOTION_DETECTED\",\"timestamp\":\"$(date +%s)\"}' -u $USERNAME -P $PASSWORD"
echo ""

echo "4. Simulate motion cleared:"
echo "   mosquitto_pub -h $BROKER -t home/motion1/motion -m '{\"device_id\":\"test\",\"location\":\"Test Area\",\"event\":\"MOTION_CLEARED\",\"timestamp\":\"$(date +%s)\",\"duration\":\"30s\"}' -u $USERNAME -P $PASSWORD"
echo ""

echo "5. Manual light control:"
echo "   mosquitto_pub -h $BROKER -t home/relay1/cmnd -m 'ON' -u $USERNAME -P $PASSWORD"
echo "   mosquitto_pub -h $BROKER -t home/relay1/cmnd -m 'OFF' -u $USERNAME -P $PASSWORD"
echo ""

echo "6. Check relay status:"
echo "   mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t 'home/relay1/stat' -v"
echo ""

echo "🚀 To start the motion light controller:"
echo "   python motion_light_controller.py"
echo ""
echo "🚀 To start with custom light delay (10 seconds):"
echo "   python motion_light_controller.py --light-delay 10"
echo ""

echo "💡 Expected behavior:"
echo "   - Motion detected → Light turns ON immediately"
echo "   - Motion cleared → Light stays ON for delay period, then turns OFF"
echo "   - New motion during delay → Cancels OFF timer, keeps light ON"
echo ""

echo "🔧 Troubleshooting:"
echo "   - Ensure both ESP-01S devices are powered and connected"
echo "   - Motion detector should be at IP 192.168.18.193"
echo "   - Relay controller should be at IP 192.168.18.192"
echo "   - MQTT broker should be running at 192.168.1.102"
echo ""

echo "📊 Monitor in real-time:"
echo "   In one terminal: python motion_light_controller.py"
echo "   In another terminal: mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t '#' -v"
