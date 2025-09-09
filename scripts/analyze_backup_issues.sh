#!/bin/bash
#
# Script para identificar arquivos perdidos/incorretos na restauração
# EXECUTAR NO RASPBERRY PI
#

echo "🔍 ANÁLISE: Arquivos perdidos na restauração do backup"
echo "====================================================="
echo ""

HOMEGUARD_DIR="/home/homeguard/HomeGuard"
cd "$HOMEGUARD_DIR" || exit 1

echo "1️⃣ VERIFICANDO ARQUIVOS CRÍTICOS"
echo "================================="

# Lista de arquivos críticos para o sistema
CRITICAL_FILES=(
    "web/mqtt_activity_logger.py"
    "web/dashboard.py"
    "db/homeguard.db"
    "web/templates/base.html"
    "web/templates/dashboard.html"
)

echo "   📋 Verificando existência dos arquivos críticos:"
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(stat -c%s "$file" 2>/dev/null || echo "0")
        echo "   ✅ $file (${SIZE} bytes)"
    else
        echo "   ❌ $file - AUSENTE!"
    fi
done

echo ""
echo "2️⃣ VERIFICANDO CONFIGURAÇÕES"
echo "============================"

# Verificar IP no mqtt_activity_logger
if [ -f "web/mqtt_activity_logger.py" ]; then
    MQTT_IP=$(grep -o "'host': '[^']*'" web/mqtt_activity_logger.py | cut -d"'" -f4 2>/dev/null || echo "NÃO ENCONTRADO")
    echo "   📡 IP MQTT Logger: $MQTT_IP"
    
    if [ "$MQTT_IP" = "192.168.1.102" ]; then
        echo "   ✅ IP correto"
    else
        echo "   ❌ IP incorreto (deveria ser 192.168.1.102)"
    fi
else
    echo "   ❌ mqtt_activity_logger.py não encontrado!"
fi

# Verificar se dashboard.py tem as rotas corretas
if [ -f "web/dashboard.py" ]; then
    RELAY_ROUTE=$(grep -c "def api_relay_data" web/dashboard.py)
    TEMP_ROUTE=$(grep -c "def api_temperature_data" web/dashboard.py)
    echo "   🌐 Rotas Dashboard: relay=$RELAY_ROUTE, temp=$TEMP_ROUTE"
    
    if [ "$RELAY_ROUTE" -gt 0 ] && [ "$TEMP_ROUTE" -gt 0 ]; then
        echo "   ✅ Rotas principais presentes"
    else
        echo "   ❌ Rotas podem estar faltando"
    fi
else
    echo "   ❌ dashboard.py não encontrado!"
fi

echo ""
echo "3️⃣ VERIFICANDO PROCESSOS"
echo "========================"

# Verificar processos rodando
MQTT_LOGGER_PID=$(pgrep -f mqtt_activity_logger.py)
DASHBOARD_PID=$(pgrep -f dashboard.py)

echo "   🔄 MQTT Logger: ${MQTT_LOGGER_PID:-NÃO RODANDO}"
echo "   🌐 Dashboard: ${DASHBOARD_PID:-NÃO RODANDO}"

echo ""
echo "4️⃣ VERIFICANDO LOGS RECENTES"
echo "============================"

# Verificar logs para entender o que aconteceu
if [ -f "web/mqtt_logger.log" ]; then
    LAST_LOG=$(tail -1 web/mqtt_logger.log 2>/dev/null)
    echo "   📄 Último log MQTT: $LAST_LOG"
    
    # Contar erros recentes
    ERROR_COUNT=$(grep -c "ERROR\|❌\|Failed" web/mqtt_logger.log 2>/dev/null || echo "0")
    echo "   ⚠️ Erros no log: $ERROR_COUNT"
else
    echo "   ❌ Log do MQTT não encontrado"
fi

# Verificar se há backups disponíveis
echo ""
echo "5️⃣ VERIFICANDO BACKUPS DISPONÍVEIS"
echo "=================================="

echo "   📦 Backups encontrados:"
find . -name "*.backup*" -o -name "*backup*" 2>/dev/null | head -10 | while read file; do
    echo "      $file"
done

# Verificar se há arquivos .bak
BAK_COUNT=$(find . -name "*.bak" | wc -l)
echo "   💾 Arquivos .bak: $BAK_COUNT"

echo ""
echo "6️⃣ TESTANDO CONECTIVIDADE"
echo "========================="

# Testar broker MQTT
echo "   🔍 Testando broker MQTT..."
timeout 3 mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/test" -C 1 2>/dev/null && {
    echo "   ✅ Broker MQTT acessível"
} || {
    echo "   ❌ Problema de conectividade MQTT"
}

# Testar banco de dados
if [ -f "db/homeguard.db" ]; then
    TOTAL_RECORDS=$(sqlite3 "db/homeguard.db" "SELECT COUNT(*) FROM activity;" 2>/dev/null || echo "ERRO")
    echo "   📊 Total de registros no banco: $TOTAL_RECORDS"
    
    RECENT_RECORDS=$(sqlite3 "db/homeguard.db" "SELECT COUNT(*) FROM activity WHERE datetime(created_at) >= datetime('now', '-1 hour');" 2>/dev/null || echo "ERRO")
    echo "   📊 Registros última hora: $RECENT_RECORDS"
    
    if [ "$RECENT_RECORDS" = "0" ] || [ "$RECENT_RECORDS" = "ERRO" ]; then
        echo "   ❌ Sem registros recentes - confirma problema de captura"
    fi
else
    echo "   ❌ Banco de dados não encontrado!"
fi

echo ""
echo "📋 DIAGNÓSTICO RESUMIDO"
echo "======================="

echo ""
echo "🎯 ARQUIVOS QUE PODEM PRECISAR SER RESGATADOS:"

# Listar problemas encontrados
PROBLEMS=()

if [ ! -f "web/mqtt_activity_logger.py" ]; then
    PROBLEMS+=("mqtt_activity_logger.py - ARQUIVO AUSENTE")
elif [ "$MQTT_IP" != "192.168.1.102" ]; then
    PROBLEMS+=("mqtt_activity_logger.py - IP INCORRETO")
fi

if [ ! -f "web/dashboard.py" ]; then
    PROBLEMS+=("dashboard.py - ARQUIVO AUSENTE")
elif [ "$RELAY_ROUTE" = "0" ] || [ "$TEMP_ROUTE" = "0" ]; then
    PROBLEMS+=("dashboard.py - ROTAS FALTANDO")
fi

if [ ! -f "db/homeguard.db" ]; then
    PROBLEMS+=("homeguard.db - BANCO AUSENTE")
fi

if [ ${#PROBLEMS[@]} -eq 0 ]; then
    echo "   ✅ Arquivos principais parecem OK"
    echo "   💡 Problema pode ser apenas configuração ou processos"
else
    echo "   ❌ PROBLEMAS ENCONTRADOS:"
    for problem in "${PROBLEMS[@]}"; do
        echo "      - $problem"
    done
fi

echo ""
echo "🔧 PRÓXIMOS PASSOS RECOMENDADOS:"
echo "   1. Identificar fonte dos arquivos corretos"
echo "   2. Restaurar arquivos específicos (não toda a pasta)"
echo "   3. Corrigir configurações (IPs, etc.)"
echo "   4. Reiniciar serviços"
echo ""
echo "💡 DICA: Se você tem Git, pode usar:"
echo "   git status (para ver o que mudou)"
echo "   git checkout HEAD -- arquivo (para restaurar arquivo específico)"
