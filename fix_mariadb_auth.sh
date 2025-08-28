#!/bin/bash

"""
============================================
HomeGuard - MariaDB Socket Auth Fix
Script para corrigir problema de autenticação
do MariaDB no Raspberry Pi
============================================
"""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para print colorido
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🔧 HomeGuard - MariaDB Socket Authentication Fix"
echo "================================================"

# Verificar se MariaDB está rodando
if ! sudo systemctl is-active --quiet mariadb; then
    print_error "MariaDB não está rodando"
    print_info "Tentando iniciar MariaDB..."
    sudo systemctl start mariadb
    if ! sudo systemctl is-active --quiet mariadb; then
        print_error "Falha ao iniciar MariaDB"
        exit 1
    fi
fi

print_success "MariaDB está rodando"

# Explicar o problema
echo
print_info "PROBLEMA DETECTADO:"
echo "   O MariaDB usa 'socket authentication' por padrão para o usuário root"
echo "   Isso significa que root só pode conectar via 'sudo mysql' (não por senha)"
echo
print_info "SOLUÇÕES DISPONÍVEIS:"
echo "   1. Manter socket auth e usar sempre 'sudo mysql'"  
echo "   2. Alterar para password auth (tradicional MySQL)"
echo "   3. Configurar ambos os métodos"
echo

# Solicitar escolha
while true; do
    echo -n "Escolha uma opção (1/2/3): "
    read -n 1 -r CHOICE
    echo
    
    case $CHOICE in
        1)
            SOLUTION="socket"
            break
            ;;
        2) 
            SOLUTION="password"
            break
            ;;
        3)
            SOLUTION="both"
            break
            ;;
        *)
            print_warning "Opção inválida. Digite 1, 2 ou 3."
            ;;
    esac
done

# Implementar solução escolhida
case $SOLUTION in
    "socket")
        print_info "Configurando para usar APENAS socket authentication..."
        echo
        print_info "Com essa configuração:"
        echo "   - Root conecta via: sudo mysql"
        echo "   - Aplicação usa usuário homeguard (com senha)"
        echo "   - Mais seguro (root não usa senha)"
        
        # Garantir que root está configurado para socket
        sudo mysql -u root <<'EOF'
