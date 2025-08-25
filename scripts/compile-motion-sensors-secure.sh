#!/bin/zsh

# ============================================
# HomeGuard Motion Sensor Compiler - Secure Version
# Compila sensores de movimento com suporte TLS/SSL
# ============================================

set -e  # Parar em caso de erro

echo "🔐 HomeGuard Motion Sensor Compiler (Secure)"
echo "==========================================="

# Verificar se arduino-cli está disponível
if ! command -v arduino-cli &> /dev/null; then
    echo "❌ arduino-cli não encontrado. Instale primeiro:"
    echo "   brew install arduino-cli"
    exit 1
fi

# Configurações do compilador
BOARD_FQBN="esp8266:esp8266:generic"
TEMPLATE_DIR="/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/templates/motion_sensor"
BUILD_DIR="/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/build"
TEMPLATE_FILE="motion_detector_template_secure.ino"

# Verificar se template existe
if [ ! -f "$TEMPLATE_DIR/$TEMPLATE_FILE" ]; then
    echo "❌ Template não encontrado: $TEMPLATE_DIR/$TEMPLATE_FILE"
    exit 1
fi

# Criar diretório de build se não existir
mkdir -p "$BUILD_DIR"

# Configurações dos sensores com suporte TLS
declare -A SENSORS
SENSORS[Garagem]="101:garagem"
SENSORS[Area_Servico]="102:area_servico"
SENSORS[Varanda]="103:varanda"  
SENSORS[Mezanino]="104:mezanino"
SENSORS[Ad_Hoc]="105:adhoc"

# Função para preparar sketch para compilação
prepare_sketch() {
    local location="$1"
    local ip_octet="$2"
    local topic_suffix="$3"
    local secure="$4"
    
    local sketch_name="${location}_motion_sensor_secure"
    local sketch_dir="$BUILD_DIR/$sketch_name"
    
    echo "📁 Preparando sketch: $sketch_name"
    
    # Criar diretório do sketch
    mkdir -p "$sketch_dir"
    
    # Copiar template para o diretório do sketch
    cp "$TEMPLATE_DIR/$TEMPLATE_FILE" "$sketch_dir/$sketch_name.ino"
    
    # Verificar se certificados existem
    local cert_file="$TEMPLATE_DIR/../../../etc/mosquitto/certs/devices/motion_${topic_suffix}_client.crt"
    local key_file="$TEMPLATE_DIR/../../../etc/mosquitto/certs/devices/motion_${topic_suffix}_client.key"
    local ca_file="$TEMPLATE_DIR/../../../etc/mosquitto/certs/ca.crt"
    
    if [[ "$secure" == "1" ]]; then
        if [ -f "$cert_file" ] && [ -f "$key_file" ] && [ -f "$ca_file" ]; then
            echo "🔐 Incluindo certificados TLS para $location"
            
            # Gerar arquivo de certificados
            cat > "$sketch_dir/certificates.h" << EOF
// Certificados TLS para $location
// Gerado automaticamente

#ifndef CERTIFICATES_H
#define CERTIFICATES_H

const char* ca_cert = R"EOF(
$(cat "$ca_file")
)EOF";

const char* client_cert = R"EOF(
$(cat "$cert_file")
)EOF";

const char* client_key = R"EOF(  
$(cat "$key_file")
)EOF";

#endif
EOF
            
            # Adicionar include no sketch
            sed -i '' '1i\
#include "certificates.h"
' "$sketch_dir/$sketch_name.ino"
            
        else
            echo "⚠️ Certificados não encontrados para $location - TLS desabilitado"
            secure="0"
        fi
    fi
    
    echo "✅ Sketch preparado em: $sketch_dir"
}

