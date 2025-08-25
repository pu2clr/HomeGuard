# HomeGuard Motion Sensor Compiler

Automated compilation and upload system for ESP-01S motion sensors using arduino-cli.

## 🎯 Overview

This system provides automated compilation and upload for 5 different motion sensor locations:

| Location | IP Address | MQTT Topic | Description |
|----------|------------|------------|-------------|
| **Garagem** | 192.168.18.201 | `home/motion_garagem` | Garage motion detection |
| **Área Serviço** | 192.168.18.202 | `home/motion_area_servico` | Service area monitoring |
| **Varanda** | 192.168.18.203 | `home/motion_varanda` | Balcony/terrace monitoring |
| **Mezanino** | 192.168.18.204 | `home/motion_mezanino` | Mezzanine level detection |
| **Ad-Hoc** | 192.168.18.205 | `home/motion_adhoc` | Flexible/temporary location |

## 🚀 Quick Start

### 1. Setup Development Environment
```bash
# Install and configure arduino-cli with ESP8266 support
./scripts/setup-dev-environment.sh
```

### 2. Compile and Upload Single Sensor
```bash
# Interactive script - choose sensor and USB port
./scripts/compile-motion-sensors.sh
```

### 3. Batch Compile All Sensors
```bash
# Compile all 5 sensors at once
./scripts/batch-compile-sensors.sh
```

### 4. Test Deployed Sensors
```bash
# Test network connectivity and MQTT responses
./scripts/test-all-motion-sensors.sh
```

## 📁 File Structure

```
HomeGuard/
├── scripts/
│   ├── setup-dev-environment.sh      # Install arduino-cli & dependencies
│   ├── compile-motion-sensors.sh     # Interactive compile & upload
│   ├── batch-compile-sensors.sh      # Batch compile all sensors
│   └── test-all-motion-sensors.sh    # Test deployed sensors
├── source/esp01/mqtt/motion_detector/
│   ├── motion_detector_template.ino  # Template with build-time configuration
│   └── motion_detector.ino          # Original single-device version
├── build/                            # Temporary build files
├── firmware/                         # Compiled .bin files
└── UPLOAD_INSTRUCTIONS.md           # Generated upload guide
```

## 🔧 Hardware Requirements

### ESP-01S Module
- **WiFi**: ESP8266 with 1MB flash
- **Power**: 3.3V (stable power supply required)
- **Programming**: USB-to-serial adapter (CP2102/CH340)

### PIR Motion Sensor
- **VCC**: Connect to 3.3V
- **GND**: Connect to GND
- **OUT**: Connect to GPIO2 (Pin 2)

### Programming Mode
- **GPIO0**: Connect to GND for upload mode
- **Reset**: Power cycle after connecting GPIO0

## 📊 Build System Features

### Template-Based Compilation
- Single source file with build-time configuration
- Configurable device location, IP, and MQTT topics
- No manual code editing required

### arduino-cli Integration
- Automated ESP8266 core installation
- Library dependency management
- Cross-platform support (macOS/Linux)

### Batch Processing
- Compile all 5 sensors simultaneously
- Generate firmware files for manual upload
- Create comprehensive documentation

### Interactive Upload
- USB port detection and selection
- Step-by-step upload guidance
- Real-time compilation feedback

## 🎛️ Configuration Parameters

Each sensor is compiled with unique parameters:

```cpp
// Build-time defines (set automatically by scripts)
#define DEVICE_LOCATION "Garagem"           // Location name
#define DEVICE_IP_LAST_OCTET 201           // IP: 192.168.18.201
#define MQTT_TOPIC_SUFFIX "motion_garagem" // MQTT topic base
```

### Automatic Code Generation
- **IP Address**: `192.168.18.{DEVICE_IP_LAST_OCTET}`
- **Device ID**: `motion_{IP_OCTET}_{MAC_SUFFIX}`
- **MQTT Topics**: `home/{MQTT_TOPIC_SUFFIX}/{subtopic}`

## 📡 MQTT Integration

### Topic Structure
```
home/{sensor_topic}/
├── cmnd          # Commands (STATUS, RESET, SENSITIVITY_*, etc.)
├── status        # Device status (JSON with location, IP, MAC, etc.)
├── motion        # Motion events (MOTION_DETECTED, MOTION_CLEARED)
├── heartbeat     # Keep-alive messages every 60 seconds
└── config        # Configuration change confirmations
```

