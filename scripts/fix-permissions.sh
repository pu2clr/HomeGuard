#!/bin/bash

# =============================================================================
# CORREÇÃO RÁPIDA - PERMISSÕES SYSTEMD HOMEGUARD
# =============================================================================
# Script para corrigir problema de permissões do serviço systemd
# =============================================================================

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO:${NC} $1"
}

echo -e "${BLUE}"
echo "=================================================================="
echo "       CORREÇÃO RÁPIDA - PERMISSÕES SYSTEMD HOMEGUARD"
echo "=================================================================="
echo -e "${NC}"

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
    error "Este script deve ser executado como root ou com sudo"
    error "Use: sudo $0"
    exit 1
fi

# Configurações
USER="homeguard"
PROJECT_DIR="/home/$USER/HomeGuard"
SERVICE_NAME="homeguard-mqtt"

echo ""
info "=== DIAGNOSTICANDO PROBLEMA ==="

# Verificar se usuário existe
if ! id "$USER" &>/dev/null; then
    error "Usuário '$USER' não encontrado!"
    exit 1
fi

log "✓ Usuário '$USER' encontrado"

# Verificar se projeto existe
if [[ ! -d "$PROJECT_DIR" ]]; then
    error "Diretório do projeto não encontrado: $PROJECT_DIR"
    exit 1
fi

log "✓ Diretório do projeto encontrado: $PROJECT_DIR"

# Verificar permissões atuais
echo ""
info "Permissões atuais:"
ls -la "$(dirname "$PROJECT_DIR")" | grep "$(basename "$PROJECT_DIR")"
ls -la "$PROJECT_DIR" | head -5

echo ""
info "=== CORRIGINDO PERMISSÕES ==="

# 1. Corrigir permissões do diretório home do usuário
HOME_DIR="/home/$USER"
log "Corrigindo permissões do diretório home: $HOME_DIR"
chown "$USER:$USER" "$HOME_DIR"
chmod 755 "$HOME_DIR"

# 2. Corrigir permissões do projeto
log "Corrigindo permissões do projeto: $PROJECT_DIR"
chown -R "$USER:$USER" "$PROJECT_DIR"
chmod 755 "$PROJECT_DIR"

# 3. Corrigir permissões específicas
chmod +x "$PROJECT_DIR/web/mqtt_service.py"
mkdir -p "$PROJECT_DIR/logs" "$PROJECT_DIR/db"
chown -R "$USER:$USER" "$PROJECT_DIR/logs" "$PROJECT_DIR/db"

# 4. Verificar e corrigir arquivo de serviço
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
if [[ -f "$SERVICE_FILE" ]]; then
    log "Verificando arquivo de serviço: $SERVICE_FILE"
    
    # Verificar se ProtectHome=false
    if grep -q "ProtectHome=true" "$SERVICE_FILE"; then
        warn "Corrigindo ProtectHome=true para ProtectHome=false"
        sed -i 's/ProtectHome=true/ProtectHome=false/g' "$SERVICE_FILE"
        log "✓ Arquivo de serviço corrigido"
    else
        log "✓ Arquivo de serviço já configurado corretamente"
    fi
else
    error "Arquivo de serviço não encontrado: $SERVICE_FILE"
    exit 1
fi

echo ""
info "=== REINICIANDO SERVIÇO ==="

# Parar serviço se estiver rodando
if systemctl is-active --quiet "$SERVICE_NAME"; then
    log "Parando serviço..."
    systemctl stop "$SERVICE_NAME"
fi

# Recarregar configuração
log "Recarregando configuração systemd..."
systemctl daemon-reload

# Iniciar serviço
log "Iniciando serviço..."
systemctl start "$SERVICE_NAME"

# Aguardar um pouco
sleep 3

echo ""
info "=== VERIFICANDO RESULTADO ==="

# Verificar status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    log "✅ Serviço iniciado com sucesso!"
    
    echo ""
    info "Status do serviço:"
    systemctl status "$SERVICE_NAME" --no-pager -l | head -15
    
else
    error "❌ Serviço ainda não está funcionando"
    
    echo ""
    error "Logs recentes do erro:"
    journalctl -u "$SERVICE_NAME" --no-pager -l -n 10
    
    echo ""
    warn "Possíveis soluções adicionais:"
    echo "  1. Verificar se broker MQTT está rodando:"
    echo "     sudo systemctl status mosquitto"
    echo ""
    echo "  2. Testar execução manual:"
    echo "     sudo -u $USER python3 $PROJECT_DIR/web/mqtt_service.py start"
    echo ""
    echo "  3. Verificar dependências Python:"
    echo "     sudo -u $USER pip3 install paho-mqtt"
    
    exit 1
fi

echo ""
info "=== VERIFICAÇÃO DE PERMISSÕES FINAL ==="

# Mostrar permissões corrigidas
echo "Permissões corrigidas:"
ls -la "$HOME_DIR" | grep "$(basename "$PROJECT_DIR")"
echo ""
echo "Conteúdo do projeto:"
ls -la "$PROJECT_DIR" | head -8

echo ""
log "✅ Correção de permissões concluída com sucesso!"

echo ""
info "COMANDOS ÚTEIS:"
echo "  • Ver status: systemctl status $SERVICE_NAME"
echo "  • Ver logs: journalctl -u $SERVICE_NAME -f"
echo "  • Gerenciar: $PROJECT_DIR/scripts/manage-mqtt-service.sh status"

echo ""
echo -e "${GREEN}"
echo "=================================================================="
echo "           PROBLEMA DE PERMISSÕES CORRIGIDO!"
echo "=================================================================="
echo -e "${NC}"
