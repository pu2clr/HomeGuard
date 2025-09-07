#!/bin/bash
# MQTT Command Examples for HomeGuard Audio System

BROKER="192.168.1.102"
USERNAME="homeguard" 
PASSWORD="pu2clr123456"
TOPIC="home/audio/cmnd"

echo "🎛️ HomeGuard Audio - MQTT Command Examples"
echo "========================================="

echo "📊 1. Request Status:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'STATUS' -u $USERNAME -P $PASSWORD"

echo "🐕 2. Dog Barking:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'DOGS' -u $USERNAME -P $PASSWORD"

echo "👣 3. Footsteps:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'FOOTSTEPS' -u $USERNAME -P $PASSWORD"

echo "🚽 4. Toilet Flush:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'TOILET' -u $USERNAME -P $PASSWORD"

echo "📺 5. TV Background:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'TV' -u $USERNAME -P $PASSWORD"

echo "🚪 6. Door Sound:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'DOOR' -u $USERNAME -P $PASSWORD"

echo "🌅 7. Morning Routine:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'MORNING' -u $USERNAME -P $PASSWORD"

echo "🌆 8. Evening Routine:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'EVENING' -u $USERNAME -P $PASSWORD"

echo "🎲 9. Random Activity:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'RANDOM' -u $USERNAME -P $PASSWORD"

echo "🏠 10. Set Mode - Home:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'MODE_HOME' -u $USERNAME -P $PASSWORD"

echo "✈️ 11. Set Mode - Away:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'MODE_AWAY' -u $USERNAME -P $PASSWORD"

echo "⏹️ 12. Stop Audio:"
echo "mosquitto_pub -h $BROKER -t $TOPIC -m 'STOP' -u $USERNAME -P $PASSWORD"

echo ""
echo "📡 Monitor all audio events:"
echo "mosquitto_sub -h $BROKER -u $USERNAME -P $PASSWORD -t 'home/audio/#' -v"
