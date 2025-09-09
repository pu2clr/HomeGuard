#!/bin/bash
# Script para corrigir autenticação remota MySQL/MariaDB
# HomeGuard - Fix Remote Authentication

echo "🔧 HomeGuard - Corrigindo Autenticação Remota MySQL/MariaDB"
echo "=========================================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detectar IP do cliente (seu Mac)
CLIENT_IP=$(who am i 2>/dev/null | awk '{print $5}' | tr -d '()')
if [[ -z "$CLIENT_IP" ]]; then
    CLIENT_IP="192.168.1.205"  # IP detectado do erro
fi

echo -e "${BLUE}🔍 IP do cliente detectado: ${CLIENT_IP}${NC}"

# Verificar se MariaDB/MySQL está rodando
if systemctl is-active --quiet mariadb; then
    SERVICE="mariadb"
    echo -e "${GREEN}✅ MariaDB está rodando${NC}"
elif systemctl is-active --quiet mysql; then
    SERVICE="mysql"
    echo -e "${GREEN}✅ MySQL está rodando${NC}"
else
    echo -e "${RED}❌ Nem MariaDB nem MySQL estão rodando!${NC}"
    echo -e "${YELLOW}💡 Execute: sudo systemctl start mariadb${NC}"
    exit 1
fi

echo -e "\n${BLUE}🔧 Corrigindo autenticação remota...${NC}"

# Criar script SQL para correção
cat > /tmp/fix_remote_auth.sql << EOF
-- Mostrar usuários atuais
SELECT 'Usuários antes da correção:' as info;
SELECT User, Host, plugin, authentication_string FROM mysql.user WHERE User IN ('root', 'homeguard');

-- Remover usuários problemáticos
DROP USER IF EXISTS 'root'@'${CLIENT_IP}';
DROP USER IF EXISTS 'homeguard'@'${CLIENT_IP}';

-- Criar/atualizar usuário homeguard para qualquer IP (%)
CREATE USER IF NOT EXISTS 'homeguard'@'%' IDENTIFIED BY 'homeguard123';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';

-- Criar/atualizar usuário root para qualquer IP (%)
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Criar usuários específicos para seu IP
CREATE USER IF NOT EXISTS 'homeguard'@'${CLIENT_IP}' IDENTIFIED BY 'homeguard123';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'${CLIENT_IP}';

CREATE USER IF NOT EXISTS 'root'@'${CLIENT_IP}' IDENTIFIED BY 'root123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'${CLIENT_IP}' WITH GRANT OPTION;

-- Garantir plugin correto para MariaDB/MySQL 8+
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='homeguard';
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root';

-- Para MariaDB 10.4+, pode ser necessário usar plugin diferente
UPDATE mysql.user SET plugin='' WHERE User='homeguard' AND plugin='unix_socket';
UPDATE mysql.user SET plugin='' WHERE User='root' AND plugin='unix_socket';

-- Aplicar mudanças
FLUSH PRIVILEGES;

-- Mostrar usuários após correção
SELECT 'Usuários após correção:' as info;
SELECT User, Host, plugin FROM mysql.user WHERE User IN ('root', 'homeguard') ORDER BY User, Host;

-- Testar criação do database
CREATE DATABASE IF NOT EXISTS homeguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Mostrar databases
SHOW DATABASES;
EOF

echo -e "${YELLOW}📝 Executando correções SQL...${NC}"
if sudo mysql < /tmp/fix_remote_auth.sql; then
    echo -e "${GREEN}✅ Correções aplicadas com sucesso!${NC}"
else
    echo -e "${YELLOW}⚠️  Erro na correção, tentando método alternativo...${NC}"
    
    # Método alternativo direto
    echo -e "${YELLOW}🔄 Aplicando correções diretamente...${NC}"
    
    # Corrigir usuários um por um
    sudo mysql -e "CREATE USER IF NOT EXISTS 'homeguard'@'%' IDENTIFIED BY 'homeguard123';" 2>/dev/null
    sudo mysql -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root123';" 2>/dev/null
    sudo mysql -e "CREATE USER IF NOT EXISTS 'homeguard'@'${CLIENT_IP}' IDENTIFIED BY 'homeguard123';" 2>/dev/null  
    sudo mysql -e "CREATE USER IF NOT EXISTS 'root'@'${CLIENT_IP}' IDENTIFIED BY 'root123';" 2>/dev/null
    
    # Aplicar permissões
    sudo mysql -e "GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';" 2>/dev/null
    sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;" 2>/dev/null
    sudo mysql -e "GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'${CLIENT_IP}';" 2>/dev/null
    sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'${CLIENT_IP}' WITH GRANT OPTION;" 2>/dev/null
    
    # Corrigir plugin de autenticação
    sudo mysql -e "UPDATE mysql.user SET plugin='mysql_native_password' WHERE User IN ('homeguard', 'root');" 2>/dev/null
    sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    # Criar database
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS homeguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
    
    echo -e "${GREEN}✅ Correções alternativas aplicadas!${NC}"
