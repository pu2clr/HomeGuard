#!/usr/bin/env python3
"""
Script de debug para verificar condições de envio do DHT11
Envia comandos MQTT para forçar leitura e debug
"""

import json
import time
import paho.mqtt.client as mqtt

# MQTT Configuration
MQTT_BROKER = "192.168.1.37"
MQTT_PORT = 1883
MQTT_USERNAME = "home_user" 
MQTT_PASSWORD = "Pega9018"

# Device configuration
DEVICE_ID = "ESP01_DHT11_001"
COMMAND_TOPIC = f"home/sensor/{DEVICE_ID}/command"
STATUS_TOPIC = f"home/sensor/{DEVICE_ID}/status"
DATA_TOPIC = f"home/sensor/{DEVICE_ID}/data"

def on_connect(client, userdata, flags, rc):
    print(f"🔌 Conectado ao MQTT broker: {rc}")
    if rc == 0:
        # Subscribe to all topics for this device
        topics = [STATUS_TOPIC, DATA_TOPIC, f"home/sensor/{DEVICE_ID}/+"]
        for topic in topics:
            client.subscribe(topic)
            print(f"📡 Inscrito: {topic}")

def on_message(client, userdata, msg):
    timestamp = time.strftime("%H:%M:%S")
    topic = msg.topic
    payload = msg.payload.decode()
    
    print(f"\n📨 [{timestamp}] {topic}")
    print(f"   📄 {payload}")
    
    try:
        json_data = json.loads(payload)
        print(f"   📊 JSON parsed:")
        for key, value in json_data.items():
            print(f"      • {key}: {value}")
    except:
        pass
    print("-" * 40)

def send_command(client, command):
    print(f"📤 Enviando comando: {command}")
    result = client.publish(COMMAND_TOPIC, command)
    if result.rc == 0:
        print(f"✅ Comando enviado com sucesso")
    else:
        print(f"❌ Falha ao enviar comando: {result.rc}")
    time.sleep(2)

def main():
    print("🔧 Debug DHT11 - Testador de Comandos MQTT")
    print(f"🌐 Broker: {MQTT_BROKER}:{MQTT_PORT}")
    print(f"📍 Device: {DEVICE_ID}")
    print("=" * 50)
    
    client = mqtt.Client()
    client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
        
        time.sleep(2)  # Wait for connection
        
        print("\n🚀 Iniciando sequência de testes...")
        
        # Test 1: Status request
        print("\n1️⃣ Testando comando STATUS...")
        send_command(client, "STATUS")
        
        # Test 2: Force sensor read
        print("\n2️⃣ Testando comando READ...")
        send_command(client, "READ")
        
        # Test 3: Force data send (if implemented)
        print("\n3️⃣ Testando comando SEND_DATA...")
        send_command(client, "SEND_DATA")
        
        # Test 4: Force update (if implemented)
        print("\n4️⃣ Testando comando FORCE_UPDATE...")
        send_command(client, "FORCE_UPDATE")
        
        print("\n👂 Escutando respostas... (Ctrl+C para parar)")
        
        # Keep listening for responses
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\n\n🛑 Teste interrompido pelo usuário")
        
    except Exception as e:
        print(f"❌ Erro: {e}")
        
    finally:
        client.loop_stop()
        client.disconnect()
        print("🔌 Desconectado")

if __name__ == "__main__":
    main()