-- Garantir que root usa socket auth
UPDATE mysql.user SET plugin='unix_socket' WHERE User='root';
FLUSH PRIVILEGES;
SELECT User, Host, plugin FROM mysql.user WHERE User='root';
EOF
        
        print_success "Root configurado para socket authentication"
        echo
        print_info "Para conectar como root, use: sudo mysql"
        ;;
        
    "password")
        print_info "Configurando para usar password authentication..."
        
        # Solicitar senha
        while true; do
            echo -n "Digite a nova senha para root: "
            read -s ROOT_PASSWORD
            echo
            echo -n "Confirme a senha: "  
            read -s ROOT_PASSWORD_CONFIRM
            echo
            
            if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
                if [ ${#ROOT_PASSWORD} -ge 8 ]; then
                    break
                else
                    print_warning "Senha muito curta! Use pelo menos 8 caracteres."
                fi
            else
                print_warning "Senhas não coincidem. Tente novamente."
            fi
        done
        
        # Configurar password auth
        sudo mysql -u root <<EOF
-- Alterar root para usar password auth
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_PASSWORD';
FLUSH PRIVILEGES;
SELECT User, Host, plugin FROM mysql.user WHERE User='root';
EOF
        
        if [ $? -eq 0 ]; then
            print_success "Root configurado para password authentication"
            echo
            print_info "Para conectar como root, use: mysql -u root -p"
            
            # Testar nova configuração
            if mysql -u root -p$ROOT_PASSWORD -e "SELECT 'Conexão com senha OK' AS status;" 2>/dev/null; then
                print_success "Teste de conexão com senha bem-sucedido"
            else
                print_warning "Teste de conexão falhou, mas configuração foi aplicada"
            fi
        else
            print_error "Falha na configuração de password auth"
            exit 1
        fi
        ;;
        
    "both")
        print_info "Configurando para usar AMBOS os métodos..."
        
        # Solicitar senha
        while true; do
            echo -n "Digite a senha para root: "
            read -s ROOT_PASSWORD
            echo
            echo -n "Confirme a senha: "
            read -s ROOT_PASSWORD_CONFIRM  
            echo
            
            if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
                if [ ${#ROOT_PASSWORD} -ge 8 ]; then
                    break
                else
                    print_warning "Senha muito curta! Use pelo menos 8 caracteres."
                fi
            else
                print_warning "Senhas não coincidem. Tente novamente."
            fi
        done
        
        # Configurar ambos métodos
        sudo mysql -u root <<EOF
-- Manter root@localhost com socket auth
UPDATE mysql.user SET plugin='unix_socket' WHERE User='root' AND Host='localhost';

-- Criar root@% com password auth para acesso remoto
DROP USER IF EXISTS 'root'@'%';
CREATE USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;
SELECT User, Host, plugin FROM mysql.user WHERE User='root';
EOF
        
        if [ $? -eq 0 ]; then
            print_success "Configuração híbrida aplicada"
            echo
            print_info "Métodos de conexão:"
            echo "   - Local com socket: sudo mysql"
            echo "   - Local/remoto com senha: mysql -u root -p"
            
            # Testar ambas conexões
            if mysql -u root -p$ROOT_PASSWORD -e "SELECT 'Conexão com senha OK' AS status;" 2>/dev/null; then
                print_success "Conexão com senha funciona"
            fi
            
            if sudo mysql -u root -e "SELECT 'Conexão socket OK' AS status;" 2>/dev/null; then
                print_success "Conexão socket funciona"
            fi
        else
            print_error "Falha na configuração híbrida"
            exit 1
        fi
        ;;
esac

# Configurar usuário homeguard se não existir
print_info "Verificando usuário homeguard..."

if ! sudo mysql -u root -e "SELECT User FROM mysql.user WHERE User='homeguard';" 2>/dev/null | grep -q homeguard; then
    print_info "Usuário homeguard não encontrado, criando..."
    
    echo -n "Digite a senha para o usuário homeguard: "
    read -s HOMEGUARD_PASSWORD
    echo
    
    sudo mysql -u root <<EOF
CREATE USER IF NOT EXISTS 'homeguard'@'%' IDENTIFIED BY '$HOMEGUARD_PASSWORD';
CREATE USER IF NOT EXISTS 'homeguard'@'localhost' IDENTIFIED BY '$HOMEGUARD_PASSWORD';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Usuário homeguard criado"
        
        # Testar conexão homeguard
        if mysql -u homeguard -p$HOMEGUARD_PASSWORD -e "SELECT 'homeguard OK' AS status;" 2>/dev/null; then
            print_success "Usuário homeguard pode conectar"
        else
            print_warning "Usuário homeguard criado mas conexão falhou"
        fi
    else
        print_error "Falha ao criar usuário homeguard"
    fi
else
    print_success "Usuário homeguard já existe"
fi

# Criar database se não existir
print_info "Verificando database homeguard..."

if ! sudo mysql -u root -e "SHOW DATABASES;" | grep -q homeguard; then
    print_info "Database homeguard não encontrada, criando..."
    
    sudo mysql -u root <<'EOF'
CREATE DATABASE IF NOT EXISTS homeguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE homeguard;

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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_motion_device ON motion_sensors(device_id);
CREATE INDEX IF NOT EXISTS idx_motion_timestamp ON motion_sensors(timestamp_received);
CREATE INDEX IF NOT EXISTS idx_dht11_device ON dht11_sensors(device_id);
CREATE INDEX IF NOT EXISTS idx_dht11_timestamp ON dht11_sensors(timestamp_received);
CREATE INDEX IF NOT EXISTS idx_alerts_device ON sensor_alerts(device_id);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON sensor_alerts(is_active);

-- Privilégios
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Database homeguard criada"
    else
        print_error "Falha ao criar database"
    fi
else
    print_success "Database homeguard já existe"
fi

# Resumo final
echo
echo "======================================"
echo "🎉 CONFIGURAÇÃO CONCLUÍDA"
echo "======================================"
echo

case $SOLUTION in
    "socket")
        echo "✅ Root configurado para socket authentication"
        echo "   Conexão root: sudo mysql"
        ;;
    "password")
        echo "✅ Root configurado para password authentication"  
        echo "   Conexão root: mysql -u root -p"
        ;;
    "both")
        echo "✅ Root configurado para ambos métodos"
        echo "   Socket: sudo mysql"
        echo "   Password: mysql -u root -p"
        ;;
esac

echo "✅ Usuário homeguard configurado"
echo "✅ Database homeguard criada"
echo "✅ Tabelas HomeGuard criadas"
echo
echo "🚀 Próximo passo:"
echo "   cd /home/pi/HomeGuard/web"  
echo "   python3 homeguard_flask_mysql.py"
echo
echo "📱 Dashboard: http://$(hostname -I | awk '{print $1}'):5000"