### Example Commands
```bash
# Check device status
mosquitto_pub -h 192.168.18.236 -t "home/motion_garagem/cmnd" -m "STATUS" -u homeguard -P pu2clr123456

# Monitor all motion events
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion_+/motion" -v

# Configure sensitivity
mosquitto_pub -h 192.168.18.236 -t "home/motion_garagem/cmnd" -m "SENSITIVITY_HIGH" -u homeguard -P pu2clr123456
```

## 🔍 Troubleshooting

### Setup Issues
```bash
# Check arduino-cli installation
arduino-cli version

# Verify ESP8266 core
arduino-cli core list | grep esp8266

# Check required libraries
arduino-cli lib list | grep PubSubClient
```

### Upload Issues
1. **ESP-01S not in programming mode**
   - Connect GPIO0 to GND before power-on
   - Power cycle the device

2. **USB port not detected**
   - Check USB-to-serial adapter drivers
   - Try different USB ports
   - Verify device permissions

3. **Compilation errors**
   - Run setup script: `./scripts/setup-dev-environment.sh`
   - Update arduino-cli: `arduino-cli upgrade`

### Network Issues
```bash
# Test IP connectivity
ping 192.168.18.201

# Check MQTT broker
mosquitto_pub -h 192.168.18.236 -t test -m "hello" -u homeguard -P pu2clr123456

# Monitor device output
screen /dev/tty.usbserial-XXXX 115200
```

## 🧪 Testing and Validation

### After Upload Checklist
1. ✅ Remove GPIO0 from GND (exit programming mode)
2. ✅ Power cycle ESP-01S
3. ✅ Connect PIR sensor to GPIO2
4. ✅ Test network connectivity: `ping 192.168.18.{IP}`
5. ✅ Test MQTT responses: `STATUS` command
6. ✅ Verify motion detection events

### Automated Testing
```bash
# Test all sensors at once
./scripts/test-all-motion-sensors.sh

# Monitor continuous operation
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion_+/+" -v
```

## 📈 Advanced Usage

### Custom Sensor Configuration
```bash
# Run interactive script and select option 6 for custom config
./scripts/compile-motion-sensors.sh

# Enter custom parameters:
# - Location: Custom_Location
# - IP octet: 210
# - MQTT topic: motion_custom
```

### Manual Compilation
```bash
# Compile specific sensor manually
arduino-cli compile \
  --fqbn esp8266:esp8266:generic \
  --build-property compiler.cpp.extra_flags="-DDEVICE_LOCATION=Garagem -DDEVICE_IP_LAST_OCTET=201 -DMQTT_TOPIC_SUFFIX=motion_garagem" \
  source/esp01/mqtt/motion_detector/motion_detector_template.ino
```

### Firmware Distribution
```bash
# After batch compilation, firmware files are available in:
firmware/
├── Garagem_motion_sensor.bin
├── Area_Servico_motion_sensor.bin
├── Varanda_motion_sensor.bin
├── Mezanino_motion_sensor.bin
└── Ad_Hoc_motion_sensor.bin

# Upload pre-compiled firmware
arduino-cli upload \
  --fqbn esp8266:esp8266:generic \
  --port /dev/tty.usbserial-XXXX \
  --input-file firmware/Garagem_motion_sensor.bin
```

## 🔄 Integration with Home Automation

### Motion-Light Controller Integration
The motion sensors work seamlessly with the existing motion-light controller:

```python
# The controller listens to all motion sensors
# Topics: home/motion_*/motion
# Events: MOTION_DETECTED, MOTION_CLEARED

# Run the motion-light controller
python source/esp01/mqtt/motion_detector/motion_light_controller.py
```

### Multiple Sensor Monitoring
```python
# Example: Monitor specific sensors
import paho.mqtt.client as mqtt

def on_message(client, userdata, msg):
    print(f"Sensor: {msg.topic} - Event: {msg.payload.decode()}")

client = mqtt.Client()
client.username_pw_set("homeguard", "pu2clr123456")
client.on_message = on_message
client.connect("192.168.18.236", 1883, 60)

# Subscribe to all motion sensors
client.subscribe("home/motion_+/motion")
client.loop_forever()
```

## 📞 Support

For issues or questions:

1. **Check logs**: Use serial monitor to view device output
2. **Verify network**: Ensure WiFi connectivity and MQTT broker
3. **Test MQTT**: Use mosquitto_pub/sub for debugging
4. **Hardware check**: Verify ESP-01S and PIR sensor connections

## 🔗 Related Documentation

- [Main Project README](../README.md)
- [MQTT Broker Setup](../docs/MQTT_BROKER_SETUP.md)
- [Motion Detection System](../docs/MOTION_DETECTION.md)
- [Python Integration](../docs/PYTHON_INTEGRATION.md)
