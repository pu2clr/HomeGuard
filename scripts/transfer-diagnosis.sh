#!/bin/bash
#
# Transfer do diagnóstico completo
#

echo "🔍 TRANSFERINDO DIAGNÓSTICO COMPLETO"
echo "===================================="

PI_USER="homeguard"
PI_HOST="100.87.71.125"
SCRIPT_NAME="diagnosis_complete.sh"

echo "📡 Transferindo script de diagnóstico..."
scp "scripts/$SCRIPT_NAME" "$PI_USER@$PI_HOST:~/"

if [ $? -eq 0 ]; then
    echo "✅ Script transferido com sucesso!"
    echo ""
    echo "🚀 EXECUTE NO RASPBERRY PI:"
    echo "   ssh $PI_USER@$PI_HOST"
    echo "   chmod +x $SCRIPT_NAME"
    echo "   ./$SCRIPT_NAME"
    echo ""
    echo "🎯 O QUE O DIAGNÓSTICO VAI FAZER:"
    echo "   ✅ Testar todas as APIs individualmente"
    echo "   ✅ Verificar templates existentes"
    echo "   ✅ Testar páginas web"
    echo "   ✅ Criar template ultra-básico funcional"
    echo "   ✅ Identificar exatamente onde está o problema"
    echo ""
    echo "📊 RESULTADO ESPERADO:"
    echo "   Dashboard ultra-básico em: http://100.87.71.125:5000/ultra-basic"
    echo "   Esse DEVE funcionar e mostrar dados"
    echo ""
    echo "🔄 Após o diagnóstico, me informe:"
    echo "   1. Se o ultra-básico funciona"
    echo "   2. Se mostra dados de temperatura/umidade" 
    echo "   3. Qual o comportamento dos outros painéis"
else
    echo "❌ Erro ao transferir. Execute manualmente:"
    echo ""
    echo "📋 INSTRUÇÕES MANUAIS:"
    echo "   1. ssh $PI_USER@$PI_HOST"
    echo "   2. nano diagnosis_complete.sh"
    echo "   3. Cole o conteúdo do script"
    echo "   4. chmod +x diagnosis_complete.sh"
    echo "   5. ./diagnosis_complete.sh"
fi

echo ""
echo "💡 Este diagnóstico vai criar uma versão ULTRA-BÁSICA"
echo "   que definitivamente deve funcionar se o backend estiver OK"
