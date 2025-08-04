# HomeGuard Troubleshooting Guide

## Common Issues and Solutions

### MQTT Connection Issues

#### Issue: "Connection refused"
**Symptoms:**
- ESP-01S can't connect to MQTT broker
- Error code -2 in serial monitor

**Solutions:**
1. **Check broker IP address:**
   ```bash
   ping YOUR_BROKER_IP
   ```

2. **Verify broker is running:**
   ```bash
   # Linux
   sudo systemctl status mosquitto
   
   # Check if port is open
   netstat -ln | grep 1883
   ```

3. **Test broker manually:**
   ```bash
   mosquitto_pub -h YOUR_BROKER_IP -t test/topic -m "test"
   ```

#### Issue: "Authentication failed"
**Symptoms:**
- ESP-01S connects to WiFi but fails MQTT auth
- Error code -4 in serial monitor

**Solutions:**
1. **Verify credentials in code:**
   ```cpp
   const char* mqtt_user = "deviceuser";
   const char* mqtt_pass = "correct_password";
   ```

2. **Check user exists in broker:**
   ```bash
   sudo mosquitto_passwd -U /etc/mosquitto/pwfile
   ```

3. **Verify ACL permissions:**
   ```bash
   sudo cat /etc/mosquitto/aclfile
   ```

### WiFi Connection Issues

#### Issue: "WiFi connection failed"
**Symptoms:**
- ESP-01S can't connect to WiFi
- Constant "." dots in serial monitor

**Solutions:**
1. **Check credentials:**
   ```cpp
   const char* ssid = "YOUR_EXACT_WIFI_NAME";
   const char* password = "YOUR_EXACT_PASSWORD";
   ```

2. **Check signal strength:**
   - Move ESP-01S closer to router
   - Check for interference

3. **Check WiFi band:**
   - ESP-01S only supports 2.4GHz
   - Disable 5GHz-only mode if enabled

### Hardware Issues

#### Issue: "Programming failed"
**Symptoms:**
- Can't upload sketch to ESP-01S
- "Failed to connect" errors

**Solutions:**
1. **Check connections:**
   ```
   VCC    → 3.3V (NOT 5V!)
   GND    → GND
   TX     → RX
   RX     → TX
   GPIO0  → GND (for programming only)
   CH_EN  → 3.3V
   ```

2. **Power supply issues:**
   - Use stable 3.3V supply (min 200mA)
   - Add 100uF capacitor near ESP-01S
   - Check for voltage drops

3. **Programming mode:**
   - Connect GPIO0 to GND before powering on
   - Reset or power cycle with GPIO0 grounded
   - Remove GPIO0 connection after upload

#### Issue: "Relay not responding"
**Symptoms:**
- Commands received but relay doesn't switch
- Status shows correct state but no physical change

**Solutions:**
1. **Check relay wiring:**
   ```
   ESP GPIO0 → Relay IN
   Relay VCC → 3.3V or 5V (check relay specs)
   Relay GND → Common GND
   ```

2. **Verify relay type:**
   - Check if relay is active HIGH or LOW
   - Adjust code accordingly:
   ```cpp
   digitalWrite(PIN_RELAY, state ? LOW : HIGH);  // Active LOW
   digitalWrite(PIN_RELAY, state ? HIGH : LOW);  // Active HIGH
   ```

3. **Power requirements:**
   - Some relays need separate power supply
   - Check current requirements

### Software Issues

#### Issue: "Device not discovered"
**Symptoms:**
- Python client can't find devices
- No heartbeat messages

**Solutions:**
1. **Check MQTT topics:**
   ```bash
   mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/+" -u homeuser -P password
   ```

2. **Verify device ID generation:**
   - Check serial monitor for device ID
   - Ensure MAC address is read correctly

3. **Check heartbeat interval:**
   ```cpp
   const unsigned long HEARTBEAT_INTERVAL = 30000;  // 30 seconds
   ```

#### Issue: "Schedule not working"
**Symptoms:**
- Schedule sent but device doesn't follow it
- No schedule activation

