#!/bin/bash
#
# Correção URGENTE: IP incorreto no mqtt_activity_logger.py
# EXECUTAR NO RASPBERRY PI
#

echo "🔧 CORREÇÃO: IP do MQTT Logger após restore backup"
echo "================================================="
echo ""

HOMEGUARD_DIR="/home/homeguard/HomeGuard"
cd "$HOMEGUARD_DIR" || exit 1

echo "1️⃣ VERIFICANDO IP ATUAL"
echo "======================"

if [ -f "web/mqtt_activity_logger.py" ]; then
    CURRENT_IP=$(grep -o "'host': '[^']*'" web/mqtt_activity_logger.py | cut -d"'" -f4)
    echo "   📡 IP atual no logger: $CURRENT_IP"
    echo "   🎯 IP correto deveria ser: 192.168.1.102"
    
    if [ "$CURRENT_IP" = "192.168.1.102" ]; then
        echo "   ✅ IP já está correto!"
        
        # Se IP está correto, verificar se logger está rodando
        MQTT_PID=$(pgrep -f mqtt_activity_logger.py)
        if [ -n "$MQTT_PID" ]; then
            echo "   ✅ MQTT Logger rodando (PID: $MQTT_PID)"
            echo "   💡 Problema pode ser outro - verificar logs"
        else
            echo "   ❌ MQTT Logger não está rodando!"
            echo "   🔧 Precisa reiniciar o logger"
        fi
        
    else
        echo "   ❌ IP INCORRETO! Este é o problema!"
        echo ""
        echo "2️⃣ CORRIGINDO IP"
        echo "==============="
        
        # Fazer backup
        cp web/mqtt_activity_logger.py web/mqtt_activity_logger.py.backup.$(date +%Y%m%d_%H%M%S)
        echo "   📦 Backup criado"
        
        # Corrigir IP
        sed -i.bak "s/'host': '$CURRENT_IP'/'host': '192.168.1.102'/g" web/mqtt_activity_logger.py
        
        # Verificar se correção funcionou
        NEW_IP=$(grep -o "'host': '[^']*'" web/mqtt_activity_logger.py | cut -d"'" -f4)
        
        if [ "$NEW_IP" = "192.168.1.102" ]; then
            echo "   ✅ IP corrigido para: $NEW_IP"
        else
            echo "   ❌ Falha na correção automática"
            echo "   🔧 Corrigir manualmente:"
            echo "      nano web/mqtt_activity_logger.py"
            echo "      Alterar 'host': '$CURRENT_IP' para 'host': '192.168.1.102'"
            exit 1
        fi
    fi
else
    echo "   ❌ Arquivo mqtt_activity_logger.py não encontrado!"
    exit 1
fi

echo ""
echo "3️⃣ REINICIANDO MQTT LOGGER"
echo "=========================="

# Parar processo atual
sudo pkill -f mqtt_activity_logger.py
sleep 2

MQTT_PID=$(pgrep -f mqtt_activity_logger.py)
if [ -z "$MQTT_PID" ]; then
    echo "   ✅ Processo anterior parado"
else
    echo "   ⚠️ Forçando parada..."
    sudo kill -9 $MQTT_PID
    sleep 1
fi

# Iniciar com IP correto
echo "   🚀 Iniciando MQTT Logger com IP correto..."
python3 web/mqtt_activity_logger.py > mqtt_logger_ip_fix.log 2>&1 &
NEW_PID=$!

sleep 3

# Verificar se iniciou
if ps -p $NEW_PID > /dev/null; then
    echo "   ✅ MQTT Logger iniciado (PID: $NEW_PID)"
else
    echo "   ❌ Falha ao iniciar. Verificar logs:"
    cat mqtt_logger_ip_fix.log
    exit 1
fi

echo ""
echo "4️⃣ TESTANDO CAPTURA"
echo "=================="

echo "   🧪 Aguardando estabilização..."
sleep 5

# Enviar comando de teste
echo "   📤 Enviando comando de teste ao relé..."
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "STATUS" 2>/dev/null

sleep 3

# Verificar se foi capturado
DB_PATH="db/homeguard.db"
if [ -f "$DB_PATH" ]; then
    RECENT_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM activity WHERE datetime(created_at) >= datetime('now', '-2 minutes');" 2>/dev/null || echo "0")
    echo "   📊 Mensagens recentes: $RECENT_COUNT"
    
    RELAY_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM activity WHERE topic LIKE 'home/relay/%' AND datetime(created_at) >= datetime('now', '-2 minutes');" 2>/dev/null || echo "0")
    echo "   🔌 Comandos de relé: $RELAY_COUNT"
    
    if [ "$RELAY_COUNT" -gt 0 ]; then
        echo "   ✅ RELÉS SENDO CAPTURADOS!"
        echo "   📄 Último comando:"
        sqlite3 "$DB_PATH" "SELECT created_at, topic, message FROM activity WHERE topic LIKE 'home/relay/%' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null
    else
        echo "   ⚠️ Ainda sem captura de relés"
        echo "   💡 Aguardar mais alguns minutos"
    fi
else
    echo "   ❌ Banco de dados não encontrado"
fi

echo ""
echo "5️⃣ TESTE COMPLETO"
echo "================"

# Enviar sequência de comandos
echo "   🔌 Testando sequência completa..."

mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "ON" 2>/dev/null
sleep 1
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "OFF" 2>/dev/null
sleep 1
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "STATUS" 2>/dev/null

sleep 3

# Verificar resultados finais
FINAL_RELAY_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM activity WHERE topic LIKE 'home/relay/%' AND datetime(created_at) >= datetime('now', '-1 minute');" 2>/dev/null || echo "0")

echo "   🔌 Total de comandos capturados: $FINAL_RELAY_COUNT"

if [ "$FINAL_RELAY_COUNT" -ge 3 ]; then
    echo "   🎉 SUCESSO! Relés sendo capturados corretamente!"
    echo "   📄 Últimos comandos:"
    sqlite3 "$DB_PATH" "SELECT created_at, topic, message FROM activity WHERE topic LIKE 'home/relay/%' ORDER BY created_at DESC LIMIT 3;" 2>/dev/null | while read line; do
        echo "      $line"
    done
else
    echo "   ⚠️ Ainda com problemas de captura"
    echo "   📄 Verificar logs:"
    tail -10 web/mqtt_logger.log 2>/dev/null || echo "   Log não encontrado"
fi

echo ""
echo "✅ CORREÇÃO CONCLUÍDA!"
echo "====================="
echo ""
echo "📊 RESULTADO:"
echo "   🔧 IP corrigido: 192.168.1.102"
echo "   🔄 MQTT Logger: Reiniciado (PID: $NEW_PID)"
echo "   🔌 Comandos capturados: $FINAL_RELAY_COUNT"
echo ""
echo "🎯 PRÓXIMOS PASSOS:"
echo "   1. Aguardar alguns minutos"
echo "   2. Testar dashboard de relés"
echo "   3. Verificar se outros sensores também foram afetados"
echo ""
echo "💾 LOGS E BACKUPS:"
echo "   📄 Log atual: mqtt_logger_ip_fix.log"
echo "   📦 Backup: web/mqtt_activity_logger.py.backup.*"
