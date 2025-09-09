#!/bin/bash

# =============================================================================
# INICIALIZADOR DO SISTEMA DE CÂMERAS HOMEGUARD
# =============================================================================
# Script para iniciar todos os componentes do sistema de câmeras
# =============================================================================

set -e

# Configuração de diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$SCRIPT_DIR/venv_camera"
CONFIG_FILE="$SCRIPT_DIR/camera_config.json"
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
echo -e "${BLUE}"
echo "=================================================================="
echo "          HOMEGUARD - SISTEMA DE CÂMERAS INTELBRAS"
echo "=================================================================="
echo -e "${NC}"

# Verificar se está no diretório correto
if [[ ! -f "$SCRIPT_DIR/camera_integration.py" ]]; then
    error "Script deve ser executado do diretório raspberry_pi3/"
    error "Caminho atual: $SCRIPT_DIR"
    exit 1
fi

log "Diretório do projeto: $PROJECT_DIR"
log "Diretório de trabalho: $SCRIPT_DIR"

# =============================================================================
# VERIFICAÇÕES INICIAIS
# =============================================================================
echo ""
info "=== VERIFICAÇÕES INICIAIS ==="

# Verificar arquivo de configuração
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Arquivo de configuração não encontrado: $CONFIG_FILE"
    error "Execute primeiro: ./setup_camera_system.sh"
    exit 1
fi

log "✓ Arquivo de configuração encontrado"

# Verificar virtual environment
if [[ ! -d "$VENV_DIR" ]]; then
    error "Virtual environment não encontrado: $VENV_DIR"
    error "Execute primeiro: ./setup_camera_system.sh"
    exit 1
fi

log "✓ Virtual environment encontrado"

# Criar diretório de logs se não existir
mkdir -p "$LOG_DIR"
mkdir -p "$SCRIPT_DIR/snapshots"
mkdir -p "$SCRIPT_DIR/recordings"

log "✓ Diretórios criados/verificados"

# =============================================================================
# ATIVAR VIRTUAL ENVIRONMENT
# =============================================================================
echo ""
info "=== ATIVANDO VIRTUAL ENVIRONMENT ==="

source "$VENV_DIR/bin/activate"
log "✓ Virtual environment ativado"

# Verificar dependências principais
python_packages=(
    "opencv-python"
    "paho-mqtt"
    "flask"
    "numpy"
)

for package in "${python_packages[@]}"; do
    if python -c "import ${package//-/_}" 2>/dev/null; then
        log "✓ $package disponível"
    else
        warn "⚠ $package não encontrado"
        info "Instalando $package..."
        pip install "$package"
    fi
done

# =============================================================================
# VERIFICAR CONFIGURAÇÃO
# =============================================================================
echo ""
info "=== VERIFICANDO CONFIGURAÇÃO ==="

# Verificar sintaxe JSON
if python -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
    log "✓ Configuração JSON válida"
else
    error "✗ Erro na sintaxe do arquivo de configuração"
    error "Verifique o arquivo: $CONFIG_FILE"
    exit 1
fi

