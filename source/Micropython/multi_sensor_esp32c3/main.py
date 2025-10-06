"""
MicroPython Multi-Sensor Monitor para ESP32-C3
- Sensor de movimento IR (PIR)
- Controle de relé via comandos MQTT (ON/OFF)
- Monitoramento de temperatura/umidade com DHT11/DHT22
- Integrado ao sistema HomeGuard via MQTT

Hardware necessário:
- ESP32-C3 Super Mini
- Sensor PIR/IR de movimento
- Módulo DHT11 ou DHT22
- Módulo relé 3.3V
- LED de status (opcional)

Conexões:
- GPIO0: DHT11/DHT22 (com pull-up 10kΩ)
- GPIO1: Sensor PIR/IR (digital)
- GPIO5: Controle do relé
- GPIO8: LED de status
- GPIO10: Reserva para expansão

Examples of MQTT commands to control the device:

# Monitorar todos os dados:
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/#" -v

# Comandos de controle do relé:
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/relay/command" -m "ON"
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/relay/command" -m "OFF"

# Solicitar leitura imediata dos sensores:
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/command" -m "READ"

# Solicitar status do dispositivo:
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/command" -m "STATUS"

"""

import machine
import time
import network
import dht
import json
from umqtt.simple import MQTTClient

# ===== CONFIGURAÇÕES DE REDE WiFi =====
WIFI_SSID = 'Homeguard'
WIFI_PASS = 'pu2clr123456'
WIFI_TIMEOUT = 30  # Timeout em segundos

# ===== CONFIGURAÇÕES DO MQTT =====
MQTT_SERVER = '192.168.1.102'
MQTT_PORT = 1883
MQTT_USER = 'homeguard'
MQTT_PASS = 'pu2clr123456'
DEVICE_ID = 'MULTI_SENSOR_C3A'

# ===== TÓPICOS MQTT =====
TOPIC_BASE = f'home/multisensor/{DEVICE_ID}'
TOPIC_STATUS = f'{TOPIC_BASE}/status'
TOPIC_COMMAND = f'{TOPIC_BASE}/command'
TOPIC_TEMPERATURE = f'{TOPIC_BASE}/temperature'
TOPIC_HUMIDITY = f'{TOPIC_BASE}/humidity'
TOPIC_MOTION = f'{TOPIC_BASE}/motion'
TOPIC_RELAY_STATUS = f'{TOPIC_BASE}/relay/status'
TOPIC_RELAY_COMMAND = f'{TOPIC_BASE}/relay/command'
TOPIC_HEARTBEAT = f'{TOPIC_BASE}/heartbeat'
TOPIC_INFO = f'{TOPIC_BASE}/info'

# ===== CONFIGURAÇÃO DE PINOS DO ESP32-C3 =====
DHT_PIN = 0         # GPIO0 - DHT11/DHT22
PIR_PIN = 1         # GPIO1 - Sensor PIR/IR
RELAY_PIN = 5       # GPIO5 - Controle do relé
LED_PIN = 8         # GPIO8 - LED de status
EXPANSION_PIN = 10  # GPIO10 - Reserva para expansão

# ===== CONFIGURAÇÕES DOS SENSORES =====
DHT_TYPE = dht.DHT11    # Altere para dht.DHT22 se usar DHT22
MOTION_DEBOUNCE = 200   # ms - debounce do sensor PIR
MOTION_TIMEOUT = 30000  # ms - timeout para movimento
TEMP_THRESHOLD = 0.5    # °C - mudança mínima para enviar
HUMID_THRESHOLD = 2.0   # % - mudança mínima para enviar

# ===== INTERVALOS DE TEMPO =====
SENSOR_READ_INTERVAL = 5000    # 5 segundos - leitura dos sensores
DATA_SEND_INTERVAL = 60000     # 60 segundos - envio forçado de dados
HEARTBEAT_INTERVAL = 300000    # 5 minutos - heartbeat
MOTION_CHECK_INTERVAL = 100    # 100ms - verificação de movimento

# ===== VARIÁVEIS GLOBAIS =====
# Conectividade
wifi_connected = False
mqtt_connected = False
client = None

# Estado dos sensores
last_temperature = None
last_humidity = None
last_motion_time = 0
motion_detected = False
motion_start_time = 0
relay_state = False

# Timing
last_sensor_read = 0
last_data_send = 0
last_heartbeat = 0
last_motion_check = 0
boot_time = time.ticks_ms()

# Contadores
sensor_read_count = 0
motion_event_count = 0
relay_toggle_count = 0

# ===== CONFIGURAÇÃO DE HARDWARE =====
dht_sensor = dht.DHT11(machine.Pin(DHT_PIN)) if DHT_TYPE == dht.DHT11 else dht.DHT22(machine.Pin(DHT_PIN))
pir_sensor = machine.Pin(PIR_PIN, machine.Pin.IN)
relay_pin = machine.Pin(RELAY_PIN, machine.Pin.OUT)
led_pin = machine.Pin(LED_PIN, machine.Pin.OUT)

