#!/bin/bash

# Script de teste para ESP32-C3 Multi-Sensor
# Testa o simulador e funcionalidades do dispositivo

echo "🧪 TESTE ESP32-C3 MULTI-SENSOR"
echo "=============================="

# Verificar se os arquivos necessários existem
echo "📋 Verificando arquivos..."

if [ ! -f "main.py" ]; then
    echo "❌ main.py não encontrado!"
    exit 1
fi

if [ ! -f "simulate_multi_sensor.py" ]; then
    echo "❌ simulate_multi_sensor.py não encontrado!"
    exit 1
fi

echo "✅ Arquivos encontrados"

# Verificar Python
echo ""
echo "🐍 Verificando Python..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 não encontrado!"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo "✅ $PYTHON_VERSION encontrado"

# Executar validação básica do código
echo ""
echo "🔍 Validando sintaxe do código..."

# Verificar sintaxe do main.py
python3 -m py_compile main.py 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ main.py: Sintaxe válida"
else
    echo "❌ main.py: Erro de sintaxe"
    python3 -m py_compile main.py
    exit 1
fi

# Verificar sintaxe do simulador
python3 -m py_compile simulate_multi_sensor.py 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ simulate_multi_sensor.py: Sintaxe válida"
else
    echo "❌ simulate_multi_sensor.py: Erro de sintaxe"
    python3 -m py_compile simulate_multi_sensor.py
    exit 1
fi

# Teste de execução rápida
echo ""
echo "⚡ Teste rápido de execução..."
echo "   (Será interrompido após 10 segundos)"

timeout 10 python3 simulate_multi_sensor.py &
PID=$!

sleep 10
kill $PID 2>/dev/null

echo ""
echo "✅ Teste básico concluído!"
echo ""
echo "🚀 Para executar o simulador completo:"
echo "   python3 simulate_multi_sensor.py"
echo ""
echo "📡 Comandos MQTT de teste:"
echo "   # Monitorar dados:"
echo "   mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t 'home/multisensor/MULTI_SENSOR_C3A/#' -v"
echo ""
echo "   # Controlar relé:"
echo "   mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t 'home/multisensor/MULTI_SENSOR_C3A/relay/command' -m 'ON'"
echo "   mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t 'home/multisensor/MULTI_SENSOR_C3A/relay/command' -m 'OFF'"
echo ""
echo "   # Solicitar leitura:"
echo "   mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t 'home/multisensor/MULTI_SENSOR_C3A/command' -m 'READ'"