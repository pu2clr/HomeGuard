"""
Micropython Grid Monitor para ESP32-C3
- Monitora rede elétrica via sensor analógico (ex: ZMPT101B)
- Aciona relé para ligar/desligar lâmpada
- Publica eventos via MQTT
"""

import machine
import time
import network
from umqtt.simple import MQTTClient

# Configurações de rede WiFi
WIFI_SSID = 'Homeguard'
WIFI_PASS = 'pu2clr123456'

# Configurações do MQTT
MQTT_SERVER = '192.168.1.102'
MQTT_PORT = 1883
MQTT_USER = 'homeguard'
MQTT_PASS = 'pu2clr123456'
DEVICE_ID = 'GRID_MONITOR_C3'

TOPIC_STATUS = b'home/grid/GRID_MONITOR_C3/status'
TOPIC_COMMAND = b'home/grid/GRID_MONITOR_C3/command'

# Pinos do ESP32-C3 (ajuste conforme seu modelo)
ZMPT_PIN = 0      # ADC0 (GPIO0)
RELAY_PIN = 7     # GPIO7 (verifique no seu Super Mini)
LED_PIN = 8       # GPIO8 (LED onboard, se existir)
GRID_THRESHOLD = 950  # Ajuste conforme seu sensor

adc = machine.ADC(machine.Pin(ZMPT_PIN))
adc.atten(machine.ADC.ATTN_11DB)  # Faixa completa 0-3.3V
relay = machine.Pin(RELAY_PIN, machine.Pin.OUT)
led = machine.Pin(LED_PIN, machine.Pin.OUT)

grid_online = False
relay_manual_override = False
relay_manual_state = False
client = None  # Variável global para o objeto MQTTClient

# Conectar ao WiFi
def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    if not wlan.isconnected():
        print('Conectando ao WiFi...')
        wlan.connect(WIFI_SSID, WIFI_PASS)
        while not wlan.isconnected():
            time.sleep(0.5)
    print('WiFi conectado:', wlan.ifconfig())

# Callback para comandos MQTT
def mqtt_callback(topic, msg):
    global relay_manual_override, relay_manual_state, client
    cmd = msg.decode().strip().upper()
    print('Comando MQTT recebido:', cmd)
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

# Publicar status via MQTT
def publish_status(client):
    status = '{"device_id":"%s","grid_status":"%s","relay":"%s"}' % (
        DEVICE_ID,
        'online' if grid_online else 'offline',
        'on' if relay.value() else 'off')
    client.publish(TOPIC_STATUS, status)
    print('Status publicado:', status)

# Loop principal
def main():
    global grid_online, client
    connect_wifi()
    client = MQTTClient(DEVICE_ID, MQTT_SERVER, port=MQTT_PORT, user=MQTT_USER, password=MQTT_PASS)
    client.set_callback(mqtt_callback)
    client.connect()
    client.subscribe(TOPIC_COMMAND)
    print('MQTT conectado e inscrito em', TOPIC_COMMAND)
    last_grid_online = None
    while True:
        client.check_msg()
        # Múltiplas leituras para robustez
        max_val = 0
        for _ in range(20):
            val = adc.read()
            if val > max_val:
                max_val = val
            time.sleep_ms(2)
        grid_online = max_val > GRID_THRESHOLD
        # Controle do relé
        if relay_manual_override:
            relay.value(1 if relay_manual_state else 0)
        else:
            relay.value(0 if grid_online else 1)  # Liga relé se falta energia
        # LED status
        led.value(0 if grid_online else 1)
        # Publica status se houver mudança
        if last_grid_online is None or last_grid_online != grid_online:
            publish_status(client)
            last_grid_online = grid_online
        time.sleep(1)

if __name__ == '__main__':
    main()
