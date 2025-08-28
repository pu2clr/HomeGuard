#!/bin/bash
# Script para testar conectividade remota MySQL/MariaDB
# HomeGuard - Test Remote Connection

echo "🧪 HomeGuard - Teste de Conectividade Remota MySQL/MariaDB"
echo "=========================================================="

# Verificar parâmetros
if [ $# -lt 1 ]; then
    echo "📋 Uso: $0 <IP_DO_RASPBERRY> [usuario] [senha]"
    echo "📋 Exemplo: $0 192.168.18.100"
    echo "📋 Exemplo: $0 192.168.1.100 homeguard homeguard123"
    exit 1
fi

RASPBERRY_IP=$1
USER=${2:-homeguard}
PASS=${3:-homeguard123}

echo "🎯 Testando conexão para:"
echo "   📡 Host: $RASPBERRY_IP"
echo "   👤 Usuário: $USER"
echo "   🔑 Senha: $PASS"
echo "   🚪 Porta: 3306"

# Teste 1: Ping
echo -e "\n1️⃣  Testando conectividade de rede (ping)..."
if ping -c 3 $RASPBERRY_IP >/dev/null 2>&1; then
    echo "✅ Ping: OK - Raspberry Pi está acessível na rede"
else
    echo "❌ Ping: FALHA - Verificar conectividade de rede"
    echo "💡 Dicas:"
    echo "   - Verificar se o IP está correto"
    echo "   - Verificar se o Raspberry Pi está ligado"
    echo "   - Verificar se estão na mesma rede"
fi

# Teste 2: Porta 3306
echo -e "\n2️⃣  Testando porta 3306..."
if command -v nc >/dev/null 2>&1; then
    if nc -z -w5 $RASPBERRY_IP 3306; then
        echo "✅ Porta 3306: ABERTA - MySQL/MariaDB está ouvindo"
    else
        echo "❌ Porta 3306: FECHADA ou não acessível"
        echo "💡 Possíveis causas:"
        echo "   - MySQL/MariaDB não está rodando"
        echo "   - bind-address configurado apenas para localhost (127.0.0.1)"
        echo "   - Firewall bloqueando a porta 3306"
    fi
elif command -v telnet >/dev/null 2>&1; then
    echo "Tentando via telnet..."
    timeout 5 telnet $RASPBERRY_IP 3306 2>&1 | head -3
else
    echo "⚠️  nc (netcat) e telnet não disponíveis para testar porta"
fi

# Teste 3: Conexão MySQL
echo -e "\n3️⃣  Testando autenticação MySQL..."
if command -v mysql >/dev/null 2>&1; then
    if mysql -h $RASPBERRY_IP -P 3306 -u $USER -p$PASS -e "SELECT 1 as test;" 2>/dev/null; then
        echo "✅ Autenticação MySQL: OK"
        
        # Testar database homeguard
        echo -e "\n4️⃣  Testando acesso ao database homeguard..."
        if mysql -h $RASPBERRY_IP -P 3306 -u $USER -p$PASS -D homeguard -e "SHOW TABLES;" 2>/dev/null; then
            echo "✅ Database homeguard: ACESSÍVEL"
            mysql -h $RASPBERRY_IP -P 3306 -u $USER -p$PASS -D homeguard -e "SHOW TABLES;"
        else
            echo "⚠️  Database homeguard: NÃO ACESSÍVEL ou vazio"
            echo "💡 Executar: mysql -u root -p -e \"CREATE DATABASE IF NOT EXISTS homeguard;\""
        fi
    else
        echo "❌ Autenticação MySQL: FALHA"
        echo "💡 Possíveis causas:"
        echo "   - Usuário '$USER' não existe ou não tem acesso remoto"
        echo "   - Senha incorreta"
        echo "   - Plugin de autenticação incompatível"
        echo ""
        echo "🔧 No Raspberry Pi, execute:"
        echo "   sudo mysql -e \"CREATE USER '$USER'@'%' IDENTIFIED BY '$PASS';\""
        echo "   sudo mysql -e \"GRANT ALL PRIVILEGES ON homeguard.* TO '$USER'@'%';\""
        echo "   sudo mysql -e \"UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='$USER';\""
        echo "   sudo mysql -e \"FLUSH PRIVILEGES;\""
    fi
else
    echo "⚠️  Cliente mysql não disponível para testar autenticação"
    echo "💡 Instalar: sudo apt install mysql-client"
fi

# Informações para DBeaver
echo -e "\n📋 CONFIGURAÇÕES PARA DBEAVER:"
echo "================================"
echo "Connection Type: MySQL"
echo "Server Host: $RASPBERRY_IP"
echo "Port: 3306"
echo "Database: homeguard"
echo "Username: $USER"
echo "Password: $PASS"
echo "Driver: MySQL (com mysql-connector-java)"
echo ""
echo "🔧 Se ainda não funcionar:"
echo "1. Certifique-se que o bind-address está configurado como 0.0.0.0"
echo "2. Reinicie o MySQL/MariaDB: sudo systemctl restart mariadb"
echo "3. Verifique o firewall: sudo ufw allow 3306/tcp"
echo "4. Use o script: ./fix_remote_access_dbeaver.sh"

echo -e "\n✅ TESTE CONCLUÍDO!"
