#!/bin/bash

# Script de Validação MicroPython para HomeGuard
# Valida código antes do upload para ESP32-C3

echo "🔍 VALIDADOR DE CÓDIGO MICROPYTHON - HOMEGUARD"
echo "=============================================="
echo ""

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_FILES=("main.py" "main_fixed.py" "sensor_calibration.py")
MICROPYTHON_VERSION="1.26.1"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Verificar dependências
check_dependencies() {
    log_info "Verificando dependências..."
    
    local missing_deps=()
    
    # Verificar Python
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    # Verificar mpy-cross
    if ! command -v mpy-cross &> /dev/null; then
        missing_deps+=("mpy-cross")
    fi
    
    # Verificar pylint
    if ! command -v pylint &> /dev/null; then
        missing_deps+=("pylint")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        log_success "Todas as dependências encontradas"
        return 0
    else
        log_error "Dependências faltando: ${missing_deps[*]}"
        echo ""
        echo "Para instalar:"
        echo "pip install mpy-cross pylint micropython-stubs"
        return 1
    fi
}

# Validação de sintaxe Python básica
validate_python_syntax() {
    local file="$1"
    log_info "Validando sintaxe Python: $file"
    
    if python3 -m py_compile "$file" 2>/dev/null; then
        log_success "Sintaxe Python OK: $file"
        return 0
    else
        log_error "Erro de sintaxe Python: $file"
        python3 -m py_compile "$file"
        return 1
    fi
}

# Validação com mpy-cross
validate_micropython_syntax() {
    local file="$1"
    log_info "Validando com mpy-cross: $file"
    
    if mpy-cross "$file" 2>/dev/null; then
        log_success "MicroPython syntax OK: $file"
        # Limpar arquivo .mpy gerado
        rm -f "${file%.py}.mpy" 2>/dev/null
        return 0
    else
        log_error "Erro MicroPython syntax: $file"
        mpy-cross "$file"
        return 1
    fi
}

# Análise estática com pylint
static_analysis() {
    local file="$1"
    log_info "Análise estática: $file"
    
    # Configuração pylint para MicroPython
    local pylint_config="
[MESSAGES CONTROL]
disable=missing-docstring,invalid-name,too-few-public-methods,import-error,no-member

[BASIC]
good-names=i,j,k,ex,Run,_,adc,led,val

[IMPORTS]
ignored-modules=machine,network,umqtt,esp32,gc,time
"
    
    echo "$pylint_config" > .pylintrc_temp
    
    local score=$(pylint --rcfile=.pylintrc_temp "$file" 2>/dev/null | grep "Your code has been rated" | cut -d' ' -f7 | cut -d'/' -f1)
    
    rm -f .pylintrc_temp
    
    if [ -n "$score" ]; then
        local score_int=$(echo "$score" | cut -d'.' -f1)
        if [ "$score_int" -ge 8 ]; then
            log_success "Análise estática OK: $file (Score: $score/10)"
        elif [ "$score_int" -ge 6 ]; then
            log_warning "Análise estática ACEITÁVEL: $file (Score: $score/10)"
        else
            log_error "Análise estática RUIM: $file (Score: $score/10)"
        fi
    else
        log_warning "Não foi possível obter score de análise: $file"
    fi
}

