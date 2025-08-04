# HomeGuard Python Client

Python tools for managing HomeGuard ESP-01S devices via MQTT.

## Features

- **Device Discovery:** Automatically find HomeGuard devices on the network
- **Schedule Management:** Create and deploy time-based automation schedules
- **Direct Control:** Send immediate commands to devices
- **Real-time Monitoring:** Monitor device status and activity
- **JSON Configuration:** Flexible schedule format with examples

## Installation

1. **Create Virtual Environment:**
   ```bash
   python3 -m venv homeguard-env
   source homeguard-env/bin/activate  # Linux/macOS
   # or
   homeguard-env\Scripts\activate     # Windows
   ```

2. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## Quick Start

1. **Discover Devices:**
   ```bash
   python schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --list-devices
   ```

2. **Create Sample Schedule:**
   ```bash
   python schedule_manager.py --create-sample my_schedule.json
   ```

3. **Send Schedule:**
   ```bash
   python schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --device homeguard_abc123 --schedule my_schedule.json
   ```

## Command Reference

### Device Discovery
```bash
python schedule_manager.py --broker BROKER_IP --username USER --password PASS --list-devices
```

### Direct Commands
```bash
# Turn device ON
python schedule_manager.py --broker BROKER_IP --username USER --password PASS --device DEVICE_ID --command ON

# Turn device OFF
python schedule_manager.py --broker BROKER_IP --username USER --password PASS --device DEVICE_ID --command OFF

# Get device status
python schedule_manager.py --broker BROKER_IP --username USER --password PASS --device DEVICE_ID --command STATUS

# Restart device
python schedule_manager.py --broker BROKER_IP --username USER --password PASS --device DEVICE_ID --command RESTART
```

### Schedule Management
```bash
# Send schedule from file
python schedule_manager.py --broker BROKER_IP --username USER --password PASS --device DEVICE_ID --schedule schedule.json

# Create sample schedule file
python schedule_manager.py --create-sample my_schedule.json
```

### Monitoring
```bash
# Monitor all device activity
python schedule_manager.py --broker BROKER_IP --username USER --password PASS --monitor
```

## Schedule Format

### Basic Schedule Structure
```json
{
  "active": true,           // Enable/disable this schedule
  "hour": 20,              // Hour in 24-hour format (0-23)
  "minute": 30,            // Minute (0-59)
  "duration": 120,         // Duration in minutes (0 = instant action)
  "action": true,          // true = turn ON, false = turn OFF
  "days": "1234567"        // Days of week: 1=Monday, 7=Sunday
}
```

### Schedule Examples

#### Evening Lights (Daily)
```json
{
  "active": true,
  "hour": 20,
  "minute": 30,
  "duration": 120,
  "action": true,
  "days": "1234567",
  "description": "Turn on lights every day at 8:30 PM for 2 hours"
}
```

#### Weekday Morning Routine
```json
{
  "active": true,
  "hour": 6,
  "minute": 0,
  "duration": 30,
  "action": true,
  "days": "12345",
  "description": "Morning routine - weekdays only"
}
```

#### Security Night Mode
```json
{
  "active": true,
  "hour": 23,
  "minute": 0,
  "duration": 0,
  "action": false,
  "days": "1234567",
  "description": "Turn off all devices at 11 PM"
}
```

### Days Field Format
- `"1234567"` - Monday through Sunday
- `"12345"` - Weekdays only
- `"67"` - Weekends only
- `"1"` - Mondays only
- `"0"` - One-time execution (not implemented in current version)

## Examples Directory

The `examples/` directory contains ready-to-use schedule files:

- `evening_lights.json` - Daily evening lighting
- `morning_weekdays.json` - Weekday morning routine
- `security_off.json` - Nightly security shutdown

## Advanced Usage

### Python API

You can also use the schedule manager as a Python module:

```python
from schedule_manager import HomeGuardScheduleManager

# Initialize
manager = HomeGuardScheduleManager(
    broker_host="192.168.1.100",
    username="homeuser",
    password="yourpassword"
)

# Connect
manager.connect()

# Discover devices
devices = manager.discover_devices(timeout=10)

# Send command
manager.send_command("homeguard_abc123", "ON")

# Send schedule
schedule = {
    "active": True,
    "hour": 20,
    "minute": 30,
    "duration": 60,
    "action": True,
    "days": "1234567"
}
manager.send_schedule("homeguard_abc123", schedule)

# Disconnect
manager.disconnect()
```

### Batch Operations

Create a script to manage multiple devices:

```python
import json
from schedule_manager import HomeGuardScheduleManager

# Load configuration
with open('config.json', 'r') as f:
    config = json.load(f)

manager = HomeGuardScheduleManager(**config['broker'])
manager.connect()

# Apply schedule to all devices
devices = manager.discover_devices()
for device_id in devices:
    manager.send_schedule(device_id, config['schedule'])
```

## Troubleshooting

### Connection Issues
1. **Verify broker IP and credentials**
2. **Check firewall settings**
3. **Ensure MQTT broker is running**

### Device Not Found
1. **Check device is powered and connected**
2. **Verify device is publishing heartbeat messages**
3. **Check MQTT topic structure**

### Schedule Not Working
1. **Verify JSON format is correct**
2. **Check device has received schedule (monitor MQTT traffic)**
3. **Ensure device clock is synchronized (limitation: ESP-01S has no RTC)**

### Debug Mode

Enable verbose logging:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

Or use mosquitto clients to monitor traffic:

```bash
# Monitor all HomeGuard traffic
mosquitto_sub -h BROKER_IP -t "homeguard/+/+" -v -u USER -P PASS
```

## Requirements

- Python 3.7+
- paho-mqtt >= 1.6.0
- python-dateutil >= 2.8.0
- pytz >= 2021.1

## Integration Examples

### Cron-like Scheduling
```bash
# Add to system crontab for automated schedule deployment
0 9 * * * /path/to/homeguard-env/bin/python /path/to/schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --device homeguard_abc123 --schedule morning_routine.json
```

### Home Assistant Integration
```yaml
# configuration.yaml
shell_command:
  homeguard_lights_on: "python3 /config/homeguard/schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --device homeguard_abc123 --command ON"
  homeguard_lights_off: "python3 /config/homeguard/schedule_manager.py --broker 192.168.1.100 --username homeuser --password yourpassword --device homeguard_abc123 --command OFF"
```

## Contributing

1. **Test new features** with different ESP-01S configurations
2. **Add new schedule formats** for specific use cases
3. **Improve error handling** and user feedback
4. **Add integration examples** for other home automation platforms

## Next Steps

1. **Implement NTP time synchronization** for accurate scheduling
2. **Add recurring schedule patterns** (every N days, specific dates)
3. **Create web interface** for easier schedule management
4. **Add device grouping** for managing multiple devices as one unit
