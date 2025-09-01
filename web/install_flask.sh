#!/bin/bash

# ============================================
# HomeGuard Flask Dashboard - Instalação
# Alternativa leve ao Streamlit
# ============================================

echo "🌐 HomeGuard - Instalação Flask Dashboard"
echo "=========================================="

# Verificar se estamos no diretório correto
if [ ! -d "web" ]; then
    echo "❌ Diretório 'web' não encontrado!"
    echo "   Execute este script a partir da raiz do projeto HomeGuard"
    exit 1
fi

echo "📦 Instalando Flask (muito mais leve que Streamlit)..."

# Instalar Flask via pip3 sistema
pip3 install flask --user

# Verificar instalação
if python3 -c "import flask; print(f'Flask: {flask.__version__}')" 2>/dev/null; then
    echo "✅ Flask instalado com sucesso!"
else
    echo "❌ Erro ao instalar Flask. Tentando via apt..."
    sudo apt install python3-flask
fi

# Verificar novamente
if python3 -c "import flask; print(f'Flask: {flask.__version__}')" 2>/dev/null; then
    echo "✅ Flask funcionando!"
else
    echo "❌ Falha na instalação do Flask"
    exit 1
fi

# Verificar se templates existem
if [ ! -d "web/templates" ]; then
    echo "❌ Diretório templates não encontrado!"
    echo "   Certifique-se de que todos os arquivos foram sincronizados"
    exit 1
fi

echo ""
echo "🎉 Flask Dashboard instalado com sucesso!"
echo ""
echo "📋 Para executar:"
echo "   cd web"
echo "   python3 homeguard_flask.py"
echo ""
echo "🌐 Acesse em: http://192.168.18.198:5000"
echo ""
echo "💡 O Flask é muito mais leve que o Streamlit e deve funcionar"
echo "   perfeitamente no Raspberry Pi sem erros 'Illegal Instruction'"
