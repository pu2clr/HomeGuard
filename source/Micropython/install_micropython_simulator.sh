#!/bin/bash

# Script para instalar e configurar MicroPython Unix Port
# Simulador local completo para desenvolvimento

echo "🔧 INSTALAÇÃO MICROPYTHON UNIX PORT - SIMULADOR LOCAL"
echo "====================================================="
echo ""

# Detectar sistema operacional
OS=$(uname -s)
echo "Sistema detectado: $OS"

install_micropython_unix() {
    case $OS in
        "Darwin") # macOS
            echo "🍎 Instalando no macOS..."
            if command -v brew &> /dev/null; then
                echo "→ Instalando via Homebrew..."
                brew install micropython
            else
                echo "❌ Homebrew não encontrado!"
                echo "Instale Homebrew primeiro: https://brew.sh"
                echo "Ou compile manualmente (instruções abaixo)"
                return 1
            fi
            ;;
        "Linux")
            echo "🐧 Instalando no Linux..."
            # Verificar distribuição
            if command -v apt-get &> /dev/null; then
                echo "→ Instalando via apt (Ubuntu/Debian)..."
                sudo apt-get update
                sudo apt-get install micropython
            elif command -v yum &> /dev/null; then
                echo "→ Instalando via yum (CentOS/RHEL)..."
                sudo yum install micropython
            elif command -v pacman &> /dev/null; then
                echo "→ Instalando via pacman (Arch)..."
                sudo pacman -S micropython
            else
                echo "⚠️  Distribuição não reconhecida, tentando compilação manual..."
                compile_from_source
                return $?
            fi
            ;;
        *)
            echo "❌ Sistema não suportado: $OS"
            echo "Tentando compilação manual..."
            compile_from_source
            return $?
            ;;
    esac
}

compile_from_source() {
    echo "🔨 Compilando MicroPython do código fonte..."
    
    # Verificar dependências
    echo "→ Verificando dependências..."
    local missing_deps=()
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v make &> /dev/null; then
        missing_deps+=("make")
    fi
    
    if ! command -v gcc &> /dev/null; then
        missing_deps+=("gcc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Dependências faltando: ${missing_deps[*]}"
        case $OS in
            "Darwin")
                echo "Instale Xcode Command Line Tools: xcode-select --install"
                ;;
            "Linux")
                echo "Ubuntu/Debian: sudo apt-get install git build-essential"
                echo "CentOS/RHEL: sudo yum groupinstall 'Development Tools'"
                ;;
        esac
        return 1
    fi
    
    # Clonar e compilar
    echo "→ Clonando repositório MicroPython..."
    if [ -d "micropython" ]; then
        echo "Diretório micropython já existe, atualizando..."
        cd micropython
        git pull
    else
        git clone https://github.com/micropython/micropython.git
        cd micropython
    fi
    
    echo "→ Compilando submodules..."
    git submodule update --init
    
    echo "→ Compilando mpy-cross..."
    make -C mpy-cross
    
    echo "→ Compilando unix port..."
    cd ports/unix
    make submodules
    make
    
    if [ $? -eq 0 ]; then
        echo "✅ Compilação bem-sucedida!"
        echo "→ Executável em: $(pwd)/build-standard/micropython"
        
        # Criar link simbólico
        local bin_dir="$HOME/.local/bin"
        mkdir -p "$bin_dir"
        ln -sf "$(pwd)/build-standard/micropython" "$bin_dir/micropython"
        
        # Adicionar ao PATH se necessário
        if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
            echo "→ Adicionado $bin_dir ao PATH"
            echo "→ Execute: source ~/.bashrc"
        fi
        
        cd ../../..
        return 0
    else
        echo "❌ Erro na compilação!"
        return 1
    fi
}

test_installation() {
    echo ""
    echo "🧪 TESTANDO INSTALAÇÃO..."
    echo "========================"
    
    if command -v micropython &> /dev/null; then
        echo "✅ MicroPython encontrado!"
        micropython --version
        
        echo ""
        echo "🎯 TESTE BÁSICO:"
        echo "==============="
        
        # Teste simples
        echo "print('🚀 MicroPython funcionando!')" | micropython
        
        echo ""
        echo "🔧 TESTANDO MÓDULOS ESPECÍFICOS:"
        echo "==============================="
        
        # Testar módulos que existem no simulador
        micropython -c "
import sys
print('✅ sys module OK')
print('Platform:', sys.platform)
print('Version:', sys.version)

try:
    import time
    print('✅ time module OK')
except ImportError:
    print('❌ time module não disponível')

try:
    import gc
    print('✅ gc module OK')
except ImportError:
    print('❌ gc module não disponível')

try:
    import json
    print('✅ json module OK')
except ImportError:
    print('❌ json module não disponível')

# Módulos específicos ESP32 (não disponíveis no simulador)
try:
    import machine
    print('⚠️  machine module disponível (surpreendente!)')
except ImportError:
    print('ℹ️  machine module não disponível (esperado no simulador)')

try:
    import network
    print('⚠️  network module disponível (surpreendente!)')
except ImportError:
    print('ℹ️  network module não disponível (esperado no simulador)')
"
        
        return 0
    else
        echo "❌ MicroPython não encontrado no PATH"
        return 1
    fi
}

