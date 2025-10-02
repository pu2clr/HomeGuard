#!/bin/bash

# Validador MicroPython Simplificado para HomeGuard
# Não requer instalação de dependências externas

echo "🔍 VALIDADOR MICROPYTHON SIMPLIFICADO - HOMEGUARD"
echo "=================================================="
echo ""

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

# Validação de sintaxe Python básica
validate_python_syntax() {
    local file="$1"
    log_info "Validando sintaxe Python: $file"
    
    if python3 -c "
import ast
try:
    with open('$file', 'r') as f:
        ast.parse(f.read())
    print('✅ Sintaxe Python OK')
    exit(0)
except SyntaxError as e:
    print(f'❌ Erro de sintaxe: {e}')
    exit(1)
except Exception as e:
    print(f'❌ Erro: {e}')
    exit(1)
"; then
        log_success "Sintaxe Python OK: $file"
        return 0
    else
        log_error "Erro de sintaxe Python: $file"
        return 1
    fi
}

# Verificação de importações MicroPython
check_micropython_imports() {
    local file="$1"
    log_info "Verificando importações MicroPython: $file"
    
    local valid_modules=("machine" "time" "network" "umqtt" "gc" "esp32" "utime" "ujson" "sys" "os")
    local problematic_modules=("threading" "multiprocessing" "subprocess" "requests" "urllib" "socket" "ssl")
    local warnings=()
    local errors=()
    
    # Verificar importações problemáticas
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*import[[:space:]]+([a-zA-Z0-9_.]+) ]] || [[ $line =~ ^[[:space:]]*from[[:space:]]+([a-zA-Z0-9_.]+) ]]; then
            local module="${BASH_REMATCH[1]}"
            for prob_mod in "${problematic_modules[@]}"; do
                if [[ "$module" == "$prob_mod"* ]]; then
                    errors+=("$module - não disponível no MicroPython")
                fi
            done
        fi
    done < "$file"
    
    if [ ${#errors[@]} -eq 0 ]; then
        log_success "Importações MicroPython OK: $file"
        return 0
    else
        for error in "${errors[@]}"; do
            log_error "Importação problemática: $error"
        done
        return 1
    fi
}

# Verificação de pinos ESP32-C3
check_esp32c3_pins() {
    local file="$1"
    log_info "Verificando configuração de pinos ESP32-C3: $file"
    
    local pin_errors=()
    local pin_warnings=()
    
    # Verificar definições de pinos
    while IFS= read -r line; do
        if [[ $line =~ _PIN[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
            local pin="${BASH_REMATCH[1]}"
            
            # Verificar limites
            if [ "$pin" -gt 21 ]; then
                pin_errors+=("GPIO$pin > 21 (máximo para ESP32-C3)")
            fi
            
            # Verificar pinos reservados para SPI Flash
            if [[ " 11 12 13 14 15 16 17 " =~ " $pin " ]]; then
                pin_errors+=("GPIO$pin reservado para SPI Flash")
            fi
            
            # Verificar pinos especiais
            if [ "$pin" -eq 0 ]; then
                pin_warnings+=("GPIO0 usado para boot - verificar se é adequado")
            fi
            if [ "$pin" -eq 9 ]; then
                pin_warnings+=("GPIO9 usado para boot - verificar se é adequado")
            fi
            if [[ " 18 19 " =~ " $pin " ]]; then
                pin_warnings+=("GPIO$pin usado para USB - pode causar conflitos")
            fi
        fi
    done < "$file"
    
    local has_issues=0
    
    if [ ${#pin_errors[@]} -gt 0 ]; then
        for error in "${pin_errors[@]}"; do
            log_error "Problema de pino: $error"
        done
        has_issues=1
    fi
    
    if [ ${#pin_warnings[@]} -gt 0 ]; then
        for warning in "${pin_warnings[@]}"; do
            log_warning "Aviso de pino: $warning"
        done
    fi
    
    if [ $has_issues -eq 0 ]; then
        log_success "Configuração de pinos OK: $file"
        return 0
    else
        return 1
    fi
}

# Verificação de configurações MQTT
check_mqtt_config() {
    local file="$1"
    log_info "Verificando configuração MQTT: $file"
    
    local mqtt_items=("MQTT_SERVER" "MQTT_USER" "MQTT_PASS" "DEVICE_ID" "TOPIC_STATUS" "TOPIC_COMMAND")
    local missing_items=()
    
    for item in "${mqtt_items[@]}"; do
        if ! grep -q "$item" "$file"; then
            missing_items+=("$item")
        fi
    done
    
    if [ ${#missing_items[@]} -eq 0 ]; then
        log_success "Configuração MQTT OK: $file"
        return 0
    else
        for item in "${missing_items[@]}"; do
            log_warning "MQTT item não encontrado: $item"
        done
        return 0  # Warnings, não errors
    fi
}

# Verificação de padrões de código saudável
check_code_patterns() {
    local file="$1"
    log_info "Verificando padrões de código: $file"
    
    local issues=()
    local warnings=()
    
    # Verificar loop principal
    if ! grep -q "while True:" "$file"; then
        warnings+=("Loop principal 'while True:' não encontrado")
    fi
    
    # Verificar tratamento de exceções
    if ! grep -q "try:" "$file" || ! grep -q "except:" "$file"; then
        warnings+=("Tratamento de exceções não encontrado")
    fi
    
    # Verificar watchdog reset
    if ! grep -q "machine.idle()" "$file" && ! grep -q "time.sleep" "$file"; then
        issues+=("Nenhum yield encontrado - pode causar WDT timeout")
    fi
    
    # Verificar delays excessivos
    if grep -q "time.sleep([5-9]\|[1-9][0-9])" "$file"; then
        warnings+=("Delays longos detectados - podem afetar responsividade")
    fi
    
    # Verificar garbage collection
    if grep -q "import gc" "$file" && ! grep -q "gc.collect()" "$file"; then
        warnings+=("gc importado mas gc.collect() não usado")
    fi
    
    local has_issues=0
    
    if [ ${#issues[@]} -gt 0 ]; then
        for issue in "${issues[@]}"; do
            log_error "Problema de código: $issue"
        done
        has_issues=1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        for warning in "${warnings[@]}"; do
            log_warning "Aviso de código: $warning"
        done
    fi
    
    if [ $has_issues -eq 0 ]; then
        log_success "Padrões de código OK: $file"
        return 0
    else
        return 1
    fi
}

# Estimativa de recursos
estimate_resources() {
    local file="$1"
    log_info "Estimando uso de recursos: $file"
    
    local file_size=$(wc -c < "$file")
    local line_count=$(wc -l < "$file")
    
    # Estimativa básica de RAM (muito aproximada)
    local estimated_ram=$((file_size * 2))
    
    echo "  📊 Estatísticas do arquivo:"
    echo "     - Tamanho: $file_size bytes"
    echo "     - Linhas: $line_count"
    echo "     - RAM estimada: ${estimated_ram} bytes"
    
    if [ $estimated_ram -lt 30000 ]; then
        log_success "Uso de recursos OK para ESP32-C3"
    elif [ $estimated_ram -lt 60000 ]; then
        log_warning "Uso de recursos moderado para ESP32-C3"
    else
        log_warning "Uso de recursos alto para ESP32-C3"
    fi
    
    return 0
}

# Relatório final
generate_report() {
    local file="$1"
    local total_tests="$2"
    local passed_tests="$3"
    
    echo ""
    echo "📊 RELATÓRIO DE VALIDAÇÃO: $file"
    echo "================================"
    echo "Testes executados: $total_tests"
    echo "Testes OK: $passed_tests"
    
    local success_rate=$((passed_tests * 100 / total_tests))
    echo "Taxa de sucesso: ${success_rate}%"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_success "CÓDIGO PRONTO PARA UPLOAD! 🚀"
        echo ""
        echo "📤 Próximos passos:"
        echo "   ./test_wdt_fix.sh upload    # Upload para ESP32-C3"
        echo "   ./test_wdt_fix.sh monitor   # Monitorar funcionamento"
    elif [ $success_rate -ge 80 ]; then
        log_warning "CÓDIGO ACEITÁVEL com avisos ⚠️"
        echo "   Revise os avisos antes do upload"
    else
        log_error "CÓDIGO PRECISA DE CORREÇÕES ❌"
        echo "   Corrija os erros antes do upload"
    fi
    echo ""
}

# Validação completa
validate_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_error "Arquivo não encontrado: $file"
        return 1
    fi
    
    echo "🔍 VALIDANDO: $file"
    echo "=================="
    
    local tests_total=6
    local tests_passed=0
    
    # Executar validações
    validate_python_syntax "$file" && ((tests_passed++))
    check_micropython_imports "$file" && ((tests_passed++))
    check_esp32c3_pins "$file" && ((tests_passed++))
    check_mqtt_config "$file" && ((tests_passed++))
    check_code_patterns "$file" && ((tests_passed++))
    estimate_resources "$file" && ((tests_passed++))
    
    generate_report "$file" $tests_total $tests_passed
    
    return $((tests_total - tests_passed))
}

# Função principal
main() {
    if [ $# -eq 0 ]; then
        echo "Uso: $0 <arquivo.py>"
        echo ""
        echo "Exemplo: $0 main.py"
        exit 1
    fi
    
    validate_file "$1"
    exit $?
}

# Executar
main "$@"