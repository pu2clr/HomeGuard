#!/bin/bash

# =============================================================================
# SCRIPT PARA PARAR O SISTEMA DE CÂMERAS HOMEGUARD
# =============================================================================
# Finaliza todos os processos do sistema de câmeras de forma segura
# =============================================================================

set -e

# Configuração de diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Banner
echo -e "${RED}"
echo "=================================================================="
echo "          PARANDO SISTEMA DE CÂMERAS HOMEGUARD"
echo "=================================================================="
echo -e "${NC}"

# Função para verificar se processo está rodando
check_process() {
    local name="$1"
    local pid_file="$2"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Processo rodando
        else
            rm -f "$pid_file"  # Remover PID file obsoleto
        fi
    fi
    return 1  # Processo não rodando
}

# Função para parar processo graciosamente
stop_process() {
    local name="$1"
    local pid_file="$2"
    local timeout="${3:-10}"
    
    if ! check_process "$name" "$pid_file"; then
        info "$name não está rodando"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    info "Parando $name (PID: $pid)..."
    
    # Tentar SIGTERM primeiro
    if kill "$pid" 2>/dev/null; then
        # Aguardar finalização graciosamente
        local count=0
        while [[ $count -lt $timeout ]] && ps -p "$pid" > /dev/null 2>&1; do
            sleep 1
            ((count++))
            echo -n "."
        done
        echo ""
        
        # Verificar se processo parou
        if ! ps -p "$pid" > /dev/null 2>&1; then
            log "✓ $name finalizado graciosamente"
            rm -f "$pid_file"
            return 0
        else
            warn "$name não respondeu ao SIGTERM, forçando com SIGKILL..."
            if kill -9 "$pid" 2>/dev/null; then
                sleep 2
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    log "✓ $name finalizado forçadamente"
                    rm -f "$pid_file"
                    return 0
                else
                    error "✗ Falha ao parar $name"
                    return 1
                fi
            else
                error "✗ Processo $name (PID: $pid) não encontrado"
                rm -f "$pid_file"
                return 0
            fi
        fi
    else
        warn "Processo $name (PID: $pid) não encontrado, removendo PID file"
        rm -f "$pid_file"
        return 0
    fi
}

# =============================================================================
# PARAR PROCESSOS PRINCIPAIS
# =============================================================================
echo ""
info "=== PARANDO PROCESSOS PRINCIPAIS ==="

# Parar interface web
stop_process "Interface Web" "$SCRIPT_DIR/camera_web.pid" 5

# Parar sistema de câmeras
stop_process "Sistema de Câmeras" "$SCRIPT_DIR/camera_integration.pid" 10

# =============================================================================
# VERIFICAR PROCESSOS ÓRFÃOS
# =============================================================================
echo ""
info "=== VERIFICANDO PROCESSOS ÓRFÃOS ==="

# Procurar por processos Python relacionados ao sistema de câmeras
orphan_processes=$(ps aux | grep -E "(camera_integration|camera_web_interface)" | grep -v grep | awk '{print $2}' || true)

if [[ -n "$orphan_processes" ]]; then
    warn "Encontrados processos órfãos:"
    ps aux | grep -E "(camera_integration|camera_web_interface)" | grep -v grep | head -5
    
    echo ""
    read -p "Deseja finalizar estes processos? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for pid in $orphan_processes; do
            if ps -p "$pid" > /dev/null 2>&1; then
                info "Finalizando processo órfão PID: $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    fi
else
    log "✓ Nenhum processo órfão encontrado"
fi

# =============================================================================
# VERIFICAR SERVIÇOS SYSTEMD
# =============================================================================
echo ""
info "=== VERIFICANDO SERVIÇOS SYSTEMD ==="

# Verificar se existe serviço systemd configurado
if systemctl is-enabled homeguard-cameras &>/dev/null; then
    if systemctl is-active homeguard-cameras &>/dev/null; then
        info "Parando serviço systemd homeguard-cameras..."
        sudo systemctl stop homeguard-cameras
        log "✓ Serviço systemd parado"
    else
        info "Serviço systemd já estava parado"
    fi
else
    info "Serviço systemd não configurado"
fi

# =============================================================================
# LIMPEZA DE ARQUIVOS TEMPORÁRIOS
# =============================================================================
echo ""
info "=== LIMPEZA DE ARQUIVOS TEMPORÁRIOS ==="

# Remover PID files se ainda existirem
pid_files=(
    "$SCRIPT_DIR/camera_integration.pid"
    "$SCRIPT_DIR/camera_web.pid"
)

