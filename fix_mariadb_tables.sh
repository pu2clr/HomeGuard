#!/bin/bash

# HomeGuard - Verificação e Correção de Tabelas MariaDB
# Script para corrigir estrutura de tabelas para compatibilidade

echo "🔧 HomeGuard - Correção de Tabelas MariaDB"
echo "==========================================="

# Verificar se MariaDB está rodando
if ! sudo systemctl is-active --quiet mariadb; then
    echo "❌ MariaDB não está rodando"
    echo "💡 Execute: sudo systemctl start mariadb"
    exit 1
fi

echo "✅ MariaDB está rodando"

# Solicitar credenciais se necessário
if [ -z "$1" ]; then
    echo -n "Digite a senha do usuário homeguard: "
    read -s MYSQL_PASSWORD
    echo
else
    MYSQL_PASSWORD="$1"
fi

echo "🔍 Verificando estrutura das tabelas..."

# Conectar e verificar tabelas
mysql -u homeguard -p$MYSQL_PASSWORD homeguard <<EOF
-- Mostrar estrutura atual das tabelas
DESCRIBE motion_sensors;
DESCRIBE dht11_sensors;
DESCRIBE sensor_alerts;
EOF

if [ $? -ne 0 ]; then
    echo "❌ Erro ao conectar no database"
    echo "💡 Execute: ./basic_mariadb_fix.sh"
    exit 1
fi

echo
echo "🔧 Atualizando estrutura das tabelas para compatibilidade completa..."

# Atualizar tabelas para incluir todas as colunas necessárias
mysql -u homeguard -p$MYSQL_PASSWORD homeguard <<'EOF'
-- Adicionar colunas faltantes na tabela motion_sensors
ALTER TABLE motion_sensors 
ADD COLUMN IF NOT EXISTS unix_timestamp BIGINT,
ADD COLUMN IF NOT EXISTS raw_payload TEXT,
ADD COLUMN IF NOT EXISTS rssi INT,
ADD COLUMN IF NOT EXISTS uptime INT,
ADD COLUMN IF NOT EXISTS battery_level DECIMAL(5,2);

-- Adicionar colunas faltantes na tabela dht11_sensors
ALTER TABLE dht11_sensors
ADD COLUMN IF NOT EXISTS raw_payload TEXT,
ADD COLUMN IF NOT EXISTS rssi INT,
ADD COLUMN IF NOT EXISTS uptime INT;

-- Adicionar colunas faltantes na tabela sensor_alerts
ALTER TABLE sensor_alerts
ADD COLUMN IF NOT EXISTS device_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS location VARCHAR(255),
ADD COLUMN IF NOT EXISTS sensor_value DECIMAL(8,2),
ADD COLUMN IF NOT EXISTS threshold_value DECIMAL(8,2),
ADD COLUMN IF NOT EXISTS message TEXT,
ADD COLUMN IF NOT EXISTS severity VARCHAR(20),
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS timestamp_resolved DATETIME NULL;

-- Atualizar valores padrão onde necessário
UPDATE sensor_alerts SET is_active = TRUE WHERE is_active IS NULL;
UPDATE sensor_alerts SET severity = 'medium' WHERE severity IS NULL OR severity = '';

-- Adicionar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_motion_device ON motion_sensors(device_id);
CREATE INDEX IF NOT EXISTS idx_motion_timestamp ON motion_sensors(timestamp_received);
CREATE INDEX IF NOT EXISTS idx_dht11_device ON dht11_sensors(device_id);
CREATE INDEX IF NOT EXISTS idx_dht11_timestamp ON dht11_sensors(timestamp_received);
CREATE INDEX IF NOT EXISTS idx_alerts_device ON sensor_alerts(device_id);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON sensor_alerts(is_active);
CREATE INDEX IF NOT EXISTS idx_alerts_created ON sensor_alerts(timestamp_created);

-- Mostrar estrutura final
SELECT 'motion_sensors structure:' as info;
DESCRIBE motion_sensors;

SELECT 'dht11_sensors structure:' as info;
DESCRIBE dht11_sensors;

SELECT 'sensor_alerts structure:' as info;
DESCRIBE sensor_alerts;

EOF

if [ $? -eq 0 ]; then
    echo "✅ Tabelas atualizadas com sucesso!"
    
    echo
    echo "🧪 Testando inserção de dados..."
    
    # Testar inserção
    mysql -u homeguard -p$MYSQL_PASSWORD homeguard <<EOF
-- Inserir dados de teste
INSERT INTO motion_sensors (device_id, device_name, location, motion_detected, timestamp_received, unix_timestamp) 
VALUES ('test_001', 'Sensor Teste', 'Teste Location', TRUE, NOW(), UNIX_TIMESTAMP());

INSERT INTO dht11_sensors (device_id, device_name, location, sensor_type, temperature, humidity, timestamp_received) 
VALUES ('test_dht_001', 'DHT11 Teste', 'Teste Location', 'DHT11', 25.5, 60.0, NOW());

INSERT INTO sensor_alerts (device_id, device_name, location, alert_type, message, severity, timestamp_created) 
VALUES ('test_001', 'Sensor Teste', 'Teste Location', 'motion_detected', 'Movimento detectado durante teste', 'low', NOW());

-- Verificar inserções
SELECT COUNT(*) as motion_test FROM motion_sensors WHERE device_id = 'test_001';
SELECT COUNT(*) as dht_test FROM dht11_sensors WHERE device_id = 'test_dht_001';
SELECT COUNT(*) as alert_test FROM sensor_alerts WHERE device_id = 'test_001';

-- Limpar dados de teste
DELETE FROM motion_sensors WHERE device_id LIKE 'test_%';
DELETE FROM dht11_sensors WHERE device_id LIKE 'test_%';
DELETE FROM sensor_alerts WHERE device_id LIKE 'test_%';

SELECT 'Dados de teste removidos' as cleanup;
EOF

    if [ $? -eq 0 ]; then
        echo "✅ Testes de inserção passaram!"
        
        echo
        echo "🎉 TABELAS CORRIGIDAS COM SUCESSO!"
        echo "=================================="
        echo "✅ motion_sensors: Estrutura completa"
        echo "✅ dht11_sensors: Estrutura completa"  
        echo "✅ sensor_alerts: Estrutura completa"
        echo "✅ Índices criados para performance"
        echo "✅ Testes de inserção OK"
        
        echo
        echo "🚀 PRÓXIMO PASSO:"
        echo "   cd web/"
        echo "   python3 ../test_mysql_connection.py"
        echo "   python3 homeguard_flask_mysql.py"
        
    else
        echo "⚠️  Estrutura OK, mas erro nos testes de inserção"
    fi
    
else
    echo "❌ Erro ao atualizar estrutura das tabelas"
    echo "💡 Verifique logs: sudo journalctl -u mariadb"
fi

echo
echo "📊 RESUMO DA ESTRUTURA FINAL:"
mysql -u homeguard -p$MYSQL_PASSWORD homeguard -e "
SELECT 
    TABLE_NAME, 
    COUNT(*) as COLUMNS 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'homeguard' 
GROUP BY TABLE_NAME;
"
