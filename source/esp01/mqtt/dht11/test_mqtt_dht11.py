#!/usr/bin/env python3
"""
Script de teste para monitorar dados MQTT do sensor DHT11
"""

import json
import time
import paho.mqtt.client as mqtt
from datetime import datetime

# MQTT Configuration
MQTT_BROKER = "192.168.18.236"
MQTT_PORT = 1883
MQTT_USERNAME = "homeguard" 
MQTT_PASSWORD = "pu2clr123456"

# Topics to monitor
TOPICS = [
    "home/sensor/ESP01_DHT11_001/status",
    "home/sensor/ESP01_DHT11_001/data",
    "home/sensor/+/+",  # Wildcard para capturar qualquer tópico de sensor
    "home/sensor/ESP01_DHT11_001/+"  # Wildcard para capturar qualquer subtópico
]

received_messages = []

def on_connect(client, userdata, flags, rc):
    print(f"🔌 Conectado ao MQTT broker com resultado: {rc}")
    if rc == 0:
        print("✅ Conexão bem-sucedida!")
        for topic in TOPICS:
            client.subscribe(topic)
            print(f"📡 Inscrito no tópico: {topic}")
    else:
        print(f"❌ Falha na conexão: {rc}")

def on_message(client, userdata, msg):
    timestamp = datetime.now().strftime("%H:%M:%S")
    topic = msg.topic
    payload = msg.payload.decode()
    
    print(f"\n📨 [{timestamp}] Mensagem recebida:")
    print(f"   🏷️  Tópico: {topic}")
    print(f"   📄 Payload: {payload}")
    
    # Try to parse JSON
    try:
        json_data = json.loads(payload)
        print(f"   📊 JSON parsed:")
        for key, value in json_data.items():
            print(f"      • {key}: {value}")
    except json.JSONDecodeError:
        print(f"   📝 Texto simples: {payload}")
    
    # Store message
    received_messages.append({
        'timestamp': timestamp,
        'topic': topic,
        'payload': payload
    })
    
    print("-" * 50)

def on_disconnect(client, userdata, rc):
    print(f"🔌 Desconectado do MQTT broker: {rc}")

def main():
    print("🚀 Iniciando monitor MQTT para DHT11...")
    print(f"🌐 Broker: {MQTT_BROKER}:{MQTT_PORT}")
    print(f"👤 Usuário: {MQTT_USERNAME}")
    print("\n" + "="*60)
    
    # Create MQTT client
    client = mqtt.Client()
    client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    
    # Set callbacks
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect
    
    try:
        # Connect to broker
        print(f"🔗 Conectando ao broker MQTT...")
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        
        # Start the loop
        client.loop_start()
        
        print("👂 Escutando mensagens MQTT... (Ctrl+C para parar)")
        
        # Keep running
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\n\n🛑 Interrompido pelo usuário")
        
    except Exception as e:
        print(f"❌ Erro: {e}")
        
    finally:
        print("🔌 Desconectando...")
        client.loop_stop()
        client.disconnect()
        
        # Summary
        print(f"\n📈 Resumo da sessão:")
        print(f"   📊 Total de mensagens recebidas: {len(received_messages)}")
        
        # Group by topic
        topics_count = {}
        for msg in received_messages:
            topic = msg['topic']
            topics_count[topic] = topics_count.get(topic, 0) + 1
            
        print(f"   📂 Por tópico:")
        for topic, count in topics_count.items():
            print(f"      • {topic}: {count} mensagens")

if __name__ == "__main__":
    main()
