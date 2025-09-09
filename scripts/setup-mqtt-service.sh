#!/bin/bash

# =============================================================================
# CONFIGURADOR DE SERVIÇO SYSTEMD - HOMEGUARD MQTT SERVICE
# =============================================================================
# Script para configurar o mqtt_service.py como serviço systemd no Raspberry Pi
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO:${NC} $1"
}

# Banner
echo -e "${BLUE}"
echo "=================================================================="
echo "    CONFIGURAÇÃO SERVIÇO SYSTEMD - HOMEGUARD MQTT SERVICE"
echo "=================================================================="
echo -e "${NC}"

# Verificar se está no Raspberry Pi
if [[ $(uname -m) == arm* ]] || [[ $(uname -m) == aarch64 ]]; then
    log "Executando no Raspberry Pi: $(uname -m)"
else
    warn "Não detectado Raspberry Pi. Continuando mesmo assim..."
fi

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
SERVICE_NAME="homeguard-mqtt"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
USER="homeguard"  # Usuário do sistema HomeGuard

# Verificar se está executando como root ou com sudo
if [[ $EUID -ne 0 ]]; then
    error "Este script deve ser executado como root ou com sudo"
    error "Use: sudo $0"
    exit 1
fi

# Verificar se arquivo mqtt_service.py existe
MQTT_SERVICE_PATH="$PROJECT_DIR/web/mqtt_service.py"
if [[ ! -f "$MQTT_SERVICE_PATH" ]]; then
    error "Arquivo mqtt_service.py não encontrado: $MQTT_SERVICE_PATH"
    error "Certifique-se de estar no diretório correto do projeto HomeGuard"
    exit 1
fi

log "✓ Arquivo mqtt_service.py encontrado: $MQTT_SERVICE_PATH"

# Verificar se usuário homeguard existe
if ! id "$USER" &>/dev/null; then
    warn "Usuário '$USER' não encontrado"
    read -p "Digite o nome do usuário para executar o serviço: " USER
    if ! id "$USER" &>/dev/null; then
        error "Usuário '$USER' não existe"
        exit 1
    fi
fi

log "✓ Usuário do serviço: $USER"

# Verificar Python3
if ! command -v python3 &> /dev/null; then
    error "Python 3 não encontrado. Instale com: sudo apt install python3"
    exit 1
fi

PYTHON_PATH=$(which python3)
log "✓ Python encontrado: $PYTHON_PATH"

# Verificar se diretório de logs existe
LOG_DIR="$PROJECT_DIR/logs"
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR"
    chown "$USER:$USER" "$LOG_DIR"
    log "✓ Diretório de logs criado: $LOG_DIR"
fi

# =============================================================================
# CRIAR ARQUIVO DE SERVIÇO SYSTEMD
# =============================================================================
echo ""
info "=== CRIANDO ARQUIVO DE SERVIÇO SYSTEMD ==="

log "Criando arquivo de serviço: $SERVICE_FILE"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=HomeGuard MQTT Activity Logger Service
Documentation=https://github.com/pu2clr/HomeGuard
After=network.target mosquitto.service
Wants=network.target
RequiresMountsFor=$PROJECT_DIR

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=/usr/bin:/usr/local/bin
Environment=PYTHONPATH=$PROJECT_DIR/web:$PROJECT_DIR
ExecStart=$PYTHON_PATH $MQTT_SERVICE_PATH start
ExecStop=$PYTHON_PATH $MQTT_SERVICE_PATH stop
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_DIR/logs $PROJECT_DIR/db /tmp
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=homeguard-mqtt

[Install]
WantedBy=multi-user.target
EOF

log "✓ Arquivo de serviço criado com sucesso"

# Verificar sintaxe do arquivo de serviço
if systemd-analyze verify "$SERVICE_FILE" 2>/dev/null; then
    log "✓ Arquivo de serviço verificado com sucesso"
else
    warn "⚠ Verificação do arquivo de serviço falhou (pode funcionar mesmo assim)"
fi

# =============================================================================
# CONFIGURAR PERMISSÕES
# =============================================================================
echo ""
info "=== CONFIGURANDO PERMISSÕES ==="

