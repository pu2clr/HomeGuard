#!/bin/bash
#
# Script de teste para Simple Power Monitor
# Testa comandos MQTT e monitora respostas
#

echo "🧪 TESTE: Simple Power Monitor"
echo "==============================="
echo ""

# Configuração
BROKER="192.168.1.102"
PORT="1883"
USER="homeguard"
PASS="pu2clr123456"
DEVICE_ID="POWER_MONITOR_01"

# Tópicos
TOPIC_COMMAND="home/power/$DEVICE_ID/command"
TOPIC_STATUS="home/power/$DEVICE_ID/status"
TOPIC_ALERT="home/power/$DEVICE_ID/alert"
TOPIC_INFO="home/power/$DEVICE_ID/info"

echo "📋 Configuração do Teste:"
echo "   🏠 Broker: $BROKER:$PORT"
echo "   🆔 Device: $DEVICE_ID"
echo "   📡 Tópicos:"
echo "      - Command: $TOPIC_COMMAND"
echo "      - Status:  $TOPIC_STATUS"
echo "      - Alert:   $TOPIC_ALERT"
echo "      - Info:    $TOPIC_INFO"
echo ""

# Função para verificar conectividade
check_broker() {
    echo "🔍 Verificando conectividade MQTT..."
    timeout 3 mosquitto_sub -h $BROKER -p $PORT -u $USER -P $PASS -t "test" -C 1 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✅ Broker MQTT acessível"
        return 0
    else
        echo "   ❌ Broker MQTT inacessível"
        return 1
    fi
}

# Função para monitorar tópico
monitor_topic() {
    local topic=$1
    local duration=${2:-5}
    local description=$3
    
    echo "   📡 Monitorando $description por ${duration}s..."
    timeout $duration mosquitto_sub -h $BROKER -p $PORT -u $USER -P $PASS -t "$topic" -v 2>/dev/null | while read line; do
        echo "      📨 $line"
    done
}

# Função para enviar comando
send_command() {
    local command=$1
    local description=$2
    
    echo "   📤 Enviando comando: $command ($description)"
    mosquitto_pub -h $BROKER -p $PORT -u $USER -P $PASS -t "$TOPIC_COMMAND" -m "$command" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "      ✅ Comando enviado"
    else
        echo "      ❌ Falha ao enviar comando"
    fi
}

# Verificar conectividade primeiro
if ! check_broker; then
    echo ""
    echo "❌ Não é possível conectar ao broker MQTT"
    echo "   🔧 Verifique:"
    echo "      - IP do broker: $BROKER"
    echo "      - Credenciais: $USER / $PASS"
    echo "      - Firewall/conectividade"
    exit 1
fi

echo ""
echo "1️⃣ TESTE DE INFORMAÇÕES DO DISPOSITIVO"
echo "======================================"

echo "   🔍 Solicitando informações do dispositivo..."
send_command "INFO" "Solicitar informações"

echo ""
echo "   📡 Aguardando resposta (10 segundos)..."
monitor_topic "$TOPIC_INFO" 10 "informações do dispositivo"

echo ""
echo "2️⃣ TESTE DE STATUS"
echo "=================="

send_command "STATUS" "Solicitar status atual"

echo ""
echo "   📡 Aguardando status (10 segundos)..."
monitor_topic "$TOPIC_STATUS" 10 "status do dispositivo"

echo ""
echo "3️⃣ TESTE DE LEITURA FORÇADA"
echo "=========================="

send_command "READ" "Forçar leitura do sensor"

echo ""
echo "   📡 Aguardando dados (5 segundos)..."
monitor_topic "$TOPIC_STATUS" 5 "dados do sensor"

echo ""
echo "4️⃣ TESTE DE CONTROLE MANUAL DO RELÉ"
echo "=================================="

echo "   🔌 Testando comando ON..."
send_command "ON" "Ligar relé manualmente"
sleep 2

echo ""
echo "   🔌 Testando comando OFF..."
send_command "OFF" "Desligar relé manualmente"
sleep 2

echo ""
echo "   🔄 Voltando ao modo automático..."
send_command "AUTO" "Modo automático"
sleep 2

echo ""
echo "5️⃣ MONITORAMENTO CONTÍNUO"
echo "========================"

echo "   📊 Opções de monitoramento contínuo:"
echo ""
echo "   A) Monitorar alertas de energia:"
echo "      mosquitto_sub -h $BROKER -u $USER -P $PASS -t '$TOPIC_ALERT' -v"
echo ""
echo "   B) Monitorar status geral:"
echo "      mosquitto_sub -h $BROKER -u $USER -P $PASS -t '$TOPIC_STATUS' -v"
echo ""
echo "   C) Monitorar todos os tópicos:"
echo "      mosquitto_sub -h $BROKER -u $USER -P $PASS -t 'home/power/$DEVICE_ID/#' -v"
echo ""

read -p "   ❓ Deseja iniciar monitoramento contínuo? (y/N): " monitor

if [ "$monitor" = "y" ] || [ "$monitor" = "Y" ]; then
    echo ""
    echo "🔄 MONITORAMENTO CONTÍNUO INICIADO"
    echo "================================="
    echo "   Pressione Ctrl+C para sair"
    echo ""
    
    # Monitorar todos os tópicos do dispositivo
    mosquitto_sub -h $BROKER -p $PORT -u $USER -P $PASS -t "home/power/$DEVICE_ID/#" -v
fi

echo ""
echo "✅ TESTE CONCLUÍDO"
echo "=================="
echo ""
echo "📊 COMANDOS ÚTEIS PARA MONITORAMENTO:"
echo ""
echo "🔍 Verificar se dispositivo está online:"
echo "   mosquitto_pub -h $BROKER -u $USER -P $PASS -t '$TOPIC_COMMAND' -m 'STATUS'"
echo ""
echo "🚨 Monitorar alertas de falta de energia:"
echo "   mosquitto_sub -h $BROKER -u $USER -P $PASS -t '$TOPIC_ALERT' -v"
echo ""
echo "💓 Monitorar heartbeat (a cada 5 min):"
echo "   mosquitto_sub -h $BROKER -u $USER -P $PASS -t '$TOPIC_STATUS' -v"
echo ""
echo "🔧 Teste manual de relé:"
echo "   mosquitto_pub -h $BROKER -u $USER -P $PASS -t '$TOPIC_COMMAND' -m 'ON'"
echo "   mosquitto_pub -h $BROKER -u $USER -P $PASS -t '$TOPIC_COMMAND' -m 'OFF'"
echo "   mosquitto_pub -h $BROKER -u $USER -P $PASS -t '$TOPIC_COMMAND' -m 'AUTO'"
echo ""
echo "🎯 PRÓXIMOS PASSOS:"
echo "   1. Verificar se ESP8266 está funcionando (Serial Monitor)"
echo "   2. Testar detecção desligando disjuntor"
echo "   3. Verificar acionamento do relé"
echo "   4. Monitorar no dashboard HomeGuard"