# Extrair informações básicas da configuração
cameras_count=$(python -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
    print(len(config.get('cameras', [])))
")

mqtt_host=$(python -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
    print(config.get('mqtt', {}).get('host', 'N/A'))
")

log "✓ Câmeras configuradas: $cameras_count"
log "✓ MQTT Broker: $mqtt_host"

# =============================================================================
# TESTE DE CONECTIVIDADE BÁSICA
# =============================================================================
echo ""
info "=== TESTE DE CONECTIVIDADE ==="

# Testar MQTT (se mosquitto estiver disponível)
if command -v mosquitto_pub &> /dev/null; then
    mqtt_user=$(python -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
    print(config.get('mqtt', {}).get('username', ''))
")
    
    mqtt_pass=$(python -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
    print(config.get('mqtt', {}).get('password', ''))
")
    
    if timeout 5 mosquitto_pub -h "$mqtt_host" -u "$mqtt_user" -P "$mqtt_pass" \
       -t "homeguard/cameras/system/status" \
       -m "{\"status\":\"starting\",\"timestamp\":\"$(date -Iseconds)\"}" 2>/dev/null; then
        log "✓ Conexão MQTT funcionando"
    else
        warn "⚠ Falha na conexão MQTT (sistema continuará funcionando)"
    fi
else
    info "ℹ Mosquitto não instalado - teste MQTT pulado"
fi

# =============================================================================
# INICIAR COMPONENTES
# =============================================================================
echo ""
info "=== INICIANDO COMPONENTES ==="

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

# Parar processos existentes se estiverem rodando
stop_existing_processes() {
    info "Verificando processos existentes..."
    
    # Camera integration
    if check_process "camera_integration" "$SCRIPT_DIR/camera_integration.pid"; then
        local pid=$(cat "$SCRIPT_DIR/camera_integration.pid")
        warn "Parando processo camera_integration existente (PID: $pid)"
        kill "$pid" 2>/dev/null || true
        sleep 2
        rm -f "$SCRIPT_DIR/camera_integration.pid"
    fi
    
    # Web interface
    if check_process "camera_web" "$SCRIPT_DIR/camera_web.pid"; then
        local pid=$(cat "$SCRIPT_DIR/camera_web.pid")
        warn "Parando processo camera_web existente (PID: $pid)"
        kill "$pid" 2>/dev/null || true
        sleep 2
        rm -f "$SCRIPT_DIR/camera_web.pid"
    fi
}

stop_existing_processes

# Iniciar sistema principal de câmeras
start_camera_system() {
    info "Iniciando sistema principal de câmeras..."
    
    nohup python "$SCRIPT_DIR/camera_integration.py" \
        > "$LOG_DIR/camera_system.log" 2>&1 &
    
    echo $! > "$SCRIPT_DIR/camera_integration.pid"
    sleep 3
    
    if check_process "camera_integration" "$SCRIPT_DIR/camera_integration.pid"; then
        local pid=$(cat "$SCRIPT_DIR/camera_integration.pid")
        log "✓ Sistema de câmeras iniciado (PID: $pid)"
    else
        error "✗ Falha ao iniciar sistema de câmeras"
        error "Verifique o log: tail -f $LOG_DIR/camera_system.log"
        return 1
    fi
}

# Iniciar interface web
start_web_interface() {
    info "Iniciando interface web..."
    
    nohup python "$SCRIPT_DIR/camera_web_interface.py" \
        > "$LOG_DIR/camera_web.log" 2>&1 &
    
    echo $! > "$SCRIPT_DIR/camera_web.pid"
    sleep 3
    
    if check_process "camera_web" "$SCRIPT_DIR/camera_web.pid"; then
        local pid=$(cat "$SCRIPT_DIR/camera_web.pid")
        log "✓ Interface web iniciada (PID: $pid)"
        
        # Detectar IP local
        local_ip=$(hostname -I | awk '{print $1}')
        info "Interface disponível em: http://$local_ip:8080/"
    else
        error "✗ Falha ao iniciar interface web"
        error "Verifique o log: tail -f $LOG_DIR/camera_web.log"
        return 1
    fi
}

# Iniciar componentes
if start_camera_system; then
    sleep 2
    start_web_interface
else
    error "Falha crítica no sistema de câmeras"
    exit 1
fi

# =============================================================================
# STATUS E INFORMAÇÕES FINAIS
# =============================================================================
echo ""
info "=== SISTEMA INICIADO COM SUCESSO ==="

# Mostrar status dos processos
echo ""
log "Processos ativos:"
if check_process "camera_integration" "$SCRIPT_DIR/camera_integration.pid"; then
    pid_camera=$(cat "$SCRIPT_DIR/camera_integration.pid")
    echo "  • Sistema de câmeras: PID $pid_camera ✓"
else
    echo "  • Sistema de câmeras: ✗"
fi

if check_process "camera_web" "$SCRIPT_DIR/camera_web.pid"; then
    pid_web=$(cat "$SCRIPT_DIR/camera_web.pid")
    echo "  • Interface web: PID $pid_web ✓"
else
    echo "  • Interface web: ✗"
fi

# Informações de acesso
echo ""
local_ip=$(hostname -I | awk '{print $1}')
log "Informações de acesso:"
echo "  • Interface web: http://$local_ip:8080/"
echo "  • Logs do sistema: $LOG_DIR/"
echo "  • Snapshots: $SCRIPT_DIR/snapshots/"
echo "  • Gravações: $SCRIPT_DIR/recordings/"

# Comandos úteis
echo ""
info "Comandos úteis:"
echo "  • Ver logs em tempo real:"
echo "    tail -f $LOG_DIR/camera_system.log"
echo "    tail -f $LOG_DIR/camera_web.log"
echo ""
echo "  • Parar o sistema:"
echo "    ./stop_camera_system.sh"
echo ""
echo "  • Monitorar MQTT:"
echo "    mosquitto_sub -h $mqtt_host -u $mqtt_user -P [senha] -t 'homeguard/cameras/#' -v"
echo ""
echo "  • Status dos processos:"
echo "    ps aux | grep camera_integration"
echo "    ps aux | grep camera_web_interface"

# Aviso sobre primeira execução
echo ""
warn "PRIMEIRA EXECUÇÃO:"
echo "  1. Acesse a interface web em http://$local_ip:8080/"
echo "  2. Verifique se as câmeras aparecem no dashboard"
echo "  3. Teste a conectividade com cada câmera"
echo "  4. Configure alertas e gravações conforme necessário"

echo ""
echo -e "${GREEN}"
echo "=================================================================="
echo "       SISTEMA DE CÂMERAS HOMEGUARD INICIADO COM SUCESSO!"
echo "=================================================================="
echo -e "${NC}"

# Manter script ativo por alguns segundos para mostrar logs iniciais
echo ""
info "Exibindo logs iniciais (10 segundos)..."
sleep 2

# Mostrar últimas linhas dos logs
if [[ -f "$LOG_DIR/camera_system.log" ]]; then
    echo ""
    echo -e "${BLUE}=== LOGS DO SISTEMA DE CÂMERAS ===${NC}"
    tail -n 5 "$LOG_DIR/camera_system.log"
fi

if [[ -f "$LOG_DIR/camera_web.log" ]]; then
    echo ""
    echo -e "${BLUE}=== LOGS DA INTERFACE WEB ===${NC}"
    tail -n 5 "$LOG_DIR/camera_web.log"
fi

echo ""
log "Sistema funcionando! Use 'tail -f $LOG_DIR/*.log' para monitorar."
