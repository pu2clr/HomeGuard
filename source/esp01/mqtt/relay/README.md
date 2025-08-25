# HomeGuard Relay Control Module

## Overview
This module provides MQTT-based relay control for the HomeGuard system using ESP-01S microcontroller.

## Hardware Requirements
- ESP-01S microcontroller
- Relay module (compatible with 3.3V logic)
- 3.3V power supply
- WiFi connection

## Hardware Connections
```
ESP-01S    ->  Relay Module
GPIO0      ->  IN (Control Pin)
3.3V       ->  VCC
GND        ->  GND
```

## Network Configuration
- **WiFi Network**: YOUR_SSID
- **Static IP**: 192.168.18.192
- **Gateway**: 192.168.18.1
- **Subnet**: 255.255.255.0

## MQTT Configuration
- **Broker IP**: 192.168.18.236
- **Port**: 1883
- **Username**: homeguard
- **Password**: pu2clr123456

## MQTT Topics
- **Command Topic**: `home/relay1/cmnd`
- **Status Topic**: `home/relay1/stat`

## Commands
### Turn Relay ON
```bash
mosquitto_pub -h 192.168.18.236 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456
```

### Turn Relay OFF
```bash
mosquitto_pub -h 192.168.18.236 -t home/relay1/cmnd -m "OFF" -u homeguard -P pu2clr123456
```

### Monitor Status
```bash
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/relay1/stat" -v
```

### Monitor All Topics
```bash
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/relay1/#" -v
```

## Features
- Remote ON/OFF control via MQTT
- Status feedback
- Automatic reconnection on WiFi/MQTT loss
- Active LOW relay control (compatible with most relay modules)

## Installation
1. Connect hardware according to the wiring diagram
2. Update WiFi credentials if needed in the code
3. Upload `relay.ino` to ESP-01S using Arduino IDE
4. Monitor serial output for connection status
5. Test relay control using MQTT commands

## Troubleshooting
- Ensure ESP-01S has adequate power supply (min 3.3V, 250mA)
- Check WiFi credentials and network connectivity
- Verify MQTT broker is running and accessible
- Confirm relay module is compatible with 3.3V logic levels
