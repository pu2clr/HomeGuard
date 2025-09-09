#!/bin/bash
#
# Script para reiniciar sistema de captura MQTT
# EXECUTAR NO RASPBERRY PI se o diagnóstico mostrar MQTT Logger parado
#

echo "🔧 CORREÇÃO: Reiniciando Sistema de Captura MQTT"
echo "==============================================="
echo ""

HOMEGUARD_DIR="/home/homeguard/HomeGuard"
cd "$HOMEGUARD_DIR" || exit 1

echo "1️⃣ PARANDO PROCESSOS MQTT"
echo "========================="

# Parar mqtt_activity_logger se estiver rodando
sudo pkill -f mqtt_activity_logger.py
sleep 2

# Verificar se parou
MQTT_PID=$(pgrep -f mqtt_activity_logger.py)
if [ -z "$MQTT_PID" ]; then
    echo "   ✅ MQTT Logger parado"
else
    echo "   ⚠️ MQTT Logger ainda rodando (PID: $MQTT_PID)"
    sudo kill -9 $MQTT_PID
    sleep 1
    echo "   ✅ MQTT Logger forçadamente parado"
fi

echo ""
echo "2️⃣ VERIFICANDO ARQUIVOS"
echo "======================"

# Verificar se arquivo existe
if [ -f "web/mqtt_activity_logger.py" ]; then
    echo "   ✅ mqtt_activity_logger.py encontrado"
else
    echo "   ❌ mqtt_activity_logger.py não encontrado!"
    exit 1
fi

# Verificar se banco existe
if [ -f "db/homeguard.db" ]; then
    echo "   ✅ Banco de dados encontrado"
else
    echo "   ❌ Banco de dados não encontrado!"
    exit 1
fi

echo ""
echo "3️⃣ TESTANDO CONECTIVIDADE MQTT"
echo "============================="

# Testar broker MQTT
timeout 5 mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/test" -C 1 2>/dev/null && {
    echo "   ✅ Broker MQTT acessível"
} || {
    echo "   ⚠️ Broker MQTT pode estar com problemas"
}

echo ""
echo "4️⃣ INICIANDO MQTT LOGGER"
echo "========================"

# Fazer backup do log anterior
if [ -f "web/mqtt_logger.log" ]; then
    cp web/mqtt_logger.log web/mqtt_logger.log.backup.$(date +%Y%m%d_%H%M%S)
    echo "   📦 Backup do log anterior criado"
fi

# Iniciar mqtt_activity_logger
echo "   🚀 Iniciando MQTT Logger..."
python3 web/mqtt_activity_logger.py > mqtt_capture_restart.log 2>&1 &
MQTT_PID=$!

sleep 3

# Verificar se iniciou
if ps -p $MQTT_PID > /dev/null; then
    echo "   ✅ MQTT Logger iniciado (PID: $MQTT_PID)"
else
    echo "   ❌ Falha ao iniciar MQTT Logger"
    echo "   📄 Verificar logs:"
    cat mqtt_capture_restart.log
    exit 1
fi

echo ""
echo "5️⃣ TESTANDO CAPTURA"
echo "=================="

echo "   🧪 Aguardando estabilização..."
sleep 5

# Enviar comando de teste para relé
echo "   📤 Enviando comando de teste..."
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "STATUS" 2>/dev/null

sleep 3

# Verificar se foi capturado
RECENT_COUNT=$(sqlite3 "db/homeguard.db" "SELECT COUNT(*) FROM activity WHERE datetime(created_at) >= datetime('now', '-2 minutes');" 2>/dev/null || echo "0")

echo "   📊 Mensagens capturadas nos últimos 2 min: $RECENT_COUNT"

if [ "$RECENT_COUNT" -gt 0 ]; then
    echo "   ✅ Captura funcionando!"
    
    # Mostrar últimas mensagens
    echo "   📄 Últimas capturas:"
    sqlite3 "db/homeguard.db" "SELECT created_at, topic FROM activity ORDER BY created_at DESC LIMIT 3;" 2>/dev/null | while read line; do
        echo "      $line"
    done
else
    echo "   ⚠️ Nenhuma mensagem capturada ainda"
    echo "   💡 Aguarde mais alguns minutos ou verifique logs"
fi

echo ""
echo "6️⃣ TESTE ESPECÍFICO RELÉ"
echo "========================"

echo "   🔌 Testando comando ON/OFF no relé..."

# Comando ON
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "ON" 2>/dev/null
sleep 2

# Comando OFF  
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "OFF" 2>/dev/null
sleep 2

# Verificar se comandos foram registrados
RELAY_COUNT=$(sqlite3 "db/homeguard.db" "SELECT COUNT(*) FROM activity WHERE topic LIKE 'home/relay/%' AND datetime(created_at) >= datetime('now', '-1 minute');" 2>/dev/null || echo "0")

echo "   🔌 Comandos de relé capturados: $RELAY_COUNT"

if [ "$RELAY_COUNT" -gt 0 ]; then
    echo "   ✅ Relés sendo capturados corretamente!"
    echo "   📄 Últimos comandos registrados:"
    sqlite3 "db/homeguard.db" "SELECT created_at, topic, message FROM activity WHERE topic LIKE 'home/relay/%' ORDER BY created_at DESC LIMIT 3;" 2>/dev/null | while read line; do
        echo "      $line"
    done
else
    echo "   ❌ Comandos de relé não sendo capturados"
    echo "   🔍 Verificar logs do MQTT Logger:"
    tail -10 web/mqtt_logger.log 2>/dev/null || echo "   Log não encontrado"
fi

echo ""
echo "✅ CORREÇÃO CONCLUÍDA!"
echo "====================="
echo ""
echo "📊 RESULTADO:"
echo "   🔄 MQTT Logger: Reiniciado (PID: $MQTT_PID)"
echo "   📡 Captura geral: $RECENT_COUNT mensagens"
echo "   🔌 Captura relés: $RELAY_COUNT comandos"
echo ""
echo "🎯 PRÓXIMOS PASSOS:"
echo "   1. Aguardar alguns minutos para dados acumularem"
echo "   2. Testar dashboard: http://$(hostname -I | awk '{print $1}'):5000/relay"
echo "   3. Se ainda sem dados: verificar tópicos MQTT dos relés"
echo ""
echo "💾 LOGS:"
echo "   📄 MQTT Logger: web/mqtt_logger.log"
echo "   📄 Restart: mqtt_capture_restart.log"
