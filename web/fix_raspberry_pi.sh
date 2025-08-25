#!/bin/bash

# ============================================
# HomeGuard Streamlit - Fix para Raspberry Pi
# Resolve erro "Illegal Instruction"
# ============================================

echo "🔧 HomeGuard - Fix para Raspberry Pi ARM"
echo "========================================"

# Ativar ambiente virtual
source web/venv/bin/activate

echo "📦 Desinstalando versões problemáticas..."
pip uninstall -y streamlit pandas numpy scipy

echo "🛠️ Instalando versões compatíveis com ARM..."

# Instalar versões específicas compatíveis com Raspberry Pi
pip install --no-cache-dir streamlit==1.25.0
pip install --no-cache-dir pandas==2.0.3
pip install --no-cache-dir numpy==1.24.4
pip install --no-cache-dir plotly==5.15.0

# Instalar outras dependências
pip install --no-cache-dir paho-mqtt requests pillow

echo "🧪 Testando instalação..."

# Teste básico
python -c "
try:
    import streamlit as st
    import pandas as pd
    import numpy as np
    import plotly.express as px
    print('✅ Todas as bibliotecas importadas com sucesso!')
    print(f'Streamlit: {st.__version__}')
    print(f'Pandas: {pd.__version__}')
    print(f'Numpy: {np.__version__}')
    print(f'Plotly: {px.__version__}')
except Exception as e:
    print(f'❌ Erro: {e}')
"

echo ""
echo "🎯 Teste final do Streamlit..."
timeout 10s python -c "
import streamlit as st
print('✅ Streamlit funcionando!')
" 2>/dev/null && echo "✅ Streamlit OK" || echo "❌ Ainda com problemas"

echo ""
echo "📋 Para executar:"
echo "   source web/venv/bin/activate"
echo "   streamlit run web/homeguard_dashboard.py --server.address=0.0.0.0 --server.port=8501"
