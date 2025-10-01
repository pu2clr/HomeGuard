"""
Micropython Grid Monitor para ESP32-C3 - VERSÃO CORRIGIDA
- Monitora rede elétrica via sensor analógico (ex: ZMPT101B)
- Aciona relé para ligar/desligar lâmpada
- Publica eventos via MQTT
- Correções para evitar Interrupt WDT timeout

CORREÇÕES IMPLEMENTADAS:
1. Timeout na conexão WiFi
2. Watchdog reset no loop principal
3. Tratamento de exceções MQTT
4. Delays adequados para evitar blocking
5. Otimização da leitura ADC
6. Reconexão automática MQTT/WiFi

Examples of MQTT commands to control the device:

mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/#" -v
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "OFF"
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "ON"
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "AUTO"
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "STATUS"
"""

import machine
import time
import network
import gc
from umqtt.simple import MQTTClient

# Configurações de rede WiFi
WIFI_SSID = 'Homeguard'
WIFI_PASS = 'pu2clr123456'
WIFI_TIMEOUT = 30  # Timeout em segundos

# Configurações do MQTT
MQTT_SERVER = '192.168.1.102'
MQTT_PORT = 1883
MQTT_USER = 'homeguard'
MQTT_PASS = 'pu2clr123456'
DEVICE_ID = 'GRID_MONITOR_C3B'

TOPIC_STATUS = b'home/grid/GRID_MONITOR_C3B/status'
TOPIC_COMMAND = b'home/grid/GRID_MONITOR_C3B/command'

# Pinos do ESP32-C3
ZMPT_PIN = 0      # ADC0 (GPIO0)
RELAY_PIN = 5     # GPIO5
LED_PIN = 8       # GPIO8 (LED onboard)

# Configurações do sensor ZMPT101B (com hysteresis para estabilidade)
GRID_THRESHOLD_HIGH = 2750  # Threshold para detectar rede ON
GRID_THRESHOLD_LOW = 2650   # Threshold para detectar rede OFF
GRID_THRESHOLD = 2700       # Threshold padrão (compatibilidade)
MIN_STABLE_READINGS = 3     # Leituras consecutivas para mudança de estado

# Configurações de timing
HEARTBEAT_INTERVAL = 300  # 5 minutos
ADC_SAMPLES = 20         # Aumentado para 20 amostras (melhor estabilidade)
SAMPLE_DELAY = 20        # Mantido em 20ms para estabilidade
MAIN_LOOP_DELAY = 2      # Aumentado de 1s para 2s
OUTLIERS_TO_REMOVE = 4   # Remove 2 maiores e 2 menores valores

# Variáveis globais
count = 1
adc = None
relay = None
led = None
grid_online = False
relay_manual_override = False
relay_manual_state = False
client = None
last_heartbeat = 0
last_grid_online = None
wifi_connected = False
mqtt_connected = False

# Variáveis para controle de estabilidade
stable_readings_count = 0
pending_grid_state = None
last_voltage_readings = []  # Histórico das últimas leituras

# Inicializar hardware
def init_hardware():
    global adc, relay, led
    try:
        adc = machine.ADC(machine.Pin(ZMPT_PIN))
        adc.atten(machine.ADC.ATTN_11DB)  # Faixa completa 0-3.3V
        relay = machine.Pin(RELAY_PIN, machine.Pin.OUT)
        led = machine.Pin(LED_PIN, machine.Pin.OUT)
        
        # Test inicial do relé
        relay.value(1)
        time.sleep(0.5)
        relay.value(0)
        
        print('Hardware inicializado com sucesso')
        return True
    except Exception as e:
        print('Erro ao inicializar hardware:', e)
        return False

# Conectar ao WiFi com timeout
def connect_wifi():
    global wifi_connected
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    if wlan.isconnected():
        wifi_connected = True
        return True
    
    print('Conectando ao WiFi...')
    wlan.connect(WIFI_SSID, WIFI_PASS)
    
    # Timeout para evitar loop infinito
    start_time = time.time()
    while not wlan.isconnected():
        if time.time() - start_time > WIFI_TIMEOUT:
            print('Timeout na conexão WiFi')
            wifi_connected = False
            return False
        time.sleep(1)
        machine.idle()  # Yield para o watchdog
    
    wifi_connected = True
    print('WiFi conectado:', wlan.ifconfig())
    return True

