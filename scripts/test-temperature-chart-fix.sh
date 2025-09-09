#!/bin/bash
#
# Script para testar correção específica do gráfico de temperatura
#

echo "🌡️ Teste Específico - Gráfico de Temperatura"
echo "============================================="

DASHBOARD_URL="http://100.87.71.125:5000"

echo "🔧 Testando correções implementadas:"
echo "   ✅ Verificação robusta de escala de tempo"
echo "   ✅ Fallback para escala linear"
echo "   ✅ Logging detalhado no console"
echo "   ✅ Tratamento de erro com fallback básico"
echo ""

echo "1️⃣ Testando conectividade..."
if curl -s "$DASHBOARD_URL" >/dev/null; then
    echo "   ✅ Dashboard acessível"
else
    echo "   ❌ Dashboard inacessível"
    exit 1
fi

echo ""
echo "2️⃣ Testando API de temperatura..."
TEMP_DATA=$(curl -s "$DASHBOARD_URL/api/temperature/data" | head -c 100)
if echo "$TEMP_DATA" | grep -q "{"; then
    echo "   ✅ API retornando dados JSON"
    echo "   📊 Preview: ${TEMP_DATA}..."
else
    echo "   ❌ API com problemas"
fi

echo ""
echo "3️⃣ Instruções para teste manual:"
echo "   🌐 Abra: $DASHBOARD_URL/temperature"
echo "   🔍 Abra Console do navegador (F12)"
echo "   📊 Procure por estas mensagens:"
echo "      • 'Chart.js versão: X.X.X'"
echo "      • 'Escala de tempo: Disponível/Não disponível'"
echo "      • 'Gráfico criado com sucesso, escala: time/linear'"
echo ""

echo "4️⃣ Debugging avançado:"
echo "   Se ainda houver erro:"
echo "   a) Verifique no Console se Chart.js carregou"
echo "   b) Verifique se date adapter foi registrado"
echo "   c) Procure por mensagens de fallback"
echo ""

echo "5️⃣ Checklist de correções:"
echo "   □ Chart.js carrega sem erro"
echo "   □ Date adapter carrega (ou fallback funciona)"
echo "   □ Gráfico renderiza (linear ou time scale)"
echo "   □ Dados aparecem corretamente"
echo "   □ Sem erro 'time is not a registered controller'"
echo ""

echo "📋 Possíveis resultados:"
echo "   ✅ MELHOR: Gráfico com escala de tempo funcionando"
echo "   ✅ BOM: Gráfico com escala linear funcionando"
echo "   ✅ BÁSICO: Gráfico simples como último recurso"
echo "   ❌ PROBLEMA: Ainda com erro (verificar logs)"
echo ""

echo "🚀 Para aplicar a correção:"
echo "   cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard"
echo "   ./scripts/deploy-chartjs-fix.sh"
echo ""

echo "💡 Dica: O erro 'time is not a registered controller' deve"
echo "   ser resolvido com a verificação mais robusta implementada."
