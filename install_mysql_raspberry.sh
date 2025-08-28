#!/bin/bash

# HomeGuard - Instalador Python MySQL (Raspberry Pi OS Bookworm+)
# Resolve o problema de PEP 668 (externally managed environment)

echo "🍓 HomeGuard - Instalador MySQL Python (Raspberry Pi OS)"
echo "======================================================="

echo "🔍 Detectando sistema..."
OS_VERSION=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2)
echo "   OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "   Codename: $OS_VERSION"

# Função para testar importação
test_import() {
    local module=$1
    local python_cmd=${2:-python3}
    
    if $python_cmd -c "import $module" 2>/dev/null; then
        echo "✅ $module OK"
        return 0
    else
        echo "❌ $module falhou"
        return 1
    fi
}

echo
echo "📦 ESTRATÉGIA 1: Usando apt (recomendado para Raspberry Pi OS)"
echo "============================================================="

# Atualizar repositórios
sudo apt update

# Instalar PyMySQL primeiro (mais comum nos repos)
echo "1️⃣ Instalando PyMySQL via apt..."
if sudo apt install python3-pymysql -y; then
    echo "✅ PyMySQL instalado via apt"
    PYMYSQL_INSTALLED=true
    test_import "pymysql"
else
    echo "❌ Falha ao instalar PyMySQL via apt"
    PYMYSQL_INSTALLED=false
fi

# Tentar instalar outras dependências MySQL
echo
echo "2️⃣ Tentando outras dependências MySQL..."
MYSQL_PACKAGES=("python3-mysql.connector" "python3-mysqldb" "python3-sqlalchemy")

for pkg in "${MYSQL_PACKAGES[@]}"; do
    if sudo apt install $pkg -y 2>/dev/null; then
        echo "✅ $pkg instalado"
    else
        echo "⚠️  $pkg não disponível"
    fi
done

echo
echo "📦 ESTRATÉGIA 2: pip3 com --break-system-packages"
echo "================================================="

if [ "$PYMYSQL_INSTALLED" = false ]; then
    echo "3️⃣ Tentando pip3 --break-system-packages..."
    
    # Avisar sobre riscos
    echo "⚠️  AVISO: Usando --break-system-packages (pode afetar sistema)"
    echo "   Pressione ENTER para continuar ou Ctrl+C para cancelar"
    read -r
    
    if pip3 install --break-system-packages mysql-connector-python PyMySQL; then
        echo "✅ Drivers instalados com --break-system-packages"
        BREAK_PACKAGES=true
    else
        echo "❌ Falha mesmo com --break-system-packages"
        BREAK_PACKAGES=false
    fi
fi

echo
echo "📦 ESTRATÉGIA 3: Virtual Environment"
echo "===================================="

# Se ainda não funcionar, criar venv
if ! test_import "pymysql" && ! test_import "mysql.connector"; then
    echo "4️⃣ Criando ambiente virtual..."
    
    # Instalar python3-venv se necessário
    sudo apt install python3-venv python3-full -y
    
    # Remover venv antigo se existir
    rm -rf homeguard-env
    
    # Criar novo venv
    if python3 -m venv homeguard-env; then
        echo "✅ Ambiente virtual criado"
        
        # Ativar e instalar
        source homeguard-env/bin/activate
        pip install --upgrade pip
        pip install mysql-connector-python PyMySQL flask
        deactivate
        
        echo "✅ Pacotes instalados no ambiente virtual"
        
        # Testar no venv
        if test_import "mysql.connector" "homeguard-env/bin/python" && test_import "pymysql" "homeguard-env/bin/python"; then
            echo "✅ Testes no venv passaram"
            VENV_SUCCESS=true
        else
            echo "❌ Falha nos testes do venv"
            VENV_SUCCESS=false
        fi
    else
        echo "❌ Falha ao criar ambiente virtual"
        VENV_SUCCESS=false
    fi
fi

echo
echo "🧪 TESTES FINAIS"
echo "================"

# Testar importações
MYSQL_WORKS=false
PYMYSQL_WORKS=false

if test_import "mysql.connector"; then
    MYSQL_WORKS=true
fi

if test_import "pymysql"; then
    PYMYSQL_WORKS=true
fi

# Verificar se pelo menos um funciona
echo
echo "📊 RESULTADO:"
echo "============="

if [ "$MYSQL_WORKS" = true ] || [ "$PYMYSQL_WORKS" = true ]; then
    echo "🎉 SUCESSO! Pelo menos um driver MySQL funciona"
    
    if [ "$MYSQL_WORKS" = true ]; then
        echo "✅ mysql.connector disponível"
    fi
    
    if [ "$PYMYSQL_WORKS" = true ]; then
        echo "✅ PyMySQL disponível"
    fi
    
    echo
    echo "🚀 PRÓXIMO PASSO:"
    echo "   ./test_mysql_connection.py"
    
elif [ "$VENV_SUCCESS" = true ]; then
    echo "🎉 SUCESSO! Drivers funcionam no ambiente virtual"
    echo
    echo "🚀 PARA USAR O HOMEGUARD:"
    echo "   source homeguard-env/bin/activate"
    echo "   ./test_mysql_connection.py" 
    echo "   cd web/ && python homeguard_flask_mysql.py"
    echo "   deactivate  # quando terminar"
    
    # Criar script helper
    cat > run_homeguard.sh <<'EOF'
#!/bin/bash
echo "🔄 Ativando ambiente virtual..."
source homeguard-env/bin/activate
echo "✅ Ambiente ativo"
echo "🚀 Executando HomeGuard..."
cd web/
python homeguard_flask_mysql.py
EOF
    chmod +x run_homeguard.sh
    echo
    echo "💡 Script criado: ./run_homeguard.sh"
    
else
    echo "❌ FALHA TOTAL - Nenhum driver MySQL funciona"
    echo
    echo "🆘 SOLUÇÕES MANUAIS:"
    echo "   1. pip3 install --user mysql-connector-python"
    echo "   2. pip3 install --break-system-packages mysql-connector-python" 
    echo "   3. Usar apenas PyMySQL (modificar homeguard_flask_mysql.py)"
    echo "   4. Compilar mysql-connector-python do código fonte"
    
    exit 1
fi

echo
echo "📝 MÉTODO USADO:"
if [ "$PYMYSQL_INSTALLED" = true ]; then
    echo "   ✅ apt install python3-pymysql"
fi

if [ "$BREAK_PACKAGES" = true ]; then
    echo "   ⚠️  pip3 --break-system-packages"
fi

if [ "$VENV_SUCCESS" = true ]; then
    echo "   🔄 Virtual Environment"
fi

echo
echo "💡 Para problemas futuros, use sempre:"
echo "   sudo apt install python3-pymysql"
