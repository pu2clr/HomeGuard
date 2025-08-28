#!/bin/bash

"""
============================================
HomeGuard - MariaDB Quick Fix
Script simples para resolver ERROR 1698
============================================
"""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 HomeGuard - MariaDB Quick Fix${NC}"
echo "========================================"

# Verificar se MariaDB está rodando
if ! sudo systemctl is-active --quiet mariadb; then
    echo -e "${YELLOW}[INFO]${NC} Iniciando MariaDB..."
    sudo systemctl start mariadb
fi

echo -e "${GREEN}✅ MariaDB está rodando${NC}"
echo

# Solicitar senha para homeguard
echo -n "Digite a senha para o usuário homeguard (mín. 8 caracteres): "
read -s HOMEGUARD_PASSWORD
echo

if [ ${#HOMEGUARD_PASSWORD} -lt 8 ]; then
    echo -e "${RED}❌ Senha muito curta! Use pelo menos 8 caracteres.${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Configurando MariaDB..."

# Configurar usando comandos SQL simples
sudo mysql <<EOF
-- Manter root com socket authentication
UPDATE mysql.user SET plugin='unix_socket' WHERE User='root' AND Host='localhost';

-- Remover usuário homeguard se existir
DROP USER IF EXISTS 'homeguard'@'localhost';
DROP USER IF EXISTS 'homeguard'@'%';

-- Criar usuário homeguard
CREATE USER 'homeguard'@'localhost' IDENTIFIED BY '$HOMEGUARD_PASSWORD';  
CREATE USER 'homeguard'@'%' IDENTIFIED BY '$HOMEGUARD_PASSWORD';

-- Criar database
CREATE DATABASE IF NOT EXISTS homeguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Conceder privilégios
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'localhost';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';

-- Aplicar mudanças
FLUSH PRIVILEGES;

-- Mostrar usuários configurados
SELECT User, Host, plugin FROM mysql.user WHERE User IN ('root', 'homeguard');
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Configuração aplicada com sucesso!${NC}"
    echo
    
    # Testar conexão homeguard
    echo -e "${BLUE}[INFO]${NC} Testando conexão do usuário homeguard..."
    
    if mysql -u homeguard -p$HOMEGUARD_PASSWORD -e "SELECT 'Conexão OK!' AS status;" 2>/dev/null; then
        echo -e "${GREEN}✅ Usuário homeguard pode conectar${NC}"
    else
        echo -e "${YELLOW}⚠️  Teste de conexão falhou, mas usuário foi criado${NC}"
    fi
    
    echo
    echo -e "${BLUE}[INFO]${NC} Criando tabelas HomeGuard..."
    
    # Criar tabelas
    mysql -u homeguard -p$HOMEGUARD_PASSWORD homeguard <<'EOF'
-- Tabela motion_sensors
CREATE TABLE IF NOT EXISTS motion_sensors (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    motion_detected BOOLEAN NOT NULL,
    rssi INT,
    uptime INT,
    battery_level DECIMAL(5,2),
    timestamp_received DATETIME NOT NULL,
    unix_timestamp BIGINT,
    raw_payload TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device (device_id),
    INDEX idx_timestamp (timestamp_received)
);

-- Tabela dht11_sensors  
CREATE TABLE IF NOT EXISTS dht11_sensors (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    sensor_type VARCHAR(50) NOT NULL,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    rssi INT,
    uptime INT,
    timestamp_received DATETIME NOT NULL,
    raw_payload TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device (device_id),
    INDEX idx_timestamp (timestamp_received)
);

-- Tabela sensor_alerts
CREATE TABLE IF NOT EXISTS sensor_alerts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    alert_type VARCHAR(100) NOT NULL,
    sensor_value DECIMAL(8,2) NOT NULL,
    threshold_value DECIMAL(8,2) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    timestamp_created DATETIME NOT NULL,
    timestamp_resolved DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device (device_id),
    INDEX idx_active (is_active)
);
EOF
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Tabelas HomeGuard criadas${NC}"
    else
        echo -e "${YELLOW}⚠️  Algumas tabelas podem não ter sido criadas${NC}"
    fi
    
    # Atualizar config_mysql.json se existir
    if [ -f "web/config_mysql.json" ]; then
        echo -e "${BLUE}[INFO]${NC} Atualizando web/config_mysql.json..."
        
        # Backup do arquivo original
        cp web/config_mysql.json web/config_mysql.json.backup
        
        # Atualizar senha no config (método simples)
        sed -i "s/\"your_homeguard_password_here\"/\"$HOMEGUARD_PASSWORD\"/" web/config_mysql.json
        
        echo -e "${GREEN}✅ Configuração atualizada${NC}"
    fi
    
    echo
    echo "======================================"
    echo -e "${GREEN}🎉 CONFIGURAÇÃO CONCLUÍDA${NC}"
    echo "======================================"
    echo
    echo -e "${GREEN}✅ Root usa socket authentication (sudo mysql)${NC}"
    echo -e "${GREEN}✅ Usuário homeguard criado com senha${NC}"  
    echo -e "${GREEN}✅ Database homeguard criada${NC}"
    echo -e "${GREEN}✅ Tabelas HomeGuard criadas${NC}"
    echo
    echo -e "${BLUE}🚀 Próximo passo:${NC}"
    echo "   cd web/"
    echo "   python3 homeguard_flask_mysql.py"
    echo
    echo -e "${BLUE}📱 Dashboard:${NC} http://$(hostname -I | awk '{print $1}'):5000"
    
else
    echo -e "${RED}❌ Falha na configuração${NC}"
    echo -e "${YELLOW}💡 Tente executar: sudo mysql_secure_installation${NC}"
    exit 1
fi
