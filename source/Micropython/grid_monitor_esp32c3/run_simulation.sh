#!/bin/bash

# Script de Controle do Simulador ESP32-C3 Grid Monitor
# Permite controlar a simulação interativamente

echo "🎮 CONTROLADOR DE SIMULAÇÃO ESP32-C3 GRID MONITOR"
echo "================================================="
echo ""

# Verificar se o simulador existe
if [ ! -f "simulate_esp32.py" ]; then
    echo "❌ simulate_esp32.py não encontrado!"
    echo "   Certifique-se de estar na pasta: source/Micropython/grid_monitor_esp32c3"
    exit 1
fi

# Verificar se main.py existe
if [ ! -f "main.py" ]; then
    echo "❌ main.py não encontrado!"
    echo "   Certifique-se de estar na pasta correta"
    exit 1
fi

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Menu de simulação
show_simulation_menu() {
    echo ""
    echo "🎮 OPÇÕES DE SIMULAÇÃO:"
    echo "====================="
    echo "1. 🚀 Executar simulação completa"
    echo "2. 🔍 Validar código antes da simulação"
    echo "3. 📊 Simulação com logs detalhados"
    echo "4. 🎯 Simulação modo debug (passo a passo)"
    echo "5. 🔄 Simulação com reinício automático"
    echo "6. 📱 Gerar relatório de simulação"
    echo "7. 🛠️  Configurar parâmetros de simulação"
    echo "8. 👀 Ver código sendo simulado"
    echo "9. 🏠 Voltar ao menu principal"
    echo ""
}

# Executar simulação básica
run_basic_simulation() {
    log_info "Iniciando simulação básica..."
    echo ""
    echo "🎯 Para parar a simulação: Ctrl+C"
    echo "📊 Logs da simulação:"
    echo "===================="
    python3 simulate_esp32.py
}

# Executar com validação
run_with_validation() {
    log_info "Validando código antes da simulação..."
    
    if [ -f "validate_simple.sh" ]; then
        ./validate_simple.sh main.py
        validation_result=$?
        
        if [ $validation_result -eq 0 ]; then
            log_success "Validação OK! Iniciando simulação..."
            echo ""
            python3 simulate_esp32.py
        else
            log_error "Validação falhou! Corrija os problemas antes de simular."
            return 1
        fi
    else
        log_warning "Validador não encontrado, executando simulação diretamente..."
        python3 simulate_esp32.py
    fi
}

# Simulação com logs detalhados
run_detailed_simulation() {
    log_info "Simulação com logs detalhados..."
    echo ""
    echo "📝 Salvando logs em: simulation_log.txt"
    
    python3 simulate_esp32.py 2>&1 | tee simulation_log.txt
    
    echo ""
    log_success "Logs salvos em simulation_log.txt"
}

# Configurar parâmetros
configure_simulation() {
    echo ""
    echo "🛠️  CONFIGURAÇÃO DE SIMULAÇÃO"
    echo "============================"
    echo ""
    
    echo "Parâmetros atuais do sensor ZMPT101B:"
    grep -n "GRID_THRESHOLD\|ADC_SAMPLES\|SAMPLE_DELAY" main.py | head -5
    
    echo ""
    echo "🔧 Opções de configuração:"
    echo "1. Alterar threshold do sensor (atual: detectar em main.py)"
    echo "2. Alterar número de amostras ADC"
    echo "3. Alterar delay entre amostras"
    echo "4. Configurar WiFi/MQTT simulado"
    echo "5. Voltar"
    echo ""
    
    read -p "Escolha uma opção (1-5): " config_choice
    
    case $config_choice in
        1)
            echo "📊 Threshold atual:"
            grep "GRID_THRESHOLD" main.py
            echo ""
            echo "💡 Para alterar, edite main.py e modifique GRID_THRESHOLD"
            ;;
        2)
            echo "🔢 Samples atuais:"
            grep "ADC_SAMPLES" main.py
            echo ""
            echo "💡 Para alterar, edite main.py e modifique ADC_SAMPLES"
            ;;
        3)
            echo "⏱️  Delay atual:"
            grep "SAMPLE_DELAY" main.py
            echo ""
            echo "💡 Para alterar, edite main.py e modifique SAMPLE_DELAY"
            ;;
        4)
            echo "📡 Configurações WiFi/MQTT atuais:"
            grep -E "WIFI_SSID|MQTT_SERVER" main.py
            echo ""
            echo "💡 Para alterar, edite main.py"
            ;;
        *)
            return
            ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
}

