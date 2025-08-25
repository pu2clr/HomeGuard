# HomeGuard Motion Detector Module

This sketch transforms the ESP-01S into an intelligent motion detector, based on the working `mqtt.ino` code that is already functioning perfectly in your environment.

## Features

- **Motion Detection:** Using PIR sensor for presence monitoring
- **MQTT Communication:** Complete integration with Mosquitto broker
- **Remote Configuration:** Sensitivity and timeout adjustment via MQTT
- **Unique Identification:** ID based on device MAC address
- **Real-time Monitoring:** Status and events via MQTT
- **Heartbeat:** Periodic connectivity verification

## Required Hardware

### Components:
- 1x ESP-01S
- 1x PIR Sensor (HC-SR501 or similar)
- 1x Stable 3.3V power supply
- Connection wires

### Connections:

```
ESP-01S          PIR Sensor
-------          ----------
3.3V      <----> VCC
GND       <----> GND
GPIO2     <----> OUT

Optional (Status LED):
GPIO0     <----> LED (through 220Ω resistor)
```

**⚠️ IMPORTANT:** Use only 3.3V! Never 5V on ESP-01S.

## Code Configuration

### IP and Network (based on your working mqtt.ino):
```cpp
const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";
IPAddress local_IP(192, 168, 18, 193);  // Different IP from relay
```

### MQTT Broker (same settings that work):
```cpp
const char* mqtt_server = "192.168.18.236";
const char* mqtt_user = "homeguard";
const char* mqtt_pass = "pu2clr123456";
```

## MQTT Topic Structure

```
home/motion1/
├── cmnd        # Commands to the device
├── status      # General device status (JSON)
├── motion      # Motion events (JSON)
├── heartbeat   # Device heartbeat (JSON)
└── config      # Configuration confirmations
```

## Available MQTT Commands

### General Monitoring:
```bash
# Monitor all detector events
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion1/#" -v

# Monitor only motion detections
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion1/motion" -v
```

### Control Commands:
```bash
# Get complete device status
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "STATUS" -u homeguard -P pu2clr123456

# Restart device
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "RESET" -u homeguard -P pu2clr123456

# Configure location
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "LOCATION_Kitchen" -u homeguard -P pu2clr123456
```

### Sensitivity Configuration:
```bash
# High sensitivity (1 second debounce)
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "SENSITIVITY_HIGH" -u homeguard -P pu2clr123456

# Normal sensitivity (2 seconds debounce) 
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "SENSITIVITY_NORMAL" -u homeguard -P pu2clr123456

# Low sensitivity (5 seconds debounce)
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "SENSITIVITY_LOW" -u homeguard -P pu2clr123456
```

### Timeout Configuration:
```bash
# Set motion timeout to 30 seconds
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "TIMEOUT_30" -u homeguard -P pu2clr123456

# Set motion timeout to 60 seconds
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "TIMEOUT_60" -u homeguard -P pu2clr123456
```

### Heartbeat Control:
```bash
# Enable heartbeat
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "HEARTBEAT_ON" -u homeguard -P pu2clr123456

# Disable heartbeat
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "HEARTBEAT_OFF" -u homeguard -P pu2clr123456
```

## Message Examples

### Device Status:
```json
{
  "device_id": "motion_a1b2c3",
  "location": "Living Room",
  "mac": "AA:BB:CC:DD:EE:FF",
  "ip": "192.168.18.193",
  "motion": "CLEAR",
  "last_motion": "45s ago",
  "timeout": "30s",
  "sensitivity": "2s",
  "uptime": "3600s",
  "rssi": "-45dBm"
}
```

### Motion Detected Event:
```json
{
  "device_id": "motion_a1b2c3",
  "location": "Living Room",
  "event": "MOTION_DETECTED",
  "timestamp": "123456789",
  "rssi": "-45dBm"
}
```

