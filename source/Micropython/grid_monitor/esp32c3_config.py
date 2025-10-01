# Configurações otimizadas para ESP32-C3 Grid Monitor
# Adicionar ao início do main_fixed.py se necessário

"""
CONFIGURAÇÕES ESPECÍFICAS ESP32-C3
==================================

Estas configurações foram ajustadas especificamente para o ESP32-C3
para evitar o erro Interrupt WDT timeout.
"""

# Configurações de hardware ESP32-C3 Super Mini
ESP32_C3_CONFIG = {
    # Pinos específicos do ESP32-C3 Super Mini
    'ZMPT_PIN': 0,      # ADC0 (GPIO0) - Entrada analógica
    'RELAY_PIN': 5,     # GPIO5 - Saída digital para relé
    'LED_PIN': 8,       # GPIO8 - LED onboard (se disponível)
    
    # Configurações ADC otimizadas
    'ADC_ATTENUATION': 3,  # machine.ADC.ATTN_11DB = 3 (0-3.3V range)
    'ADC_SAMPLES': 8,      # Reduzido para evitar blocking
    'SAMPLE_DELAY_MS': 25, # Delay entre amostras
    
    # Timing para evitar WDT timeout
    'WIFI_TIMEOUT': 25,        # Timeout WiFi reduzido
    'MAIN_LOOP_DELAY': 2.5,    # Loop principal mais lento
    'HEARTBEAT_INTERVAL': 300, # Status a cada 5 minutos
    'WDT_FEED_INTERVAL': 5,    # Feed watchdog a cada 5 loops
    
    # Thresholds de energia
    'GRID_THRESHOLD': 2700,    # Ajustar conforme ZMPT101B
    'GRID_THRESHOLD_LOW': 2500, # Threshold baixo para hysteresis
    
    # Configurações de memória
    'GC_COLLECT_INTERVAL': 30, # Garbage collection a cada 30 loops
    'MIN_FREE_MEMORY': 10000,  # Memória mínima livre (bytes)
}

# Função para aplicar configurações
def apply_esp32c3_config():
    """
    Aplica configurações otimizadas para ESP32-C3
    Chame esta função no início do main()
    """
    import machine
    import esp32
    
    # Configurar frequência da CPU (opcional)
    try:
        # Reduzir frequência pode ajudar com estabilidade
        # machine.freq(160000000)  # 160MHz (padrão é 240MHz)
        print('CPU freq:', machine.freq())
    except:
        pass
    
    # Configurar watchdog se disponível
    try:
        # ESP32-C3 tem watchdog interno
        # Não é necessário configurar manualmente no MicroPython
        pass
    except:
        pass
    
    return ESP32_C3_CONFIG

# Função para debug de hardware
def debug_hardware_info():
    """
    Mostra informações de debug do hardware
    """
    import machine
    import esp32
    import gc
    
    print("=== DEBUG HARDWARE ESP32-C3 ===")
    print(f"CPU Freq: {machine.freq()} Hz")
    print(f"Free Memory: {gc.mem_free()} bytes")
    print(f"Hall Sensor: {esp32.hall_sensor()}")
    
    try:
        temp = esp32.raw_temperature()
        print(f"Temperature: {temp}")
    except:
        print("Temperature: N/A")
    
    # Teste dos pinos
    config = ESP32_C3_CONFIG
    try:
        test_pin = machine.Pin(config['RELAY_PIN'], machine.Pin.OUT)
        test_pin.value(1)
        test_pin.value(0)
        print(f"Relay Pin {config['RELAY_PIN']}: OK")
    except Exception as e:
        print(f"Relay Pin {config['RELAY_PIN']}: ERROR - {e}")
    
    try:
        test_adc = machine.ADC(machine.Pin(config['ZMPT_PIN']))
        test_adc.atten(config['ADC_ATTENUATION'])
        reading = test_adc.read()
        print(f"ADC Pin {config['ZMPT_PIN']}: {reading}")
    except Exception as e:
        print(f"ADC Pin {config['ZMPT_PIN']}: ERROR - {e}")
    
    print("==============================")

# Função de watchdog manual
def feed_watchdog():
    """
    Feed manual do watchdog
    Chame periodicamente no loop principal
    """
    import machine
    machine.idle()  # Yield para o watchdog

# Verificação de memória
def check_memory_health():
    """
    Verifica saúde da memória e força garbage collection se necessário
    """
    import gc
    
    free_mem = gc.mem_free()
    if free_mem < ESP32_C3_CONFIG['MIN_FREE_MEMORY']:
        print(f"Low memory detected: {free_mem} bytes")
        gc.collect()
        new_free_mem = gc.mem_free()
        print(f"After GC: {new_free_mem} bytes")
        return new_free_mem
    
    return free_mem

# Exemplo de uso no main_fixed.py:
"""
# No início da função main():
config = apply_esp32c3_config()
debug_hardware_info()

# No loop principal:
loop_count = 0
while True:
    # ... resto do código ...
    
    # Feed watchdog periodicamente
    if loop_count % config['WDT_FEED_INTERVAL'] == 0:
        feed_watchdog()
    
    # Garbage collection periódico
    if loop_count % config['GC_COLLECT_INTERVAL'] == 0:
        check_memory_health()
    
    loop_count += 1
"""