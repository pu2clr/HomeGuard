#!/bin/bash
#
# Script para diagnosticar e corrigir views do banco - EXECUTAR NO RASPBERRY PI
#

echo "🔍 Diagnóstico e Correção das Views do Banco"
echo "============================================="
echo ""

# Localizar banco de dados
DB_PATH="/home/homeguard/HomeGuard/db/homeguard.db"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ Banco de dados não encontrado: $DB_PATH"
    echo "   Procurando em outros locais..."
    
    # Procurar banco em outros locais
    find /home/homeguard -name "*.db" 2>/dev/null | head -5
    exit 1
fi

echo "📊 Banco encontrado: $DB_PATH"
echo ""

echo "1️⃣ TESTANDO DADOS DIRETOS (tabela activity)"
echo "============================================="

# Testar dados diretos na tabela activity
TEMP_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM activity WHERE topic LIKE 'home/temperature/%/data';" 2>/dev/null || echo "0")
HUMIDITY_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM activity WHERE topic LIKE 'home/humidity/%/data';" 2>/dev/null || echo "0")

echo "   🌡️ Registros de temperatura na tabela: $TEMP_COUNT"
echo "   💧 Registros de umidade na tabela: $HUMIDITY_COUNT"

if [ "$TEMP_COUNT" -gt 0 ]; then
    echo "   📄 Exemplo de registro de temperatura:"
    sqlite3 "$DB_PATH" "SELECT created_at, topic, message FROM activity WHERE topic LIKE 'home/temperature/%/data' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || echo "   Erro ao buscar exemplo"
fi

echo ""
echo "2️⃣ TESTANDO VIEWS EXISTENTES"
echo "============================"

# Listar views existentes
echo "   📋 Views existentes no banco:"
sqlite3 "$DB_PATH" ".tables" | grep vw_ || echo "   Nenhuma view encontrada"

# Testar view de temperatura
TEMP_VIEW_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM vw_temperature_activity;" 2>/dev/null || echo "ERRO")
echo "   🌡️ Registros na vw_temperature_activity: $TEMP_VIEW_COUNT"

# Testar view de umidade
HUMIDITY_VIEW_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM vw_humidity_activity;" 2>/dev/null || echo "ERRO")
echo "   💧 Registros na vw_humidity_activity: $HUMIDITY_VIEW_COUNT"

echo ""
echo "3️⃣ RECRIANDO VIEWS CORRETAS"
echo "==========================="

echo "   🔧 Removendo views existentes..."

sqlite3 "$DB_PATH" << 'EOF'
DROP VIEW IF EXISTS vw_temperature_activity;
DROP VIEW IF EXISTS vw_humidity_activity;
DROP VIEW IF EXISTS vw_motion_activity;
DROP VIEW IF EXISTS vw_relay_activity;
EOF

echo "   ✅ Views antigas removidas"

echo "   🔧 Criando views corretas..."

sqlite3 "$DB_PATH" << 'EOF'
-- View de temperatura correta
CREATE VIEW vw_temperature_activity AS
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.temperature') as temperature,
    json_extract(message, '$.unit') as unit,
    json_extract(message, '$.rssi') as rssi,
    json_extract(message, '$.uptime') as uptime
FROM activity 
WHERE topic LIKE 'home/temperature/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL
ORDER BY created_at DESC;

-- View de umidade correta
CREATE VIEW vw_humidity_activity AS
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.humidity') as humidity,
    json_extract(message, '$.unit') as unit,
    json_extract(message, '$.rssi') as rssi,
    json_extract(message, '$.uptime') as uptime
FROM activity 
WHERE topic LIKE 'home/humidity/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.humidity') IS NOT NULL
ORDER BY created_at DESC;

-- View de movimento correta
CREATE VIEW vw_motion_activity AS
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location
FROM activity 
WHERE topic LIKE 'home/motion/%/event'
    AND json_valid(message) = 1
    AND json_extract(message, '$.motion') = 1
ORDER BY created_at DESC;

-- View de relés correta
CREATE VIEW vw_relay_activity AS
SELECT 
    created_at,
    topic,
    message,
    CASE 
        WHEN message = 'ON' THEN 'Ligado'
        WHEN message = 'OFF' THEN 'Desligado'
        ELSE message 
    END as status_brasileiro,
    substr(topic, length('home/relay/') + 1, 
           length(topic) - length('home/relay/') - length('/command')) as relay_id
FROM activity 
WHERE topic LIKE 'home/relay/%/command'
ORDER BY created_at DESC;
EOF

echo "   ✅ Views criadas"

echo ""
echo "4️⃣ TESTANDO VIEWS CORRIGIDAS"
echo "============================"

# Testar views novamente
NEW_TEMP_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM vw_temperature_activity;" 2>/dev/null || echo "ERRO")
echo "   🌡️ Registros na vw_temperature_activity: $NEW_TEMP_COUNT"

NEW_HUMIDITY_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM vw_humidity_activity;" 2>/dev/null || echo "ERRO")
echo "   💧 Registros na vw_humidity_activity: $NEW_HUMIDITY_COUNT"

if [ "$NEW_TEMP_COUNT" -gt 0 ]; then
    echo "   📄 Exemplo da view de temperatura:"
    sqlite3 "$DB_PATH" "SELECT device_id, temperature, created_at FROM vw_temperature_activity LIMIT 3;" 2>/dev/null || echo "   Erro ao buscar exemplo"
fi

echo ""
echo "5️⃣ REINICIANDO DASHBOARD"
echo "========================"

# Parar dashboard
sudo pkill -f dashboard.py
sleep 2

# Iniciar dashboard
cd /home/homeguard/HomeGuard
python3 web/dashboard.py > dashboard_views_fixed.log 2>&1 &
DASHBOARD_PID=$!

sleep 3
echo "   ✅ Dashboard reiniciado (PID: $DASHBOARD_PID)"

echo ""
echo "6️⃣ TESTANDO APIS CORRIGIDAS"
echo "==========================="

sleep 2

# Testar API de temperatura
TEMP_API_COUNT=$(curl -s "http://localhost:5000/api/temperature/data?hours=1" | jq '. | length' 2>/dev/null || echo "ERRO")
echo "   🌡️ API temperatura retorna: $TEMP_API_COUNT registros"

# Testar API de umidade
HUMIDITY_API_COUNT=$(curl -s "http://localhost:5000/api/humidity/data?hours=1" | jq '. | length' 2>/dev/null || echo "ERRO")
echo "   💧 API umidade retorna: $HUMIDITY_API_COUNT registros"

echo ""
echo "✅ CORREÇÃO CONCLUÍDA!"
echo "====================="
echo ""
echo "📊 RESULTADOS:"
echo "   📦 Dados na tabela: Temp=$TEMP_COUNT, Umid=$HUMIDITY_COUNT"
echo "   📋 Views corrigidas: Temp=$NEW_TEMP_COUNT, Umid=$NEW_HUMIDITY_COUNT"
echo "   🌐 APIs funcionando: Temp=$TEMP_API_COUNT, Umid=$HUMIDITY_API_COUNT"
echo ""
echo "🧪 TESTE AGORA:"
echo "   Dashboard: http://$(hostname -I | awk '{print $1}'):5000/"
echo "   Ultra-básico: http://$(hostname -I | awk '{print $1}'):5000/ultra-basic"
echo ""
echo "🎯 O ultra-básico DEVE mostrar dados agora!"
echo "   Se mostrar: problema era nas views"
echo "   Se não mostrar: verificar logs em dashboard_views_fixed.log"
