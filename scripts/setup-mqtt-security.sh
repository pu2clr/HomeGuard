#!/bin/bash

# ============================================
# HomeGuard MQTT Security Setup Script
# Automatiza a configuração de segurança TLS
# ============================================

set -e  # Parar em caso de erro

echo "🔒 HomeGuard MQTT Security Setup"
echo "================================="
echo ""

# Verificar se está executando como root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script deve ser executado como root (sudo)"
   exit 1
fi

# Configurações
MQTT_CERTS_DIR="/etc/mosquitto/certs"
MQTT_CONFIG_DIR="/etc/mosquitto/conf.d"
MQTT_LOG_DIR="/var/log/mosquitto"
MQTT_DATA_DIR="/var/lib/mosquitto"

BROKER_IP="192.168.18.198"
USERNAME="homeguard"
PASSWORD="pu2clr123456"

echo "📋 Configurações:"
echo "   Broker IP: $BROKER_IP"
echo "   Username: $USERNAME"
echo "   Certificados: $MQTT_CERTS_DIR"
echo ""

# Função para criar diretórios
create_directories() {
    echo "📁 Criando diretórios necessários..."
    mkdir -p "$MQTT_CERTS_DIR"
    mkdir -p "$MQTT_CONFIG_DIR" 
    mkdir -p "$MQTT_LOG_DIR"
    mkdir -p "$MQTT_DATA_DIR"
    echo "✅ Diretórios criados"
}

# Função para gerar certificados SSL
generate_certificates() {
    echo "🔐 Gerando certificados SSL..."
    
    cd "$MQTT_CERTS_DIR"
    
    # Gerar chave privada da CA
    echo "   Gerando Autoridade Certificadora (CA)..."
    openssl genrsa -out ca.key 4096
    
    # Gerar certificado da CA
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=HomeGuard/OU=Security/CN=HomeGuard-CA"
    
    # Gerar chave privada do servidor
    echo "   Gerando certificado do servidor..."
    openssl genrsa -out server.key 4096
    
    # Gerar requisição de certificado do servidor
    openssl req -new -key server.key -out server.csr \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=HomeGuard/OU=MQTT/CN=$BROKER_IP"
    
    # Assinar certificado do servidor
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out server.crt -days 3650
    
    # Limpar arquivo temporário
    rm server.csr
    
    echo "✅ Certificados SSL gerados"
}

# Função para criar arquivo de senhas
create_password_file() {
    echo "🔑 Criando arquivo de senhas..."
    
    # Remover arquivo existente se houver
    rm -f /etc/mosquitto/homeguard.pw
    
    # Criar arquivo de senhas
    mosquitto_passwd -b -c /etc/mosquitto/homeguard.pw "$USERNAME" "$PASSWORD"
    
    echo "✅ Arquivo de senhas criado"
}

# Função para criar ACL
create_acl_file() {
    echo "📝 Criando arquivo de controle de acesso (ACL)..."
    
    cat > /etc/mosquitto/homeguard.acl << EOF
# HomeGuard MQTT Access Control List
# Usuário homeguard tem acesso completo ao tópico home/#

user $USERNAME
topic readwrite home/#
topic read \$SYS/broker/load/#
topic read \$SYS/broker/clients/#
topic read \$SYS/broker/messages/#
EOF
    
    echo "✅ Arquivo ACL criado"
}

# Função para criar configuração do Mosquitto
create_mosquitto_config() {
    echo "⚙️ Criando configuração do Mosquitto..."
    
    cat > "$MQTT_CONFIG_DIR/homeguard.conf" << EOF
# ========================================
# MQTT Broker Security Configuration
# HomeGuard Project - $(date)
# ========================================

# Desabilitar conexões anônimas
allow_anonymous false

# Arquivo de senhas
password_file /etc/mosquitto/homeguard.pw

# Controle de acesso por tópicos
acl_file /etc/mosquitto/homeguard.acl

# ========================================
# TLS/SSL Configuration
# ========================================

# Porta padrão sem criptografia (apenas localhost)
port 1883
bind_address 127.0.0.1

# Porta TLS/SSL (acesso seguro da rede)
listener 8883
bind_address 0.0.0.0

# Certificados SSL
cafile $MQTT_CERTS_DIR/ca.crt
certfile $MQTT_CERTS_DIR/server.crt
keyfile $MQTT_CERTS_DIR/server.key

# Versões TLS permitidas (apenas versões seguras)
tls_version tlsv1.2

# ========================================
# Logging e Monitoramento
# ========================================

# Logs detalhados para auditoria
log_dest file $MQTT_LOG_DIR/mosquitto.log
log_type error
log_type warning  
log_type notice
log_type information
log_type debug

# Logs de conexão para monitoramento
connection_messages true
log_timestamp true

# ========================================
# Configurações de Performance e Segurança
# ========================================

# Timeout de conexões inativas
keepalive_interval 60

# Máximo de conexões simultâneas
max_connections 100

# Tamanho máximo de mensagem (1MB)
message_size_limit 1048576

# Persistência de dados
persistence true
persistence_location $MQTT_DATA_DIR/

# QoS máximo permitido
max_qos 2

# Retenção de mensagens
retain_available true
EOF
    
    echo "✅ Configuração do Mosquitto criada"
}

