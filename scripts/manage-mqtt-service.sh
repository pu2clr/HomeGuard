#!/bin/bash

# =============================================================================
# GERENCIADOR DO SERVIÇO HOMEGUARD MQTT
# =============================================================================
# Script para gerenciar o serviço mqtt_service.py no Raspberry Pi
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
SERVICE_NAME="homeguard-mqtt"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # Diretório pai do scripts/

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO:${NC} $1"
}

# Função para mostrar uso
show_usage() {
    echo "HomeGuard MQTT Service Manager"
    echo ""
    echo "Uso: $0 {status|start|stop|restart|logs|enable|disable|install}"
    echo ""
    echo "Comandos:"
    echo "  status     - Mostra status do serviço"
    echo "  start      - Inicia o serviço"
    echo "  stop       - Para o serviço"
    echo "  restart    - Reinicia o serviço"
    echo "  logs       - Mostra logs em tempo real"
    echo "  enable     - Habilita inicialização automática"
    echo "  disable    - Desabilita inicialização automática"
    echo "  install    - Instala o serviço systemd"
    echo ""
}

# Verificar se serviço existe
check_service_exists() {
    if ! systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
        error "Serviço $SERVICE_NAME não encontrado!"
        error "Execute primeiro: sudo ./scripts/setup-mqtt-service.sh"
        return 1
    fi
    return 0
}

# Mostrar status detalhado
show_status() {
    echo -e "${BLUE}"
    echo "=================================================================="
    echo "           STATUS DO SERVIÇO HOMEGUARD MQTT"
    echo "=================================================================="
    echo -e "${NC}"
    
    if ! check_service_exists; then
        return 1
    fi
    
    # Status do systemd
    echo ""
    info "=== STATUS SYSTEMD ==="
    systemctl status "$SERVICE_NAME" --no-pager || true
    
    # Verificar se está ativo
    echo ""
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ Serviço está ATIVO"
    else
        error "❌ Serviço está INATIVO"
    fi
    
    # Verificar se está habilitado para boot
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log "✅ Inicialização automática HABILITADA"
    else
        warn "⚠ Inicialização automática DESABILITADA"
    fi
    
    # Mostrar últimas linhas do log
    echo ""
    info "=== ÚLTIMAS LINHAS DO LOG ==="
    journalctl -u "$SERVICE_NAME" --no-pager -l -n 10 || true
    
    # Estatísticas do banco de dados (se disponível)
    echo ""
    info "=== ESTATÍSTICAS ==="
    
    # Verificar se o Python está disponível e o banco existe
    if command -v python3 &> /dev/null && [[ -f "$PROJECT_DIR/db/homeguard.db" ]]; then
        python3 -c "
import sqlite3
import os
try:
    db_path = os.path.join('$PROJECT_DIR', 'db', 'homeguard.db')
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Total de registros
    cursor.execute('SELECT COUNT(*) FROM activity')
    total = cursor.fetchone()[0]
    print(f'📊 Total de mensagens MQTT: {total:,}')
    
    # Últimas 24 horas
    cursor.execute(\"\"\"
        SELECT COUNT(*) FROM activity 
        WHERE created_at >= datetime('now', '-24 hours')
    \"\"\")
    last_24h = cursor.fetchone()[0]
    print(f'🕐 Últimas 24 horas: {last_24h:,} mensagens')
    
    # Última atividade
    cursor.execute(\"\"\"
        SELECT created_at, topic FROM activity 
        ORDER BY created_at DESC LIMIT 1
    \"\"\")
    result = cursor.fetchone()
    if result:
        print(f'🕒 Última atividade: {result[0]} ({result[1]})')
    
    conn.close()
except Exception as e:
    print(f'❌ Erro ao acessar banco: {e}')
"
    else
        echo "📊 Estatísticas não disponíveis (Python/DB não encontrado)"
    fi
}

# Mostrar logs em tempo real
show_logs() {
    echo -e "${BLUE}"
    echo "=================================================================="
    echo "              LOGS EM TEMPO REAL - CTRL+C PARA SAIR"
    echo "=================================================================="
    echo -e "${NC}"
    
    if ! check_service_exists; then
        return 1
    fi
    
    journalctl -u "$SERVICE_NAME" -f --no-pager
}

# Iniciar serviço
start_service() {
    if ! check_service_exists; then
        return 1
    fi
    
    log "Iniciando serviço $SERVICE_NAME..."
    sudo systemctl start "$SERVICE_NAME"
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ Serviço iniciado com sucesso"
    else
        error "❌ Falha ao iniciar serviço"
        echo ""
        error "Logs do erro:"
        journalctl -u "$SERVICE_NAME" --no-pager -l -n 10
        return 1
    fi
}

# Parar serviço
stop_service() {
    if ! check_service_exists; then
        return 1
    fi
    
    log "Parando serviço $SERVICE_NAME..."
    sudo systemctl stop "$SERVICE_NAME"
    sleep 2
    
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ Serviço parado com sucesso"
    else
        warn "⚠ Serviço pode ainda estar finalizando..."
    fi
}

# Reiniciar serviço
restart_service() {
    if ! check_service_exists; then
        return 1
    fi
    
    log "Reiniciando serviço $SERVICE_NAME..."
    sudo systemctl restart "$SERVICE_NAME"
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ Serviço reiniciado com sucesso"
    else
        error "❌ Falha ao reiniciar serviço"
        return 1
    fi
}

# Habilitar inicialização automática
enable_service() {
    if ! check_service_exists; then
        return 1
    fi
    
    log "Habilitando inicialização automática..."
    sudo systemctl enable "$SERVICE_NAME"
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log "✅ Inicialização automática habilitada"
    else
        error "❌ Falha ao habilitar inicialização automática"
        return 1
    fi
}

# Desabilitar inicialização automática
disable_service() {
    if ! check_service_exists; then
        return 1
    fi
    
    log "Desabilitando inicialização automática..."
    sudo systemctl disable "$SERVICE_NAME"
    
    if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log "✅ Inicialização automática desabilitada"
    else
        error "❌ Falha ao desabilitar inicialização automática"
        return 1
    fi
}

# Instalar serviço
install_service() {
    log "Executando instalação do serviço..."
    
    if [[ ! -f "$PROJECT_DIR/scripts/setup-mqtt-service.sh" ]]; then
        error "Script de instalação não encontrado: $PROJECT_DIR/scripts/setup-mqtt-service.sh"
        return 1
    fi
    
    sudo "$PROJECT_DIR/scripts/setup-mqtt-service.sh"
}

# Verificar argumentos
if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

# Processar comando
case "$1" in
    status)
        show_status
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    logs)
        show_logs
        ;;
    enable)
        enable_service
        ;;
    disable)
        disable_service
        ;;
    install)
        install_service
        ;;
    *)
        error "Comando desconhecido: $1"
        show_usage
        exit 1
        ;;
esac
