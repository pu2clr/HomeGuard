#!/bin/bash
echo "🚨 TRANSFERINDO CORREÇÃO DIRETA"
echo "==============================="

PI_USER="homeguard"
PI_HOST="100.87.71.125"

echo "📡 Transferindo script de correção direta..."
scp "scripts/fix_direct.sh" "$PI_USER@$PI_HOST:~/"

if [ $? -eq 0 ]; then
    echo "✅ Script transferido!"
    echo ""
    echo "🚀 EXECUTE AGORA:"
    echo "   ssh $PI_USER@$PI_HOST 'chmod +x fix_direct.sh && ./fix_direct.sh'"
    echo ""
    echo "🎯 O que fará:"
    echo "   ✅ Para dashboard atual"
    echo "   ✅ Adiciona rota /ultra-basic"
    echo "   ✅ Cria template ultra-básico"
    echo "   ✅ Reinicia dashboard"
    echo "   ✅ Testa conectividade"
    echo ""
    echo "📊 Resultado esperado:"
    echo "   http://100.87.71.125:5000/ultra-basic deve funcionar!"
else
    echo "❌ Erro na transferência"
fi