# Verificação de importações MicroPython
check_micropython_imports() {
    local file="$1"
    log_info "Verificando importações MicroPython: $file"
    
    local valid_imports=("machine" "time" "network" "umqtt.simple" "gc" "esp32" "utime" "ujson")
    local invalid_imports=()
    
    # Procurar por importações problemáticas
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*import[[:space:]]+([a-zA-Z0-9_.]+) ]]; then
            local module="${BASH_REMATCH[1]}"
            # Verificar se é uma importação padrão Python que pode não existir no MicroPython
            if [[ "$module" =~ ^(os|sys|threading|multiprocessing|subprocess)$ ]]; then
                invalid_imports+=("$module")
            fi
        fi
    done < "$file"
    
    if [ ${#invalid_imports[@]} -eq 0 ]; then
        log_success "Importações MicroPython OK: $file"
        return 0
    else
        log_error "Importações problemáticas encontradas: ${invalid_imports[*]}"
        return 1
    fi
}

# Verificação de pinos ESP32-C3
check_esp32c3_pins() {
    local file="$1"
    log_info "Verificando configuração de pinos ESP32-C3: $file"
    
    local pin_errors=()
    
    # Verificar pinos válidos para ESP32-C3
    while IFS= read -r line; do
        if [[ $line =~ _PIN[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
            local pin="${BASH_REMATCH[1]}"
            # ESP32-C3 tem GPIO 0-21, mas alguns são reservados
            if [ "$pin" -gt 21 ]; then
                pin_errors+=("GPIO$pin > 21 (máximo para ESP32-C3)")
            fi
            if [ "$pin" -eq 11 ] || [ "$pin" -eq 12 ] || [ "$pin" -eq 13 ] || [ "$pin" -eq 14 ] || [ "$pin" -eq 15 ] || [ "$pin" -eq 16 ] || [ "$pin" -eq 17 ]; then
                pin_errors+=("GPIO$pin reservado para SPI Flash")
            fi
        fi
    done < "$file"
    
    if [ ${#pin_errors[@]} -eq 0 ]; then
        log_success "Configuração de pinos OK: $file"
        return 0
    else
        log_error "Problemas de pinos: ${pin_errors[*]}"
        return 1
    fi
}

# Verificação de configurações MQTT
check_mqtt_config() {
    local file="$1"
    log_info "Verificando configuração MQTT: $file"
    
    local mqtt_errors=()
    
    # Verificar se tem configurações MQTT
    if ! grep -q "MQTT_SERVER" "$file"; then
        mqtt_errors+=("MQTT_SERVER não encontrado")
    fi
    
    if ! grep -q "MQTT_USER" "$file"; then
        mqtt_errors+=("MQTT_USER não encontrado")
    fi
    
    if ! grep -q "MQTT_PASS" "$file"; then
        mqtt_errors+=("MQTT_PASS não encontrado")
    fi
    
    # Verificar se os tópicos estão definidos
    if ! grep -q "TOPIC_STATUS" "$file"; then
        mqtt_errors+=("TOPIC_STATUS não encontrado")
    fi
    
    if ! grep -q "TOPIC_COMMAND" "$file"; then
        mqtt_errors+=("TOPIC_COMMAND não encontrado")
    fi
    
    if [ ${#mqtt_errors[@]} -eq 0 ]; then
        log_success "Configuração MQTT OK: $file"
        return 0
    else
        log_error "Problemas MQTT: ${mqtt_errors[*]}"
        return 1
    fi
}

# Estimativa de uso de memória
estimate_memory_usage() {
    local file="$1"
    log_info "Estimando uso de memória: $file"
    
    local file_size=$(wc -c < "$file")
    local estimated_ram=$((file_size * 3))  # Estimativa rough: 3x o tamanho do arquivo
    
    if [ $estimated_ram -lt 50000 ]; then
        log_success "Uso estimado de RAM: ${estimated_ram} bytes (OK para ESP32-C3)"
    elif [ $estimated_ram -lt 100000 ]; then
        log_warning "Uso estimado de RAM: ${estimated_ram} bytes (LIMITE para ESP32-C3)"
    else
        log_error "Uso estimado de RAM: ${estimated_ram} bytes (MUITO ALTO para ESP32-C3)"
    fi
}

# Simulação básica de funcionamento
simulate_basic_logic() {
    local file="$1"
    log_info "Simulando lógica básica: $file"
    
    # Verificar se tem loop principal
    if grep -q "while True:" "$file"; then
        log_success "Loop principal encontrado"
    else
        log_warning "Loop principal não encontrado"
    fi
    
    # Verificar se tem tratamento de exceções
    if grep -q "try:" "$file" && grep -q "except:" "$file"; then
        log_success "Tratamento de exceções encontrado"
    else
        log_warning "Tratamento de exceções não encontrado"
    fi
    
    # Verificar se tem machine.idle() para watchdog
    if grep -q "machine.idle()" "$file"; then
        log_success "Watchdog reset encontrado (machine.idle)"
    else
        log_warning "Watchdog reset não encontrado - pode causar WDT timeout"
    fi
}

# Relatório de validação
generate_report() {
    local file="$1"
    local total_tests="$2"
    local passed_tests="$3"
    
    echo ""
    echo "📊 RELATÓRIO DE VALIDAÇÃO: $file"
    echo "================================"
    echo "Testes executados: $total_tests"
    echo "Testes passaram: $passed_tests"
    echo "Taxa de sucesso: $((passed_tests * 100 / total_tests))%"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_success "CÓDIGO PRONTO PARA UPLOAD! 🚀"
    elif [ $passed_tests -ge $((total_tests * 80 / 100)) ]; then
        log_warning "CÓDIGO ACEITÁVEL, mas verifique os warnings ⚠️"
    else
        log_error "CÓDIGO PRECISA DE CORREÇÕES antes do upload ❌"
    fi
    echo ""
}

# Validação completa de um arquivo
validate_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_error "Arquivo não encontrado: $file"
        return 1
    fi
    
    echo ""
    echo "🔍 VALIDANDO: $file"
    echo "==================="
    
    local tests_total=8
    local tests_passed=0
    
    # Executar todos os testes
    validate_python_syntax "$file" && ((tests_passed++))
    validate_micropython_syntax "$file" && ((tests_passed++))
    static_analysis "$file" && ((tests_passed++))
    check_micropython_imports "$file" && ((tests_passed++))
    check_esp32c3_pins "$file" && ((tests_passed++))
    check_mqtt_config "$file" && ((tests_passed++))
    estimate_memory_usage "$file" && ((tests_passed++))
    simulate_basic_logic "$file" && ((tests_passed++))
    
    generate_report "$file" $tests_total $tests_passed
    
    return $((tests_total - tests_passed))
}

# Função principal
main() {
    # Verificar dependências
    if ! check_dependencies; then
        exit 1
    fi
    
    echo ""
    
    # Se arquivo específico foi passado como argumento
    if [ $# -gt 0 ]; then
        validate_file "$1"
        exit $?
    fi
    
    # Validar todos os arquivos Python
    local total_errors=0
    for file in "${PYTHON_FILES[@]}"; do
        if [ -f "$file" ]; then
            validate_file "$file"
            total_errors=$((total_errors + $?))
        else
            log_warning "Arquivo não encontrado: $file"
        fi
    done
    
    echo ""
    echo "🎯 VALIDAÇÃO COMPLETA"
    echo "===================="
    if [ $total_errors -eq 0 ]; then
        log_success "TODOS OS ARQUIVOS VALIDADOS COM SUCESSO! 🎉"
        echo ""
        echo "📤 Próximos passos:"
        echo "1. ./test_wdt_fix.sh upload    # Upload para ESP32-C3"
        echo "2. ./test_wdt_fix.sh monitor   # Monitorar funcionamento"
    else
        log_error "ENCONTRADOS $total_errors PROBLEMAS NOS ARQUIVOS"
        echo ""
        echo "🔧 Corrija os problemas antes do upload"
    fi
    
    exit $total_errors
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi