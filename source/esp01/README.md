# MOSQUITTO MQTT Broker

Mosquitto is an open source server and set of utilities that implement the MQTT protocol, enabling fast and lightweight communication between Internet of Things (IoT) devices through messages published to topics.

## Installation and Usage of Mosquitto (MQTT Client)

The **HomeGuard** project can be easily tested using the `mosquitto_pub` and `mosquitto_sub` command line utilities, which are part of the Mosquitto package.

Below, see how to install and use these tools on different operating systems.

---

## Installation

### macOS

1. **Install Homebrew** (if you don't have it):
    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

2. **Install Mosquitto:**
    ```bash
    brew install mosquitto
    ```

3. **Start Mosquitto service:**
    ```bash
    brew services start mosquitto
    ```

4. The `mosquitto_pub` and `mosquitto_sub` commands will be available in the terminal.

---

### Linux (Ubuntu/Debian)

1. **Update the repository and install:**
    ```bash
    sudo apt update
    sudo apt install mosquitto mosquitto-clients
    ```

2. **Start and enable the service:**
    ```bash
    sudo systemctl start mosquitto
    sudo systemctl enable mosquitto
    ```

3. **Check service status:**
    ```bash
    sudo systemctl status mosquitto
    ```

4. The `mosquitto_pub` and `mosquitto_sub` commands will be available.

---

### Windows

1. **Download the Mosquitto installer:**
    - Access: [https://mosquitto.org/download/](https://mosquitto.org/download/)
    - Download the Windows installer and follow the instructions.

2. **Install as Administrator:**
    - Run the installer as Administrator
    - Follow the installation wizard

3. **Start the service:**
    ```cmd
    net start mosquitto
    ```

4. After installation, add the executables directory (`mosquitto_pub.exe` and `mosquitto_sub.exe`) to the system PATH (optional, but recommended for use in terminal/cmd).

---

## Basic Configuration

### Default Configuration
Mosquitto runs with default settings, but for HomeGuard, you'll need to configure authentication and access control.

### Create Configuration File

1. **Linux/macOS:**
   ```bash
   sudo nano /etc/mosquitto/mosquitto.conf
   ```

2. **Windows:**
   Edit `C:\Program Files\mosquitto\mosquitto.conf`

### Basic Secure Configuration
```conf
# Basic settings
pid_file /var/run/mosquitto.pid
persistence true
persistence_location /var/lib/mosquitto/
log_dest file /var/log/mosquitto/mosquitto.log

# Network settings
listener 1883 0.0.0.0
protocol mqtt

# Security settings
allow_anonymous false
password_file /etc/mosquitto/pwfile

# Access control
acl_file /etc/mosquitto/aclfile
```

### Create User Authentication

1. **Create password file:**
   ```bash
   sudo mosquitto_passwd -c /etc/mosquitto/pwfile homeuser
   sudo mosquitto_passwd /etc/mosquitto/pwfile deviceuser
   ```

2. **Create ACL file:**
   ```bash
   sudo nano /etc/mosquitto/aclfile
   ```
   
   Content:
   ```
   # Admin user - full access
   user homeuser
   topic readwrite #
   
   # Device user - limited access
   user deviceuser
   topic readwrite homeguard/+/+
   ```

3. **Restart Mosquitto:**
   ```bash
   sudo systemctl restart mosquitto
   ```

---

## Usage Examples

### Basic Testing

1. **Test without authentication:**
   ```bash
   # Subscribe (Terminal 1)
   mosquitto_sub -h localhost -t "test/topic"
   
   # Publish (Terminal 2)
   mosquitto_pub -h localhost -t "test/topic" -m "Hello MQTT"
   ```

2. **Test with authentication:**
   ```bash
   # Subscribe with credentials
   mosquitto_sub -h localhost -t "test/topic" -u homeuser -P yourpassword
   
   # Publish with credentials
   mosquitto_pub -h localhost -t "test/topic" -m "Hello Secure MQTT" -u homeuser -P yourpassword
   ```

### HomeGuard Device Testing

1. **Monitor device heartbeat:**
   ```bash
   mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/heartbeat" -u homeuser -P yourpassword
   ```

2. **Monitor all device activity:**
   ```bash
   mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/+" -v -u homeuser -P yourpassword
   ```

3. **Send commands to device:**
   ```bash
   # Turn device ON
   mosquitto_pub -h YOUR_BROKER_IP -t "homeguard/DEVICE_ID/cmnd" -m "ON" -u homeuser -P yourpassword
   
   # Turn device OFF
   mosquitto_pub -h YOUR_BROKER_IP -t "homeguard/DEVICE_ID/cmnd" -m "OFF" -u homeuser -P yourpassword
   
   # Get device status
   mosquitto_pub -h YOUR_BROKER_IP -t "homeguard/DEVICE_ID/cmnd" -m "STATUS" -u homeuser -P yourpassword
   ```

4. **Send schedule to device:**
   ```bash
   mosquitto_pub -h YOUR_BROKER_IP -t "homeguard/DEVICE_ID/schedule" -m '{"active":true,"hour":20,"minute":30,"duration":60,"action":true,"days":"1234567"}' -u homeuser -P yourpassword
   ```

### Advanced Monitoring

1. **Monitor with timestamps:**
   ```bash
   mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/+" -v -F "%I:%M:%S %t %p" -u homeuser -P yourpassword
   ```

2. **Save messages to file:**
   ```bash
   mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/+" -v -u homeuser -P yourpassword > homeguard.log
   ```

3. **Filter specific message types:**
   ```bash
   # Only heartbeat messages
   mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/heartbeat" -u homeuser -P yourpassword
   
   # Only status messages
   mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/stat" -u homeuser -P yourpassword
   
   # Only motion detection
   mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/motion" -u homeuser -P yourpassword
   ```

---

## Troubleshooting

### Connection Issues

1. **Check if Mosquitto is running:**
   ```bash
   # Linux
   sudo systemctl status mosquitto
   
   # Check if port is open
   netstat -ln | grep 1883
   ```

2. **Test connectivity:**
   ```bash
   telnet YOUR_BROKER_IP 1883
   ```

3. **Check firewall:**
   ```bash
   # Linux (UFW)
   sudo ufw allow 1883/tcp
   ```

### Authentication Issues

1. **Verify user exists:**
   ```bash
   sudo mosquitto_passwd -U /etc/mosquitto/pwfile
   ```

2. **Test credentials:**
   ```bash
   mosquitto_pub -h localhost -t test -m "auth test" -u username -P password --debug
   ```

### Permission Issues

1. **Check ACL configuration:**
   ```bash
   sudo cat /etc/mosquitto/aclfile
   ```

2. **Test topic permissions:**
   ```bash
   # Should work
   mosquitto_pub -h localhost -t "homeguard/test/cmnd" -m "test" -u deviceuser -P password
   
   # Should fail
   mosquitto_pub -h localhost -t "admin/test" -m "test" -u deviceuser -P password
   ```

---

## Security Best Practices

1. **Always use authentication** in production
2. **Implement proper ACLs** to limit device access
3. **Use TLS encryption** for sensitive data (port 8883)
4. **Regular password updates** for MQTT users
5. **Monitor connection logs** for suspicious activity
6. **Firewall configuration** to limit access

---

## Integration with HomeGuard

### Device Discovery Process
1. **Device boots** and connects to WiFi
2. **Generates unique ID** based on MAC address
3. **Connects to MQTT broker** with authentication
4. **Publishes heartbeat** to announce presence
5. **Subscribes to command topics** for control
6. **Reports status** periodically

### Topic Structure
```
homeguard/
├── {device_id}/
│   ├── cmnd          # Commands to device
│   ├── stat          # Device status (JSON)
│   ├── schedule      # Schedule configuration
│   ├── heartbeat     # Device heartbeat
│   └── motion        # Motion sensor events
└── system/
    ├── discovery     # Device discovery
    └── logs          # System logs
```

### Message Formats

#### Device Status (JSON)
```json
{
  "device_id": "homeguard_abc123",
  "mac": "aa:bb:cc:dd:ee:ff",
  "ip": "192.168.1.150",
  "relay": "ON",
  "motion": "CLEAR",
  "rssi": -45,
  "uptime": 123456
}
```

#### Heartbeat (JSON)
```json
{
  "device_id": "homeguard_abc123",
  "timestamp": 123456789,
  "status": "ONLINE",
  "rssi": -45
}
```

#### Schedule (JSON)
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

---

## Next Steps

1. **Setup MQTT broker** with authentication
2. **Program ESP-01S** with HomeGuard firmware
3. **Test device communication** using mosquitto clients
4. **Deploy Python client** for advanced management
5. **Integrate with home automation** systems

For advanced Python client usage, see `/python/README.md`
For troubleshooting help, see `/docs/troubleshooting.md`



## Device MQTT Monitor examples

% mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "home/#" -v       

home/motion/MOTION_01/status offline
home/motion/MOTION_02/status offline
home/motion/MOTION_03/status online

home/RDA5807/frequency 10390

home/motion/MOTION_03/heartbeat {"uptime":180,"rssi":-55}

home/RDA5807/volume 4
home/RDA5807/status Unmuted

home/motion/MOTION_03/event {"motion":1,"ts":"218","device_id":"MOTION_03","name":"MAKER_SPACE","location":"Maker Space"}
home/motion/MOTION_03/event {"motion":0,"ts":"225","device_id":"MOTION_03","name":"MAKER_SPACE","location":"Maker Space"}
home/motion/MOTION_03/event {"motion":1,"ts":"231","device_id":"MOTION_03","name":"MAKER_SPACE","location":"Maker Space"}
home/motion/MOTION_03/event {"motion":0,"ts":"239","device_id":"MOTION_03","name":"MAKER_SPACE","location":"Maker Space"}
home/motion/MOTION_03/heartbeat {"uptime":240,"rssi":-58}
home/motion/MOTION_03/event {"motion":1,"ts":"245","device_id":"MOTION_03","name":"MAKER_SPACE","location":"Maker Space"}

home/sensor/ESP01_DHT11_BRANCO/status online
home/temperature/ESP01_DHT11_BRANCO/data {"device_id":"ESP01_DHT11_BRANCO","device_name":"sala","location":"Sala","sensor_type":"DHT11","temperature":26.1,"unit":"°C","rssi":-63,"uptime":120084,"timestamp":"120084"}
home/humidity/ESP01_DHT11_BRANCO/data {"device_id":"ESP01_DHT11_BRANCO","device_name":"sala","location":"Sala","sensor_type":"DHT11","humidity":54.0,"unit":"%","rssi":-63,"uptime":120086,"timestamp":"120086"}
home/temperature/ESP01_DHT11_BRANCO/data {"device_id":"ESP01_DHT11_BRANCO","device_name":"sala","location":"Sala","sensor_type":"DHT11","temperature":26.9,"unit":"°C","rssi":-62,"uptime":126478,"timestamp":"126478"}
home/humidity/ESP01_DHT11_BRANCO/data {"device_id":"ESP01_DHT11_BRANCO","device_name":"sala","location":"Sala","sensor_type":"DHT11","humidity":50.0,"unit":"%","rssi":-62,"uptime":126480,"timestamp":"126480"}
home/motion/MOTION_03/heartbeat {"uptime":540,"rssi":-60}


home/relay/ESP01_RELAY_001/info {"RELAY_ID":"ESP01_RELAY_001","name":"Luz da Sala","location":"Sala","ip":"192.168.18.192","rssi":-53,"uptime":4698,"relay_state":"off","last_command":"BOOT","firmware":"HomeGuard_v1.0"}
home/relay/ESP01_RELAY_001/status off

