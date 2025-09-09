#!/bin/bash
#
# Script para transferir e executar a correção no Raspberry Pi
#

echo "📡 Transferindo script de correção para Raspberry Pi"
echo "=================================================="

PI_USER="homeguard"
PI_HOST="100.87.71.125"
SCRIPT_NAME="fix_temperature_chart_pi.sh"

echo "🔄 Transferindo script..."
scp "scripts/$SCRIPT_NAME" "$PI_USER@$PI_HOST:~/"

if [ $? -eq 0 ]; then
    echo "✅ Script transferido com sucesso"
    echo ""
    echo "🚀 Para executar no Raspberry Pi:"
    echo "   ssh $PI_USER@$PI_HOST"
    echo "   chmod +x $SCRIPT_NAME"
    echo "   ./$SCRIPT_NAME"
    echo ""
    echo "💡 Ou execute diretamente:"
    echo "   ssh $PI_USER@$PI_HOST 'chmod +x $SCRIPT_NAME && ./$SCRIPT_NAME'"
else
    echo "❌ Erro ao transferir script"
    echo ""
    echo "📋 Alternativa manual:"
    echo "   1. Copie o conteúdo de: scripts/$SCRIPT_NAME"
    echo "   2. SSH no Raspberry Pi: ssh $PI_USER@$PI_HOST"
    echo "   3. Cole em um arquivo: nano $SCRIPT_NAME"
    echo "   4. Execute: chmod +x $SCRIPT_NAME && ./$SCRIPT_NAME"
fi
