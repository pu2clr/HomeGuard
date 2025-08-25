#!/usr/bin/env python3

"""
🧪 Teste Flask MQTT
Testar se o Flask está processando mensagens MQTT corretamente
"""

import os
import sys
import time
from datetime import datetime
import threading

# Adicionar path para importar módulos
sys.path.append('.')

def test_flask_mqtt():
    """Teste principal"""
    print("🧪 Teste Flask MQTT DHT11")
    print("="*50)
    
    try:
        # Importar módulos do Flask
        print("📦 Importando módulos Flask...")
        from flask_mqtt_controller import mqtt_controller, init_mqtt
        from homeguard_flask import dashboard
        
        print("✅ Módulos importados com sucesso")
        
        # Verificar se dashboard tem a função necessária
        if hasattr(dashboard, 'process_dht11_mqtt_data'):
            print("✅ Função process_dht11_mqtt_data encontrada")
        else:
            print("❌ Função process_dht11_mqtt_data NÃO encontrada")
            return
        
        # Testar conexão MQTT
        print("\n🔌 Testando conexão MQTT...")
        if init_mqtt():
            print("✅ MQTT conectado com sucesso")
            print(f"📊 Status de conexão: {mqtt_controller.connected}")
            
            # Verificar se tópicos foram subscritos
            if mqtt_controller.client:
                print(f"🎧 Cliente MQTT ativo: {mqtt_controller.client}")
            
            # Aguardar um pouco para receber mensagens
            print("\n⏳ Aguardando mensagens MQTT por 30 segundos...")
            print("   (Aguarde dados chegarem do ESP01...)")
            
            # Contador de mensagens
            start_time = time.time()
            initial_count = 0
            
            # Verificar quantos registros existem atualmente no banco
            sensors = dashboard.get_dht11_sensors_data()
            if sensors:
                print(f"📊 Sensores atuais: {len(sensors)}")
                for sensor in sensors:
                    print(f"   📱 {sensor['device_id']}: T={sensor.get('temperature')}, H={sensor.get('humidity')}")
            else:
                print("📊 Nenhum sensor no banco ainda")
            
            # Esperar por mensagens
            for i in range(30):
                time.sleep(1)
                
                # A cada 5 segundos, verificar se chegaram dados novos
                if i % 5 == 0 and i > 0:
                    new_sensors = dashboard.get_dht11_sensors_data()
                    print(f"⏰ {i}s - Verificando novos dados...")
                    
                    if new_sensors and len(new_sensors) != initial_count:
                        print(f"🆕 NOVA MENSAGEM DETECTADA!")
                        for sensor in new_sensors:
                            print(f"   📱 {sensor['device_id']}: T={sensor.get('temperature')}, H={sensor.get('humidity')}")
                        initial_count = len(new_sensors)
            
            print(f"\n⏱️  Teste concluído após 30 segundos")
            
        else:
            print("❌ Falha ao conectar MQTT")
            return
            
    except ImportError as e:
        print(f"❌ Erro de importação: {e}")
        print("💡 Certifique-se de estar na pasta 'web' e ter todos os módulos")
        
    except Exception as e:
        print(f"❌ Erro durante teste: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        try:
            # Desconectar MQTT
            if 'mqtt_controller' in locals():
                mqtt_controller.disconnect()
                print("🔌 MQTT desconectado")
        except:
            pass

if __name__ == "__main__":
    # Verificar se estamos na pasta correta
    if not os.path.exists('homeguard_flask.py'):
        print("❌ Execute este script da pasta 'web':")
        print("   cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/web")
        print("   python test_flask_mqtt.py")
        sys.exit(1)
    
    test_flask_mqtt()
