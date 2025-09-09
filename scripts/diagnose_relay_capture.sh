#!/bin/bash
#
# Script de Diagnóstico - Problema de Registro de Relés
# EXECUTAR NO RASPBERRY PI
#

echo "🔍 DIAGNÓSTICO: Relés não registrando no banco"
echo "=============================================="
echo ""
echo "🎯 SITUAÇÃO:"
echo "   ✅ Relé responde a comandos MQTT"
echo "   ❌ Dados não aparecem no banco após 14h"
echo ""

HOMEGUARD_DIR="/home/homeguard/HomeGuard"
cd "$HOMEGUARD_DIR" || exit 1

echo "1️⃣ VERIFICANDO PROCESSO MQTT LOGGER"
echo "==================================="

# Verificar se mqtt_activity_logger está rodando
MQTT_LOGGER_PID=$(pgrep -f mqtt_activity_logger.py)

if [ -n "$MQTT_LOGGER_PID" ]; then
    echo "   ✅ MQTT Logger rodando (PID: $MQTT_LOGGER_PID)"
    
    # Verificar há quanto tempo está rodando
    START_TIME=$(ps -o lstart= -p $MQTT_LOGGER_PID 2>/dev/null)
    echo "   📅 Iniciado em: $START_TIME"
else
    echo "   ❌ MQTT Logger NÃO está rodando!"
    echo "   🔧 Isso explica por que não está capturando dados"
fi

echo ""
echo "2️⃣ TESTANDO COMUNICAÇÃO MQTT"
echo "============================"

# Testar se consegue se conectar ao broker MQTT
echo "   🔍 Testando conexão MQTT..."

timeout 5 mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/#" -C 1 2>/dev/null && {
    echo "   ✅ Broker MQTT acessível"
} || {
    echo "   ❌ Broker MQTT inacessível ou sem dados de relé"
}

# Verificar IP no mqtt_activity_logger.py
if [ -f "web/mqtt_activity_logger.py" ]; then
    CURRENT_IP=$(grep -o "'host': '[^']*'" web/mqtt_activity_logger.py | cut -d"'" -f4)
    echo "   🔍 IP configurado no logger: $CURRENT_IP"
    
    if [ "$CURRENT_IP" != "192.168.1.102" ]; then
        echo "   ❌ IP INCORRETO! Deveria ser 192.168.1.102"
        echo "   🔧 ESTE É O PROBLEMA!"
    else
        echo "   ✅ IP correto no logger"
    fi
fi

echo ""
echo "3️⃣ VERIFICANDO LOGS MQTT LOGGER"
echo "==============================="

# Verificar logs do mqtt logger
if [ -f "web/mqtt_logger.log" ]; then
    echo "   📄 Últimas linhas do log MQTT:"
    echo "   ================================"
    tail -10 web/mqtt_logger.log | while read line; do
        echo "   $line"
    done
    echo "   ================================"
    
    # Verificar se há erros recentes
    ERROR_COUNT=$(grep -c "ERROR\|❌" web/mqtt_logger.log 2>/dev/null || echo "0")
    echo "   🔍 Erros no log: $ERROR_COUNT"
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo "   ⚠️ Últimos erros:"
        grep "ERROR\|❌" web/mqtt_logger.log | tail -3 | while read line; do
            echo "   $line"
        done
    fi
else
    echo "   ❌ Log do MQTT logger não encontrado"
fi

echo ""
echo "4️⃣ TESTANDO REGISTRO EM TEMPO REAL"
echo "=================================="

echo "   🧪 Enviando comando de teste ao relé..."

# Enviar comando de teste
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "STATUS" 2>/dev/null && {
    echo "   ✅ Comando STATUS enviado"
} || {
    echo "   ❌ Falha ao enviar comando"
}

sleep 3

# Verificar se foi registrado no banco
DB_PATH="db/homeguard.db"
if [ -f "$DB_PATH" ]; then
    RECENT_RELAY_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM activity WHERE topic LIKE 'home/relay/%' AND datetime(created_at) >= datetime('now', '-5 minutes');" 2>/dev/null || echo "0")
    echo "   📊 Registros de relé nos últimos 5 min: $RECENT_RELAY_COUNT"
    
    if [ "$RECENT_RELAY_COUNT" -gt 0 ]; then
        echo "   📄 Último registro de relé:"
        sqlite3 "$DB_PATH" "SELECT created_at, topic, message FROM activity WHERE topic LIKE 'home/relay/%' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || echo "   Erro ao buscar"
    fi
else
    echo "   ❌ Banco de dados não encontrado"
fi

echo ""
echo "5️⃣ VERIFICANDO CONFIGURAÇÃO MQTT"
echo "==============================="

# Verificar configuração do mqtt_activity_logger
if [ -f "web/mqtt_activity_logger.py" ]; then
    echo "   🔍 Configuração MQTT no logger:"
    
    MQTT_HOST=$(grep -o "'host': '[^']*'" web/mqtt_activity_logger.py | cut -d"'" -f4)
    MQTT_PORT=$(grep -o "'port': [^,]*" web/mqtt_activity_logger.py | cut -d: -f2 | tr -d ' ,')
    MQTT_TOPIC=$(grep -o "'topic': '[^']*'" web/mqtt_activity_logger.py | cut -d"'" -f4)
    
    echo "   📡 Host: $MQTT_HOST"
    echo "   🔌 Port: $MQTT_PORT"
    echo "   📋 Topic: $MQTT_TOPIC"
    
    # Verificar se a configuração está correta
    if [ "$MQTT_HOST" = "192.168.1.102" ] && [ "$MQTT_PORT" = "1883" ] && [ "$MQTT_TOPIC" = "home/#" ]; then
        echo "   ✅ Configuração MQTT correta"
    else
        echo "   ⚠️ Configuração MQTT pode estar incorreta"
    fi
else
    echo "   ❌ Arquivo mqtt_activity_logger.py não encontrado"
fi

echo ""
echo "6️⃣ DIAGNÓSTICO FINAL"
echo "==================="

if [ -z "$MQTT_LOGGER_PID" ]; then
    echo "   🎯 PROBLEMA IDENTIFICADO: MQTT Logger parado"
    echo "   🔧 SOLUÇÃO: Reiniciar o MQTT Logger"
    echo ""
    echo "   💡 Para reiniciar:"
    echo "      cd /home/homeguard/HomeGuard"
    echo "      python3 web/mqtt_activity_logger.py &"
    echo ""
elif [ "$RECENT_RELAY_COUNT" = "0" ]; then
    echo "   🎯 PROBLEMA: MQTT Logger roda mas não captura relés"
    echo "   🔧 POSSÍVEIS CAUSAS:"
    echo "      1. Tópicos de relé mudaram"
    echo "      2. Broker MQTT com problemas"
    echo "      3. Configuração incorreta"
    echo ""
else
    echo "   ✅ Sistema funcionando - pode ser problema temporário"
fi

echo ""
echo "🚀 AÇÕES RECOMENDADAS:"
echo "====================="
echo "   1. Se MQTT Logger parado: reiniciar"
echo "   2. Se rodando mas sem captura: verificar tópicos"
echo "   3. Testar comando manual e verificar se registra"
echo ""
echo "🧪 TESTE MANUAL:"
echo "   mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \\"
echo "     -t 'home/relay/ESP01_RELAY_001/command' -m 'ON'"
echo ""
echo "📊 VERIFICAR RESULTADO:"
echo "   sqlite3 db/homeguard.db \"SELECT * FROM activity WHERE topic LIKE 'home/relay/%' ORDER BY created_at DESC LIMIT 5;\""