create_test_examples() {
    echo ""
    echo "📝 CRIANDO EXEMPLOS DE TESTE..."
    echo "==============================="
    
    # Criar diretório de exemplos
    mkdir -p micropython_examples
    cd micropython_examples
    
    # Exemplo 1: Teste básico
    cat > test_basic.py << 'EOF'
"""
Teste básico MicroPython - Simulador local
"""

import sys
import time
import gc

print("🚀 MicroPython Simulator Test")
print("=" * 30)
print(f"Platform: {sys.platform}")
print(f"Version: {sys.version}")
print(f"Free memory: {gc.mem_free()} bytes")

# Teste de loop simples
print("\n🔄 Testando loop...")
for i in range(5):
    print(f"Loop {i+1}/5")
    time.sleep(0.1)

print("\n✅ Teste básico concluído!")
EOF

    # Exemplo 2: Simulação de sensor (sem hardware)
    cat > test_sensor_simulation.py << 'EOF'
"""
Simulação de sensor ZMPT101B - sem hardware
Simula leituras de tensão para testar lógica
"""

import time
import random
import gc

# Configurações simuladas
GRID_THRESHOLD_HIGH = 2750
GRID_THRESHOLD_LOW = 2650
MIN_STABLE_READINGS = 3

# Variáveis globais simuladas
grid_online = False
stable_readings_count = 0
pending_grid_state = None
reading_count = 0

def simulate_adc_reading():
    """Simula leitura do sensor ZMPT101B"""
    # Simular condições diferentes
    if reading_count < 10:
        # Simular rede normal (alta tensão)
        return random.randint(2800, 3000)
    elif reading_count < 20:
        # Simular queda de energia (baixa tensão)
        return random.randint(2400, 2600)
    else:
        # Simular retorno da energia
        return random.randint(2800, 3000)

def read_grid_voltage_simulated():
    """Simula função read_grid_voltage com filtro"""
    readings = []
    
    # Simular 20 amostras
    for i in range(20):
        val = simulate_adc_reading()
        readings.append(val)
        time.sleep(0.001)  # Simular delay
    
    # Aplicar filtro (remover outliers)
    readings.sort()
    filtered_readings = readings[2:-2]  # Remove 2 menores e 2 maiores
    
    if filtered_readings:
        average_val = sum(filtered_readings) // len(filtered_readings)
        print(f'ADC simulado: min={readings[0]}, max={readings[-1]}, avg_filtered={average_val}')
        return average_val
    else:
        return sum(readings) // len(readings)

def simulate_grid_monitor():
    """Simula o loop principal do grid monitor"""
    global grid_online, stable_readings_count, pending_grid_state, reading_count
    
    print("🔌 Iniciando simulação Grid Monitor...")
    print("====================================")
    
    while reading_count < 30:  # Simular 30 leituras
        reading_count += 1
        
        # Simular leitura de tensão
        voltage_reading = read_grid_voltage_simulated()
        
        # Aplicar hysteresis
        if grid_online:
            new_state = voltage_reading > GRID_THRESHOLD_LOW
        else:
            new_state = voltage_reading > GRID_THRESHOLD_HIGH
        
        # Verificar estabilidade
        if pending_grid_state != new_state:
            pending_grid_state = new_state
            stable_readings_count = 1
        else:
            stable_readings_count += 1
        
        # Mudar estado apenas após leituras estáveis
        if stable_readings_count >= MIN_STABLE_READINGS:
            if grid_online != new_state:
                grid_online = new_state
                print(f'*** MUDANÇA DE ESTADO: Grid {"ON" if grid_online else "OFF"} (tensão: {voltage_reading}) ***')
        
        # Log detalhado
        print(f'Leitura {reading_count}: {voltage_reading} - Grid: {"ON" if grid_online else "OFF"} (stable: {stable_readings_count}/{MIN_STABLE_READINGS})')
        
        # Simular delay do loop principal
        time.sleep(0.5)
        
        # Garbage collection periódico
        if reading_count % 10 == 0:
            gc.collect()
            print(f'Memória livre: {gc.mem_free()} bytes')
    
    print("\n✅ Simulação concluída!")

if __name__ == '__main__':
    simulate_grid_monitor()
EOF

    # Exemplo 3: Teste de algoritmos
    cat > test_algorithms.py << 'EOF'
"""
Teste de algoritmos de filtragem - MicroPython
Valida algoritmos sem hardware
"""

import time
import random

def test_outlier_filter():
    """Testa filtro de outliers"""
    print("🔍 Testando filtro de outliers...")
    
    # Dados de teste com outliers
    test_data = [
        [2800, 2810, 2805, 1000, 2815, 2790, 5000, 2800, 2820, 2795],  # Com outliers
        [2800, 2810, 2805, 2815, 2790, 2800, 2820, 2795, 2785, 2825],  # Sem outliers
    ]
    
    for i, readings in enumerate(test_data):
        print(f"\nTeste {i+1}: {readings}")
        
        # Aplicar filtro
        readings_copy = readings.copy()
        readings_copy.sort()
        
        # Remover 2 menores e 2 maiores
        filtered = readings_copy[2:-2]
        
        original_avg = sum(readings) // len(readings)
        filtered_avg = sum(filtered) // len(filtered)
        
        print(f"Original: min={min(readings)}, max={max(readings)}, avg={original_avg}")
        print(f"Filtrado: min={min(filtered)}, max={max(filtered)}, avg={filtered_avg}")
        print(f"Diferença: {abs(original_avg - filtered_avg)} pontos")

def test_hysteresis():
    """Testa lógica de hysteresis"""
    print("\n🔄 Testando hysteresis...")
    
    THRESHOLD_HIGH = 2750
    THRESHOLD_LOW = 2650
    
    # Sequência de teste
    test_sequence = [2500, 2600, 2700, 2800, 2700, 2600, 2500, 2800]
    
    grid_state = False
    
    for voltage in test_sequence:
        if grid_state:
            new_state = voltage > THRESHOLD_LOW
        else:
            new_state = voltage > THRESHOLD_HIGH
        
        if new_state != grid_state:
            grid_state = new_state
            print(f"Tensão: {voltage} → Grid {'ON' if grid_state else 'OFF'}")
        else:
            print(f"Tensão: {voltage} → Grid {'ON' if grid_state else 'OFF'} (sem mudança)")

if __name__ == '__main__':
    test_outlier_filter()
    test_hysteresis()
EOF

    # Script de execução
    cat > run_tests.py << 'EOF'
"""
Executor de testes MicroPython
"""

import sys
import time

def run_test(filename):
    """Executa um teste específico"""
    print(f"\n🚀 Executando: {filename}")
    print("=" * 50)
    
    try:
        # Simular import do arquivo
        with open(filename, 'r') as f:
            code = f.read()
        
        # Executar código
        exec(code)
        
        print(f"✅ {filename} executado com sucesso!")
        
    except Exception as e:
        print(f"❌ Erro em {filename}: {e}")

def main():
    """Executa todos os testes"""
    tests = [
        'test_basic.py',
        'test_sensor_simulation.py', 
        'test_algorithms.py'
    ]
    
    print("🧪 SUITE DE TESTES MICROPYTHON")
    print("==============================")
    
    for test in tests:
        run_test(test)
        time.sleep(1)
    
    print("\n🎯 Todos os testes concluídos!")

if __name__ == '__main__':
    main()
EOF

    cd ..
    
    echo "✅ Exemplos criados em: micropython_examples/"
    echo ""
    echo "🚀 Para executar:"
    echo "cd micropython_examples"
    echo "micropython test_basic.py"
    echo "micropython test_sensor_simulation.py"
    echo "micropython run_tests.py"
}

