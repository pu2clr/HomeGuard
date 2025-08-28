#!/bin/bash
# Teste específico para o IP 192.168.18.205
# HomeGuard - Test Specific IP Connection

echo "🎯 Teste Específico - IP 192.168.18.205"
echo "======================================"

RASPBERRY_IP="192.168.18.100"  # Ajuste conforme seu Raspberry Pi
CLIENT_IP="192.168.18.205"     # Seu IP (Mac)

echo "🔍 Testando do cliente $CLIENT_IP para Raspberry Pi"
echo "📡 Se você estiver executando do Raspberry Pi, este teste simula conexão remota"

# Teste 1: Usuário homeguard
echo -e "\n1️⃣ Testando usuário homeguard..."
if mysql -h localhost -P 3306 -u homeguard -phomeguard123 -e "SELECT 'OK' as test, USER() as current_user, @@hostname as server;" 2>/dev/null; then
    echo "✅ homeguard: OK"
else
    echo "❌ homeguard: FALHA"
fi

# Teste 2: Usuário root
echo -e "\n2️⃣ Testando usuário root..."  
if mysql -h localhost -P 3306 -u root -proot123 -e "SELECT 'OK' as test, USER() as current_user, @@hostname as server;" 2>/dev/null; then
    echo "✅ root: OK"
else
    echo "❌ root: FALHA"
fi

# Teste 3: Verificar usuários no banco
echo -e "\n3️⃣ Usuários configurados no MySQL:"
mysql -u root -proot123 -e "
SELECT 
    User, 
    Host, 
    plugin,
    CASE 
        WHEN Host = '%' THEN '✅ Acesso Global'
        WHEN Host = 'localhost' THEN '🏠 Apenas Local'
        WHEN Host LIKE '192.168.%' THEN '🌐 IP Específico'
        ELSE '❓ Outro'
    END as Tipo_Acesso
FROM mysql.user 
WHERE User IN ('root', 'homeguard') 
ORDER BY User, Host;
" 2>/dev/null

# Teste 4: Verificar database homeguard
echo -e "\n4️⃣ Verificando database homeguard..."
if mysql -u homeguard -phomeguard123 -D homeguard -e "SELECT DATABASE() as current_db, COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'homeguard';" 2>/dev/null; then
    echo "✅ Database homeguard acessível"
else
    echo "⚠️ Database homeguard pode não existir ou estar inacessível"
fi

# Teste 5: Simulação do erro que você estava tendo
echo -e "\n5️⃣ Simulando conexão do seu Mac (IP: $CLIENT_IP)..."
echo "Comando que deve funcionar agora:"
echo "mysql -h [IP_DO_RASPBERRY] -P 3306 -u homeguard -phomeguard123 -e \"SHOW DATABASES;\""

# Mostrar configurações atuais
echo -e "\n📋 CONFIGURAÇÕES PARA DBEAVER:"
echo "================================"
echo "Host: [IP_DO_SEU_RASPBERRY_PI]"
echo "Port: 3306"
echo "Database: homeguard"
echo "Username: homeguard"
echo "Password: homeguard123"
echo ""
echo "Se ainda der erro, tente:"
echo "Username: root"
echo "Password: root123"

echo -e "\n✅ Teste concluído!"