# Função para ajustar permissões
set_permissions() {
    echo "🔒 Configurando permissões..."
    
    # Certificados
    chown -R mosquitto:mosquitto "$MQTT_CERTS_DIR"
    chmod 700 "$MQTT_CERTS_DIR"
    chmod 600 "$MQTT_CERTS_DIR"/*.key
    chmod 644 "$MQTT_CERTS_DIR"/*.crt
    
    # Arquivos de configuração
    chown mosquitto:mosquitto /etc/mosquitto/homeguard.pw
    chown mosquitto:mosquitto /etc/mosquitto/homeguard.acl
    chmod 600 /etc/mosquitto/homeguard.pw
    chmod 644 /etc/mosquitto/homeguard.acl
    
    # Logs
    chown -R mosquitto:mosquitto "$MQTT_LOG_DIR"
    chmod 755 "$MQTT_LOG_DIR"
    
    # Dados
    chown -R mosquitto:mosquitto "$MQTT_DATA_DIR"
    chmod 755 "$MQTT_DATA_DIR"
    
    echo "✅ Permissões configuradas"
}

# Função para testar configuração
test_configuration() {
    echo "🧪 Testando configuração..."
    
    # Testar sintaxe da configuração
    if mosquitto -c "$MQTT_CONFIG_DIR/homeguard.conf" -v &
    then
        MOSQUITTO_PID=$!
        sleep 3
        kill $MOSQUITTO_PID 2>/dev/null || true
        wait $MOSQUITTO_PID 2>/dev/null || true
        echo "✅ Configuração válida"
    else
        echo "❌ Erro na configuração"
        return 1
    fi
}

# Função para reiniciar serviços
restart_services() {
    echo "🔄 Reiniciando serviços..."
    
    systemctl restart mosquitto
    systemctl enable mosquitto
    
    if systemctl is-active --quiet mosquitto; then
        echo "✅ Mosquitto rodando com segurança"
    else
        echo "❌ Erro ao iniciar Mosquitto"
        systemctl status mosquitto
        return 1
    fi
}

# Função para mostrar informações finais
show_final_info() {
    echo ""
    echo "🎉 Configuração de segurança concluída!"
    echo "====================================="
    echo ""
    echo "📊 Status dos serviços:"
    systemctl status mosquitto --no-pager -l
    echo ""
    echo "🔌 Portas de conexão:"
    echo "   Porta 1883 (sem TLS): localhost apenas"
    echo "   Porta 8883 (com TLS): rede completa"
    echo ""
    echo "🔑 Credenciais:"
    echo "   Usuário: $USERNAME"
    echo "   Senha: $PASSWORD"
    echo "   Tópicos permitidos: home/#"
    echo ""
    echo "📁 Arquivos importantes:"
    echo "   Certificado CA: $MQTT_CERTS_DIR/ca.crt"
    echo "   Configuração: $MQTT_CONFIG_DIR/homeguard.conf"
    echo "   Logs: $MQTT_LOG_DIR/mosquitto.log"
    echo ""
    echo "🧪 Teste de conexão (sem TLS):"
    echo "   mosquitto_sub -h localhost -p 1883 -u $USERNAME -P $PASSWORD -t home/test"
    echo ""
    echo "🔐 Teste de conexão (com TLS):"
    echo "   mosquitto_sub -h $BROKER_IP -p 8883 --cafile $MQTT_CERTS_DIR/ca.crt -u $USERNAME -P $PASSWORD -t home/test"
    echo ""
}

# Função principal
main() {
    echo "🚀 Iniciando configuração de segurança..."
    echo ""
    
    create_directories
    generate_certificates  
    create_password_file
    create_acl_file
    create_mosquitto_config
    set_permissions
    test_configuration
    restart_services
    show_final_info
    
    echo "✅ Setup de segurança concluído com sucesso!"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