# Tornar mqtt_service.py executável
chmod +x "$MQTT_SERVICE_PATH"
log "✓ mqtt_service.py marcado como executável"

# Dar permissões corretas para o usuário nos diretórios necessários
chown -R "$USER:$USER" "$PROJECT_DIR/web"
chown -R "$USER:$USER" "$PROJECT_DIR/logs" 2>/dev/null || true
chown -R "$USER:$USER" "$PROJECT_DIR/db" 2>/dev/null || true

log "✓ Permissões configuradas para usuário $USER"

# =============================================================================
# INSTALAR E ATIVAR SERVIÇO
# =============================================================================
echo ""
info "=== INSTALANDO E ATIVANDO SERVIÇO ==="

# Recarregar configuração systemd
log "Recarregando configuração systemd..."
systemctl daemon-reload

# Ativar serviço para iniciar no boot
log "Ativando serviço para iniciar no boot..."
systemctl enable "$SERVICE_NAME"

# Verificar se serviço já está rodando
if systemctl is-active --quiet "$SERVICE_NAME"; then
    warn "Serviço já está rodando. Reiniciando..."
    systemctl restart "$SERVICE_NAME"
else
    log "Iniciando serviço..."
    systemctl start "$SERVICE_NAME"
fi

# Aguardar um pouco para o serviço inicializar
sleep 3

# =============================================================================
# VERIFICAR STATUS
# =============================================================================
echo ""
info "=== VERIFICANDO STATUS DO SERVIÇO ==="

# Verificar status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    log "✅ Serviço está rodando com sucesso!"
    
    # Mostrar informações do serviço
    echo ""
    info "Status detalhado:"
    systemctl status "$SERVICE_NAME" --no-pager -l
    
else
    error "❌ Falha ao iniciar o serviço"
    echo ""
    error "Logs do serviço:"
    journalctl -u "$SERVICE_NAME" --no-pager -l -n 20
    exit 1
fi

# Verificar se está habilitado para boot
if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    log "✅ Serviço configurado para iniciar no boot"
else
    warn "⚠ Serviço não está habilitado para boot"
fi

# =============================================================================
# INFORMAÇÕES FINAIS
# =============================================================================
echo ""
echo -e "${GREEN}"
echo "=================================================================="
echo "           SERVIÇO HOMEGUARD MQTT CONFIGURADO COM SUCESSO!"
echo "=================================================================="
echo -e "${NC}"

echo ""
info "COMANDOS ÚTEIS:"
echo "  • Ver status:           sudo systemctl status $SERVICE_NAME"
echo "  • Parar serviço:        sudo systemctl stop $SERVICE_NAME"
echo "  • Iniciar serviço:      sudo systemctl start $SERVICE_NAME"
echo "  • Reiniciar serviço:    sudo systemctl restart $SERVICE_NAME"
echo "  • Ver logs em tempo real: sudo journalctl -u $SERVICE_NAME -f"
echo "  • Ver logs recentes:    sudo journalctl -u $SERVICE_NAME -n 50"
echo "  • Desabilitar boot:     sudo systemctl disable $SERVICE_NAME"

echo ""
info "ARQUIVOS IMPORTANTES:"
echo "  • Arquivo de serviço:   $SERVICE_FILE"
echo "  • Script principal:     $MQTT_SERVICE_PATH"
echo "  • Logs do sistema:      journalctl -u $SERVICE_NAME"
echo "  • Logs da aplicação:    $LOG_DIR/mqtt_service.log"

echo ""
info "VERIFICAÇÃO AUTOMÁTICA:"
echo "  O serviço irá iniciar automaticamente quando o Raspberry Pi for reiniciado."
echo "  Para testar: sudo reboot"

echo ""
warn "IMPORTANTE:"
echo "  • Certifique-se de que o broker MQTT esteja rodando"
echo "  • Verifique as configurações em $PROJECT_DIR/web/"
echo "  • Monitor os logs após reinicialização para garantir funcionamento"

echo ""
log "Configuração concluída! O serviço HomeGuard MQTT está pronto para produção."
