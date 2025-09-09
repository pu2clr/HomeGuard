#!/bin/bash
"""
Exemplos Práticos de Consultas SQL JSON para HomeGuard
"""

echo "🗃️  Exemplos de Consultas SQL JSON para HomeGuard"
echo "==============================================="

DB_PATH="$HOME/HomeGuard/db/homeguard.db"

echo "📍 Caminho do banco: $DB_PATH"
echo ""

# Verificar se o banco existe
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Banco de dados não encontrado!"
    echo "   Execute primeiro: python3 web/init_database.py"
    exit 1
fi

echo "1️⃣  Verificar estrutura da tabela:"
echo "================================"
sqlite3 "$DB_PATH" ".schema activity"
echo ""

echo "2️⃣  Total de registros:"
echo "====================="
sqlite3 "$DB_PATH" "SELECT COUNT(*) as total_records FROM activity;"
echo ""

echo "3️⃣  Registros com JSON válido:"
echo "============================="
sqlite3 "$DB_PATH" "SELECT COUNT(*) as json_records FROM activity WHERE json_valid(message) = 1;"
echo ""

echo "4️⃣  Tópicos únicos (últimas 24h):"
echo "================================"
sqlite3 "$DB_PATH" -column -header \
"SELECT DISTINCT topic, COUNT(*) as count 
FROM activity 
WHERE created_at >= datetime('now', '-24 hours') 
GROUP BY topic 
ORDER BY count DESC 
LIMIT 10;"
echo ""

echo "5️⃣  Dispositivos identificados via JSON:"
echo "======================================="
sqlite3 "$DB_PATH" -column -header \
"SELECT DISTINCT 
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    COUNT(*) as messages
FROM activity 
WHERE json_valid(message) = 1 
    AND json_extract(message, '$.device_id') IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
GROUP BY json_extract(message, '$.device_id')
ORDER BY messages DESC;"
echo ""

echo "6️⃣  Exemplo: Dados de temperatura (se existirem):"
echo "==============================================="
sqlite3 "$DB_PATH" -column -header \
"SELECT 
    created_at,
    json_extract(message, '$.device_id') as device,
    json_extract(message, '$.temperature') as temp,
    json_extract(message, '$.unit') as unit,
    json_extract(message, '$.location') as location
FROM activity 
WHERE json_valid(message) = 1 
    AND json_extract(message, '$.temperature') IS NOT NULL
ORDER BY created_at DESC 
LIMIT 5;"
echo ""

echo "7️⃣  Exemplo: Comandos SQL para copy & paste:"
echo "=========================================="
echo ""
echo "# Conectar ao banco SQLite:"
echo "sqlite3 $DB_PATH"
echo ""
echo "# Configurar output legível:"
echo ".mode column"
echo ".headers on"
echo ""
echo "# Buscar temperaturas do ESP01_DHT22_BRANCO:"
echo "SELECT created_at, json_extract(message, '$.temperature') as temp"
echo "FROM activity" 
echo "WHERE topic = 'home/temperature/ESP01_DHT22_BRANCO/data'"
echo "    AND json_valid(message) = 1"
echo "ORDER BY created_at DESC LIMIT 10;"
echo ""
echo "# Estatísticas de temperatura:"
echo "SELECT"
echo "    COUNT(*) as readings,"
echo "    ROUND(AVG(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as avg_temp,"
echo "    ROUND(MIN(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as min_temp,"
echo "    ROUND(MAX(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as max_temp"
echo "FROM activity"
echo "WHERE topic = 'home/temperature/ESP01_DHT22_BRANCO/data'"
echo "    AND json_valid(message) = 1;"
echo ""

echo "✅ Para executar consultas personalizadas:"
echo "   sqlite3 $DB_PATH"
echo "   Consulte o arquivo SQL_JSON_QUERIES.md para mais exemplos!"
