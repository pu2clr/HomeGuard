#!/bin/bash
#
# Transfer e execução do rollback
#

echo "🚨 TRANSFERINDO SCRIPT DE ROLLBACK"
echo "=================================="

PI_USER="homeguard"
PI_HOST="100.87.71.125"
SCRIPT_NAME="rollback_dashboard.sh"

echo "📡 Transferindo script de rollback..."
scp "scripts/$SCRIPT_NAME" "$PI_USER@$PI_HOST:~/"

if [ $? -eq 0 ]; then
    echo "✅ Script transferido com sucesso!"
    echo ""
    echo "🚀 EXECUTE NO RASPBERRY PI:"
    echo "   ssh $PI_USER@$PI_HOST"
    echo "   chmod +x $SCRIPT_NAME"
    echo "   ./$SCRIPT_NAME"
    echo ""
    echo "💡 Ou execute diretamente:"
    echo "   ssh $PI_USER@$PI_HOST 'chmod +x $SCRIPT_NAME && ./$SCRIPT_NAME'"
    echo ""
    echo "🎯 OBJETIVO DO ROLLBACK:"
    echo "   ✅ Restaurar templates funcionais básicos"
    echo "   ✅ Corrigir base.html sem quebrar outros painéis"
    echo "   ✅ Garantir que todos os painéis carreguem dados"
    echo "   ✅ Voltar ao estado estável"
else
    echo "❌ Erro ao transferir. Execute manualmente:"
    echo ""
    echo "📋 INSTRUÇÕES MANUAIS:"
    echo "   1. ssh $PI_USER@$PI_HOST"
    echo "   2. nano rollback_dashboard.sh"
    echo "   3. Cole o conteúdo do script"
    echo "   4. chmod +x rollback_dashboard.sh"
    echo "   5. ./rollback_dashboard.sh"
fi

echo ""
echo "🔄 Após o rollback, teste:"
echo "   http://100.87.71.125:5000/ - Dashboard principal"
echo "   http://100.87.71.125:5000/temperature - Temperatura"
echo "   http://100.87.71.125:5000/humidity - Umidade"
echo "   http://100.87.71.125:5000/motion - Movimento"
echo "   http://100.87.71.125:5000/relay - Relés"
