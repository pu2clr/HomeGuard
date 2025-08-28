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
elif pip3 install --user mysql-connector-python PyMySQL; then
    echo "✅ Drivers instalados via pip3 --user"
    METHOD="pip3-user"
elif pip3 install --break-system-packages mysql-connector-python PyMySQL; then
    echo "✅ Drivers instalados via pip3 --break-system-packages"
    METHOD="pip3-break"
else
    echo "⚠️  Falha no pip3, tentando métodos alternativos..."
    METHOD="none"
fi

# Método 2: Usando apt (fallback)
if [ "$METHOD" = "none" ]; then
    echo "2️⃣ Tentando via apt..."
    sudo apt update
    
    # Tentar diferentes nomes de pacotes
    if sudo apt install python3-pymysql -y; then
        echo "✅ PyMySQL instalado via apt"
        METHOD="apt-pymysql"
        
        # Tentar instalar mysql-connector via alternativas
        if sudo apt install python3-mysql.connector -y 2>/dev/null; then
            echo "✅ mysql.connector instalado via apt"
            METHOD="apt-full"
        else
            echo "⚠️  mysql.connector não disponível via apt, mas PyMySQL funcionará"
        fi
    else
        echo "❌ Falha no apt também"
        METHOD="failed"
    fi
fi

# Método 3: Virtual Environment (se tudo falhar)
if [ "$METHOD" = "failed" ]; then
    echo "3️⃣ Criando ambiente virtual..."
    
    # Instalar dependências para venv
    sudo apt install python3-full python3-venv python3-dev -y
    
    # Criar virtual environment no diretório homeguard-env
    if python3 -m venv homeguard-env; then
        echo "✅ Ambiente virtual criado"
        
        # Ativar ambiente e instalar dependências
        source homeguard-env/bin/activate
        pip install mysql-connector-python PyMySQL flask
        deactivate
        
        echo "✅ Drivers instalados no ambiente virtual"
        METHOD="venv"
        
        # Criar script de ativação
        cat > activate_env.sh <<'EOF'
#!/bin/bash
echo "🔄 Ativando ambiente virtual HomeGuard..."
source homeguard-env/bin/activate
echo "✅ Ambiente ativo. Para desativar: deactivate"
echo "🚀 Executar: python homeguard_flask_mysql.py"
EOF
        chmod +x activate_env.sh
        
    else
        echo "❌ Falha ao criar ambiente virtual"
        METHOD="failed"
    fi
fi

echo
echo "✅ Instalação concluída via $METHOD"

# Testar importação
echo
echo "🧪 Testando importação dos módulos..."

# Determinar comando python baseado no método
if [ "$METHOD" = "venv" ]; then
    PYTHON_CMD="homeguard-env/bin/python"
else
    PYTHON_CMD="python3"
fi

# Teste mysql.connector
if $PYTHON_CMD -c "import mysql.connector; print('✅ mysql.connector OK')" 2>/dev/null; then
    echo "✅ mysql.connector importado com sucesso"
    MYSQL_OK=true
else
    echo "⚠️  mysql.connector não disponível"
    MYSQL_OK=false
fi

# Teste PyMySQL  
if $PYTHON_CMD -c "import pymysql; print('✅ PyMySQL OK')" 2>/dev/null; then
    echo "✅ PyMySQL importado com sucesso"
    PYMYSQL_OK=true
else
    echo "⚠️  PyMySQL não disponível"
    PYMYSQL_OK=false
fi

# Verificar se pelo menos um driver funciona
if [ "$MYSQL_OK" = false ] && [ "$PYMYSQL_OK" = false ]; then
    echo
    echo "❌ NENHUM DRIVER MYSQL FUNCIONOU"
    echo "💡 Tente executar manualmente:"
    echo "   pip3 install --user mysql-connector-python"
    echo "   pip3 install --break-system-packages mysql-connector-python"
    echo "   sudo apt install python3-pymysql"
    exit 1
fi

echo
echo "🎉 DEPENDÊNCIAS INSTALADAS COM SUCESSO!"
echo "======================================="

if [ "$MYSQL_OK" = true ]; then
    echo "✅ mysql.connector: OK"
fi

if [ "$PYMYSQL_OK" = true ]; then
    echo "✅ PyMySQL: OK"
fi

echo "✅ Python3: $(python3 --version)"

if [ "$METHOD" = "venv" ]; then
    echo "⚠️  USANDO AMBIENTE VIRTUAL"
    echo "   Para usar o HomeGuard:"
    echo "   1. source homeguard-env/bin/activate"
    echo "   2. cd web/"
    echo "   3. python homeguard_flask_mysql.py"
    echo "   4. deactivate (quando terminar)"
    echo
    echo "   Ou use: ./activate_env.sh"
else
    echo "✅ pip3: $(pip3 --version | cut -d' ' -f2)"
fi

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