# Estado inicial
relay_pin.value(0)  # Relé desligado
led_pin.value(1)    # LED desligado (lógica invertida)

def get_timestamp():
    """Retorna timestamp em milissegundos desde o boot"""
    return time.ticks_ms()

def get_uptime():
    """Retorna uptime em segundos"""
    return time.ticks_diff(time.ticks_ms(), boot_time) // 1000

def blink_led(times=1, delay_ms=100):
    """Pisca o LED indicando atividade"""
    for _ in range(times):
        led_pin.value(0)  # Liga
        time.sleep_ms(delay_ms)
        led_pin.value(1)  # Desliga
        time.sleep_ms(delay_ms)

def connect_wifi():
    """Conecta ao WiFi"""
    global wifi_connected
    
    print('Conectando ao WiFi...')
    sta_if = network.WLAN(network.STA_IF)
    sta_if.active(True)
    sta_if.connect(WIFI_SSID, WIFI_PASS)
    
    start_time = time.ticks_ms()
    while not sta_if.isconnected() and time.ticks_diff(time.ticks_ms(), start_time) < WIFI_TIMEOUT * 1000:
        blink_led(1, 200)
        time.sleep_ms(500)
    
    if sta_if.isconnected():
        wifi_connected = True
        led_pin.value(0)  # LED ligado indicando WiFi conectado
        print('WiFi conectado!')
        print('IP:', sta_if.ifconfig()[0])
        return True
    else:
        wifi_connected = False
        print('Falha na conexão WiFi')
        return False

def mqtt_callback(topic, msg):
    """Callback para mensagens MQTT recebidas"""
    global relay_state, relay_toggle_count
    
    try:
        topic_str = topic.decode()
        message = msg.decode().strip().upper()
        
        print(f'MQTT recebido: {topic_str} = {message}')
        
        # Comandos do relé
        if topic_str == TOPIC_RELAY_COMMAND:
            if message == 'ON':
                relay_state = True
                relay_pin.value(1)
                relay_toggle_count += 1
                publish_relay_status()
                blink_led(2, 100)
                print('Relé LIGADO')
            elif message == 'OFF':
                relay_state = False
                relay_pin.value(0)
                relay_toggle_count += 1
                publish_relay_status()
                blink_led(3, 100)
                print('Relé DESLIGADO')
        
        # Comandos gerais
        elif topic_str == TOPIC_COMMAND:
            if message == 'READ':
                read_and_publish_sensors(force=True)
                blink_led(1, 50)
            elif message == 'STATUS':
                publish_status()
                blink_led(1, 50)
            elif message == 'INFO':
                publish_device_info()
                blink_led(1, 50)
                
    except Exception as e:
        print(f'Erro no callback MQTT: {e}')

def connect_mqtt():
    """Conecta ao MQTT"""
    global client, mqtt_connected
    
    try:
        if not wifi_connected:
            return False
            
        print('Conectando ao MQTT...')
        client = MQTTClient(DEVICE_ID, MQTT_SERVER, port=MQTT_PORT, 
                           user=MQTT_USER, password=MQTT_PASS)
        client.set_callback(mqtt_callback)
        client.connect()
        
        # Subscrever aos tópicos de comando
        client.subscribe(TOPIC_COMMAND.encode())
        client.subscribe(TOPIC_RELAY_COMMAND.encode())
        
        mqtt_connected = True
        print('MQTT conectado!')
        print(f'Subscrito a: {TOPIC_COMMAND}')
        print(f'Subscrito a: {TOPIC_RELAY_COMMAND}')
        
        # Publicar status inicial
        publish_status()
        publish_device_info()
        
        return True
        
    except Exception as e:
        print(f'Erro na conexão MQTT: {e}')
        mqtt_connected = False
        return False

def publish_mqtt(topic, payload, retain=False):
    """Publica mensagem MQTT com tratamento de erro"""
    try:
        if mqtt_connected and client:
            if isinstance(payload, dict):
                payload = json.dumps(payload)
            client.publish(topic.encode(), payload, retain=retain)
            return True
    except Exception as e:
        print(f'Erro ao publicar MQTT: {e}')
        return False
    return False