**Solutions:**
1. **Verify JSON format:**
   ```json
   {
     "active": true,
     "hour": 20,
     "minute": 30,
     "duration": 60,
     "action": true,
     "days": "1234567"
   }
   ```

2. **Check time synchronization:**
   - ESP-01S doesn't have RTC
   - Implement NTP time sync for accuracy

3. **EEPROM issues:**
   ```cpp
   EEPROM.begin(512);  // Initialize EEPROM
   EEPROM.commit();    // Save changes
   ```

### Network Issues

#### Issue: "Intermittent disconnections"
**Symptoms:**
- Device connects then disconnects randomly
- WiFi or MQTT connection drops

**Solutions:**
1. **WiFi power management:**
   ```cpp
   WiFi.setSleepMode(WIFI_NONE_SLEEP);
   ```

2. **Increase connection timeout:**
   ```cpp
   client.setKeepAlive(60);
   client.setSocketTimeout(30);
   ```

3. **Check router settings:**
   - Disable AP isolation
   - Increase DHCP lease time
   - Check for MAC filtering

#### Issue: "Firewall blocking connections"
**Symptoms:**
- Local connections work, remote don't
- Timeout errors from external clients

**Solutions:**
1. **Open MQTT port:**
   ```bash
   # Linux (UFW)
   sudo ufw allow 1883/tcp
   
   # Windows
   netsh advfirewall firewall add rule name="MQTT" dir=in action=allow protocol=TCP localport=1883
   ```

2. **Check router firewall:**
   - Port forwarding for external access
   - DMZ settings (not recommended)

## Debugging Tools and Commands

### Serial Monitor Debugging
```cpp
Serial.begin(115200);
Serial.println("Debug message");
Serial.print("Variable: ");
Serial.println(variable);
```

### MQTT Traffic Monitoring
```bash
# Monitor all traffic
mosquitto_sub -h YOUR_BROKER_IP -t "#" -v

# Monitor HomeGuard devices only
mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/+" -v

# Monitor specific device
mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/DEVICE_ID/+" -v
```

### Network Diagnostics
```bash
# Check connectivity
ping YOUR_BROKER_IP

# Check port availability
telnet YOUR_BROKER_IP 1883

# Check WiFi signal
iwconfig  # Linux
```

### Python Client Debugging
```bash
# Enable verbose logging
python -m logging.DEBUG schedule_manager.py --monitor

# Test with simple MQTT client
python -c "
import paho.mqtt.client as mqtt
client = mqtt.Client()
client.username_pw_set('homeuser', 'password')
client.connect('YOUR_BROKER_IP', 1883, 60)
client.publish('test/topic', 'Hello')
"
```

## Performance Optimization

### ESP-01S Optimization
```cpp
// Reduce serial baud rate for stability
Serial.begin(9600);

// Optimize WiFi connection
WiFi.persistent(false);
WiFi.mode(WIFI_STA);
WiFi.setAutoConnect(true);
WiFi.setAutoReconnect(true);

// MQTT optimization
client.setKeepAlive(60);
client.setBufferSize(512);
```

### Broker Optimization
```conf
# /etc/mosquitto/mosquitto.conf
max_connections 100
max_inflight_messages 20
max_queued_messages 1000
message_size_limit 8192
```

## Preventive Maintenance

### Regular Checks
1. **Monitor device health:**
   - Check heartbeat frequency
   - Monitor WiFi signal strength
   - Check memory usage

2. **Update firmware:**
   - Keep ESP8266 core updated
   - Update library versions
   - Test new features in development environment

3. **Backup configurations:**
   - Save device configurations
   - Backup MQTT broker settings
   - Document network settings

### Monitoring Scripts
```bash
#!/bin/bash
# Simple monitoring script
while true; do
    echo "$(date): Checking devices..."
    timeout 10 mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/heartbeat" -C 5
    sleep 300  # Check every 5 minutes
done
```

## Getting Help

1. **Check logs:**
   - ESP-01S serial output
   - MQTT broker logs
   - Router logs

2. **Test with minimal setup:**
   - Use basic MQTT example
   - Test with simple commands
   - Isolate the problem

3. **Community resources:**
   - ESP8266 Arduino forums
   - MQTT community
   - Home automation forums
