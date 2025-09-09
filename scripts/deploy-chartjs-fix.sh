#!/bin/bash
#
# Script para aplicar as correções do Chart.js no Raspberry Pi
#

echo "🚀 Aplicando correções Chart.js no Raspberry Pi"
echo "==============================================="

# Configurações (ajuste conforme necessário)
PI_USER="homeguard"
PI_HOST="100.87.71.125"
PI_PATH="/home/homeguard/HomeGuard/web/templates"
LOCAL_TEMPLATES="web/templates"

echo "🔧 Configuração:"
echo "   Usuário: $PI_USER"
echo "   Host: $PI_HOST"
echo "   Caminho remoto: $PI_PATH"
echo ""

# Verificar conectividade
echo "1️⃣ Testando conectividade..."
if ping -c 1 $PI_HOST >/dev/null 2>&1; then
    echo "   ✅ Raspberry Pi acessível"
else
    echo "   ❌ Raspberry Pi não acessível"
    echo "   Verifique a conexão de rede"
    exit 1
fi

# Fazer backup remoto
echo ""
echo "2️⃣ Fazendo backup dos templates atuais..."
ssh $PI_USER@$PI_HOST "
    cd $PI_PATH
    if [ ! -d backups ]; then
        mkdir -p backups
    fi
    
    BACKUP_DIR=\"backups/chartjs-fix-\$(date +%Y%m%d-%H%M%S)\"
    mkdir -p \$BACKUP_DIR
    
    echo 'Backup criado em: '\$BACKUP_DIR
    cp *.html \$BACKUP_DIR/ 2>/dev/null || true
    ls -la \$BACKUP_DIR/
"

# Transferir templates corrigidos
echo ""
echo "3️⃣ Transferindo templates corrigidos..."

# Lista de templates para transferir
TEMPLATES=(
    "base.html"
    "temperature_panel.html" 
    "temperature_debug.html"
)

for template in "${TEMPLATES[@]}"; do
    echo "   📄 Transferindo $template..."
    scp "$LOCAL_TEMPLATES/$template" "$PI_USER@$PI_HOST:$PI_PATH/"
    
    if [ $? -eq 0 ]; then
        echo "   ✅ $template transferido com sucesso"
    else
        echo "   ❌ Erro ao transferir $template"
    fi
done

# Verificar permissões
echo ""
echo "4️⃣ Ajustando permissões..."
ssh $PI_USER@$PI_HOST "
    cd $PI_PATH
    chown $PI_USER:$PI_USER *.html
    chmod 644 *.html
    echo 'Permissões ajustadas'
"

# Reiniciar serviço
echo ""
echo "5️⃣ Reiniciando dashboard..."
ssh $PI_USER@$PI_HOST "
    sudo systemctl restart homeguard-dashboard || sudo pkill -f dashboard.py
    sleep 3
    echo 'Dashboard reiniciado'
"

# Testar resultado
echo ""
echo "6️⃣ Testando resultado..."
sleep 5

echo "   🌐 Testando página principal..."
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null "http://$PI_HOST:5000/" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo "   ✅ Dashboard funcionando ($RESPONSE)"
else
    echo "   ❌ Dashboard com problemas ($RESPONSE)"
fi

echo "   📊 Testando API temperatura..."
RESPONSE=$(curl -s "http://$PI_HOST:5000/api/temperature/data" 2>/dev/null | head -c 10)
if echo "$RESPONSE" | grep -q "{"; then
    echo "   ✅ API funcionando"
else
    echo "   ❌ API com problemas"
fi

echo ""
echo "✅ Processo concluído!"
echo ""
echo "🧪 Próximos testes:"
echo "   1. Acesse: http://$PI_HOST:5000/temperature-debug"
echo "   2. Abra o console do navegador (F12)"
echo "   3. Verifique se não há erros do Chart.js"
echo "   4. Teste os botões de carregar dados"
echo "   5. Verifique se os gráficos aparecem"
echo ""
echo "📋 Se houver problemas:"
echo "   - Verifique logs: sudo journalctl -u homeguard-dashboard -f"
echo "   - Restaure backup se necessário"
echo "   - Execute novamente este script"
echo ""
echo "🎯 Objetivo: Gráficos devem renderizar sem erros de Chart.js"
