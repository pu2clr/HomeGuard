#!/bin/bash
#
# Script para testar o dashboard após as correções do Chart.js
#

echo "🧪 Testando Dashboard HomeGuard - Chart.js"
echo "=========================================="

DASHBOARD_URL="http://100.87.71.125:5000"

echo "🌐 URL Base: $DASHBOARD_URL"
echo ""

# Função para testar endpoint
test_endpoint() {
    local endpoint="$1"
    local description="$2"
    local url="$DASHBOARD_URL$endpoint"
    
    echo -n "🔍 $description... "
    
    response=$(curl -s -w "%{http_code}" -o /dev/null "$url" || echo "000")
    
    if [ "$response" = "200" ]; then
        echo "✅ OK ($response)"
    else
        echo "❌ ERRO ($response)"
    fi
}

# Função para testar API
test_api() {
    local endpoint="$1"
    local description="$2"
    local url="$DASHBOARD_URL$endpoint"
    
    echo -n "📊 $description... "
    
    response=$(curl -s "$url" 2>/dev/null | head -c 50)
    
    if echo "$response" | grep -q "{"; then
        echo "✅ JSON OK"
    else
        echo "❌ Falha no JSON"
    fi
}

echo "1️⃣ Testando páginas principais:"
test_endpoint "/" "Dashboard principal"
test_endpoint "/temperature" "Painel de temperatura"
test_endpoint "/temperature-debug" "Debug de temperatura"

echo ""
echo "2️⃣ Testando APIs de dados:"
test_api "/api/temperature/data" "API dados temperatura"
test_api "/api/temperature/stats" "API stats temperatura"

echo ""
echo "3️⃣ Verificando Chart.js no navegador:"
echo "   Abra no navegador: $DASHBOARD_URL/temperature-debug"
echo "   Verifique o console (F12) para erros do Chart.js"
echo ""

echo "4️⃣ Próximos passos:"
echo "   ✅ Se tudo OK: aplicar script fix-chartjs-templates.sh no Raspberry Pi"
echo "   ✅ Testar painéis: Umidade, Movimento, Relés"
echo "   ✅ Verificar gráficos renderizam corretamente"
echo ""

echo "🔧 Para debug detalhado:"
echo "   curl -s '$DASHBOARD_URL/api/temperature/data' | jq ."
echo "   curl -s '$DASHBOARD_URL/api/temperature/stats' | jq ."
echo ""

echo "📱 Acesso mobile:"
echo "   $DASHBOARD_URL"
echo ""

# Teste adicional de conectividade
echo "5️⃣ Teste de conectividade:"
if ping -c 1 100.87.71.125 >/dev/null 2>&1; then
    echo "   ✅ Raspberry Pi acessível"
else
    echo "   ❌ Raspberry Pi não acessível"
fi

echo ""
echo "📋 Checklist Chart.js:"
echo "   □ Date adapter carregado (chartjs-adapter-date-fns)"
echo "   □ Canvas destruído corretamente antes de recriar"
echo "   □ Timestamps convertidos para Date objects"
echo "   □ Fallback para escala linear se time adapter falhar"
echo "   □ Try-catch em operações críticas"
