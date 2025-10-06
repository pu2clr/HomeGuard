"""
Teste Rápido de Módulos - ESP32-C3
Verificar se DHT e MQTT estão disponíveis antes de executar main.py
"""

print("🔍 VERIFICANDO MÓDULOS ESP32-C3...")
print("=" * 40)

# Teste 1: Módulo DHT
print("📍 Testando módulo DHT...")
try:
    import dht
    import machine
    
    # Testar criação de sensor
    test_pin = machine.Pin(0)
    dht11_sensor = dht.DHT11(test_pin)
    dht22_sensor = dht.DHT22(test_pin)
    
    print("✅ DHT11/DHT22: Disponível (nativo)")
    dht_ok = True
except ImportError:
    print("❌ DHT: Módulo não encontrado")
    print("💡 Solução: import upip; upip.install('micropython-dht')")
    dht_ok = False
except Exception as e:
    print(f"⚠️ DHT: Erro inesperado: {e}")
    dht_ok = False

# Teste 2: Módulo MQTT
print("\n📍 Testando módulo MQTT...")
try:
    from umqtt.simple import MQTTClient
    
    # Testar criação de cliente
    test_client = MQTTClient("test", "localhost")
    
    print("✅ MQTT: Disponível (umqtt.simple)")
    mqtt_ok = True
except ImportError:
    print("❌ MQTT: Módulo não encontrado")
    print("💡 Solução: import upip; upip.install('micropython-umqtt.simple')")
    mqtt_ok = False
except Exception as e:
    print(f"⚠️ MQTT: Erro inesperado: {e}")
    mqtt_ok = False

# Teste 3: Módulos básicos
print("\n📍 Testando módulos básicos...")
modules_basic = ['machine', 'network', 'time', 'json']
basic_ok = True

for module in modules_basic:
    try:
        exec(f"import {module}")
        print(f"✅ {module}: OK")
    except ImportError:
        print(f"❌ {module}: Não encontrado")
        basic_ok = False

# Teste 4: GPIO e Pin
print("\n📍 Testando GPIO...")
try:
    import machine
    pin0 = machine.Pin(0, machine.Pin.OUT)
    pin1 = machine.Pin(1, machine.Pin.IN)
    pin5 = machine.Pin(5, machine.Pin.OUT)
    pin8 = machine.Pin(8, machine.Pin.OUT)
    print("✅ GPIO: Pinos 0,1,5,8 configurados")
    gpio_ok = True
except Exception as e:
    print(f"❌ GPIO: Erro: {e}")
    gpio_ok = False

# Resumo final
print("\n" + "=" * 40)
print("📋 RESUMO DA VERIFICAÇÃO:")
print(f"DHT11/DHT22: {'✅ OK' if dht_ok else '❌ FALHA'}")
print(f"MQTT:        {'✅ OK' if mqtt_ok else '❌ FALHA'}")
print(f"Básicos:     {'✅ OK' if basic_ok else '❌ FALHA'}")
print(f"GPIO:        {'✅ OK' if gpio_ok else '❌ FALHA'}")

if all([dht_ok, mqtt_ok, basic_ok, gpio_ok]):
    print("\n🎉 TODOS OS MÓDULOS OK! Pronto para executar main.py")
else:
    print("\n⚠️ ALGUNS MÓDULOS FALTANDO. Instale antes de continuar:")
    if not dht_ok:
        print("   import upip; upip.install('micropython-dht')")
    if not mqtt_ok:
        print("   import upip; upip.install('micropython-umqtt.simple')")

print("=" * 40)