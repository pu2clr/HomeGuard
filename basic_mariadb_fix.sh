#!/bin/bash

# HomeGuard - Correção Básica MariaDB
# Script mínimo para resolver ERROR 1698

echo "🔧 HomeGuard - Correção Básica MariaDB"
echo "======================================"

# Verificar se MariaDB está rodando
if ! sudo systemctl is-active --quiet mariadb; then
    echo "Iniciando MariaDB..."
    sudo systemctl start mariadb
fi

echo "✅ MariaDB está rodando"
echo

# Solicitar senha para homeguard
while true; do
    echo -n "Digite a senha para homeguard (min 8 chars): "
    read -s PASS
    echo
    
    if [ ${#PASS} -ge 8 ]; then
        break
    else
        echo "❌ Senha muito curta! Mínimo 8 caracteres."
    fi
done

echo "🔧 Configurando database e usuário..."

# Executar comandos SQL básicos
sudo mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS homeguard;
CREATE USER IF NOT EXISTS 'homeguard'@'localhost' IDENTIFIED BY '$PASS';
CREATE USER IF NOT EXISTS 'homeguard'@'%' IDENTIFIED BY '$PASS';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'localhost';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';
FLUSH PRIVILEGES;
EOF

# Verificar se funcionou
if [ $? -eq 0 ]; then
    echo "✅ Database e usuário configurados"
    
    # Testar conexão
    echo "🔍 Testando conexão..."
    if mysql -u homeguard -p$PASS -e "SELECT 'Conexão OK' as status;" homeguard 2>/dev/null; then
        echo "✅ Conexão homeguard funcionando"
        
        # Criar tabelas essenciais
        echo "📊 Criando tabelas..."
        mysql -u homeguard -p$PASS homeguard <<EOF
CREATE TABLE IF NOT EXISTS motion_sensors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    location VARCHAR(255),
    motion_detected BOOLEAN,
    timestamp_received DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dht11_sensors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    location VARCHAR(255),
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    timestamp_received DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sensor_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    alert_type VARCHAR(100),
    message TEXT,
    timestamp_created DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
        
        if [ $? -eq 0 ]; then
            echo "✅ Tabelas criadas"
            
            # Atualizar configuração se existe
            if [ -f "web/config_mysql.json" ]; then
                echo "🔧 Atualizando configuração..."
                cp web/config_mysql.json web/config_mysql.json.backup 2>/dev/null
                sed -i.bak "s/your_homeguard_password_here/$PASS/g" web/config_mysql.json 2>/dev/null
                echo "✅ Configuração atualizada"
            fi
            
            echo
            echo "🎉 CONFIGURAÇÃO COMPLETA!"
            echo "========================="
            echo "✅ Database: homeguard"
            echo "✅ Usuário: homeguard"  
            echo "✅ Tabelas: motion_sensors, dht11_sensors, sensor_alerts"
            echo "✅ Conectividade: OK"
            echo
            echo "🚀 Próximo passo:"
            echo "   cd web/"
            echo "   python3 homeguard_flask_mysql.py"
            echo
            echo "📱 Dashboard: http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'localhost'):5000"
            
        else
            echo "⚠️  Usuário OK, mas erro ao criar tabelas"
            echo "💡 Execute manualmente: mysql -u homeguard -p"
        fi
        
    else
        echo "❌ Erro na conexão do usuário homeguard"
        echo "💡 Verifique a senha e tente novamente"
    fi
    
else
    echo "❌ Erro na configuração básica"
    echo "💡 Possíveis soluções:"
    echo "   - sudo systemctl restart mariadb"
    echo "   - sudo mysql_secure_installation"
    echo "   - Verificar logs: sudo journalctl -u mariadb"
fi
