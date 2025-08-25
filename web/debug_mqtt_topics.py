#!/usr/bin/env python3

"""
Debug MQTT - Identificar origem de mensagens formato antigo
Monitora todos os tópicos e identifica quem está enviando formato antigo
"""

import paho.mqtt.client as mqtt
import json
import time
from datetime import datetime

# Configurações
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_USERNAME = 'homeguard'
MQTT_PASSWORD = 'pu2clr123456'

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Conectado ao broker MQTT")
        # Monitorar TODOS os tópicos
        client.subscribe("#")
        print("📡 Monitorando todos os tópicos...")
    else:
        print(f"❌ Falha na conexão MQTT. Código: {rc}")

def on_message(client, userdata, msg):
    topic = msg.topic
    try:
        payload = msg.payload.decode('utf-8')
        timestamp = datetime.now().strftime('%H:%M:%S')
        
        # Detectar formato antigo
        if "home/temperature/" in topic or "home/humidity/" in topic:
            print(f"🔴 [{timestamp}] FORMATO ANTIGO DETECTADO:")
            print(f"   Tópico: {topic}")
            print(f"   Payload: {payload}")
            print(f"   Tamanho: {len(payload)} bytes")
            
            # Tentar descobrir o IP do dispositivo
            try:
                data = json.loads(payload)
                if 'ip' in data:
                    print(f"   IP do dispositivo: {data['ip']}")
                if 'device_id' in data:
                    print(f"   Device ID: {data['device_id']}")
            except:
                pass
            print("-" * 50)
            
        # Mostrar formato novo também
        elif "home/sensor/" in topic and "/data" in topic:
            print(f"🟢 [{timestamp}] Formato novo detectado: {topic}")
            
        # Mostrar outros tópicos interessantes
        elif topic.startswith("home/"):
            print(f"🔵 [{timestamp}] Outro tópico: {topic}")
            
    except Exception as e:
        print(f"❌ Erro ao processar: {e}")

def main():
    client = mqtt.Client()
    client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        print("🚀 Iniciando monitor MQTT...")
        print("Pressione Ctrl+C para parar")
        print("=" * 50)
        
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_forever()
        
    except KeyboardInterrupt:
        print("\n🛑 Parando monitor...")
        client.disconnect()

if __name__ == "__main__":
    main()