def read_temperature_humidity():
    """Lê temperatura e umidade do DHT"""
    global last_temperature, last_humidity, sensor_read_count
    
    try:
        dht_sensor.measure()
        temperature = dht_sensor.temperature()
        humidity = dht_sensor.humidity()
        
        sensor_read_count += 1
        
        if temperature is not None and humidity is not None:
            # Verificar se houve mudança significativa
            temp_changed = (last_temperature is None or 
                          abs(temperature - last_temperature) >= TEMP_THRESHOLD)
            humid_changed = (last_humidity is None or 
                           abs(humidity - last_humidity) >= HUMID_THRESHOLD)
            
            if temp_changed or humid_changed:
                last_temperature = temperature
                last_humidity = humidity
                
                return {
                    'temperature': temperature,
                    'humidity': humidity,
                    'changed': True
                }
            else:
                return {
                    'temperature': temperature,
                    'humidity': humidity,
                    'changed': False
                }
        else:
            print('Erro na leitura do DHT')
            return None
            
    except Exception as e:
        print(f'Erro ao ler DHT: {e}')
        return None

def check_motion():
    """Verifica sensor de movimento PIR"""
    global motion_detected, motion_start_time, last_motion_time, motion_event_count
    
    try:
        current_motion = pir_sensor.value()
        current_time = time.ticks_ms()
        
        # Movimento detectado (borda de subida)
        if current_motion and not motion_detected:
            motion_detected = True
            motion_start_time = current_time
            last_motion_time = current_time
            motion_event_count += 1
            
            motion_data = {
                'device_id': DEVICE_ID,
                'event': 'MOTION_DETECTED',
                'timestamp': get_timestamp(),
                'uptime': get_uptime(),
                'motion_count': motion_event_count
            }
            
            publish_mqtt(TOPIC_MOTION, motion_data)
            blink_led(1, 50)
            print('MOVIMENTO DETECTADO!')
            
        # Movimento parou (timeout)
        elif motion_detected and not current_motion:
            if time.ticks_diff(current_time, motion_start_time) >= MOTION_TIMEOUT:
                motion_detected = False
                duration = time.ticks_diff(current_time, motion_start_time) // 1000
                
                motion_data = {
                    'device_id': DEVICE_ID,
                    'event': 'MOTION_CLEARED',
                    'timestamp': get_timestamp(),
                    'duration_seconds': duration,
                    'uptime': get_uptime()
                }
                
                publish_mqtt(TOPIC_MOTION, motion_data)
                print(f'MOVIMENTO FINALIZADO (duração: {duration}s)')
        
        return current_motion
        
    except Exception as e:
        print(f'Erro ao ler sensor PIR: {e}')
        return False

def publish_temperature_humidity(temp_data, force=False):
    """Publica dados de temperatura e umidade"""
    if temp_data and (temp_data['changed'] or force):
        timestamp = get_timestamp()
        uptime = get_uptime()
        
        # Publicar temperatura
        temp_payload = {
            'device_id': DEVICE_ID,
            'sensor_type': 'DHT11' if DHT_TYPE == dht.DHT11 else 'DHT22',
            'temperature': temp_data['temperature'],
            'unit': '°C',
            'timestamp': timestamp,
            'uptime': uptime,
            'reading_count': sensor_read_count
        }
        publish_mqtt(TOPIC_TEMPERATURE, temp_payload, retain=True)
        
        # Publicar umidade
        humid_payload = {
            'device_id': DEVICE_ID,
            'sensor_type': 'DHT11' if DHT_TYPE == dht.DHT11 else 'DHT22',
            'humidity': temp_data['humidity'],
            'unit': '%',
            'timestamp': timestamp,
            'uptime': uptime,
            'reading_count': sensor_read_count
        }
        publish_mqtt(TOPIC_HUMIDITY, humid_payload, retain=True)
        
        print(f'Temp: {temp_data["temperature"]}°C, Humid: {temp_data["humidity"]}%')

def publish_relay_status():
    """Publica status do relé"""
    status_data = {
        'device_id': DEVICE_ID,
        'relay_state': 'ON' if relay_state else 'OFF',
        'timestamp': get_timestamp(),
        'uptime': get_uptime(),
        'toggle_count': relay_toggle_count
    }
    publish_mqtt(TOPIC_RELAY_STATUS, status_data, retain=True)

def publish_status():
    """Publica status geral do dispositivo"""
    status_data = {
        'device_id': DEVICE_ID,
        'status': 'online',
        'wifi_connected': wifi_connected,
        'mqtt_connected': mqtt_connected,
        'timestamp': get_timestamp(),
        'uptime': get_uptime(),
        'sensors': {
            'dht_ok': last_temperature is not None,
            'pir_ok': True,
            'relay_ok': True
        },
        'current_values': {
            'temperature': last_temperature,
            'humidity': last_humidity,
            'motion': motion_detected,
            'relay': 'ON' if relay_state else 'OFF'
        }
    }
    publish_mqtt(TOPIC_STATUS, status_data, retain=True)

