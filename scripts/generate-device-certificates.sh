#!/bin/bash

# ============================================
# HomeGuard Device Certificate Generator
# Gera certificados individuais para dispositivos
# ============================================

set -e

echo "🔐 HomeGuard Device Certificate Generator"
echo "========================================"

# Verificar se está executando como root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script deve ser executado como root (sudo)"
   exit 1
fi

# Configurações
MQTT_CERTS_DIR="/etc/mosquitto/certs"
DEVICE_CERTS_DIR="$MQTT_CERTS_DIR/devices"

# Verificar se CA existe
if [ ! -f "$MQTT_CERTS_DIR/ca.crt" ] || [ ! -f "$MQTT_CERTS_DIR/ca.key" ]; then
    echo "❌ Certificados da CA não encontrados em $MQTT_CERTS_DIR"
    echo "Execute primeiro: sudo ./setup-mqtt-security.sh"
    exit 1
fi

# Criar diretório para certificados de dispositivos
mkdir -p "$DEVICE_CERTS_DIR"

# Função para gerar certificado de dispositivo
generate_device_certificate() {
    local device_name="$1"
    local device_type="${2:-sensor}"
    
    if [ -z "$device_name" ]; then
        echo "❌ Nome do dispositivo é obrigatório"
        return 1
    fi
    
    echo "🔧 Gerando certificado para dispositivo: $device_name"
    
    cd "$DEVICE_CERTS_DIR"
    
    # Gerar chave privada do dispositivo
    openssl genrsa -out "${device_name}_client.key" 4096
    
    # Gerar requisição de certificado
    openssl req -new -key "${device_name}_client.key" -out "${device_name}_client.csr" \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=HomeGuard/OU=${device_type}/CN=${device_name}-device"
    
    # Assinar com CA
    openssl x509 -req -in "${device_name}_client.csr" \
        -CA "$MQTT_CERTS_DIR/ca.crt" \
        -CAkey "$MQTT_CERTS_DIR/ca.key" \
        -CAcreateserial \
        -out "${device_name}_client.crt" \
        -days 3650
    
    # Limpar arquivo temporário
    rm "${device_name}_client.csr"
    
    # Ajustar permissões
    chown mosquitto:mosquitto "${device_name}_client".*
    chmod 600 "${device_name}_client.key"
    chmod 644 "${device_name}_client.crt"
    
    echo "✅ Certificado gerado para $device_name"
    echo "   Chave privada: $DEVICE_CERTS_DIR/${device_name}_client.key"
    echo "   Certificado: $DEVICE_CERTS_DIR/${device_name}_client.crt"
}

# Função para gerar certificados para todos os sensores de movimento
generate_motion_sensor_certificates() {
    echo "🏠 Gerando certificados para sensores de movimento..."
    
    local sensors=("garagem" "area_servico" "varanda" "mezanino" "adhoc")
    
    for sensor in "${sensors[@]}"; do
        generate_device_certificate "motion_${sensor}" "motion_sensor"
    done
    
    echo "✅ Todos os certificados de sensores de movimento gerados"
}

# Função para gerar código Arduino com certificado
generate_arduino_code() {
    local device_name="$1"
    
    if [ -z "$device_name" ]; then
        echo "❌ Nome do dispositivo é obrigatório"
        return 1
    fi
    
    local cert_file="$DEVICE_CERTS_DIR/${device_name}_client.crt"
    local key_file="$DEVICE_CERTS_DIR/${device_name}_client.key"
    local ca_file="$MQTT_CERTS_DIR/ca.crt"
    
    if [ ! -f "$cert_file" ]; then
        echo "❌ Certificado não encontrado: $cert_file"
        return 1
    fi
    
    echo "📝 Gerando código Arduino para $device_name..."
    
    cat > "$DEVICE_CERTS_DIR/${device_name}_certificates.h" << EOF
// ============================================
// HomeGuard Device Certificates
// Device: $device_name
// Generated: $(date)
// ============================================

#ifndef ${device_name^^}_CERTIFICATES_H
#define ${device_name^^}_CERTIFICATES_H

// Certificado da Autoridade Certificadora (CA)
const char* ca_cert = R"EOF(
$(cat "$ca_file")
)EOF";

// Certificado do cliente (dispositivo)
const char* client_cert = R"EOF(
$(cat "$cert_file")
)EOF";

// Chave privada do cliente (MANTENHA SEGURA!)
const char* client_key = R"EOF(
$(cat "$key_file")
)EOF";

#endif // ${device_name^^}_CERTIFICATES_H
EOF
    
    echo "✅ Arquivo de certificados Arduino criado:"
    echo "   $DEVICE_CERTS_DIR/${device_name}_certificates.h"
}

# Função para mostrar status dos certificados
show_certificates_status() {
    echo "📋 Status dos Certificados"
    echo "========================="
    echo ""
    
    # CA
    if [ -f "$MQTT_CERTS_DIR/ca.crt" ]; then
        echo "🔒 Autoridade Certificadora (CA):"
        echo "   Certificado: $MQTT_CERTS_DIR/ca.crt"
        openssl x509 -in "$MQTT_CERTS_DIR/ca.crt" -noout -subject -dates
        echo ""
    fi
    
    # Servidor
    if [ -f "$MQTT_CERTS_DIR/server.crt" ]; then
        echo "🖥️ Servidor MQTT:"
        echo "   Certificado: $MQTT_CERTS_DIR/server.crt"
        openssl x509 -in "$MQTT_CERTS_DIR/server.crt" -noout -subject -dates
        echo ""
    fi
    
    # Dispositivos
    if [ -d "$DEVICE_CERTS_DIR" ]; then
        echo "📱 Dispositivos:"
        for cert in "$DEVICE_CERTS_DIR"/*_client.crt; do
            if [ -f "$cert" ]; then
                echo "   $(basename "$cert")"
                openssl x509 -in "$cert" -noout -subject -dates
                echo ""
            fi
        done
    fi
}

# Função de ajuda
show_help() {
    echo "Uso: $0 [COMANDO] [OPÇÕES]"
    echo ""
    echo "COMANDOS:"
    echo "  device <nome>           Gerar certificado para dispositivo específico"
    echo "  motion-sensors          Gerar certificados para todos os sensores"
    echo "  arduino <nome>          Gerar arquivo .h com certificados para Arduino"
    echo "  status                  Mostrar status de todos os certificados"
    echo "  help                    Mostrar esta ajuda"
    echo ""
    echo "EXEMPLOS:"
    echo "  $0 device esp32_garage"
    echo "  $0 motion-sensors"
    echo "  $0 arduino motion_garagem"
    echo "  $0 status"
}

# Função principal
main() {
    case "${1:-help}" in
        "device")
            if [ -z "$2" ]; then
                echo "❌ Nome do dispositivo é obrigatório"
                echo "Uso: $0 device <nome_dispositivo>"
                exit 1
            fi
            generate_device_certificate "$2" "${3:-device}"
            ;;
        "motion-sensors")
            generate_motion_sensor_certificates
            ;;
        "arduino")
            if [ -z "$2" ]; then
                echo "❌ Nome do dispositivo é obrigatório"
                echo "Uso: $0 arduino <nome_dispositivo>"
                exit 1
            fi
            generate_arduino_code "$2"
            ;;
        "status")
            show_certificates_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "❌ Comando inválido: $1"
            show_help
            exit 1
            ;;
    esac
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
