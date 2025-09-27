
# Grid Monitor with ESP32-C3 and MicroPython

This project implements a power grid monitor using ESP32-C3 and MicroPython. It controls a relay, monitors the grid via an analog sensor (e.g., ZMPT101B), and publishes events via MQTT.

## Folder Structure

```
Micropython/
└── grid_monitor/
    └── main.py   # Main script for ESP32-C3
```

## Installing MicroPython on ESP32-C3

### 1. Download MicroPython firmware
- Go to: https://micropython.org/download/esp32c3/
- Download the latest `.bin` file for ESP32-C3.

### 2. Install the firmware
#### Linux/macOS:
```bash
pip install esptool
esptool.py --chip esp32c3 erase_flash
esptool.py --chip esp32c3 --baud 460800 write_flash -z 0x0 <firmware.bin>
```
#### Windows:
- Install Python and esptool via `pip install esptool`
- Use the command prompt with the commands above.

### 3. Using Thonny IDE
- Download from https://thonny.org/
- Open Thonny, select "MicroPython (ESP32)" as the interpreter.
- Connect ESP32-C3 via USB, select the correct port.
- Upload the `main.py` file from the `grid_monitor` folder to ESP32-C3.


## MQTT Module: micropython-umqtt.simple-1.3.4

This project requires the MQTT communication module `micropython-umqtt.simple-1.3.4` for ESP32-C3. This module is a MicroPython library for MQTT protocol, allowing the device to publish and subscribe to topics on an MQTT broker.

**Origin:**
- Official repository: https://github.com/micropython/micropython-lib/tree/master/micropython/umqtt.simple
- Version used: 1.3.4 (folder: `micropython-umqtt.simple-1.3.4`)

**Why is it needed?**
- The default MicroPython firmware for ESP32-C3 does not include MQTT libraries.
- This module enables reliable MQTT communication for automation and monitoring.

**How to add the module to ESP32-C3:**

### Using Thonny IDE
1. Open Thonny and connect your ESP32-C3.
2. In Thonny, go to the Files panel.
3. Right-click the folder `micropython-umqtt.simple-1.3.4` and select "Upload to /" (or drag and drop to the device).
4. Ensure the folder is present on the ESP32-C3 filesystem.
5. In your `main.py`, import as:
   ```python
   from micropython_umqtt_simple import MQTTClient
   ```

### Using Shell (Linux/macOS)
Assuming your ESP32-C3 is mounted as a USB device or accessible via ampy:
```bash
ampy --port /dev/ttyUSB0 put micropython-umqtt.simple-1.3.4
```
Or use rshell:
```bash
rshell
cp -r micropython-umqtt.simple-1.3.4 /pyboard/
```
Replace `/dev/ttyUSB0` and `/pyboard/` with your actual device path.

**Note:**
- The module folder must be in the root or accessible path for imports.
- If you rename the main file to `umqtt_simple.py`, import as:
   ```python
   from umqtt_simple import MQTTClient
   ```

If you have issues, check that the folder and files are present on the ESP32-C3 and the import path is correct.



## Pin Configuration
- Adjust the pins at the beginning of `main.py` according to your Super Mini model.
- ZMPT_PIN: ADC0 (GPIO0)
- RELAY_PIN: GPIO7
- LED_PIN: GPIO8


## Usage
- The monitor connects to WiFi, listens for MQTT commands, and publishes status.
- Supported commands: ON, OFF, AUTO, STATUS
- The relay is triggered automatically in case of power failure or manually via MQTT.


## Supported Operating Systems
- Linux, Windows, macOS (for firmware upload and Thonny usage)


## Tips
- Check the ESP32-C3 Super Mini documentation to correctly map the pins.
- Test the ZMPT101B sensor and adjust the GRID_THRESHOLD according to your grid.
- The file must be named `main.py` for automatic execution on ESP32-C3.


## ADC Resolution Note
- **Important:** The ADC resolution varies by platform:
    - ESP8266: 10 bits (0-1023)
    - ESP32-C3: 12 bits (0-4095)
- You must adjust the threshold (GRID_THRESHOLD) and logic according to the platform and sensor used. Always calibrate for your hardware.