usage() {
    echo ""
    echo "📖 USO DO SIMULADOR MICROPYTHON:"
    echo "================================"
    echo ""
    echo "# Executar REPL interativo:"
    echo "micropython"
    echo ""
    echo "# Executar arquivo:"
    echo "micropython meu_script.py"
    echo ""
    echo "# Executar código inline:"
    echo "micropython -c \"print('Hello MicroPython!')\""
    echo ""
    echo "# Modo verbose (debug):"
    echo "micropython -v meu_script.py"
    echo ""
    echo "🎯 VANTAGENS DO SIMULADOR LOCAL:"
    echo "- ✅ Teste de lógica sem hardware"
    echo "- ✅ Debug rápido e fácil"
    echo "- ✅ Desenvolvimento offline"
    echo "- ✅ Validação de algoritmos"
    echo "- ✅ CI/CD integration"
}

main() {
    echo "Escolha uma opção:"
    echo "1. Instalar MicroPython Unix Port"
    echo "2. Testar instalação existente"
    echo "3. Criar exemplos de teste"
    echo "4. Mostrar uso"
    echo "5. Fazer tudo"
    echo ""
    read -p "Opção (1-5): " choice
    
    case $choice in
        1)
            install_micropython_unix
            ;;
        2)
            test_installation
            ;;
        3)
            create_test_examples
            ;;
        4)
            usage
            ;;
        5)
            install_micropython_unix && test_installation && create_test_examples && usage
            ;;
        *)
            echo "Opção inválida!"
            exit 1
            ;;
    esac
}

# Verificar se foi chamado com argumentos
if [ $# -gt 0 ]; then
    case $1 in
        "install")
            install_micropython_unix
            ;;
        "test")
            test_installation
            ;;
        "examples")
            create_test_examples
            ;;
        "usage")
            usage
            ;;
        *)
            echo "Argumentos: install, test, examples, usage"
            exit 1
            ;;
    esac
else
    main
fi