### Motion Cleared Event:
```json
{
  "device_id": "motion_a1b2c3",
  "location": "Living Room", 
  "event": "MOTION_CLEARED",
  "timestamp": "123456820",
  "duration": "31s"
}
```

### Heartbeat:
```json
{
  "device_id": "motion_a1b2c3",
  "timestamp": "123456789",
  "status": "ONLINE",
  "location": "Living Room",
  "rssi": "-45dBm"
}
```

## Default Settings

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| IP Address | 192.168.18.193 | Fixed IP (different from relay) |
| Motion Timeout | 30 seconds | Time to clear detection |
| Debounce Delay | 2 seconds | Anti-noise delay |
| Heartbeat Interval | 60 seconds | Heartbeat interval |
| Location | "Living Room" | Configurable location |

## Installation and Testing

### 1. Programming:
```
1. Connect GPIO0 to GND
2. Upload motion_detector.ino sketch
3. Disconnect GPIO0 from GND
4. Restart ESP-01S
```

### 2. Verification:
```bash
# Check if device is online
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion1/status" -v

# Test a command
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "STATUS" -u homeguard -P pu2clr123456
```

### 3. Monitoring:
```bash
# Monitor motion detections in real-time
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion1/motion" -v
```

## PIR Sensor Adjustments

### HC-SR501 Physical Settings:
- **Sensitivity (Sens):** Adjusts detection distance (3-7 meters)
- **Time Delay (Time):** Adjusts high output time (5s-300s)
- **Trigger Mode:** 
  - H = Repeatable trigger (recommended)
  - L = Non-repeatable trigger

### Recommendations:
- **Sensitivity:** Medium (potentiometer center position)
- **Time Delay:** Minimum (fully counterclockwise)
- **Trigger Mode:** H (jumper in H position)

*Timeout is controlled via software, not by the sensor.*

## Troubleshooting

### Common Issues:

1. **Sensor doesn't detect motion:**
   - Check connections (VCC, GND, OUT)
   - Wait 1-2 minutes for initial PIR calibration
   - Adjust sensitivity physically on sensor

2. **Too many false positives:**
   - Use `SENSITIVITY_LOW` command
   - Check for interference (heat, sunlight)
   - Adjust sensor position

3. **Device doesn't appear on MQTT:**
   - Check IP (must be different from relay: 192.168.18.193)
   - Test connection: `ping 192.168.18.193`
   - Check Serial Monitor logs

4. **Detection too fast:**
   - Adjust timeout: `TIMEOUT_60` for 60 seconds
   - Use `SENSITIVITY_NORMAL` or `SENSITIVITY_LOW`

### Debug via Serial:
```
115200 baud
Messages include:
- WiFi/MQTT connection status
- Motion events detected
- Command confirmations received
```

## Integration with Existing System

### Python Script for Monitoring:
```python
import paho.mqtt.client as mqtt
import json
from datetime import datetime

def on_message(client, userdata, msg):
    if "motion" in msg.topic:
        data = json.loads(msg.payload.decode())
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {data['location']}: {data['event']}")

client = mqtt.Client()
client.username_pw_set("homeguard", "pu2clr123456")
client.on_message = on_message
client.connect("192.168.18.236", 1883, 60)
client.subscribe("home/motion1/motion")
client.loop_forever()
```

### Home Assistant Integration:
```yaml
# configuration.yaml
binary_sensor:
  - platform: mqtt
    name: "Living Room Motion"
    state_topic: "home/motion1/motion"
    payload_on: "MOTION_DETECTED"
    payload_off: "MOTION_CLEARED"
    value_template: "{{ value_json.event }}"
    device_class: motion
```

## Next Steps

1. **Test the PIR sensor** separately before integration
2. **Configure the location** appropriately via MQTT command
3. **Adjust sensitivity** as needed
4. **Monitor for several hours** to validate functionality
5. **Integrate with existing automation system**

The code is based exactly on your working `mqtt.ino`, just adapted for motion detection instead of relay control.
