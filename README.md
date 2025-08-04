# HomeGuard
Home Security and Automation System based on ESP8266 (ESP-01S) with MQTT integration.

## **Project Overview**

The HomeGuard project presents a home automation and security system based on ESP8266 (ESP-01S) integrated via MQTT, with relay control, motion sensors, dynamic scheduling logic, and real-time notifications. The MQTT broker used is Mosquitto, running locally or in the cloud.

### **Features**
- ✅ Relay control via MQTT
- ✅ Motion sensor integration
- ✅ Dynamic scheduling system
- ✅ Real-time notifications
- ✅ Web interface for manual control
- ✅ Authentication support
- ✅ Device identification by MAC address
- ✅ DHCP and fixed IP support

### **Project Requirements**

#### Hardware Requirements:
- ESP-01S (ESP8266) modules
- USB-Serial adapter (CH340, CP2102, FTDI)
- Relay modules (3.3V compatible)
- Motion sensors (PIR)
- Stable 3.3V power supply

#### Software Requirements:
- Arduino IDE with ESP8266 support
- Mosquitto MQTT broker
- Python 3.7+ (for scheduling scripts)
- Required Python packages: `paho-mqtt`, `json`, `datetime`

### **Implementation Order**

1. **Environment Setup** (Arduino IDE + ESP8266 support)
2. **MQTT Broker Installation and Configuration**
3. **ESP-01S Hardware Setup and Programming**
4. **Basic MQTT Communication Testing**
5. **Advanced Features Implementation** (scheduling, authentication)
6. **Python Client Configuration**
7. **System Integration and Testing**

---

## **Step 1: Environment Setup**

### **Arduino IDE and ESP8266 Setup**

