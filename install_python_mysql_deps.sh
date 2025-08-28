#!/bin/bash

# HomeGuard - Instalador de Dependências Python MySQL
# Script para instalar drivers MySQL/MariaDB para Python

echo "🐍 HomeGuard - Instalador Dependências Python"
echo "=============================================="

# Verificar se Python3 está instalado
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 não encontrado!"
    echo "💡 Instale com: sudo apt install python3 python3-pip -y"
    exit 1
fi

echo "✅ Python3 encontrado: $(python3 --version)"

# Verificar se pip3 está instalado
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 não encontrado!"
    echo "🔧 Instalando pip3..."
    sudo apt update
    sudo apt install python3-pip -y
    
    if ! command -v pip3 &> /dev/null; then
        echo "❌ Falha ao instalar pip3"
        exit 1
    fi
fi

echo "✅ pip3 encontrado: $(pip3 --version)"

echo
echo "📦 Instalando dependências MySQL/MariaDB..."

# Método 1: Usando pip3 (recomendado)
echo "1️⃣ Tentando via pip3..."

# Atualizar pip primeiro
pip3 install --upgrade pip

# Instalar drivers MySQL
if pip3 install mysql-connector-python PyMySQL; then
    echo "✅ Drivers instalados via pip3"
    METHOD="pip3"
else
    echo "⚠️  Falha no pip3, tentando apt..."
    
    # Método 2: Usando apt (fallback)
    echo "2️⃣ Tentando via apt..."
    sudo apt update
    
    if sudo apt install python3-mysql.connector python3-pymysql -y; then
        echo "✅ Drivers instalados via apt"
        METHOD="apt"
    else
        echo "❌ Falha em ambos os métodos"
        echo
        echo "🔧 SOLUÇÕES ALTERNATIVAS:"
        echo "   1. sudo apt install python3-dev default-libmysqlclient-dev build-essential"
        echo "   2. pip3 install --user mysql-connector-python"
        echo "   3. sudo apt install python3-pymysql"
        exit 1
    fi
fi

echo
echo "✅ Instalação concluída via $METHOD"

# Testar importação
echo
echo "🧪 Testando importação dos módulos..."

# Teste mysql.connector
if python3 -c "import mysql.connector; print('✅ mysql.connector OK')" 2>/dev/null; then
    echo "✅ mysql.connector importado com sucesso"
else
    echo "❌ mysql.connector falhou"
    FAILED=true
fi

# Teste PyMySQL  
if python3 -c "import pymysql; print('✅ PyMySQL OK')" 2>/dev/null; then
    echo "✅ PyMySQL importado com sucesso"
else
    echo "⚠️  PyMySQL falhou (opcional)"
fi

# Verificar se falhou
if [ "$FAILED" = true ]; then
    echo
    echo "❌ PROBLEMAS DETECTADOS"
    echo "💡 Tente executar manualmente:"
    echo "   pip3 install --user mysql-connector-python"
    echo "   python3 -c 'import mysql.connector'"
    exit 1
fi

echo
echo "🎉 DEPENDÊNCIAS INSTALADAS COM SUCESSO!"
echo "======================================="
echo "✅ mysql.connector: OK"
echo "✅ PyMySQL: OK (ou disponível via apt)"
echo "✅ Python3: $(python3 --version)"
echo "✅ pip3: $(pip3 --version | cut -d' ' -f2)"

# Instalar dependências adicionais do Flask se necessário
echo
echo "📦 Verificando dependências Flask..."

FLASK_DEPS=("flask" "datetime" "json")
MISSING_DEPS=()

for dep in "${FLASK_DEPS[@]}"; do
    if ! python3 -c "import $dep" 2>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "🔧 Instalando dependências Flask faltantes..."
    
    if [ ${#MISSING_DEPS[@]} -eq 1 ] && [ "${MISSING_DEPS[0]}" = "flask" ]; then
        pip3 install flask
        echo "✅ Flask instalado"
    else
        echo "⚠️  Algumas dependências podem estar faltando: ${MISSING_DEPS[*]}"
    fi
else
    echo "✅ Dependências Flask OK"
fi

echo
echo "🚀 PRÓXIMO PASSO:"
echo "   ./test_mysql_connection.py"
echo "   # Se OK, execute:"
echo "   cd web/ && python3 homeguard_flask_mysql.py"

# Mostrar informações do ambiente
echo
echo "📊 INFORMAÇÕES DO AMBIENTE:"
echo "   Sistema: $(uname -a | cut -d' ' -f1-3)"
echo "   Python: $(python3 --version)"
echo "   Pip: $(pip3 --version | cut -d' ' -f1-2)"
echo "   Arquitetura: $(uname -m)"

# Listar pacotes Python instalados relacionados ao MySQL
echo
echo "📋 PACOTES MYSQL INSTALADOS:"
pip3 list | grep -i mysql || echo "   (nenhum via pip3)"
dpkg -l | grep -i mysql | grep python || echo "   (nenhum via apt)"
