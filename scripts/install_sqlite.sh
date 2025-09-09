#!/bin/bash

# ============================================
# HomeGuard SQLite Installation Script
# Instala SQLite e dependências no Raspberry Pi
# ============================================

echo "🔧 HomeGuard - Instalação do SQLite e Dependências"
echo "================================================"

# Verificar se é sistema Debian/Ubuntu
if ! command -v apt-get &> /dev/null; then
    echo "❌ Este script é para sistemas Debian/Ubuntu (Raspberry Pi OS)"
    exit 1
fi

# Atualizar lista de pacotes
echo "📦 Atualizando lista de pacotes..."
sudo apt-get update -y

# Instalar SQLite3 e ferramentas
echo "🗄️ Instalando SQLite3..."
sudo apt-get install -y sqlite3 libsqlite3-dev

# Instalar Python 3 e dependências
echo "🐍 Instalando Python 3 e dependências..."
sudo apt-get install -y python3 python3-pip python3-dev python3-venv

# Instalar paho-mqtt para Python
echo "📡 Instalando biblioteca MQTT para Python..."
pip3 install --user paho-mqtt

# Verificar instalações
echo ""
echo "✅ Verificando instalações:"

# Verificar SQLite
if command -v sqlite3 &> /dev/null; then
    SQLITE_VERSION=$(sqlite3 --version | cut -d' ' -f1)
    echo "   SQLite3: $SQLITE_VERSION ✓"
else
    echo "   SQLite3: ❌ Não instalado"
fi

# Verificar Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo "   Python3: $PYTHON_VERSION ✓"
else
    echo "   Python3: ❌ Não instalado"
fi

# Verificar paho-mqtt
if python3 -c "import paho.mqtt.client" 2>/dev/null; then
    echo "   paho-mqtt: ✓"
else
    echo "   paho-mqtt: ❌ Não instalado"
fi

echo ""
echo "🎉 Instalação concluída!"
echo ""
echo "📋 Comandos disponíveis:"
echo "   sqlite3 --version                    # Verificar versão do SQLite"
echo "   python3 motion_monitor_sqlite.py     # Iniciar monitor com SQLite"
echo "   python3 db_utility.py --stats        # Ver estatísticas do banco"
echo "   python3 db_utility.py --recent 50    # Ver últimos 50 eventos"
echo ""
echo "📁 O banco de dados será criado em: ./db/homeguard.db"