for pid_file in "${pid_files[@]}"; do
    if [[ -f "$pid_file" ]]; then
        rm -f "$pid_file"
        info "Removido: $(basename "$pid_file")"
    fi
done

# Limpar sockets se existirem
if [[ -S "/tmp/homeguard_camera.sock" ]]; then
    rm -f "/tmp/homeguard_camera.sock"
    info "Removido socket Unix"
fi

# =============================================================================
# FINALIZAR MQTT (OPCIONAL)
# =============================================================================
echo ""
info "=== NOTIFICAÇÃO MQTT ==="

# Enviar notificação de sistema parado via MQTT
if [[ -f "$SCRIPT_DIR/camera_config.json" ]] && command -v mosquitto_pub &> /dev/null; then
    mqtt_host=$(python3 -c "
import json
try:
    with open('$SCRIPT_DIR/camera_config.json') as f:
        config = json.load(f)
        print(config.get('mqtt', {}).get('host', ''))
except:
    pass
" 2>/dev/null)
    
    mqtt_user=$(python3 -c "
import json
try:
    with open('$SCRIPT_DIR/camera_config.json') as f:
        config = json.load(f)
        print(config.get('mqtt', {}).get('username', ''))
except:
    pass
" 2>/dev/null)
    
    mqtt_pass=$(python3 -c "
import json
try:
    with open('$SCRIPT_DIR/camera_config.json') as f:
        config = json.load(f)
        print(config.get('mqtt', {}).get('password', ''))
except:
    pass
" 2>/dev/null)
    
    if [[ -n "$mqtt_host" && -n "$mqtt_user" ]]; then
        if timeout 5 mosquitto_pub -h "$mqtt_host" -u "$mqtt_user" -P "$mqtt_pass" \
           -t "homeguard/cameras/system/status" \
           -m "{\"status\":\"stopped\",\"timestamp\":\"$(date -Iseconds)\",\"uptime\":0}" 2>/dev/null; then
            log "✓ Notificação MQTT enviada"
        else
            info "Falha ao enviar notificação MQTT (normal se broker estiver offline)"
        fi
    fi
fi

# =============================================================================
# STATUS FINAL
# =============================================================================
echo ""
info "=== STATUS FINAL ==="

# Verificar se todos os processos foram parados
running_processes=$(ps aux | grep -E "(camera_integration|camera_web_interface)" | grep -v grep | wc -l)

if [[ $running_processes -eq 0 ]]; then
    log "✓ Todos os processos foram finalizados com sucesso"
else
    warn "⚠ Ainda existem $running_processes processos relacionados rodando"
    ps aux | grep -E "(camera_integration|camera_web_interface)" | grep -v grep | head -3
fi

# Informações sobre logs
echo ""
info "LOGS PRESERVADOS:"
if [[ -d "$LOG_DIR" ]]; then
    log_files=$(find "$LOG_DIR" -name "*.log" 2>/dev/null | wc -l)
    echo "  • Arquivos de log: $log_files em $LOG_DIR/"
    echo "  • Para ver últimas atividades: tail -n 50 $LOG_DIR/camera_system.log"
fi

# Informações sobre snapshots/gravações
snapshots_count=0
recordings_count=0

if [[ -d "$SCRIPT_DIR/snapshots" ]]; then
    snapshots_count=$(find "$SCRIPT_DIR/snapshots" -name "*.jpg" 2>/dev/null | wc -l)
fi

if [[ -d "$SCRIPT_DIR/recordings" ]]; then
    recordings_count=$(find "$SCRIPT_DIR/recordings" -name "*.mp4" 2>/dev/null | wc -l)
fi

echo ""
info "DADOS PRESERVADOS:"
echo "  • Snapshots: $snapshots_count arquivos"
echo "  • Gravações: $recordings_count arquivos"
echo "  • Configuração: $SCRIPT_DIR/camera_config.json"
echo "  • Banco de dados: $(dirname "$SCRIPT_DIR")/db/homeguard.db"

# Comandos para reiniciar
echo ""
info "PARA REINICIAR O SISTEMA:"
echo "  • Executar: ./start_camera_system.sh"
echo "  • Ou via systemd: sudo systemctl start homeguard-cameras"

echo ""
echo -e "${GREEN}"
echo "=================================================================="
echo "          SISTEMA DE CÂMERAS PARADO COM SUCESSO!"
echo "=================================================================="
echo -e "${NC}"
