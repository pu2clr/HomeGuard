#!/usr/bin/env python3

"""
🔍 Teste Simples MQTT DHT11
Verificar se dados estão chegando do ESP01
"""

import paho.mqtt.client as mqtt
import json
import time
from datetime import datetime

# Configuração MQTT (mesmo do sistema)
MQTT_CONFIG = {
    'broker_host': '192.168.18.236',
    'broker_port': 1883,
    'username': 'homeguard',
    'password': 'pu2clr123456',
    'client_id': 'debug_dht11_test',
    'keepalive': 60
}

def on_connect(client, userdata, flags, rc):
    """Callback de conexão"""
    if rc == 0:
        print(f"✅ Conectado ao MQTT {MQTT_CONFIG['broker_host']}:{MQTT_CONFIG['broker_port']}")
        
        # Subscrever tópicos DHT11
        topics = [
            "home/temperature/+/data",
            "home/humidity/+/data", 
            "home/sensor/+/status",
            "home/sensor/+/info"
        ]
        
        for topic in topics:
            client.subscribe(topic)
            print(f"🎧 Subscrito em: {topic}")
            
        print("\n⏳ Aguardando mensagens MQTT...")
        print("   (O ESP01 deve enviar dados a cada 2 minutos)")
        print("=" * 60)
        
    else:
        print(f"❌ Falha na conexão MQTT: {rc}")

def on_message(client, userdata, msg):
    """Callback de mensagem recebida"""
    try:
        topic = msg.topic
        payload = msg.payload.decode()
        timestamp = datetime.now().strftime('%H:%M:%S')
        
        print(f"\n📨 [{timestamp}] MQTT Recebido:")
        print(f"   📍 Tópico: {topic}")
        print(f"   📦 Payload: {payload}")
        
        # Extrair device_id do tópico
        topic_parts = topic.split('/')
        if len(topic_parts) >= 3:
            device_id = topic_parts[2]
            print(f"   🏷️  Device: {device_id}")
        
        # Tentar parsear JSON
        try:
            data = json.loads(payload)
            print(f"   📊 Dados JSON:")
            for key, value in data.items():
                print(f"      {key}: {value}")
                
            # Identificar tipo de dados
            if 'temperature' in data:
                print(f"   🌡️  Temperatura: {data['temperature']}°C")
            if 'humidity' in data:
                print(f"   💧 Umidade: {data['humidity']}%")
            if 'rssi' in data:
                print(f"   📶 RSSI: {data['rssi']} dBm")
                
        except json.JSONDecodeError:
            print(f"   ⚠️  Payload não é JSON válido")
            
        print("-" * 40)
        
    except Exception as e:
        print(f"❌ Erro ao processar mensagem: {e}")

def on_disconnect(client, userdata, rc):
    """Callback de desconexão"""
    print(f"\n⚠️  Desconectado do MQTT (código: {rc})")

def main():
    """Função principal"""
    print("🔍 Teste Simples MQTT DHT11")
    print("="*40)
    print(f"Broker: {MQTT_CONFIG['broker_host']}:{MQTT_CONFIG['broker_port']}")
    print(f"Client ID: {MQTT_CONFIG['client_id']}")
    
    # Criar cliente MQTT (compatível com paho-mqtt 2.0)
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, MQTT_CONFIG['client_id'])
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect
    
    try:
        # Configurar credenciais
        if MQTT_CONFIG.get('username') and MQTT_CONFIG.get('password'):
            client.username_pw_set(MQTT_CONFIG['username'], MQTT_CONFIG['password'])
            print(f"🔐 Usando credenciais: {MQTT_CONFIG['username']}")
        
        # Conectar
        print("\n🔌 Conectando...")
        client.connect(
            MQTT_CONFIG['broker_host'], 
            MQTT_CONFIG['broker_port'], 
            MQTT_CONFIG['keepalive']
        )
        
        # Loop infinito para escutar mensagens
        print("🔄 Iniciando loop MQTT...")
        client.loop_forever()
        
    except KeyboardInterrupt:
        print("\n🛑 Interrompido pelo usuário")
    except Exception as e:
        print(f"\n❌ Erro: {e}")
    finally:
        print("🔌 Desconectando...")
        client.disconnect()

if __name__ == "__main__":
    main()
