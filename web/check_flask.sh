#!/bin/bash

# Script para verificar status do Flask Dashboard

echo "🔍 Verificando status do HomeGuard Flask Dashboard..."
echo "=================================================="

# Verificar se está rodando
if pgrep -f "python3 homeguard_flask.py" > /dev/null; then
    PID=$(pgrep -f "python3 homeguard_flask.py")
    echo "✅ Status: RODANDO (PID: $PID)"
    
    # Mostrar IP local
    LOCAL_IP=$(hostname -I | cut -d' ' -f1)
    echo "🌐 URL: http://$LOCAL_IP:5000"
    
    # Verificar porta
    if netstat -tuln | grep :5000 > /dev/null; then
        echo "🔌 Porta 5000: ABERTA"
    else
        echo "❌ Porta 5000: FECHADA"
    fi
    
else
    echo "❌ Status: PARADO"
fi

echo ""
echo "📝 Últimas 10 linhas do log:"
echo "----------------------------"
if [ -f "flask.log" ]; then
    tail -n 10 flask.log
else
    echo "Arquivo de log não encontrado."
fi

echo ""
echo "🛠️  Comandos úteis:"
echo "   • Parar:      pkill -f 'python3 homeguard_flask.py'"
echo "   • Iniciar:    ./restart_flask.sh"
echo "   • Ver logs:   tail -f flask.log"
echo "   • Teste DB:   ls -la ../db/"
