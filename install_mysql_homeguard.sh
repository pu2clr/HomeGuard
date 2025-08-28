#!/bin/bash

"""
============================================
HomeGuard - MySQL Installation Script
Script de instalação automática do MySQL Server
para Raspberry Pi 4
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

# Verificar se está rodando como root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Este script não deve ser executado como root!"
        print_info "Execute como usuário normal (pi). O script usará sudo quando necessário."
        exit 1
    fi
}

# Verificar conectividade com internet
check_internet() {
    print_info "Verificando conectividade com internet..."
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "Sem conexão com internet. Verifique sua conexão."
        exit 1
    fi
    print_success "Conexão com internet OK"
}

# Atualizar sistema
update_system() {
    print_info "Atualizando sistema..."
    sudo apt update
    if [ $? -eq 0 ]; then
        sudo apt upgrade -y
        print_success "Sistema atualizado"
    else
        print_error "Falha ao atualizar sistema"
        exit 1
    fi
}

# Instalar MySQL Server
install_mysql() {
    print_info "Instalando MySQL Server..."
    
    # Configurar instalação não-interativa
    sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password temp_password'
    sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password temp_password'
    
    sudo apt install mysql-server -y
    
    if [ $? -eq 0 ]; then
        print_success "MySQL Server instalado"
    else
        print_error "Falha ao instalar MySQL Server"
        exit 1
    fi
}

# Iniciar e habilitar MySQL
start_mysql() {
    print_info "Iniciando serviço MySQL..."
    sudo systemctl start mysql
    sudo systemctl enable mysql
    
    if sudo systemctl is-active --quiet mysql; then
        print_success "MySQL está rodando"
    else
        print_error "Falha ao iniciar MySQL"
        exit 1
    fi
}

# Configurar segurança do MySQL
secure_mysql() {
    print_info "Configurando segurança do MySQL..."
    
    # Solicitar senha do root
    echo
    echo "=============================================="
    echo "CONFIGURAÇÃO DE SEGURANÇA DO MYSQL"
    echo "=============================================="
    echo
    
    while true; do
        echo -n "Digite a senha para o usuário root do MySQL: "
        read -s ROOT_PASSWORD
        echo
        echo -n "Confirme a senha: "
        read -s ROOT_PASSWORD_CONFIRM
        echo
        
        if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
            if [ ${#ROOT_PASSWORD} -lt 8 ]; then
                print_warning "Senha muito curta! Use pelo menos 8 caracteres."
                continue
            fi
            break
        else
            print_warning "Senhas não coincidem. Tente novamente."
        fi
    done
    
    # Alterar senha temporária
    mysql -u root -ptemp_password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';" 2>/dev/null
    
    # Configurações de segurança
    mysql -u root -p$ROOT_PASSWORD <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1', '%');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Configuração de segurança aplicada"
    else
        print_error "Falha na configuração de segurança"
        exit 1
    fi
}

# Configurar acesso remoto
configure_remote_access() {
    print_info "Configurando acesso remoto..."
    
    # Backup do arquivo de configuração
    sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup
    
    # Alterar bind-address
    sudo sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
    
    print_success "Arquivo de configuração alterado"
}

# Criar usuário homeguard
create_homeguard_user() {
    print_info "Criando usuário homeguard..."
    
    echo
    echo -n "Digite a senha para o usuário 'homeguard': "
    read -s HOMEGUARD_PASSWORD
    echo
    
    mysql -u root -p$ROOT_PASSWORD <<EOF
CREATE USER IF NOT EXISTS 'homeguard'@'%' IDENTIFIED BY '$HOMEGUARD_PASSWORD';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';
UPDATE mysql.user SET host='%' WHERE user='root' AND host='localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Usuário homeguard criado"
        echo "🔑 Credenciais criadas:"
        echo "   - Usuário: homeguard"
        echo "   - Senha: [informada pelo usuário]"
    else
        print_error "Falha ao criar usuário homeguard"
        exit 1
    fi
}

# Criar database
create_database() {
    print_info "Criando database homeguard..."
    
    mysql -u root -p$ROOT_PASSWORD <<EOF
CREATE DATABASE IF NOT EXISTS homeguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE homeguard;

-- Criar tabelas HomeGuard
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

-- Criar índices para performance
CREATE INDEX idx_motion_device ON motion_sensors(device_id);
CREATE INDEX idx_motion_timestamp ON motion_sensors(timestamp_received);
CREATE INDEX idx_dht11_device ON dht11_sensors(device_id);
CREATE INDEX idx_dht11_timestamp ON dht11_sensors(timestamp_received);
CREATE INDEX idx_alerts_device ON sensor_alerts(device_id);
CREATE INDEX idx_alerts_active ON sensor_alerts(is_active);

-- Conceder privilégios específicos
GRANT SELECT, INSERT, UPDATE, DELETE ON homeguard.* TO 'homeguard'@'%';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Database e tabelas criadas"
    else
        print_error "Falha ao criar database"
        exit 1
    fi
}

# Reiniciar MySQL
restart_mysql() {
    print_info "Reiniciando MySQL..."
    sudo systemctl restart mysql
    
    if sudo systemctl is-active --quiet mysql; then
        print_success "MySQL reiniciado com sucesso"
    else
        print_error "Falha ao reiniciar MySQL"
        exit 1
    fi
}

# Configurar firewall
configure_firewall() {
    print_info "Configurando firewall..."
    
    if sudo ufw status | grep -q "Status: active"; then
        sudo ufw allow 3306/tcp
        print_success "Regra de firewall adicionada para porta 3306"
    else
        print_warning "UFW não está ativo, pulando configuração de firewall"
    fi
}

# Instalar dependências Python
install_python_deps() {
    print_info "Instalando dependências Python..."
    
    pip3 install mysql-connector-python PyMySQL --user
    
    if [ $? -eq 0 ]; then
        print_success "Dependências Python instaladas"
    else
        print_warning "Falha ao instalar algumas dependências Python"
        print_info "Tentando instalação alternativa..."
        sudo apt install python3-mysql.connector python3-pymysql -y
    fi
}

# Testar instalação
test_installation() {
    print_info "Testando instalação..."
    
    # Testar conexão local
    mysql -u root -p$ROOT_PASSWORD -e "SHOW DATABASES;" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Conexão root local OK"
    else
        print_error "Falha na conexão root local"
    fi
    
    # Testar usuário homeguard
    mysql -u homeguard -p$HOMEGUARD_PASSWORD -e "USE homeguard; SHOW TABLES;" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Usuário homeguard OK"
    else
        print_error "Falha na conexão do usuário homeguard"
    fi
    
    # Verificar se a porta está aberta
    if sudo netstat -tlnp | grep :3306 > /dev/null; then
        print_success "MySQL escutando na porta 3306"
    else
        print_warning "MySQL pode não estar escutando na porta 3306"
    fi
}

# Criar arquivo de configuração
create_config_file() {
    print_info "Criando arquivo de configuração..."
    
    cat > ~/homeguard_mysql_config.json <<EOF
{
    "mysql": {
        "host": "localhost",
        "port": 3306,
        "database": "homeguard",
        "user": "homeguard",
        "password": "$HOMEGUARD_PASSWORD",
        "charset": "utf8mb4",
        "autocommit": true
    },
    "installation": {
        "date": "$(date)",
        "raspberry_pi": true,
        "remote_access": true,
        "ssl_enabled": false
    },
    "backup": {
        "enabled": true,
        "directory": "/home/pi/backup/mysql",
        "retention_days": 7
    }
}
EOF
    
    chmod 600 ~/homeguard_mysql_config.json
    print_success "Arquivo de configuração criado: ~/homeguard_mysql_config.json"
}

# Criar script de backup
create_backup_script() {
    print_info "Criando script de backup..."
    
    mkdir -p ~/backup/mysql
    
    cat > ~/backup/mysql/backup_homeguard.sh <<'EOF'
#!/bin/bash
# HomeGuard MySQL Backup Script

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/pi/backup/mysql"
DB_NAME="homeguard"
MYSQL_USER="homeguard"

# Solicitar senha se não estiver definida
if [ -z "$MYSQL_PASSWORD" ]; then
    echo -n "Digite a senha do MySQL para $MYSQL_USER: "
    read -s MYSQL_PASSWORD
    echo
fi

# Criar backup
mysqldump -u $MYSQL_USER -p$MYSQL_PASSWORD $DB_NAME > $BACKUP_DIR/homeguard_$DATE.sql

if [ $? -eq 0 ]; then
    echo "✅ Backup criado: homeguard_$DATE.sql"
    
    # Remover backups antigos (mais de 7 dias)
    find $BACKUP_DIR -name "homeguard_*.sql" -type f -mtime +7 -delete
    echo "🗑️  Backups antigos removidos"
else
    echo "❌ Falha no backup"
    exit 1
fi
EOF
    
    chmod +x ~/backup/mysql/backup_homeguard.sh
    print_success "Script de backup criado: ~/backup/mysql/backup_homeguard.sh"
}

# Função principal
main() {
    echo
    echo "=============================================="
    echo "🏠 HomeGuard - MySQL Installation Script"
    echo "=============================================="
    echo
    
    check_root
    check_internet
    
    echo "Este script irá:"
    echo "1. Atualizar o sistema"
    echo "2. Instalar MySQL Server"
    echo "3. Configurar acesso remoto"
    echo "4. Criar usuário e database HomeGuard"
    echo "5. Instalar dependências Python"
    echo "6. Configurar backups"
    echo
    
    read -p "Deseja continuar? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Instalação cancelada"
        exit 0
    fi
    
    echo
    print_info "Iniciando instalação..."
    
    update_system
    install_mysql
    start_mysql
    secure_mysql
    configure_remote_access
    create_homeguard_user
    create_database
    restart_mysql
    configure_firewall
    install_python_deps
    test_installation
    create_config_file
    create_backup_script
    
    echo
    echo "=============================================="
    echo "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "=============================================="
    echo
    echo "📊 Informações de Conexão:"
    echo "   Host: $(hostname -I | awk '{print $1}')"
    echo "   Porta: 3306"
    echo "   Database: homeguard"
    echo "   Usuário: homeguard"
    echo
    echo "📁 Arquivos criados:"
    echo "   - Configuração: ~/homeguard_mysql_config.json"
    echo "   - Backup script: ~/backup/mysql/backup_homeguard.sh"
    echo
    echo "🔧 Próximos passos:"
    echo "   1. Use o arquivo homeguard_flask_mysql.py"
    echo "   2. Configure backup automático (crontab)"
    echo "   3. Teste conexão remota"
    echo
    echo "💡 Para testar conexão remota:"
    echo "   mysql -h $(hostname -I | awk '{print $1}') -u homeguard -p"
    echo
}

# Executar função principal
main "$@"
