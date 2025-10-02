"""
Micropython Grid Monitor for Raspberry Pi Pico
- Monitors power grid using analog sensor (e.g., ZMPT101B)
- Controls relay to turn light ON/OFF
- Publishes events via MQTT

Adapted for Raspberry Pi Pico (WiFi via Pico W)
"""

import machine
import time
import network
from umqtt.simple import MQTTClient

# WiFi configuration
WIFI_SSID = 'Homeguard'
WIFI_PASS = 'pu2clr123456'

# MQTT configuration
MQTT_SERVER = '192.168.1.102'
MQTT_PORT = 1883
MQTT_USER = 'homeguard'
MQTT_PASS = 'pu2clr123456'
DEVICE_ID = 'GRID_MONITOR_PICO'

TOPIC_STATUS = b'home/grid/GRID_MONITOR_PICO/status'
TOPIC_COMMAND = b'home/grid/GRID_MONITOR_PICO/command'

# Pin configuration for Raspberry Pi Pico (adjust as needed)
ZMPT_PIN = 26      # ADC0 (GP26)
RELAY_PIN = 15     # GP15 (adjust to your relay circuit)
LED_PIN = 25       # Onboard LED (GP25)
GRID_THRESHOLD = 2800  # Adjust for your sensor and 12-bit ADC (0-4095)

count = 1

adc = machine.ADC(ZMPT_PIN)
relay = machine.Pin(RELAY_PIN, machine.Pin.OUT)
led = machine.Pin(LED_PIN, machine.Pin.OUT)

grid_online = False
relay_manual_override = False
relay_manual_state = False
client = None  # Global MQTTClient object

# Connect to WiFi (Pico W)
def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    if not wlan.isconnected():
        print('Connecting to WiFi...')
        wlan.connect(WIFI_SSID, WIFI_PASS)
        while not wlan.isconnected():
            time.sleep(0.5)
    print('WiFi connected:', wlan.ifconfig())

# MQTT command callback
def mqtt_callback(topic, msg):
    global relay_manual_override, relay_manual_state, client
    cmd = msg.decode().strip().upper()
    if cmd == 'ON':
        relay_manual_override = True
        relay_manual_state = True
        relay.value(1)
    elif cmd == 'OFF':
        relay_manual_override = True
        relay_manual_state = False
        relay.value(0)
    elif cmd == 'AUTO':
        relay_manual_override = False
    elif cmd == 'STATUS':
        publish_status(client)

# Publish status via MQTT
def publish_status(client):
    status = '{"device_id":"%s","grid_status":"%s","relay":"%s"}' % (
        DEVICE_ID,
        'online' if grid_online else 'offline',
        'on' if relay.value() else 'off')
    client.publish(TOPIC_STATUS, status)

# Main loop
def main():
    global grid_online, client, count
    connect_wifi()
    client = MQTTClient(DEVICE_ID, MQTT_SERVER, port=MQTT_PORT, user=MQTT_USER, password=MQTT_PASS)
    client.set_callback(mqtt_callback)
    client.connect()
    client.subscribe(TOPIC_COMMAND)
    relay.value(1)
    time.sleep(2)
    relay.value(0)
    last_grid_online = None
    while True:
        client.check_msg()
        # Multiple readings for robustness
        max_val = 0
        for _ in range(20):
            val = adc.read_u16() >> 4  # Convert 16-bit to 12-bit (0-4095)
            if val > max_val:
                max_val = val
            time.sleep_ms(20)
        grid_online = max_val > GRID_THRESHOLD
        print('Reading', count, ':', max_val)
        count += 1
        # Relay control
        if relay_manual_override:
            relay.value(1 if relay_manual_state else 0)
        else:
            relay.value(0 if grid_online else 1)
        # LED status
        led.value(0 if grid_online else 1)
        # Publish status if changed
        if last_grid_online is None or last_grid_online != grid_online:
            publish_status(client)
            last_grid_online = grid_online
        time.sleep(1)

if __name__ == '__main__':
    main()
