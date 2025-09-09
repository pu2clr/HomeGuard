#!/usr/bin/env python3

"""
🔍 Debug Real-Time
Teste para verificar se dados estão chegando em tempo real
"""

import sqlite3
import time
from datetime import datetime, timedelta
import threading
from flask_mqtt_controller import MQTTRelayController
import json

class RealTimeDebugger:
    def __init__(self):
        self.db_path = '../db/homeguard.db'
        self.last_record_count = 0
        self.mqtt = None
        
    def get_db_stats(self):
        """Obter estatísticas do banco"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Total de registros
            cursor.execute("SELECT COUNT(*) FROM dht11_sensors")
            total = cursor.fetchone()[0]
            
            # Último registro
            cursor.execute("""
                SELECT device_id, temperature, humidity, timestamp_received 
                FROM dht11_sensors 
                ORDER BY timestamp_received DESC 
                LIMIT 1
            """)
            last = cursor.fetchone()
            
            # Registros na última hora
            cursor.execute("""
                SELECT COUNT(*) FROM dht11_sensors 
                WHERE datetime(timestamp_received) >= datetime('now', '-1 hour')
            """)
            last_hour = cursor.fetchone()[0]
            
            conn.close()
            
            return {
                'total': total,
                'last_record': last,
                'last_hour_count': last_hour
            }
            
        except Exception as e:
            print(f"❌ Erro ao acessar banco: {e}")
            return None

    def monitor_database(self):
        """Monitorar mudanças no banco"""
        print("🔍 Iniciando monitoramento do banco de dados...")
        
        while True:
            stats = self.get_db_stats()
            if stats:
                current_time = datetime.now().strftime('%H:%M:%S')
                
                if stats['total'] != self.last_record_count:
                    print(f"\n🆕 [{current_time}] NOVO REGISTRO!")
                    print(f"   📊 Total: {stats['total']} (+{stats['total'] - self.last_record_count})")
                    
                    if stats['last_record']:
                        device, temp, humid, timestamp = stats['last_record']
                        print(f"   📱 Device: {device}")
                        print(f"   🌡️  Temp: {temp}°C")
                        print(f"   💧 Humid: {humid}%")
                        print(f"   ⏰ Time: {timestamp}")
                    
                    self.last_record_count = stats['total']
                else:
                    print(f"⏱️  [{current_time}] Sem novos dados - Total: {stats['total']} | Última hora: {stats['last_hour_count']}")
                    
                    if stats['last_record']:
                        _, _, _, last_time = stats['last_record']
                        last_datetime = datetime.strptime(last_time, '%Y-%m-%d %H:%M:%S')
                        minutes_ago = int((datetime.now() - last_datetime).total_seconds() / 60)
                        print(f"   ⌚ Último registro há {minutes_ago} minutos")
            
            time.sleep(10)  # Verificar a cada 10 segundos

    def test_mqtt_connection(self):
        """Testar conexão MQTT"""
        print("🔗 Testando conexão MQTT...")
        
        try:
            # Configurar callback personalizado
            def on_message_debug(client, userdata, msg):
                topic = msg.topic
                payload = msg.payload.decode()
                timestamp = datetime.now().strftime('%H:%M:%S')
                
                print(f"\n📨 [{timestamp}] MQTT recebido:")
                print(f"   📝 Tópico: {topic}")
                print(f"   📦 Payload: {payload}")
                
                # Tentar parsear como JSON
                try:
                    data = json.loads(payload)
                    print(f"   🔍 Dados: {json.dumps(data, indent=2)}")
                except:
                    print(f"   ⚠️  Payload não é JSON válido")
            
            # Inicializar controlador MQTT
            self.mqtt = MQTTRelayController()
            self.mqtt.client.on_message = on_message_debug
            
            # Conectar
            if self.mqtt.connect():
                print("✅ MQTT conectado com sucesso!")
                print("🎧 Aguardando mensagens...")
                
                # Manter conexão ativa
                self.mqtt.client.loop_forever()
            else:
                print("❌ Falha ao conectar MQTT")
                
        except Exception as e:
            print(f"❌ Erro no teste MQTT: {e}")

def main():
    """Função principal de debug"""
    print("="*60)
    print("🔍 HomeGuard Debug Real-Time")
    print("="*60)
    
    debugger = RealTimeDebugger()
    
    print("\n1. Verificando estado inicial do banco...")
    initial_stats = debugger.get_db_stats()
    if initial_stats:
        print(f"   📊 Registros totais: {initial_stats['total']}")
        print(f"   📈 Registros última hora: {initial_stats['last_hour_count']}")
        
        if initial_stats['last_record']:
            device, temp, humid, timestamp = initial_stats['last_record']
            print(f"   🕐 Último registro: {timestamp}")
            print(f"      📱 {device}: {temp}°C, {humid}%")
        
        debugger.last_record_count = initial_stats['total']
    
    print("\n2. Escolha o modo de debug:")
    print("   [1] Monitorar banco de dados")
    print("   [2] Monitorar MQTT")
    print("   [3] Ambos (threads separadas)")
    
    try:
        choice = input("\nEscolha (1-3): ").strip()
        
        if choice == "1":
            debugger.monitor_database()
            
        elif choice == "2":
            debugger.test_mqtt_connection()
            
        elif choice == "3":
            print("\n🚀 Iniciando monitoramento duplo...")
            
            # Thread para monitorar banco
            db_thread = threading.Thread(target=debugger.monitor_database, daemon=True)
            db_thread.start()
            
            # Thread principal para MQTT
            time.sleep(2)  # Pequena pausa
            debugger.test_mqtt_connection()
            
        else:
            print("❌ Opção inválida")
            
    except KeyboardInterrupt:
        print("\n\n🛑 Debug interrompido pelo usuário")
    except Exception as e:
        print(f"\n❌ Erro durante debug: {e}")

if __name__ == "__main__":
    main()