# Callback para comandos MQTT
def mqtt_callback(topic, msg):
    global relay_manual_override, relay_manual_state, client
    try:
        cmd = msg.decode().strip().upper()
        print('Comando MQTT recebido:', cmd)
        
        if cmd == 'ON':
            relay_manual_override = True
            relay_manual_state = True
            relay.value(1)
            print('Relay: ON (manual)')
        elif cmd == 'OFF':
            relay_manual_override = True
            relay_manual_state = False
            relay.value(0)
            print('Relay: OFF (manual)')
        elif cmd == 'AUTO':
            relay_manual_override = False
            print('Relay: AUTO mode')
        elif cmd == 'STATUS':
            publish_status(client)
        elif cmd == 'RESTART':
            print('Reiniciando por comando MQTT...')
            time.sleep(1)
            machine.reset()
            
    except Exception as e:
        print('Erro no callback MQTT:', e)

# Conectar ao MQTT
def connect_mqtt():
    global client, mqtt_connected
    try:
        if not wifi_connected:
            return False
            
        client = MQTTClient(DEVICE_ID, MQTT_SERVER, port=MQTT_PORT, 
                           user=MQTT_USER, password=MQTT_PASS)
        client.set_callback(mqtt_callback)
        client.connect()
        client.subscribe(TOPIC_COMMAND)
        mqtt_connected = True
        print('MQTT conectado e inscrito em', TOPIC_COMMAND.decode())
        return True
    except Exception as e:
        print('Erro na conexão MQTT:', e)
        mqtt_connected = False
        return False

# Publicar status via MQTT
def publish_status(client, force=False):
    global last_heartbeat
    try:
        if not mqtt_connected:
            return False
            
        current_time = time.time()
        
        # Heartbeat a cada HEARTBEAT_INTERVAL segundos ou forçado
        if force or (current_time - last_heartbeat) >= HEARTBEAT_INTERVAL:
            status = '{"device_id":"%s","grid_status":"%s","relay":"%s","uptime":%d,"free_memory":%d,"adc_raw":%d}' % (
                DEVICE_ID,
                'online' if grid_online else 'offline',
                'on' if relay.value() else 'off',
                current_time,
                gc.mem_free(),
                adc.read() if adc else 0
            )
            client.publish(TOPIC_STATUS, status)
            last_heartbeat = current_time
            print('Status publicado:', status)
            return True
    except Exception as e:
        print('Erro ao publicar status:', e)
        return False

# Leitura otimizada do ADC com filtro de média
def read_grid_voltage():
    global adc
    try:
        readings = []
        
        # Coletar amostras
        for i in range(ADC_SAMPLES):
            val = adc.read()
            readings.append(val)
            time.sleep_ms(SAMPLE_DELAY)
            
            # Yield para o watchdog a cada 5 amostras
            if i % 5 == 0:
                machine.idle()
        
        # Aplicar filtro: remover outliers e calcular média
        if len(readings) >= OUTLIERS_TO_REMOVE:
            # Ordenar leituras
            readings.sort()
            
            # Remover 2 menores e 2 maiores valores
            outliers_half = OUTLIERS_TO_REMOVE // 2
            filtered_readings = readings[outliers_half:-outliers_half]
            
            # Calcular média dos valores filtrados
            if filtered_readings:
                average_val = sum(filtered_readings) // len(filtered_readings)
                print(f'ADC: min={readings[0]}, max={readings[-1]}, avg_filtered={average_val}')
                return average_val
            else:
                # Fallback para média simples se filtro falhar
                return sum(readings) // len(readings)
        else:
            # Muito poucas amostras, usar média simples
            return sum(readings) // len(readings)
            
    except Exception as e:
        print('Erro na leitura ADC:', e)
        return 0

