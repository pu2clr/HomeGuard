# HomeGuard MQTT Broker - Quick Reference
**Raspberry Pi 4 Broker IP: 192.168.18.236**

## 🚀 Quick Setup on Raspberry Pi

```bash
# 1. Copy and run the setup script
wget https://raw.githubusercontent.com/your-repo/HomeGuard/main/scripts/setup-mqtt-broker.sh
chmod +x setup-mqtt-broker.sh
./setup-mqtt-broker.sh

# 2. Or manual setup from project directory
scp scripts/setup-mqtt-broker.sh pi@192.168.18.236:~/
ssh pi@192.168.18.236
./setup-mqtt-broker.sh
```

## 🔐 User Accounts

| User | Password | Access Level |
|------|----------|--------------|
| `admin` | *set during setup* | Full access to all topics |
| `homeguard` | `pu2clr123456` | Device topics (home/*) |
| `homeassistant` | `homeassistant123` | Home automation integration |
| `automation` | `automation123` | Scripts and automation |

## 📡 Quick Test Commands

### Basic Connection Test
```bash
# Test authentication
mosquitto_pub -h 192.168.18.236 -t test/hello -m "Hello World" -u homeguard -P pu2clr123456

# Subscribe to test
mosquitto_sub -h 192.168.18.236 -t test/hello -u homeguard -P pu2clr123456
```

### HomeGuard Device Commands
```bash
# Monitor all HomeGuard devices
mosquitto_sub -h 192.168.18.236 -t "home/#" -u homeguard -P pu2clr123456 -v

# Relay control
mosquitto_pub -h 192.168.18.236 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456
mosquitto_pub -h 192.168.18.236 -t home/relay1/cmnd -m "OFF" -u homeguard -P pu2clr123456

# Motion sensor status
mosquitto_pub -h 192.168.18.236 -t home/motion1/cmnd -m "STATUS" -u homeguard -P pu2clr123456
```

### System Monitoring (Admin)
```bash
# Connected clients
mosquitto_sub -h 192.168.18.236 -t '$SYS/broker/clients/connected' -u admin -P [admin_password]

# Broker uptime
mosquitto_sub -h 192.168.18.236 -t '$SYS/broker/uptime' -u admin -P [admin_password]

# All system topics
mosquitto_sub -h 192.168.18.236 -t '$SYS/#' -u admin -P [admin_password] -v
```

## 🔧 Service Management

```bash
# Service control
sudo systemctl start mosquitto
sudo systemctl stop mosquitto
sudo systemctl restart mosquitto
sudo systemctl status mosquitto

# View logs
sudo tail -f /var/log/mosquitto/mosquitto.log

# Monitor health
sudo tail -f /var/log/mosquitto/monitor.log
```

## 🛠️ Configuration Files

| File | Purpose |
|------|---------|
| `/etc/mosquitto/mosquitto.conf` | Main configuration |
| `/etc/mosquitto/passwd/passwords` | User passwords |
| `/etc/mosquitto/conf.d/acl.conf` | Access control |
| `/var/log/mosquitto/mosquitto.log` | Main log |
| `/var/log/mosquitto/monitor.log` | Health monitoring |

## 🔄 Update ESP-01S Devices

### 1. Update Arduino Sketches
Change in all `.ino` files:
```cpp
// OLD
const char* mqtt_server = "192.168.18.6";

// NEW  
const char* mqtt_server = "192.168.18.236";
```

### 2. Update Python Scripts
Change in all `.py` files:
```python
# OLD
def __init__(self, broker_host="192.168.18.6", ...):

# NEW
def __init__(self, broker_host="192.168.18.236", ...):
```

### 3. Automatic Update Script
```bash
# Run from project root
./scripts/update-broker-ip.sh
```

## 🧪 Validation

```bash
# Run comprehensive test suite
./scripts/validate-mqtt-broker.sh

# Manual ping test
ping 192.168.18.236

# Port connectivity
nc -z 192.168.18.236 1883
```

## 🔒 Security Features

- ✅ **Authentication required** - No anonymous access
- ✅ **Access Control Lists** - Topic-based permissions
- ✅ **User isolation** - Each user has specific access
- ✅ **Network filtering** - Firewall rules for local network only
- ✅ **Logging** - All connections and messages logged
- ✅ **Monitoring** - Automated health checks
- ✅ **Backup** - Daily configuration backups

## 🏠 HomeGuard Topic Structure

```
home/
├── relay1/
│   ├── cmnd          # Commands: ON, OFF, STATUS, TOGGLE
│   ├── stat          # Status: ON, OFF (basic relay)
│   ├── status        # JSON status (advanced relay)
│   ├── relay         # Relay events (advanced)
│   ├── heartbeat     # Device heartbeat
│   └── config        # Configuration confirmations
└── motion1/
    ├── cmnd          # Commands: STATUS, RESET, SENSITIVITY_*, etc.
    ├── status        # Device status (JSON)
    ├── motion        # Motion events (JSON)
    ├── heartbeat     # Device heartbeat
    └── config        # Configuration confirmations
```

## 🐛 Troubleshooting

### Service Issues
```bash
# Check service status
sudo systemctl status mosquitto

# Check configuration
sudo mosquitto -c /etc/mosquitto/mosquitto.conf -t

# Restart with verbose logging
sudo mosquitto -c /etc/mosquitto/mosquitto.conf -v
```

### Connection Issues
```bash
# Test from broker machine
mosquitto_pub -h localhost -t test -m test -u homeguard -P pu2clr123456

# Check firewall
sudo ufw status

# Check listening ports
sudo netstat -tlnp | grep mosquitto
```

### Permission Issues
```bash
# Fix ownership
sudo chown -R mosquitto:mosquitto /var/lib/mosquitto/
sudo chown -R mosquitto:mosquitto /var/log/mosquitto/

# Recreate password file
sudo mosquitto_passwd -c /etc/mosquitto/passwd/passwords homeguard
```

## 📞 Quick Support Commands

```bash
# System info
uname -a
mosquitto version

# Service status
sudo systemctl is-active mosquitto
sudo systemctl is-enabled mosquitto

# Network status
ip addr show
ss -tlnp | grep 1883

# Log analysis
sudo journalctl -u mosquitto -f
sudo tail -20 /var/log/mosquitto/mosquitto.log
```
