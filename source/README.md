# HomeGuard Source Code

This directory contains the Arduino source code for the HomeGuard project.

## Directory Structure

```
esp01/
├── mqtt/
│   ├── mqtt.ino              # Basic MQTT example
│   ├── homeguard_advanced.ino # Advanced features with scheduling
│   └── README.md             # MQTT setup and usage
└── web/
    └── web.ino               # Web interface example
```

## Arduino Sketches

### Basic MQTT Example (`mqtt/mqtt.ino`)
- Simple relay control via MQTT
- Fixed IP configuration
- Basic authentication support
- Status reporting

### Motion Detector (`mqtt/motion_detector.ino`)
- **New Feature!** PIR motion sensor integration
- Remote monitoring via MQTT
- Configurable sensitivity and timeout
- JSON event reporting
- Device identification by MAC address
- Real-time alerts and status

### Advanced MQTT Example (`mqtt/homeguard_advanced.ino`)
- **Features:**
  - DHCP support for automatic IP assignment
  - MAC-based device identification
  - JSON schedule system
  - Motion sensor integration
  - Heartbeat monitoring
  - EEPROM configuration storage
  - Comprehensive error handling

### Web Interface Example (`web/web.ino`)
- HTTP-based relay control
- Simple web interface
- Fixed IP configuration
- Manual relay operation

## Quick Setup

1. **Install Required Libraries:**
   ```
   - PubSubClient (for MQTT)
   - ArduinoJson (for JSON handling)
   - ESP8266WiFi (included with ESP8266 package)
   ```

2. **Configure Your Sketch:**
   - Update WiFi credentials
   - Set MQTT broker IP
   - Configure authentication
   - Adjust pin assignments if needed

3. **Upload to ESP-01S:**
   - Connect GPIO0 to GND for programming
   - Upload sketch
   - Remove GPIO0 connection and restart

## Configuration Parameters

### WiFi Settings
```cpp
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
```

### MQTT Settings
```cpp
const char* mqtt_server = "192.168.1.100";  // Your broker IP
const int mqtt_port = 1883;
const char* mqtt_user = "deviceuser";
const char* mqtt_pass = "your_password";
```

### Motion Sensor Setup (`mqtt/motion_detector.ino`)
```
PIR Sensor VCC -> 3.3V
PIR Sensor GND -> GND
PIR Sensor OUT -> GPIO2
Optional LED   -> GPIO0 (with 220Ω resistor)
```

### Basic Relay Setup
```cpp
#define PIN_RELAY 0    // Relay control pin
#define PIN_SENSOR 2   // Motion sensor pin (if available)
```

## Usage Examples

### Motion Detection Commands
```bash
# Monitor motion events
mosquitto_sub -h BROKER_IP -t "home/motion1/motion" -u USER -P PASS

# Get motion detector status  
mosquitto_pub -h BROKER_IP -t "home/motion1/cmnd" -m "STATUS" -u USER -P PASS

# Configure sensitivity
mosquitto_pub -h BROKER_IP -t "home/motion1/cmnd" -m "SENSITIVITY_HIGH" -u USER -P PASS

# Set location
mosquitto_pub -h BROKER_IP -t "home/motion1/cmnd" -m "LOCATION_Kitchen" -u USER -P PASS
```

### Basic Relay Commands
```bash
# Turn relay ON
mosquitto_pub -h BROKER_IP -t "homeguard/DEVICE_ID/cmnd" -m "ON"

# Turn relay OFF
mosquitto_pub -h BROKER_IP -t "homeguard/DEVICE_ID/cmnd" -m "OFF"

# Get status
mosquitto_pub -h BROKER_IP -t "homeguard/DEVICE_ID/cmnd" -m "STATUS"
```

### Schedule Commands (Advanced sketch only)
```bash
# Send schedule
mosquitto_pub -h BROKER_IP -t "homeguard/DEVICE_ID/schedule" -m '{"active":true,"hour":20,"minute":30,"duration":60,"action":true,"days":"1234567"}'
```

## Device Topics Structure

```
homeguard/
└── {device_id}/
    ├── cmnd          # Commands to device
    ├── stat          # Device status (JSON)
    ├── schedule      # Schedule configuration
    ├── heartbeat     # Device heartbeat
    └── motion        # Motion sensor events
```

## Troubleshooting

### Common Issues:
1. **Upload Failed:** Check GPIO0 connection and power supply
2. **WiFi Connection Failed:** Verify credentials and signal strength
3. **MQTT Connection Failed:** Check broker IP and authentication
4. **Relay Not Working:** Verify wiring and relay type (active HIGH/LOW)

### Debug Output:
All sketches include serial debug output at 115200 baud. Connect to serial monitor to see:
- WiFi connection status
- MQTT connection attempts
- Command processing
- Error messages

## Next Steps

1. **Test Basic Functionality:** Start with basic MQTT example
2. **Upgrade to Advanced:** Use advanced sketch for scheduling features
3. **Python Integration:** Use the Python client in `/python/` directory
4. **System Integration:** Connect to home automation systems

For detailed troubleshooting, see `/docs/troubleshooting.md`.