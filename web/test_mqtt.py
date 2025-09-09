#!/usr/bin/env python3

"""
Script de teste para verificar conexão MQTT e controle de relés
"""

import sys
import time
from flask_mqtt_controller import mqtt_controller, init_mqtt
from mqtt_relay_config import MQTT_CONFIG, RELAYS_CONFIG

def test_mqtt_connection():
    """Testar conexão MQTT"""
    print("🧪 TESTE DE CONEXÃO MQTT")
    print("=" * 40)
    
    print(f"Broker: {MQTT_CONFIG['broker_host']}:{MQTT_CONFIG['broker_port']}")
    print(f"Client ID: {MQTT_CONFIG['client_id']}")
    print()
    
    # Tentar conectar
    print("🔌 Tentando conectar...")
    if init_mqtt():
        print("✅ Conexão MQTT bem-sucedida!")
        
        # Aguardar um pouco para receber status
        print("⏳ Aguardando status dos relés...")
        time.sleep(3)
        
        # Mostrar status atual
        print("\n📊 STATUS DOS RELÉS:")
        print("-" * 30)
        relays = mqtt_controller.get_relays_config_with_status()
        for relay in relays:
            status = relay.get('status', 'unknown')
            last_update = relay.get('last_update', 'Nunca')
            print(f"  {relay['name']} ({relay['id']}): {status.upper()}")
            print(f"    Última atualização: {last_update}")
            print(f"    Tópico comando: {relay['mqtt_topic_command']}")
            print(f"    Tópico status: {relay['mqtt_topic_status']}")
            print()
        
        return True
    else:
        print("❌ Falha na conexão MQTT!")
        print("\n🔧 Verifique:")
        print("  • IP do broker está correto?")
        print("  • Broker MQTT está rodando?")
        print("  • Firewall bloqueando porta 1883?")
        return False

def test_relay_commands():
    """Testar envio de comandos"""
    if not mqtt_controller.connected:
        print("❌ MQTT não conectado. Execute primeiro test_mqtt_connection()")
        return
    
    print("\n🎮 TESTE DE COMANDOS")
    print("=" * 30)
    
    # Pegar primeiro relé para teste
    relay_id = RELAYS_CONFIG[0]['id']
    relay_name = RELAYS_CONFIG[0]['name']
    
    print(f"Testando relé: {relay_name} ({relay_id})")
    
    # Teste de comandos
    commands = ['on', 'off', 'toggle']
    for cmd in commands:
        print(f"\n📤 Enviando comando: {cmd.upper()}")
        result = mqtt_controller.send_command(relay_id, cmd)
        
        if result['success']:
            print(f"✅ {result['message']}")
        else:
            print(f"❌ Erro: {result['message']}")
        
        time.sleep(1)

if __name__ == '__main__':
    try:
        # Teste de conexão
        if test_mqtt_connection():
            
            # Perguntar se quer testar comandos
            while True:
                resposta = input("\n🤔 Deseja testar envio de comandos? (s/n): ").lower().strip()
                if resposta in ['s', 'sim', 'y', 'yes']:
                    test_relay_commands()
                    break
                elif resposta in ['n', 'nao', 'não', 'no']:
                    print("⏭️  Pulando teste de comandos")
                    break
                else:
                    print("❓ Responda 's' ou 'n'")
        
        # Manter conexão para monitorar
        print("\n👀 Monitorando por 30 segundos...")
        print("   (mensagens MQTT aparecerão aqui)")
        print("   Pressione Ctrl+C para sair")
        
        for i in range(30):
            time.sleep(1)
            print(f"⏰ {30-i} segundos restantes...", end='\r')
        
    except KeyboardInterrupt:
        print("\n\n⏹️  Teste interrompido pelo usuário")
    
    finally:
        print("\n🔌 Desconectando MQTT...")
        mqtt_controller.disconnect()
        print("✅ Teste finalizado!")
