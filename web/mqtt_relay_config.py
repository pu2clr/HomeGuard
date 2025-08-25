#!/usr/bin/env python3

"""
============================================
Configuração MQTT para Controle de Relés
============================================
"""

# Configuração do Broker MQTT
MQTT_CONFIG = {
    'broker_host': '192.168.18.236',  # 🔧 ALTERE AQUI o IP do seu broker MQTT
    'broker_port': 1883,
    'username': 'homeguard',  # Se precisar de autenticação, coloque aqui
    'password': 'pu2clr123456',  # Se precisar de autenticação, coloque aqui
    'keepalive': 60,
    'client_id': 'homeguard_flask_dashboard'
}

# Configuração dos Relés
RELAYS_CONFIG = [
    {
        "id": "ESP01_RELAY_001",
        "name": "Luz da Garagem",
        "location": "Garagem",
        "mqtt_topic_command": "home/relay/ESP01_RELAY_001/command",  # Tópico para enviar comandos
        "mqtt_topic_status": "home/relay/ESP01_RELAY_001/status",    # Tópico para receber status
        "status": "unknown"
    },
    {
        "id": "ESP01_RELAY_002", 
        "name": "Luz da Varanda",
        "location": "Varanda",
        "mqtt_topic_command": "home/relay/ESP01_RELAY_002/command",
        "mqtt_topic_status": "home/relay/ESP01_RELAY_002/status",
        "status": "unknown"
    },
    {
        "id": "ESP01_RELAY_003",
        "name": "Bomba d'Água", 
        "location": "Externa",
        "mqtt_topic_command": "home/relay/ESP01_RELAY_003/command",
        "mqtt_topic_status": "home/relay/ESP01_RELAY_003/status",
        "status": "unknown"
    }
]

# Comandos MQTT aceitos
RELAY_COMMANDS = {
    'on': 'ON',        # Comando para ligar
    'off': 'OFF',      # Comando para desligar  
    'toggle': 'TOGGLE' # Comando para alternar estado
}

# Configurações de timeout
RELAY_TIMEOUT = {
    'command_timeout': 5,      # Timeout para receber confirmação do comando (segundos)
    'status_refresh': 30,      # Intervalo para atualizar status dos relés (segundos)
    'connection_retry': 3      # Número de tentativas de reconexão MQTT
}