# Ver código
view_code() {
    echo ""
    echo "👀 CÓDIGO SENDO SIMULADO (main.py):"
    echo "==================================="
    echo ""
    
    # Mostrar primeiras 50 linhas
    head -50 main.py | nl
    
    echo ""
    echo "... (mostrando primeiras 50 linhas)"
    echo "📄 Arquivo completo: $(wc -l < main.py) linhas"
    echo ""
    read -p "Pressione Enter para continuar..."
}

# Gerar relatório
generate_report() {
    log_info "Gerando relatório de simulação..."
    
    report_file="simulation_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# RELATÓRIO DE SIMULAÇÃO ESP32-C3 GRID MONITOR
==================================================

**Data:** $(date)
**Código:** main.py
**Simulador:** simulate_esp32.py

## CONFIGURAÇÕES DETECTADAS:

\`\`\`
$(grep -E "WIFI_SSID|MQTT_SERVER|GRID_THRESHOLD|ADC_SAMPLES|SAMPLE_DELAY" main.py)
\`\`\`

## ESTRUTURA DO CÓDIGO:

**Tamanho:** $(wc -l < main.py) linhas
**Tamanho:** $(wc -c < main.py) bytes

## VALIDAÇÃO:

EOF

    if [ -f "validate_simple.sh" ]; then
        echo "Executando validação..." >> "$report_file"
        ./validate_simple.sh main.py >> "$report_file" 2>&1
    else
        echo "Validador não disponível" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

## MÓDULOS SIMULADOS:

- ✅ machine (Pin, ADC, idle, reset)
- ✅ network (WLAN, WiFi connection)
- ✅ umqtt.simple (MQTTClient)
- ✅ gc (garbage collector)
- ✅ time (sleep_ms, ticks_ms)

## HARDWARE SIMULADO:

- 📊 GPIO0: ADC (Sensor ZMPT101B)
- 🔌 GPIO5: OUTPUT (Relay)
- 💡 GPIO8: OUTPUT (LED)

## PARA EXECUTAR:

\`\`\`bash
cd source/Micropython/grid_monitor_esp32c3
python3 simulate_esp32.py
\`\`\`

---
**Gerado por:** ./run_simulation.sh
EOF

    log_success "Relatório gerado: $report_file"
    echo ""
    echo "📄 Conteúdo do relatório:"
    echo "========================"
    cat "$report_file"
    echo ""
    read -p "Pressione Enter para continuar..."
}

# Menu principal
main_menu() {
    while true; do
        echo ""
        echo "🎮 SIMULADOR ESP32-C3 GRID MONITOR"
        echo "=================================="
        echo ""
        echo "📱 Status dos arquivos:"
        
        if [ -f "main.py" ]; then
            echo "   ✅ main.py ($(wc -l < main.py) linhas)"
        else
            echo "   ❌ main.py não encontrado"
        fi
        
        if [ -f "simulate_esp32.py" ]; then
            echo "   ✅ simulate_esp32.py"
        else
            echo "   ❌ simulate_esp32.py não encontrado"
        fi
        
        if [ -f "validate_simple.sh" ]; then
            echo "   ✅ validate_simple.sh"
        else
            echo "   ⚠️  validate_simple.sh não encontrado"
        fi
        
        show_simulation_menu
        
        read -p "Escolha uma opção (1-9): " choice
        
        case $choice in
            1)
                run_basic_simulation
                ;;
            2)
                run_with_validation
                ;;
            3)
                run_detailed_simulation
                ;;
            4)
                log_info "Modo debug não implementado ainda"
                log_info "Use a simulação básica com Ctrl+C para parar"
                ;;
            5)
                log_info "Reinício automático não implementado ainda"
                log_info "Use a simulação básica"
                ;;
            6)
                generate_report
                ;;
            7)
                configure_simulation
                ;;
            8)
                view_code
                ;;
            9)
                log_info "Saindo do simulador..."
                exit 0
                ;;
            *)
                log_error "Opção inválida!"
                ;;
        esac
        
        echo ""
        read -p "Pressione Enter para voltar ao menu..."
    done
}

# Verificar argumentos da linha de comando
if [ "$1" = "run" ]; then
    run_basic_simulation
elif [ "$1" = "validate" ]; then
    run_with_validation
elif [ "$1" = "report" ]; then
    generate_report
elif [ "$1" = "config" ]; then
    configure_simulation
else
    # Menu interativo
    main_menu
fi