# Verificar e reconectar conexões
def check_connections():
    global wifi_connected, mqtt_connected, client
    
    # Verificar WiFi
    wlan = network.WLAN(network.STA_IF)
    if not wlan.isconnected():
        wifi_connected = False
        mqtt_connected = False
        print('WiFi desconectado, tentando reconectar...')
        if not connect_wifi():
            return False
    
    # Verificar MQTT
    if wifi_connected and not mqtt_connected:
        print('MQTT desconectado, tentando reconectar...')
        connect_mqtt()
    
    return wifi_connected and mqtt_connected

# Loop principal
def main():
    global grid_online, client, count, last_grid_online
    
    print('Inicializando Grid Monitor ESP32-C3...')
    
    # Inicializar hardware
    if not init_hardware():
        print('Falha na inicialização do hardware!')
        return
    
    # Conectar WiFi
    if not connect_wifi():
        print('Falha na conexão WiFi!')
        return
    
    # Conectar MQTT
    if not connect_mqtt():
        print('Falha na conexão MQTT!')
        return
    
    print('Sistema inicializado com sucesso!')
    
    # Publicar status inicial
    publish_status(client, force=True)
    
    # Loop principal
    while True:
        try:
            # Reset do watchdog
            machine.idle()
            
            # Verificar mensagens MQTT
            if mqtt_connected:
                client.check_msg()
            
            # Verificar conexões
            check_connections()
            
            # Leitura da tensão da rede com filtro de estabilidade
            voltage_reading = read_grid_voltage()
            
            # Manter histórico das últimas leituras
            last_voltage_readings.append(voltage_reading)
            if len(last_voltage_readings) > 10:
                last_voltage_readings.pop(0)
            
            # Aplicar hysteresis para evitar oscilação
            if grid_online:
                # Se estava ON, só muda para OFF se ficar abaixo do threshold baixo
                new_state = voltage_reading > GRID_THRESHOLD_LOW
            else:
                # Se estava OFF, só muda para ON se ficar acima do threshold alto
                new_state = voltage_reading > GRID_THRESHOLD_HIGH
            
            # Verificar estabilidade da mudança de estado
            if pending_grid_state != new_state:
                pending_grid_state = new_state
                stable_readings_count = 1
            else:
                stable_readings_count += 1
            
            # Só muda o estado após leituras consecutivas estáveis
            if stable_readings_count >= MIN_STABLE_READINGS:
                if grid_online != new_state:
                    grid_online = new_state
                    print(f'*** MUDANÇA DE ESTADO: Grid {"ON" if grid_online else "OFF"} (tensão: {voltage_reading}) ***')
            
            # Log detalhado
            avg_voltage = sum(last_voltage_readings) // len(last_voltage_readings) if last_voltage_readings else voltage_reading
            print(f'Leitura {count}: {voltage_reading} (avg: {avg_voltage}) - Grid: {"ON" if grid_online else "OFF"} (stable: {stable_readings_count}/{MIN_STABLE_READINGS})')
            count += 1
            
            # Controle do relé
            if relay_manual_override:
                relay.value(1 if relay_manual_state else 0)
            else:
                # Liga relé quando NÃO há energia (invertido)
                relay.value(0 if grid_online else 1)
            
            # LED status (invertido também)
            led.value(0 if grid_online else 1)
            
            # Publicar status se houver mudança ou heartbeat
            if last_grid_online is None or last_grid_online != grid_online:
                publish_status(client, force=True)
                last_grid_online = grid_online
            else:
                publish_status(client, force=False)
            
            # Garbage collection periódico
            if count % 50 == 0:
                gc.collect()
                print('Memória livre:', gc.mem_free())
            
            # Delay do loop principal
            time.sleep(MAIN_LOOP_DELAY)
            
        except KeyboardInterrupt:
            print('Interrompido pelo usuário')
            break
        except Exception as e:
            print('Erro no loop principal:', e)
            time.sleep(5)  # Pausa maior em caso de erro
            # Tentar reconectar
            check_connections()

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print('Erro fatal:', e)
        print('Reiniciando em 10 segundos...')
        time.sleep(10)
        machine.reset()