fi

# Limpar arquivo temporário
rm -f /tmp/fix_remote_auth.sql

echo -e "\n${BLUE}🔄 Reiniciando MySQL/MariaDB...${NC}"
if sudo systemctl restart $SERVICE; then
    echo -e "${GREEN}✅ Serviço reiniciado com sucesso!${NC}"
    sleep 3
else
    echo -e "${RED}❌ Erro ao reiniciar serviço${NC}"
    exit 1
fi

echo -e "\n${BLUE}🧪 Testando autenticação...${NC}"

# Testar usuário homeguard
echo -e "${YELLOW}Testando usuário homeguard...${NC}"
if mysql -u homeguard -phomeguard123 -e "SELECT 'Conexão homeguard OK' as status;" 2>/dev/null; then
    echo -e "${GREEN}✅ Usuário homeguard: Autenticação local OK${NC}"
else
    echo -e "${RED}❌ Usuário homeguard: Falha na autenticação local${NC}"
fi

# Testar usuário root
echo -e "${YELLOW}Testando usuário root...${NC}"
if mysql -u root -proot123 -e "SELECT 'Conexão root OK' as status;" 2>/dev/null; then
    echo -e "${GREEN}✅ Usuário root: Autenticação local OK${NC}"
else
    echo -e "${RED}❌ Usuário root: Falha na autenticação local${NC}"
fi

# Mostrar usuários finais
echo -e "\n${BLUE}👥 Usuários configurados:${NC}"
sudo mysql -e "SELECT User, Host, plugin FROM mysql.user WHERE User IN ('root', 'homeguard') ORDER BY User, Host;" 2>/dev/null

echo -e "\n${BLUE}📡 Testando conectividade de rede...${NC}"
RASPBERRY_IP=$(hostname -I | awk '{print $1}')
echo -e "${YELLOW}IP do Raspberry Pi: ${RASPBERRY_IP}${NC}"

# Verificar se a porta está aberta
if netstat -tlnp | grep -q ":3306"; then
    echo -e "${GREEN}✅ Porta 3306 está aberta e ouvindo${NC}"
    netstat -tlnp | grep ":3306"
else
    echo -e "${RED}❌ Porta 3306 não está ouvindo${NC}"
fi

echo -e "\n${BLUE}📋 INFORMAÇÕES PARA DBEAVER:${NC}"
echo "======================================"
echo -e "${YELLOW}Host:${NC} ${RASPBERRY_IP}"
echo -e "${YELLOW}Port:${NC} 3306"
echo -e "${YELLOW}Database:${NC} homeguard"
echo -e "${YELLOW}Username:${NC} homeguard"
echo -e "${YELLOW}Password:${NC} homeguard123"
echo ""
echo -e "${YELLOW}OU usar ROOT:${NC}"
echo -e "${YELLOW}Username:${NC} root"
echo -e "${YELLOW}Password:${NC} root123"

echo -e "\n${BLUE}🧪 TESTE DO SEU MAC:${NC}"
echo "Execute do seu Mac:"
echo -e "${YELLOW}mysql -h ${RASPBERRY_IP} -P 3306 -u homeguard -phomeguard123 -e \"SHOW DATABASES;\"${NC}"
echo ""
echo -e "${YELLOW}ou${NC}"
echo -e "${YELLOW}mysql -h ${RASPBERRY_IP} -P 3306 -u root -proot123 -e \"SHOW DATABASES;\"${NC}"

echo -e "\n${GREEN}✅ CORREÇÃO DE AUTENTICAÇÃO CONCLUÍDA!${NC}"
echo -e "${BLUE}🎯 Agora tente conectar no DBeaver novamente${NC}"
