#!/bin/bash

# Script para reiniciar o Flask Dashboard no Raspberry Pi

echo "🔄 Reiniciando HomeGuard Flask Dashboard..."

# Parar processo existente (se estiver rodando)
pkill -f "python3 homeguard_flask.py" 2>/dev/null || true

# Aguardar um momento
sleep 2

# Iniciar o Flask em background
nohup python3 homeguard_flask.py > flask.log 2>&1 &

# Verificar se iniciou
sleep 3

if pgrep -f "python3 homeguard_flask.py" > /dev/null; then
    echo "✅ Flask Dashboard iniciado com sucesso!"
    echo "📝 Logs em: $(pwd)/flask.log"
    echo "🌐 Acesse: http://$(hostname -I | cut -d' ' -f1):5000"
    echo ""
    echo "Para parar: pkill -f 'python3 homeguard_flask.py'"
    echo "Para ver logs: tail -f flask.log"
else
    echo "❌ Erro ao iniciar Flask Dashboard"
    echo "📝 Verificar logs:"
    cat flask.log
fi
