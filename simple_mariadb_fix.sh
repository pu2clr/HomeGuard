#!/bin/bash

"""
Simple MariaDB Fix for HomeGuard
Resolve o ERROR 1698 usando comandos básicos
"""

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

# Usar comandos MySQL simples que funcionam no MariaDB
sudo mysql -e "
SET sql_mode = '';
DELETE FROM mysql.user WHERE User='homeguard';
INSERT INTO mysql.user (User, Host, Password, Select_priv, Insert_priv, Update_priv, Delete_priv, Create_priv, Drop_priv, Grant_priv, References_priv, Index_priv, Alter_priv) 
VALUES ('homeguard', 'localhost', PASSWORD('$PASS'), 'N','N','N','N','N','N','N','N','N','N');
INSERT INTO mysql.user (User, Host, Password, Select_priv, Insert_priv, Update_priv, Delete_priv, Create_priv, Drop_priv, Grant_priv, References_priv, Index_priv, Alter_priv)  
VALUES ('homeguard', '%', PASSWORD('$PASS'), 'N','N','N','N','N','N','N','N','N','N');
CREATE DATABASE IF NOT EXISTS homeguard;
INSERT INTO mysql.db VALUES ('%', 'homeguard', 'homeguard', 'Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y');
INSERT INTO mysql.db VALUES ('localhost', 'homeguard', 'homeguard', 'Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y');
FLUSH PRIVILEGES;
"

if [ $? -eq 0 ]; then
    echo "✅ Usuário homeguard criado"
    
    # Testar conexão
    if mysql -u homeguard -p$PASS -e "SELECT 'OK' as status;" homeguard 2>/dev/null; then
        echo "✅ Conexão funcionando"
        
        # Criar tabelas básicas
        mysql -u homeguard -p$PASS homeguard -e "
        CREATE TABLE IF NOT EXISTS motion_sensors (
            id INT AUTO_INCREMENT PRIMARY KEY,
            device_id VARCHAR(255),
            device_name VARCHAR(255),
            location VARCHAR(255),
            motion_detected BOOLEAN,
            timestamp_received DATETIME,
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
            timestamp_received DATETIME,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS sensor_alerts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            device_id VARCHAR(255),
            alert_type VARCHAR(100),
            message TEXT,
            timestamp_created DATETIME,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );"
        
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
