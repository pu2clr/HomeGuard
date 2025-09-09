#!/bin/bash
#
# Script para aplicar correção específica do painel de temperatura
#

echo "🌡️ Aplicando Correção - Painel de Temperatura"
echo "=============================================="

# Configurações
PI_USER="homeguard"
PI_HOST="100.87.71.125"
PI_PATH="/home/homeguard/HomeGuard/web/templates"
LOCAL_TEMPLATES="web/templates"

echo "🔧 Problema: 'time' is not a registered controller"
echo "✅ Solução: Verificação robusta + fallback para escala linear"
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

# Fazer backup específico
echo ""
echo "2️⃣ Fazendo backup dos templates de temperatura..."
ssh $PI_USER@$PI_HOST "
    cd $PI_PATH
    
    # Criar diretório de backup se não existir
    if [ ! -d backups ]; then
        mkdir -p backups
    fi
    
    BACKUP_DIR=\"backups/temp-chart-fix-\$(date +%Y%m%d-%H%M%S)\"
    mkdir -p \$BACKUP_DIR
    
    echo 'Backup específico criado em: '\$BACKUP_DIR
    
    # Backup dos templates relacionados à temperatura
    cp base.html \$BACKUP_DIR/ 2>/dev/null || echo 'base.html não encontrado'
    cp temperature_panel.html \$BACKUP_DIR/ 2>/dev/null || echo 'temperature_panel.html não encontrado'
    cp temperature_debug.html \$BACKUP_DIR/ 2>/dev/null || echo 'temperature_debug.html não encontrado'
    
    ls -la \$BACKUP_DIR/
"

# Transferir apenas templates corrigidos
echo ""
echo "3️⃣ Transferindo templates corrigidos..."

TEMPLATES=(
    "base.html"
    "temperature_panel.html"
)

for template in "${TEMPLATES[@]}"; do
    echo "   📄 Transferindo $template..."
    scp "$LOCAL_TEMPLATES/$template" "$PI_USER@$PI_HOST:$PI_PATH/"
    
    if [ $? -eq 0 ]; then
        echo "   ✅ $template transferido com sucesso"
    else
        echo "   ❌ Erro ao transferir $template"
        exit 1
    fi
done

# Ajustar permissões
echo ""
echo "4️⃣ Ajustando permissões..."
ssh $PI_USER@$PI_HOST "
    cd $PI_PATH
    chown $PI_USER:$PI_USER base.html temperature_panel.html
    chmod 644 base.html temperature_panel.html
    echo 'Permissões ajustadas'
"

# Reiniciar apenas o dashboard
echo ""
echo "5️⃣ Reiniciando dashboard..."
ssh $PI_USER@$PI_HOST "
    # Tentar parar o serviço graciosamente
    sudo systemctl restart homeguard-dashboard 2>/dev/null || {
        echo 'Serviço systemd não encontrado, tentando pkill...'
        sudo pkill -f dashboard.py
        sleep 2
    }
    
    echo 'Dashboard reiniciado'
"

# Aguardar inicialização
echo ""
echo "6️⃣ Aguardando inicialização..."
sleep 5

# Testar resultado específico
echo ""
echo "7️⃣ Testando correção..."

echo "   🌐 Testando página de temperatura..."
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null "http://$PI_HOST:5000/temperature" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo "   ✅ Página de temperatura carregando ($RESPONSE)"
else
    echo "   ❌ Página com problemas ($RESPONSE)"
fi

echo "   📊 Testando API de dados..."
TEMP_API=$(curl -s "http://$PI_HOST:5000/api/temperature/data" 2>/dev/null | head -c 50)
if echo "$TEMP_API" | grep -q "{"; then
    echo "   ✅ API de temperatura funcionando"
else
    echo "   ❌ API com problemas"
fi

echo ""
echo "✅ Correção aplicada com sucesso!"
echo ""
echo "🧪 TESTE MANUAL OBRIGATÓRIO:"
echo "   1. Acesse: http://$PI_HOST:5000/temperature"
echo "   2. Abra Console do navegador (F12)"
echo "   3. Procure por mensagens:"
echo "      • 'Chart.js versão: X.X.X'"
echo "      • 'Escala de tempo: Disponível/Não disponível'"
echo "      • 'Gráfico criado com sucesso, escala: time/linear'"
echo "   4. Clique em 'Atualizar' para carregar dados"
echo "   5. Verifique se o gráfico aparece SEM ERRO"
echo ""
echo "🎯 EXPECTATIVA:"
echo "   ❌ ANTES: Erro 'time' is not a registered controller"
echo "   ✅ DEPOIS: Gráfico renderiza (escala time ou linear)"
echo ""
echo "📋 Se ainda houver problemas:"
echo "   - Verifique logs: sudo journalctl -u homeguard-dashboard -f"
echo "   - Verifique console do navegador para mensagens detalhadas"
echo "   - Execute: ./scripts/test-temperature-chart-fix.sh"
echo ""
echo "💾 Backup criado em: $PI_PATH/backups/"
echo "   Para rollback: ssh $PI_USER@$PI_HOST 'cd $PI_PATH && cp backups/[DIR]/* .'"
