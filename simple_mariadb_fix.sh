#!/bin/bash

# Simple MariaDB Fix for HomeGuard
# Resolve o ERROR 1698 usando comandos básicos

echo "🔧 HomeGuard - MariaDB Simple Fix"
echo "=================================="

# Verificar MariaDB
if ! sudo systemctl is-active --quiet mariadb; then
    echo "Iniciando MariaDB..."
    sudo systemctl start mariadb
fi

echo "✅ MariaDB rodando"

# Solicitar senha
echo
echo -n "Senha para usuário homeguard (8+ chars): "
read -s PASS
echo

if [ ${#PASS} -lt 8 ]; then
    echo "❌ Senha muito curta!"
    exit 1
fi

echo "🔧 Configurando..."

# Usar comandos MariaDB simples e compatíveis
sudo mysql <<EOF
-- Criar database primeiro
CREATE DATABASE IF NOT EXISTS homeguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Remover usuário se existir (ignora erro se não existir)  
DROP USER IF EXISTS 'homeguard'@'localhost';
DROP USER IF EXISTS 'homeguard'@'%';

-- Criar usuário homeguard com privilégios no database homeguard
CREATE USER 'homeguard'@'localhost' IDENTIFIED BY '$PASS';
CREATE USER 'homeguard'@'%' IDENTIFIED BY '$PASS';

-- Conceder todos os privilégios no database homeguard
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'localhost';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';

-- Aplicar mudanças
FLUSH PRIVILEGES;

-- Verificar usuários criados
SELECT User, Host FROM mysql.user WHERE User='homeguard';
EOF

if [ $? -eq 0 ]; then
    echo "✅ Usuário homeguard criado"
    
    # Testar conexão
    if mysql -u homeguard -p$PASS -e "SELECT 'OK' as status;" homeguard 2>/dev/null; then
        echo "✅ Conexão funcionando"
        
        # Criar tabelas básicas
        mysql -u homeguard -p$PASS homeguard <<EOF
CREATE TABLE IF NOT EXISTS motion_sensors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255),
    device_name VARCHAR(255),
    location VARCHAR(255),
    motion_detected BOOLEAN,
    rssi INT,
    uptime INT,
    battery_level DECIMAL(5,2),
    timestamp_received DATETIME,
    unix_timestamp BIGINT,
    raw_payload TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dht11_sensors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255),
    device_name VARCHAR(255), 
    location VARCHAR(255),
    sensor_type VARCHAR(50),
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    rssi INT,
    uptime INT,
    timestamp_received DATETIME,
    raw_payload TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sensor_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255),
    device_name VARCHAR(255),
    location VARCHAR(255),
    alert_type VARCHAR(100),
    sensor_value DECIMAL(8,2),
    threshold_value DECIMAL(8,2),
    message TEXT,
    severity VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    timestamp_created DATETIME,
    timestamp_resolved DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
        
        if [ $? -eq 0 ]; then
            echo "✅ Tabelas criadas"
            
            # Atualizar config se existir  
            if [ -f "web/config_mysql.json" ]; then
                cp web/config_mysql.json web/config_mysql.json.bak
                sed -i "s/your_homeguard_password_here/$PASS/" web/config_mysql.json
                echo "✅ Config atualizado"
            fi
            
            echo
            echo "🎉 SUCESSO!"
            echo "=========="
            echo "✅ Usuário: homeguard"
            echo "✅ Database: homeguard" 
            echo "✅ Tabelas criadas"
            echo
            echo "🚀 Execute:"
            echo "   cd web/"
            echo "   python3 homeguard_flask_mysql.py"
            
        else
            echo "⚠️  Usuário OK, mas erro nas tabelas"
        fi
    else
        echo "⚠️  Usuário criado mas teste de conexão falhou"
    fi
else
    echo "❌ Erro na configuração"
    echo "💡 Tente: sudo mysql_secure_installation"
fi