# Função para compilar sensor
compile_sensor() {
    local location="$1"
    local config="$2"
    local secure="${3:-0}"
    
    IFS=':' read -r ip_octet topic_suffix <<< "$config"
    
    local sketch_name="${location}_motion_sensor_secure"
    local sketch_dir="$BUILD_DIR/$sketch_name"
    
    echo ""
    echo "🔨 Compilando sensor: $location"
    echo "   Localização: $location"
    echo "   IP: 192.168.18.$ip_octet"
    echo "   Tópico: motion_$topic_suffix"
    echo "   TLS: $([ "$secure" = "1" ] && echo "HABILITADO" || echo "DESABILITADO")"
    echo "   Porta MQTT: $([ "$secure" = "1" ] && echo "8883" || echo "1883")"
    
    # Preparar sketch
    prepare_sketch "$location" "$ip_octet" "$topic_suffix" "$secure"
    
    # Definir flags de compilação
    local build_flags="-DDEVICE_LOCATION=\\\"$location\\\" -DDEVICE_IP_LAST_OCTET=$ip_octet -DMQTT_TOPIC_SUFFIX=\\\"$topic_suffix\\\""
    
    if [[ "$secure" == "1" ]]; then
        build_flags="$build_flags -DMQTT_SECURE=1 -DMQTT_PORT=8883"
    else
        build_flags="$build_flags -DMQTT_SECURE=0 -DMQTT_PORT=1883"
    fi
    
    # Adicionar debug se solicitado
    if [[ "$DEBUG" == "1" ]]; then
        build_flags="$build_flags -DDEBUG_SERIAL=1"
    fi
    
    echo "   Build flags: $build_flags"
    
    # Compilar
    if arduino-cli compile --fqbn "$BOARD_FQBN" \
        --build-property "compiler.cpp.extra_flags=$build_flags" \
        --output-dir "$sketch_dir" \
        "$sketch_dir" 2>/dev/null; then
        
        # Verificar se binário foi gerado
        if [ -f "$sketch_dir/$sketch_name.ino.bin" ]; then
            local file_size=$(stat -f%z "$sketch_dir/$sketch_name.ino.bin" 2>/dev/null)
            echo "✅ Compilação bem-sucedida!"
            echo "   Arquivo: $sketch_dir/$sketch_name.ino.bin"
            echo "   Tamanho: $file_size bytes"
        else
            echo "❌ Erro: arquivo binário não encontrado"
            return 1
        fi
    else
        echo "❌ Falha na compilação de $location"
        return 1
    fi
}

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES] [SENSORES]"
    echo ""
    echo "OPÇÕES:"
    echo "  --secure, -s     Compilar com suporte TLS (requer certificados)"
    echo "  --debug, -d      Habilitar debug serial"
    echo "  --help, -h       Mostrar esta ajuda"
    echo ""
    echo "SENSORES:"
    echo "  all             Compilar todos os sensores (padrão)"
    echo "  Garagem         Compilar apenas sensor da Garagem"
    echo "  Area_Servico    Compilar apenas sensor da Área de Serviço"
    echo "  Varanda         Compilar apenas sensor da Varanda"
    echo "  Mezanino        Compilar apenas sensor do Mezanino"
    echo "  Ad_Hoc          Compilar apenas sensor Ad Hoc"
    echo ""
    echo "EXEMPLOS:"
    echo "  $0                    # Compilar todos sem TLS"
    echo "  $0 --secure          # Compilar todos com TLS"
    echo "  $0 --debug Garagem   # Compilar Garagem com debug"
    echo "  $0 -s -d             # Compilar todos com TLS e debug"
}

# Função para verificar certificados
check_certificates() {
    local cert_dir="/etc/mosquitto/certs"
    
    if [ ! -d "$cert_dir" ]; then
        echo "❌ Diretório de certificados não encontrado: $cert_dir"
        echo "Execute primeiro: sudo ./scripts/setup-mqtt-security.sh"
        return 1
    fi
    
    if [ ! -f "$cert_dir/ca.crt" ]; then
        echo "❌ Certificado CA não encontrado: $cert_dir/ca.crt"
        return 1
    fi
    
    echo "✅ Certificados base encontrados"
    return 0
}

# Função principal
main() {
    local secure="0"
    local debug="0"
    local sensors_to_compile=()
    
    # Parse argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --secure|-s)
                secure="1"
                shift
                ;;
            --debug|-d)
                debug="1"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            all)
                sensors_to_compile=("${(@k)SENSORS}")  # ZSH syntax para chaves do array
                shift
                ;;
            Garagem|Area_Servico|Varanda|Mezanino|Ad_Hoc)
                sensors_to_compile+=("$1")
                shift
                ;;
            *)
                echo "❌ Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Se nenhum sensor especificado, compilar todos
    if [[ ${#sensors_to_compile[@]} -eq 0 ]]; then
        sensors_to_compile=("${(@k)SENSORS}")  # ZSH syntax
    fi
    
    # Verificar certificados se TLS habilitado
    if [[ "$secure" == "1" ]]; then
        echo "🔐 Modo seguro habilitado - verificando certificados..."
        if ! check_certificates; then
            echo "Execute: sudo ./scripts/setup-mqtt-security.sh"
            echo "E depois: sudo ./scripts/generate-device-certificates.sh motion-sensors"
            exit 1
        fi
    fi
    
    # Exportar variável DEBUG para as funções
    export DEBUG="$debug"
    
    echo ""
    echo "🚀 Iniciando compilação..."
    echo "   Sensores: ${sensors_to_compile[*]}"
    echo "   TLS: $([ "$secure" = "1" ] && echo "HABILITADO" || echo "DESABILITADO")"
    echo "   Debug: $([ "$debug" = "1" ] && echo "HABILITADO" || echo "DESABILITADO")"
    echo ""
    
    # Compilar sensores selecionados
    local success_count=0
    local total_count=${#sensors_to_compile[@]}
    
    for sensor in "${sensors_to_compile[@]}"; do
        if compile_sensor "$sensor" "${SENSORS[$sensor]}" "$secure"; then
            ((success_count++))
        fi
    done
    
    echo ""
    echo "📊 Resultado da compilação:"
    echo "   Sucessos: $success_count/$total_count"
    
    if [[ $success_count -eq $total_count ]]; then
        echo "🎉 Todas as compilações foram bem-sucedidas!"
        
        echo ""
        echo "📋 Arquivos gerados em $BUILD_DIR:"
        find "$BUILD_DIR" -name "*.bin" -exec ls -lh {} \; | while read -r line; do
            echo "   $line"
        done
        
        if [[ "$secure" == "1" ]]; then
            echo ""
            echo "🔐 IMPORTANTE - Modo Seguro:"
            echo "   • Dispositivos conectarão na porta 8883 (TLS)"
            echo "   • Certificados incluídos no firmware"
            echo "   • Comunicação criptografada"
        fi
        
        exit 0
    else
        echo "❌ Algumas compilações falharam"
        exit 1
    fi
}

# Executar se chamado diretamente
if [[ "${ZSH_EVAL_CONTEXT}" == *:file ]]; then
    main "$@"
fi
