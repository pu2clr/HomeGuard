# MQTT Modules for ESP-01S

This directory contains MQTT-based modules for the HomeGuard system using ESP-01S microcontrollers.

## Available Modules

### 1. Relay Control Module
- **Location**: `relay/relay.ino`
- **Purpose**: Controls relay modules for switching electrical devices
- **IP Address**: 192.168.18.192
- **MQTT Topics**: 
  - Commands: `home/relay1/cmnd`
  - Status: `home/relay1/stat`

### 2. Motion Detection Module  
- **Location**: `motion_detector/motion_detector.ino`
- **Purpose**: PIR motion sensor monitoring with event reporting
- **IP Address**: 192.168.18.193
- **MQTT Topics**:
  - Commands: `home/motion1/cmnd`
  - Status: `home/motion1/status`
  - Motion Events: `home/motion1/motion`
  - Heartbeat: `home/motion1/heartbeat`
  - Configuration: `home/motion1/config`

## MQTT Broker Configuration

- **IP**: 192.168.18.6
- **Port**: 1883
- **Username**: homeguard
- **Password**: pu2clr123456
- **WiFi Network**: APRC

## Quick Commands

### Monitor All Devices
```bash
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "#" -v
```

### Control Relay
```bash
# Turn ON
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456

# Turn OFF
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "OFF" -u homeguard -P pu2clr123456
```

### Monitor Motion Detector
```bash
# Subscribe to all motion events
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/motion1/#" -v

# Request status
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "STATUS" -u homeguard -P pu2clr123456
```

## Hardware Requirements

### ESP-01S Common Connections
- VCC -> 3.3V
- GND -> GND
- WiFi Network: APRC

### Relay Module
- Relay IN -> GPIO0
- Relay VCC -> 3.3V
- Relay GND -> GND

### Motion Detection Module
- PIR Sensor OUT -> GPIO2
- PIR Sensor VCC -> 3.3V
- PIR Sensor GND -> GND
- Status LED -> GPIO0 (optional)
