# Motion-Activated Light Controller

## Overview
This Python script integrates the HomeGuard motion detector with the relay control module to create an automatic lighting system. When motion is detected, the light turns ON automatically. When motion clears, the light stays ON for a configurable delay period before turning OFF.

## Features
- **Automatic Light Control**: Lights turn ON when motion is detected
- **Configurable Delay**: Keep lights ON for specified time after motion clears
- **Smart Timer Management**: New motion cancels OFF timer and keeps lights ON
- **Real-time Monitoring**: Shows motion events and light status
- **Statistics Tracking**: Counts motion events and light activations
- **Automatic Reconnection**: Handles MQTT connection issues
- **Manual Override**: Supports manual light control via MQTT

## Hardware Requirements
- ESP-01S with motion detector (IP: 192.168.18.193)
- ESP-01S with relay module (IP: 192.168.18.192)
- MQTT broker running at 192.168.18.236
- Both devices connected to YOUR_SSID WiFi network

## Installation
```bash
# Navigate to the motion detector directory
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/source/esp01/mqtt/motion_detector

# Activate virtual environment
source /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/homeguard-env/bin/activate

# Run the controller
python motion_light_controller.py
```

## Usage

### Basic Usage
```bash
# Start with default 5-second delay
python motion_light_controller.py

# Start with custom delay (10 seconds)
python motion_light_controller.py --light-delay 10

# Start with different broker
python motion_light_controller.py --broker 192.168.1.100 --light-delay 15
```

### Command Line Options
```
--broker        MQTT broker IP (default: 192.168.18.236)
--port          MQTT broker port (default: 1883)
--username      MQTT username (default: homeguard)
--password      MQTT password (default: pu2clr123456)
--light-delay   Seconds to keep light on after motion cleared (default: 5)
```

## How It Works

### Motion Detection Flow
```
1. PIR Sensor detects movement
2. ESP-01S publishes MOTION_DETECTED event
3. Python script receives event
4. Script sends "ON" command to relay
5. Light turns ON immediately
```

### Motion Cleared Flow
```
1. Motion timeout expires on ESP-01S
2. ESP-01S publishes MOTION_CLEARED event
3. Python script starts delay timer
4. After delay expires (no new motion):
5. Script sends "OFF" command to relay
6. Light turns OFF
```

### Smart Timer Logic
```
- New motion during delay → Timer cancelled, light stays ON
- Multiple motion events → Only one timer running
- Manual light control → Timer respects manual state
```

## MQTT Topics Used

### Motion Detector Topics
- **Input**: `home/motion1/motion` - Motion events (DETECTED/CLEARED)
- **Input**: `home/motion1/status` - Motion sensor status
- **Input**: `home/motion1/heartbeat` - Device heartbeat

### Relay Control Topics  
- **Output**: `home/relay1/cmnd` - Commands to relay (ON/OFF)
- **Input**: `home/relay1/stat` - Relay status feedback

## Example Output
```
🔗 Connecting to MQTT broker...
💡 Light delay configured: 5 seconds
✅ Connected to MQTT broker at 192.168.18.236
📡 Subscribed to motion and relay topics
💡 Motion-activated light controller is ready!
============================================================

🚶 [2025-08-10 14:30:15] MOTION DETECTED at Living Room
   Device: motion_646415
   📤 Sent command: Light ON
💡 [2025-08-10 14:30:15] Light turned ON

✅ [2025-08-10 14:30:45] MOTION CLEARED at Living Room (Duration: 30s)
   ⏰ Starting 5s timer to turn light OFF

⏰ [2025-08-10 14:30:50] Timer expired - turning light OFF
   📤 Sent command: Light OFF
🌙 [2025-08-10 14:30:50] Light turned OFF
```

## Manual Control Commands

### Check Motion Sensor Status
```bash
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "STATUS" -u homeguard -P pu2clr123456
```

