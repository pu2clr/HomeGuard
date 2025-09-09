#!/bin/bash

# HomeGuard - Diagnóstico MariaDB
# Script para identificar problemas no MariaDB

echo "🔍 HomeGuard - Diagnóstico MariaDB"
echo "================================="

echo "1️⃣ Verificando status do MariaDB..."
if sudo systemctl is-active --quiet mariadb; then
    echo "✅ MariaDB está rodando"
else
    echo "❌ MariaDB não está rodando"
    echo "   Tentando iniciar..."
    sudo systemctl start mariadb
    
    if sudo systemctl is-active --quiet mariadb; then
        echo "✅ MariaDB iniciado com sucesso"
    else
        echo "❌ Falha ao iniciar MariaDB"
        echo "   Verificar logs: sudo journalctl -u mariadb"
        exit 1
    fi
fi

echo
echo "2️⃣ Verificando versão do MariaDB..."
mysql_version=$(sudo mysql -V 2>/dev/null || echo "Erro ao obter versão")
echo "   $mysql_version"

echo
echo "3️⃣ Verificando conexão root..."
if sudo mysql -u root -e "SELECT 'Root OK' as status;" 2>/dev/null; then
    echo "✅ Root pode conectar via socket (sudo mysql)"
else
    echo "❌ Root não pode conectar"
fi

echo
echo "4️⃣ Verificando usuários existentes..."
sudo mysql -u root -e "SELECT User, Host, plugin FROM mysql.user;" 2>/dev/null | head -10

echo
echo "5️⃣ Verificando databases..."
sudo mysql -u root -e "SHOW DATABASES;" 2>/dev/null

echo
echo "6️⃣ Verificando usuário homeguard..."
if sudo mysql -u root -e "SELECT User FROM mysql.user WHERE User='homeguard';" 2>/dev/null | grep -q homeguard; then
    echo "✅ Usuário homeguard existe"
    
    # Testar senha se fornecida
    if [ -n "$1" ]; then
        echo "   Testando senha fornecida..."
        if mysql -u homeguard -p$1 -e "SELECT 'homeguard OK' as status;" 2>/dev/null; then
            echo "✅ Usuário homeguard pode conectar"
        else
            echo "❌ Usuário homeguard não pode conectar com essa senha"
        fi
    else
        echo "   Para testar senha: $0 <senha>"
    fi
else
    echo "❌ Usuário homeguard não existe"
fi

echo
echo "7️⃣ Verificando permissões de arquivo..."
mysql_datadir=$(sudo mysql -u root -e "SELECT @@datadir;" 2>/dev/null | tail -n 1)
if [ -n "$mysql_datadir" ]; then
    echo "   Diretório de dados: $mysql_datadir"
    echo "   Permissões:"
    ls -la "$mysql_datadir" 2>/dev/null | head -5
else
    echo "   Não foi possível obter diretório de dados"
fi

echo
echo "8️⃣ Verificando configuração..."
config_files="/etc/mysql/mariadb.conf.d/50-server.cnf /etc/my.cnf /etc/mysql/my.cnf"
for config in $config_files; do
    if [ -f "$config" ]; then
        echo "✅ Arquivo config encontrado: $config"
        echo "   bind-address = $(grep bind-address $config 2>/dev/null || echo 'não definido')"
        break
    fi
done

echo
echo "9️⃣ Diagnóstico de rede..."
echo "   Portas abertas (3306):"
netstat -tuln 2>/dev/null | grep :3306 || echo "   Porta 3306 não está ouvindo"

echo
echo "🔍 RESUMO DO DIAGNÓSTICO"
echo "======================="

# Verificações básicas
checks=()

if sudo systemctl is-active --quiet mariadb; then
    checks+=("✅ MariaDB rodando")
else
    checks+=("❌ MariaDB parado")
fi

if sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
    checks+=("✅ Root conecta")
else
    checks+=("❌ Root não conecta")
fi

if sudo mysql -u root -e "SELECT User FROM mysql.user WHERE User='homeguard';" 2>/dev/null | grep -q homeguard; then
    checks+=("✅ Usuário homeguard existe")
else
    checks+=("❌ Usuário homeguard não existe")
fi

if sudo mysql -u root -e "SHOW DATABASES;" 2>/dev/null | grep -q homeguard; then
    checks+=("✅ Database homeguard existe")
else
    checks+=("❌ Database homeguard não existe")
fi

for check in "${checks[@]}"; do
    echo "$check"
done

echo
echo "💡 PRÓXIMOS PASSOS:"
if [[ " ${checks[@]} " =~ " ❌ " ]]; then
    echo "   Execute: ./basic_mariadb_fix.sh"
else
    echo "   Tudo parece OK! Execute:"
    echo "   cd web/ && python3 homeguard_flask_mysql.py"
fi

echo
echo "🛠️  SCRIPTS DISPONÍVEIS:"
echo "   ./basic_mariadb_fix.sh    (mais simples)"
echo "   ./simple_mariadb_fix.sh   (intermediário)"  
echo "   ./fix_mariadb_auth.sh     (completo)"
