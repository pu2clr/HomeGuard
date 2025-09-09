#!/bin/bash
# 
# Script para corrigir a view vw_humidity_activity no Raspberry Pi
# Executa as correções no banco de dados
#

echo "🔧 Corrigindo view vw_humidity_activity no HomeGuard..."
echo "=================================================="

# Diretório do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DB_PATH="$PROJECT_DIR/db/homeguard.db"

echo "📁 Banco de dados: $DB_PATH"

# Verificar se banco existe
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Arquivo do banco não encontrado: $DB_PATH"
    exit 1
fi

echo "1️⃣ Removendo view incorreta..."
sqlite3 "$DB_PATH" "DROP VIEW IF EXISTS vw_humidity_activity;"

echo "2️⃣ Criando view corrigida..."
sqlite3 "$DB_PATH" "CREATE VIEW vw_humidity_activity as
SELECT 
    created_at,
    json_extract(message, '\$.device_id') as device_id,
    json_extract(message, '\$.name') as name,
    json_extract(message, '\$.location') as location,
    json_extract(message, '\$.sensor_type') as sensor_type,
    json_extract(message, '\$.humidity') as humidity,
    json_extract(message, '\$.unit') as unit,
    json_extract(message, '\$.rssi') as rssi,
    json_extract(message, '\$.uptime') as uptime
FROM activity 
WHERE topic like 'home/humidity/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '\$.humidity') IS NOT NULL
ORDER BY created_at DESC;"

# Verificar se foi criada corretamente
COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM vw_humidity_activity;")
echo "3️⃣ Verificando view corrigida..."
echo "   📊 Registros encontrados: $COUNT"

if [ "$COUNT" -gt 0 ]; then
    echo "✅ View corrigida com sucesso!"
    echo ""
    echo "🔍 Testando um registro:"
    sqlite3 "$DB_PATH" "SELECT device_id, location, humidity, unit, created_at FROM vw_humidity_activity LIMIT 1;" | while IFS='|' read -r device_id location humidity unit created_at; do
        echo "   Device: $device_id"
        echo "   Local: $location"
        echo "   Umidade: $humidity$unit"
        echo "   Timestamp: $created_at"
    done
else
    echo "⚠️ View criada mas sem dados. Verifique se há dados de umidade no banco."
fi

echo ""
echo "🚀 Próximos passos:"
echo "   1. Reinicie o dashboard: sudo systemctl restart mqtt-service"
echo "   2. Ou execute manualmente: cd $PROJECT_DIR/web && python3 dashboard.py"
echo "   3. Teste os botões no dashboard web"
echo ""
echo "📝 Log de APIs disponível em: journalctl -u mqtt-service -f"
