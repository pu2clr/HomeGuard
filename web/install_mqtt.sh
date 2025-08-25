#!/bin/bash

# Script para instalar dependências MQTT no Flask

echo "📦 Instalando paho-mqtt para controle de relés..."

# Atualizar pip
python3 -m pip install --upgrade pip

# Instalar paho-mqtt
python3 -m pip install paho-mqtt

echo "✅ paho-mqtt instalado com sucesso!"
echo ""
echo "🔧 Configuração necessária:"
echo "   1. Edite web/mqtt_relay_config.py"
echo "   2. Altere MQTT_CONFIG['broker_host'] para o IP do seu broker"
echo "   3. Configure os tópicos MQTT dos seus relés"
echo ""
echo "📋 Exemplo de tópicos MQTT que o ESP deve usar:"
echo "   • Comando: homeguard/relay/ESP01_RELAY_001/command"
echo "   • Status:  homeguard/relay/ESP01_RELAY_001/status"
