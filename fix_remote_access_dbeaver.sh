#!/bin/bash
# Script para configurar acesso remoto MySQL/MariaDB para DBeaver
# HomeGuard - Fix Remote Access

echo "🔧 HomeGuard - Configurando Acesso Remoto MySQL/MariaDB para DBeaver"
echo "=================================================================="

# Verificar se MariaDB está rodando
echo "🔍 Verificando status do MariaDB/MySQL..."
if systemctl is-active --quiet mariadb; then
    echo "✅ MariaDB está rodando"
    SERVICE="mariadb"
elif systemctl is-active --quiet mysql; then
    echo "✅ MySQL está rodando"
    SERVICE="mysql"
else
    echo "❌ Nem MariaDB nem MySQL estão rodando!"
    echo "💡 Execute: sudo systemctl start mariadb"
    exit 1
fi

# Verificar porta 3306
echo -e "\n🔍 Verificando porta 3306..."
if netstat -tlnp 2>/dev/null | grep -q ":3306"; then
    echo "✅ MySQL/MariaDB está ouvindo na porta 3306"
    netstat -tlnp 2>/dev/null | grep ":3306"
else
    echo "❌ MySQL/MariaDB NÃO está ouvindo na porta 3306!"
fi

# Verificar configuração bind-address
echo -e "\n🔍 Verificando configuração bind-address..."
CONFIG_FILES=(
    "/etc/mysql/mariadb.conf.d/50-server.cnf"
    "/etc/mysql/mysql.conf.d/mysqld.cnf"
    "/etc/mysql/my.cnf"
)

for config_file in "${CONFIG_FILES[@]}"; do
    if [[ -f "$config_file" ]]; then
        echo "📁 Verificando: $config_file"
        if grep -q "bind-address.*127.0.0.1" "$config_file"; then
            echo "⚠️  PROBLEMA: bind-address está definido como 127.0.0.1 (apenas local)"
            echo "🔧 Corrigindo bind-address para permitir acesso remoto..."
            
            # Backup do arquivo
            sudo cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Corrigir bind-address
            sudo sed -i 's/bind-address.*=.*127\.0\.0\.1/bind-address = 0.0.0.0/' "$config_file"
            echo "✅ bind-address corrigido em $config_file"
        elif grep -q "bind-address.*0.0.0.0" "$config_file"; then
            echo "✅ bind-address já está configurado corretamente (0.0.0.0)"
        else
            echo "ℹ️  bind-address não encontrado em $config_file"
        fi
    fi
done

echo -e "\n🔧 Configurando usuário para acesso remoto..."

# Criar script SQL temporário
cat > /tmp/fix_remote_user.sql << 'EOF'
-- Verificar usuários existentes
SELECT User, Host FROM mysql.user WHERE User IN ('root', 'homeguard');

-- Criar/Atualizar usuário homeguard para acesso remoto
CREATE USER IF NOT EXISTS 'homeguard'@'%' IDENTIFIED BY 'homeguard123';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';

-- Permitir root remoto (opcional - menos seguro)
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Para MariaDB, garantir plugin de autenticação correto
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='homeguard';
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root';

-- Aplicar mudanças
FLUSH PRIVILEGES;

-- Mostrar usuários atualizados
SELECT User, Host, plugin FROM mysql.user WHERE User IN ('root', 'homeguard');
EOF

echo "📝 Executando configuração de usuários..."
if sudo mysql < /tmp/fix_remote_user.sql; then
    echo "✅ Usuários configurados com sucesso!"
else
    echo "⚠️  Houve algum problema na configuração. Tentando método alternativo..."
    
    # Método alternativo para MariaDB
    echo "🔄 Tentando configuração MariaDB..."
    sudo mysql -e "
    CREATE USER IF NOT EXISTS 'homeguard'@'%' IDENTIFIED BY 'homeguard123';
    GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';
    CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root123';
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
    "
fi

# Limpar arquivo temporário
rm -f /tmp/fix_remote_user.sql

echo -e "\n🔄 Reiniciando serviço MySQL/MariaDB..."
if sudo systemctl restart $SERVICE; then
    echo "✅ Serviço reiniciado com sucesso!"
    sleep 2
else
    echo "❌ Erro ao reiniciar o serviço!"
    exit 1
fi

# Verificar firewall
echo -e "\n🔍 Verificando firewall..."
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        echo "🔥 UFW firewall está ativo"
        if ufw status | grep -q "3306"; then
            echo "✅ Porta 3306 já está liberada no firewall"
        else
            echo "🔧 Liberando porta 3306 no firewall..."
            sudo ufw allow 3306/tcp
            echo "✅ Porta 3306 liberada!"
        fi
    else
        echo "ℹ️  UFW firewall não está ativo"
    fi
else
    echo "ℹ️  UFW não instalado, verificando iptables..."
    if iptables -L | grep -q "3306"; then
        echo "✅ Regras para porta 3306 encontradas no iptables"
    else
        echo "⚠️  Nenhuma regra específica para porta 3306 no iptables"
    fi
fi

# Testar conexão local
echo -e "\n🧪 Testando conexão local..."
if mysql -u homeguard -phomeguard123 -e "SHOW DATABASES;" >/dev/null 2>&1; then
    echo "✅ Conexão local com usuário homeguard: OK"
else
    echo "❌ Falha na conexão local com usuário homeguard"
fi

# Mostrar informações de conexão
echo -e "\n📊 INFORMAÇÕES PARA CONEXÃO NO DBEAVER:"
echo "======================================================"
echo "🖥️  Host/Server: $(hostname -I | awk '{print $1}') ou IP_DO_RASPBERRY"
echo "🚪 Porta: 3306"
echo "👤 Usuário: homeguard"
echo "🔑 Senha: homeguard123"
echo "💾 Database: homeguard"
echo ""
echo "📋 CONFIGURAÇÕES DBEAVER:"
echo "- Connection Type: MySQL"
echo "- Driver: MySQL"
echo "- Host: [IP_DO_RASPBERRY]"
echo "- Port: 3306"
echo "- Database: homeguard"
echo "- Username: homeguard"
echo "- Password: homeguard123"
echo ""
echo "🔒 USUÁRIO ROOT (se necessário):"
echo "- Username: root"
echo "- Password: root123"

# Verificar conectividade externa
echo -e "\n🌐 Verificando conectividade externa..."
echo "Para testar do seu computador, execute:"
echo "mysql -h $(hostname -I | awk '{print $1}') -u homeguard -phomeguard123 -e 'SHOW DATABASES;'"

echo -e "\n✅ CONFIGURAÇÃO CONCLUÍDA!"
echo "🎯 Agora tente conectar no DBeaver usando as informações acima."

# Status final
echo -e "\n📈 STATUS FINAL:"
systemctl status $SERVICE --no-pager -l | head -5
netstat -tlnp 2>/dev/null | grep ":3306"