### Manual Light Control
```bash
# Turn light ON manually
mosquitto_pub -h 192.168.18.236 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456

# Turn light OFF manually
mosquitto_pub -h 192.168.18.236 -t home/relay1/cmnd -m "OFF" -u homeguard -P pu2clr123456
```

### Monitor All Activity
```bash
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "#" -v
```

## Configuration Options

### Motion Sensor Settings
```bash
# Adjust motion sensitivity
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "SENSITIVITY_LOW" -u homeguard -P pu2clr123456

# Set motion timeout
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "TIMEOUT_60" -u homeguard -P pu2clr123456

# Configure location
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "LOCATION_Kitchen" -u homeguard -P pu2clr123456
```

## Status Display
The controller automatically shows status every 30 seconds:

```
============================================================
📊 MOTION LIGHT CONTROLLER STATUS
============================================================
🔗 MQTT Connected: ✅ Yes
🚶 Motion Detected: ❌ No
💡 Light Status: 🔴 OFF
⏰ Light Delay: 5 seconds
📈 Motion Events: 15
💡 Light Activations: 8
⏱️ Uptime: 0:25:30
🕐 Last Motion: 0:02:15 ago
============================================================
```

## Testing

### Run Test Script
```bash
./test_motion_light.sh
```

### Simulate Motion Events
```bash
# Simulate motion detected
mosquitto_pub -h 192.168.18.236 -t home/motion1/motion -m '{"device_id":"test","location":"Test Area","event":"MOTION_DETECTED","timestamp":"'$(date +%s)'"}' -u homeguard -P pu2clr123456

# Simulate motion cleared
mosquitto_pub -h 192.168.18.236 -t home/motion1/motion -m '{"device_id":"test","location":"Test Area","event":"MOTION_CLEARED","timestamp":"'$(date +%s)'","duration":"30s"}' -u homeguard -P pu2clr123456
```

## Troubleshooting

### Common Issues

1. **Controller doesn't respond to motion:**
   - Check if motion detector is publishing to `home/motion1/motion`
   - Verify MQTT broker connection
   - Ensure motion detector is working: `mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion1/#" -v`

2. **Light doesn't turn ON/OFF:**
   - Check if relay controller is responding to commands
   - Test manual control: `mosquitto_pub -h 192.168.18.236 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456`
   - Verify relay status: `mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/relay1/stat" -v`

3. **Connection issues:**
   - Check MQTT broker is running: `telnet 192.168.18.236 1883`
   - Verify credentials are correct
   - Ensure ESP-01S devices are powered and connected

4. **Timer issues:**
   - Light delay is configurable with `--light-delay` parameter
   - New motion cancels existing timer
   - Manual commands override automatic behavior

### Debug Commands
```bash
# Monitor everything
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "#" -v

# Check specific device status
ping 192.168.18.193  # Motion detector
ping 192.168.18.192  # Relay controller
ping 192.168.18.236    # MQTT broker
```

## Integration Tips

1. **Adjust light delay** based on room usage patterns
2. **Configure motion sensitivity** to avoid false triggers
3. **Set appropriate motion timeout** on the sensor
4. **Monitor status regularly** to ensure system health
5. **Test manual override** commands for emergency control

## Advanced Usage

### Custom Delay Scenarios
```bash
# Quick response (1 second delay)
python motion_light_controller.py --light-delay 1

# Long delay for low-traffic areas (30 seconds)
python motion_light_controller.py --light-delay 30

# No delay (immediate OFF)
python motion_light_controller.py --light-delay 0
```

### Integration with Home Automation
The controller can be integrated with other home automation systems by monitoring the same MQTT topics or by extending the script to publish to additional topics for integration with Home Assistant, OpenHAB, etc.

## Files in this Module
- `motion_light_controller.py` - Main controller script
- `test_motion_light.sh` - Test and demonstration script
- `motion_monitor_simple.py` - Motion monitoring utility
- `motion_test.sh` - Motion detector test script
- `README.md` - This documentation