1. **Install Arduino IDE:**
   - Download from [arduino.cc](https://www.arduino.cc/en/software)
   - Install and update to latest version

2. **Add ESP8266 Board Package:**
   - Open Arduino IDE
   - Go to **File → Preferences**
   - Add this URL to "Additional Board Manager URLs":
     ```
     http://arduino.esp8266.com/stable/package_esp8266com_index.json
     ```
   - Go to **Tools → Board → Board Manager**
   - Search for "ESP8266" and install "ESP8266 by ESP8266 Community"

3. **Install Required Libraries:**
   - Go to **Sketch → Include Library → Manage Libraries**
   - Install these libraries:
     - `PubSubClient` by Nick O'Leary (for MQTT)
     - `ArduinoJson` by Benoit Blanchon (for JSON handling)
     - `ESP8266WiFi` (usually included with ESP8266 package)

---

## **Step 2: MQTT Broker Installation and Configuration**

### **Installing Mosquitto Broker**

#### **Linux (Ubuntu/Debian)**

1. **Install Mosquitto:**
   ```bash
   sudo apt update
   sudo apt install mosquitto mosquitto-clients
   ```

2. **Start and enable Mosquitto service:**
   ```bash
   sudo systemctl start mosquitto
   sudo systemctl enable mosquitto
   ```

3. **Check service status:**
   ```bash
   sudo systemctl status mosquitto
   ```

#### **macOS**

1. **Install Homebrew** (if not installed):
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

#### **Windows**

1. **Download Mosquitto:**
   - Visit [mosquitto.org/download](https://mosquitto.org/download/)
   - Download the Windows installer

2. **Install Mosquitto:**
   - Run the installer as Administrator
   - Follow installation wizard
   - Add Mosquitto directory to system PATH

3. **Start Mosquitto service:**
   ```cmd
   net start mosquitto
   ```

### **Configuring Mosquitto for Security**

1. **Create configuration file:**
   ```bash
   # Linux/macOS
   sudo nano /etc/mosquitto/mosquitto.conf
   
   # Windows
   # Edit C:\Program Files\mosquitto\mosquitto.conf
   ```

2. **Basic secure configuration:**
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

3. **Create user credentials:**
   ```bash
   # Create password file
   sudo mosquitto_passwd -c /etc/mosquitto/pwfile homeuser
   
   # Add more users
   sudo mosquitto_passwd /etc/mosquitto/pwfile deviceuser
   ```

4. **Create ACL file for topic permissions:**
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
   topic readwrite $SYS/broker/connection/+/state
   ```

5. **Restart Mosquitto:**
   ```bash
   # Linux
   sudo systemctl restart mosquitto
   
   # macOS
   brew services restart mosquitto
   
   # Windows
   net stop mosquitto
   net start mosquitto
   ```

### **Firewall Configuration**

#### **Linux (UFW)**
```bash
sudo ufw allow 1883/tcp
sudo ufw reload
```

#### **macOS**
```bash
# Add rule in System Preferences → Security & Privacy → Firewall
# Or use pfctl (advanced)
```

#### **Windows**
```cmd
netsh advfirewall firewall add rule name="MQTT" dir=in action=allow protocol=TCP localport=1883
```

### **Testing MQTT Connection**

1. **Subscribe to test topic:**
   ```bash
   mosquitto_sub -h localhost -t "test/topic" -u homeuser -P yourpassword
   ```

2. **Publish test message:**
   ```bash
   mosquitto_pub -h localhost -t "test/topic" -m "Hello MQTT" -u homeuser -P yourpassword
   ```

---

## **Step 3: ESP-01S Hardware Setup and Programming**

### **Hardware Connection for Programming**

* Use a **USB-Serial adapter** (CH340, CP2102, FTDI, or USB programmer for ESP-01S).
* Connect the wires:

  * **VCC** → 3.3V
  * **GND** → GND
  * **TX** → RX
  * **RX** → TX
  * **CH\_EN (EN/CH\_PD)** → 3.3V
  * **GPIO0** → GND (only for programming!)

### **Programming Mode**

* Connect **GPIO0 to GND**.
* Power up the module (or plug into USB).
* Select **Generic ESP8266 Module** in Arduino IDE.
* Configure board settings:
  - **Flash Mode:** DOUT
  - **Flash Size:** 1MB (FS:64KB OTA:~470KB)
  - **Reset Method:** nodemcu
  - **Flash Frequency:** 40MHz
  - **CPU Frequency:** 80MHz
* Select the correct **serial port**.
* Compile and **upload** the sketch.
* After upload, remove **GPIO0 from GND** and restart the ESP-01S.

### **Project Usage**

* Install the ESP-01S in the relay circuit, sensor, etc.
* Power the module (stable 3.3V!).
* **CH\_EN must remain at 3.3V** whenever the chip is in use.
* Program for Wi-Fi connection (fixed IP or DHCP) and control (HTTP, MQTT, etc.).

### **Important Safety Tips**

* **Never power with 5V!** ESP-01S operates at 3.3V only
* Use a stable 3.3V power supply (minimum 200mA)
* Double-check connections before powering on
* If connection errors occur, review the programming mode, power source, and connections
* For automation use, prefer MQTT over HTTP for better reliability

---

## **Step 4: Advanced ESP-01S Arduino Code**

The complete advanced Arduino code is available in `/source/esp01/mqtt/homeguard_advanced.ino`. This code includes:

- **DHCP Support:** Automatic IP assignment
- **MAC-based Device ID:** Unique identification without fixed IPs
- **MQTT Authentication:** Secure broker connection
- **Schedule Support:** JSON-based scheduling system
- **Motion Sensor Integration:** PIR sensor support
- **Heartbeat System:** Regular status reporting
- **Device Status Publishing:** Complete device information

### **Key Features of Advanced Code:**

1. **Automatic Device Identification:**
   - Uses MAC address for unique device ID
   - Topics structure: `homeguard/homeguard_abc123/cmnd`

2. **Schedule System:**
   - Accepts JSON schedule commands
   - Stores schedules in EEPROM
   - Format: `{"active":true,"hour":20,"minute":30,"duration":60,"action":true,"days":"1234567"}`

3. **Status Reporting:**
   - Publishes device status including IP, MAC, RSSI
   - Regular heartbeat messages
   - Motion detection events

---

## **Step 5: Python Client for Schedule Management**

### **Python Environment Setup**

1. **Install Python 3.7+:**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install python3 python3-pip python3-venv
   
   # macOS (with Homebrew)
   brew install python3
   
   # Windows: Download from python.org
   ```

2. **Create Virtual Environment:**
   ```bash
   # Create virtual environment
   python3 -m venv homeguard-env
   
   # Activate virtual environment
   # Linux/macOS:
   source homeguard-env/bin/activate
   
   # Windows:
   homeguard-env\Scripts\activate
   ```

3. **Install Required Packages:**
   ```bash
   pip install paho-mqtt python-dateutil pytz
   ```

The complete Python schedule manager is available in `/python/schedule_manager.py`. 

### **Python Client Usage Examples:**

1. **Install Dependencies:**
   ```bash
   cd python
   pip install -r requirements.txt
   ```

2. **Discover Devices:**
   ```bash
   python schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --list-devices
   ```

3. **Create Sample Schedule:**
   ```bash
   python schedule_manager.py --create-sample my_schedule.json
   ```

4. **Send Schedule to Device:**
   ```bash
   python schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --device homeguard_abc123 --schedule examples/evening_lights.json
   ```

5. **Send Direct Commands:**
   ```bash
   # Turn device ON
   python schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --device homeguard_abc123 --command ON
   
   # Turn device OFF
   python schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --device homeguard_abc123 --command OFF
   
   # Get device status
   python schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --device homeguard_abc123 --command STATUS
   ```

6. **Monitor Device Activity:**
   ```bash
   python schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --monitor
   ```

### **Schedule Format:**

```json
{
  "active": true,           // Enable/disable schedule
  "hour": 20,              // Hour (0-23)
  "minute": 30,            // Minute (0-59)
  "duration": 120,         // Duration in minutes
  "action": true,          // true=ON, false=OFF
  "days": "1234567"        // Days: 1=Mon, 2=Tue, ..., 7=Sun
}
```

---

## **Step 6: MQTT Topic Organization and Best Practices**

### **Recommended Topic Structure:**

```
homeguard/
├── {device_id}/
│   ├── cmnd          # Commands to device
│   ├── stat          # Device status
│   ├── schedule      # Schedule commands
│   ├── heartbeat     # Device heartbeat
│   └── motion        # Motion sensor events
└── system/
    ├── discovery     # Device discovery
    └── logs          # System logs
```

### **Device Identification Without Fixed IPs:**

1. **MAC-based IDs:** Each device uses its MAC address to create unique topics
2. **Auto-discovery:** Devices announce themselves via heartbeat messages
3. **Dynamic IP Support:** Devices work with DHCP-assigned IPs
4. **Persistent Configuration:** Schedules stored in device EEPROM

### **Security Best Practices:**

1. **MQTT Authentication:** Always use username/password
2. **Topic ACLs:** Restrict device access to their own topics
3. **TLS Encryption:** Use port 8883 for encrypted communication (advanced)
4. **Firewall Rules:** Limit MQTT access to trusted networks
5. **Regular Updates:** Keep ESP8266 firmware updated

---

## **Step 7: Testing and Troubleshooting**

### **Basic Connection Testing:**

1. **Test MQTT Broker:**
   ```bash
   # Test broker connection
   mosquitto_pub -h localhost -t test/topic -m "Hello" -u homeuser -P yourpassword
   mosquitto_sub -h localhost -t test/topic -u homeuser -P yourpassword
   ```

2. **Test ESP-01S Connection:**
   - Check serial monitor for connection messages
   - Verify WiFi connection and IP assignment
   - Monitor MQTT connection status

3. **Test Device Discovery:**
   ```bash
   python schedule_manager.py --broker YOUR_BROKER_IP --username homeuser --password yourpassword --list-devices
   ```

### **Common Issues and Solutions:**

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **MQTT Connection Refused** | ESP can't connect to broker | Check broker IP, credentials, firewall |
| **WiFi Connection Failed** | ESP can't connect to WiFi | Verify SSID/password, signal strength |
| **Authentication Failed** | MQTT auth errors | Check username/password, ACL permissions |
| **Device Not Discovered** | Python client can't find device | Check topic structure, heartbeat messages |
| **Schedule Not Working** | Device ignores schedules | Verify JSON format, device clock sync |
| **Relay Not Responding** | Commands don't control relay | Check wiring, pin configuration |

### **Debug Commands:**

```bash
# Monitor all HomeGuard traffic
mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/+/+" -u homeuser -P yourpassword

# Monitor specific device
mosquitto_sub -h YOUR_BROKER_IP -t "homeguard/homeguard_abc123/+" -u homeuser -P yourpassword

# Send test command
mosquitto_pub -h YOUR_BROKER_IP -t "homeguard/homeguard_abc123/cmnd" -m "STATUS" -u homeuser -P yourpassword
```

### **Performance Optimization:**

1. **Heartbeat Interval:** Adjust based on network conditions (default: 30s)
2. **MQTT QoS:** Use QoS 1 for important commands
3. **WiFi Power Management:** Disable for stable connection
4. **Message Retention:** Use retained messages for device status

---

## **Step 8: Advanced Features**

### **Integration with Home Assistant:**

Add to `configuration.yaml`:
```yaml
mqtt:
  broker: YOUR_BROKER_IP
  username: homeuser
  password: yourpassword

switch:
  - platform: mqtt
    name: "HomeGuard Relay 1"
    state_topic: "homeguard/homeguard_abc123/stat"
    command_topic: "homeguard/homeguard_abc123/cmnd"
    payload_on: "ON"
    payload_off: "OFF"
    state_on: "ON"
    state_off: "OFF"
    value_template: "{{ value_json.relay }}"

binary_sensor:
  - platform: mqtt
    name: "HomeGuard Motion 1"
    state_topic: "homeguard/homeguard_abc123/motion"
    payload_on: "DETECTED"
    payload_off: "CLEAR"
```

### **Cloud Integration:**

For cloud MQTT brokers (AWS IoT, Google Cloud IoT):
1. Configure TLS certificates
2. Update broker endpoint
3. Modify authentication method
4. Adjust topic permissions

---

## **Project Structure**

```
HomeGuard/
├── README.md                    # This documentation
├── source/
│   ├── esp01/
│   │   ├── mqtt/
│   │   │   ├── mqtt.ino        # Basic MQTT example
│   │   │   ├── homeguard_advanced.ino  # Advanced features
│   │   │   └── README.md       # MQTT documentation
│   │   └── web/
│   │       └── web.ino         # Web interface example
│   └── README.md
├── python/
│   ├── schedule_manager.py     # Python client
│   ├── requirements.txt        # Python dependencies
│   └── examples/               # Schedule examples
│       ├── evening_lights.json
│       ├── morning_weekdays.json
│       └── security_off.json
└── docs/                       # Additional documentation
```

---

## **Changelog**

### Version 2.0 (Current)
- ✅ Complete MQTT broker setup with authentication
- ✅ Advanced ESP-01S code with DHCP support
- ✅ MAC-based device identification
- ✅ Python schedule manager client
- ✅ Comprehensive troubleshooting guide
- ✅ Security best practices
- ✅ Home Assistant integration examples

### Version 1.0 (Previous)
- ✅ Basic ESP-01S programming guide
- ✅ Simple MQTT and web examples
- ✅ Hardware connection instructions

---

## **Summary Flow**

---

## **Summary Flow**

1. **Environment Setup:** Install Arduino IDE and ESP8266 support
2. **MQTT Broker Setup:** Install and configure Mosquitto with authentication
3. **ESP-01S Programming:** Upload advanced code with DHCP and MAC-based ID
4. **Python Environment:** Setup virtual environment and install dependencies
5. **Device Discovery:** Use Python client to discover and test devices
6. **Schedule Configuration:** Create and deploy schedules to devices
7. **System Integration:** Integrate with home automation systems
8. **Monitoring and Maintenance:** Monitor device health and troubleshoot issues

## **Quick Start Guide**

For a rapid deployment:

1. **Setup Broker:**
   ```bash
   # Ubuntu/Debian
   sudo apt install mosquitto mosquitto-clients
   sudo systemctl start mosquitto
   ```

2. **Program ESP-01S:**
   - Upload `homeguard_advanced.ino`
   - Configure WiFi credentials
   - Set broker IP address

3. **Test Connection:**
   ```bash
   cd python
   python schedule_manager.py --broker YOUR_BROKER_IP --list-devices
   ```

4. **Send First Schedule:**
   ```bash
   python schedule_manager.py --broker YOUR_BROKER_IP --device DEVICE_ID --schedule examples/evening_lights.json
   ```

## **Support and Contributing**

- **Issues:** Report bugs and feature requests
- **Documentation:** Help improve this guide
- **Code:** Contribute ESP8266 and Python improvements
- **Testing:** Test on different hardware configurations

## **References**

- [ESP-01 functional features, pin configuration, applications and relationship with ESP-01s and ESP8266](https://www.ariat-tech.com/blog/esp-01-functional-features,pin-configuration,applications-and-relationship-with-esp-01s-and-esp8266.html)
- [Mosquitto MQTT Broker Documentation](https://mosquitto.org/documentation/)
- [ESP8266 Arduino Core Documentation](https://arduino-esp8266.readthedocs.io/)
- [PubSubClient Library Documentation](https://pubsubclient.knolleary.net/)
- [MQTT Protocol Specification](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html)
- [Home Assistant MQTT Integration](https://www.home-assistant.io/integrations/mqtt/)