def publish_device_info():
    """Publica informações do dispositivo"""
    info_data = {
        'device_id': DEVICE_ID,
        'device_name': 'Multi-Sensor Monitor',
        'location': 'ESP32-C3 Multi-Sensor',
        'hardware': 'ESP32-C3 Super Mini',
        'sensors': [
            'DHT11/DHT22 (Temperature/Humidity)',
            'PIR/IR (Motion Detection)',
            'Relay Control'
        ],
        'version': '1.0.0',
        'uptime': get_uptime(),
        'counters': {
            'sensor_reads': sensor_read_count,
            'motion_events': motion_event_count,
            'relay_toggles': relay_toggle_count
        },
        'gpio_mapping': {
            'dht': DHT_PIN,
            'pir': PIR_PIN,
            'relay': RELAY_PIN,
            'led': LED_PIN
        }
    }
    publish_mqtt(TOPIC_INFO, info_data)

def publish_heartbeat():
    """Publica heartbeat periódico"""
    heartbeat_data = {
        'device_id': DEVICE_ID,
        'timestamp': get_timestamp(),
        'uptime': get_uptime(),
        'status': 'alive',
        'memory_free': 0,  # MicroPython específico se disponível
        'wifi_rssi': 0     # Se disponível
    }
    publish_mqtt(TOPIC_HEARTBEAT, heartbeat_data)

def read_and_publish_sensors(force=False):
    """Lê todos os sensores e publica dados"""
    global last_sensor_read, last_data_send
    
    current_time = time.ticks_ms()
    
    # Verificar se é hora de ler os sensores
    if not force and time.ticks_diff(current_time, last_sensor_read) < SENSOR_READ_INTERVAL:
        return
    
    last_sensor_read = current_time
    
    # Ler DHT
    temp_data = read_temperature_humidity()
    
    # Verificar se deve enviar dados (por mudança ou forçado)
    should_send = (force or 
                   time.ticks_diff(current_time, last_data_send) >= DATA_SEND_INTERVAL or
                   (temp_data and temp_data['changed']))
    
    if should_send:
        publish_temperature_humidity(temp_data, force=True)
        last_data_send = current_time

def check_connectivity():
    """Verifica e reconecta WiFi e MQTT se necessário"""
    global wifi_connected, mqtt_connected
    
    # Verificar WiFi
    sta_if = network.WLAN(network.STA_IF)
    if not sta_if.isconnected():
        wifi_connected = False
        mqtt_connected = False
        print('WiFi desconectado, tentando reconectar...')
        if connect_wifi():
            connect_mqtt()
    
    # Verificar MQTT
    elif wifi_connected and not mqtt_connected:
        print('MQTT desconectado, tentando reconectar...')
        connect_mqtt()

def main_loop():
    """Loop principal do programa"""
    global last_motion_check, last_heartbeat
    
    while True:
        try:
            current_time = time.ticks_ms()
            
            # Verificar conectividade
            check_connectivity()
            
            # Processar mensagens MQTT
            if mqtt_connected and client:
                try:
                    client.check_msg()
                except:
                    pass
            
            # Verificar movimento
            if time.ticks_diff(current_time, last_motion_check) >= MOTION_CHECK_INTERVAL:
                check_motion()
                last_motion_check = current_time
            
            # Ler e publicar sensores
            read_and_publish_sensors()
            
            # Publicar heartbeat
            if time.ticks_diff(current_time, last_heartbeat) >= HEARTBEAT_INTERVAL:
                if mqtt_connected:
                    publish_heartbeat()
                last_heartbeat = current_time
            
            # Pequeno delay para estabilidade
            time.sleep_ms(50)
            
        except KeyboardInterrupt:
            print('\nInterrompido pelo usuário')
            break
        except Exception as e:
            print(f'Erro no loop principal: {e}')
            time.sleep(1)

def main():
    """Função principal"""
    print('=== ESP32-C3 Multi-Sensor Monitor ===')
    print(f'Device ID: {DEVICE_ID}')
    print(f'DHT Type: {"DHT11" if DHT_TYPE == dht.DHT11 else "DHT22"}')
    print(f'GPIO - DHT: {DHT_PIN}, PIR: {PIR_PIN}, Relay: {RELAY_PIN}, LED: {LED_PIN}')
    print('='*40)
    
    # Aguardar estabilização
    print('Aguardando estabilização dos sensores...')
    for i in range(3, 0, -1):
        print(f'Iniciando em {i}...')
        blink_led(1, 100)
        time.sleep(1)
    
    # Conectar WiFi
    if not connect_wifi():
        print('Falha na conexão WiFi! Reiniciando...')
        machine.reset()
    
    # Conectar MQTT
    if not connect_mqtt():
        print('Falha na conexão MQTT! Continuando sem MQTT...')
    
    print('Sistema iniciado! Monitorando sensores...')
    
    # Iniciar loop principal
    main_loop()

if __name__ == '__main__':
    main()