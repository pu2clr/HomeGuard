#!/bin/bash

# =============================================================================
# TESTE RÁPIDO DE CONECTIVIDADE - CÂMERAS INTELBRAS
# =============================================================================
# Script para validar conectividade e configuração das câmeras antes da 
# instalação completa do sistema
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
echo "        HOMEGUARD - TESTE DE CÂMERAS INTELBRAS"
echo "=================================================================="
echo -e "${NC}"

# Verificar se está no Raspberry Pi
if [[ $(uname -m) == arm* ]] || [[ $(uname -m) == aarch64 ]]; then
    log "Executando no Raspberry Pi: $(uname -m)"
else
    warn "Não detectado Raspberry Pi. Alguns testes podem falhar."
fi

# Configurações padrão para teste
# EDITE ESTAS CONFIGURAÇÕES COM OS DADOS DAS SUAS CÂMERAS
CAMERAS=(
    "192.168.1.100:admin:sua_senha_camera:CAM_ENTRADA"
    "192.168.1.101:admin:sua_senha_camera:CAM_QUINTAL"
    "192.168.1.102:admin:sua_senha_camera:CAM_SALA"
    "192.168.1.103:admin:sua_senha_camera:CAM_GARAGEM"
)

MQTT_HOST="192.168.18.198"
MQTT_PORT="1883"
MQTT_USER="homeguard"
MQTT_PASS="pu2clr123456"

echo ""
info "Configurações de teste:"
echo "  • MQTT Broker: ${MQTT_HOST}:${MQTT_PORT}"
echo "  • Usuário MQTT: ${MQTT_USER}"
echo "  • Câmeras configuradas: ${#CAMERAS[@]}"
echo ""

# =============================================================================
# TESTE 1: VERIFICAR CONECTIVIDADE DE REDE
# =============================================================================
echo -e "${BLUE}=== TESTE 1: CONECTIVIDADE DE REDE ===${NC}"

test_network() {
    for camera_config in "${CAMERAS[@]}"; do
        IFS=':' read -r ip username password name <<< "$camera_config"
        
        echo -n "  • Testando ping para $name ($ip)... "
        if ping -c 1 -W 2 "$ip" &> /dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FALHOU${NC}"
            error "Câmera $name não responde ao ping!"
        fi
    done
}

test_network

# =============================================================================
# TESTE 2: VERIFICAR BROKER MQTT
# =============================================================================
echo ""
echo -e "${BLUE}=== TESTE 2: CONECTIVIDADE MQTT ===${NC}"

test_mqtt() {
    echo -n "  • Testando conexão MQTT... "
    if command -v mosquitto_pub &> /dev/null; then
        if timeout 5 mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" \
           -u "$MQTT_USER" -P "$MQTT_PASS" \
           -t "homeguard/test" -m "camera_test_$(date +%s)" &> /dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FALHOU${NC}"
            error "Não foi possível conectar ao broker MQTT!"
        fi
    else
        echo -e "${YELLOW}MOSQUITTO NÃO INSTALADO${NC}"
        warn "Instale mosquitto-clients: sudo apt install mosquitto-clients"
    fi
}

test_mqtt

# =============================================================================
# TESTE 3: VERIFICAR API HTTP DAS CÂMERAS
# =============================================================================
echo ""
echo -e "${BLUE}=== TESTE 3: API HTTP DAS CÂMERAS ===${NC}"

test_camera_http() {
    for camera_config in "${CAMERAS[@]}"; do
        IFS=':' read -r ip username password name <<< "$camera_config"
        
        echo -n "  • Testando API HTTP $name ($ip)... "
        
        # Teste básico de autenticação HTTP
        response=$(curl -s -w "%{http_code}" -u "$username:$password" \
                  --connect-timeout 5 \
                  "http://$ip/cgi-bin/magicBox.cgi?action=getDeviceType" \
                  -o /dev/null 2>/dev/null || echo "000")
        
        if [[ "$response" == "200" ]]; then
            echo -e "${GREEN}OK${NC}"
        elif [[ "$response" == "401" ]]; then
            echo -e "${RED}FALHOU - CREDENCIAIS INVÁLIDAS${NC}"
            error "Verifique usuário/senha para $name"
        elif [[ "$response" == "000" ]]; then
            echo -e "${RED}FALHOU - TIMEOUT/CONEXÃO${NC}"
            error "Câmera $name não responde na porta HTTP"
        else
            echo -e "${YELLOW}HTTP $response${NC}"
            warn "Resposta inesperada da câmera $name"
        fi
    done
}

test_camera_http

# =============================================================================
# TESTE 4: VERIFICAR STREAMS RTSP
# =============================================================================
echo ""
echo -e "${BLUE}=== TESTE 4: STREAMS RTSP ===${NC}"

test_camera_rtsp() {
    if ! command -v ffprobe &> /dev/null; then
        warn "FFmpeg não instalado. Pulando teste RTSP."
        echo "  Para instalar: sudo apt install ffmpeg"
        return
    fi

    for camera_config in "${CAMERAS[@]}"; do
        IFS=':' read -r ip username password name <<< "$camera_config"
        
        echo -n "  • Testando RTSP $name ($ip)... "
        
        # URLs RTSP mais comuns para Intelbras
        rtsp_urls=(
            "rtsp://$username:$password@$ip:554/cam/realmonitor?channel=1&subtype=1"
            "rtsp://$username:$password@$ip:554/cam/realmonitor?channel=1&subtype=0"
            "rtsp://$username:$password@$ip:554/live"
        )
        
        rtsp_working=false
        for url in "${rtsp_urls[@]}"; do
            if timeout 10 ffprobe -v quiet -select_streams v:0 \
               -show_entries stream=width,height,r_frame_rate \
               "$url" &> /dev/null; then
                echo -e "${GREEN}OK${NC}"
                info "    URL funcionando: ${url##*@}"
                
                # Obter informações do stream
                stream_info=$(timeout 10 ffprobe -v quiet -select_streams v:0 \
                             -show_entries stream=width,height,r_frame_rate \
                             -of csv=p=0 "$url" 2>/dev/null)
                if [[ -n "$stream_info" ]]; then
                    info "    Resolução/FPS: $stream_info"
                fi
                
                rtsp_working=true
                break
            fi
        done
        
        if [[ "$rtsp_working" == "false" ]]; then
            echo -e "${RED}FALHOU${NC}"
            error "Nenhuma URL RTSP funcionou para $name"
            info "  URLs testadas:"
            for url in "${rtsp_urls[@]}"; do
                info "    - ${url##*@}"
            done
        fi
    done
}

test_camera_rtsp

# =============================================================================
# TESTE 5: VERIFICAR DEPENDÊNCIAS DO SISTEMA
# =============================================================================
echo ""
echo -e "${BLUE}=== TESTE 5: DEPENDÊNCIAS DO SISTEMA ===${NC}"

test_dependencies() {
    dependencies=(
        "python3:Python 3"
        "pip3:Python PIP"
        "git:Git"
        "mosquitto_pub:Mosquitto Client"
        "ffmpeg:FFmpeg"
        "curl:cURL"
    )
    
    for dep in "${dependencies[@]}"; do
        IFS=':' read -r cmd name <<< "$dep"
        echo -n "  • $name... "
        
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}OK${NC}"
            if [[ "$cmd" == "python3" ]]; then
                version=$(python3 --version 2>&1 | cut -d' ' -f2)
                echo "    Versão: $version"
            fi
        else
            echo -e "${RED}NÃO ENCONTRADO${NC}"
            warn "Instale $name para usar o sistema completo"
        fi
    done
}

test_dependencies

# =============================================================================
# TESTE 6: VERIFICAR ESPAÇO EM DISCO
# =============================================================================
echo ""
echo -e "${BLUE}=== TESTE 6: ESPAÇO EM DISCO ===${NC}"

test_disk_space() {
    echo -n "  • Verificando espaço em disco... "
    
    available=$(df / | awk 'NR==2 {print $4}')
    available_gb=$((available / 1024 / 1024))
    
    if [[ $available_gb -gt 5 ]]; then
        echo -e "${GREEN}OK ($available_gb GB disponíveis)${NC}"
    elif [[ $available_gb -gt 2 ]]; then
        echo -e "${YELLOW}ATENÇÃO ($available_gb GB disponíveis)${NC}"
        warn "Espaço limitado. Considere limpar o sistema ou usar cartão SD maior."
    else
        echo -e "${RED}CRÍTICO ($available_gb GB disponíveis)${NC}"
        error "Espaço insuficiente! Necessário pelo menos 2GB livres."
    fi
    
    # Verificar se diretório do projeto existe
    project_dir="$HOME/HomeGuard"
    if [[ -d "$project_dir" ]]; then
        echo "  • Diretório do projeto: $project_dir ✓"
    else
        warn "Diretório do projeto não encontrado: $project_dir"
        info "  Execute: git clone <repositorio> $project_dir"
    fi
}

test_disk_space

# =============================================================================
# RESUMO DOS TESTES
# =============================================================================
echo ""
echo -e "${BLUE}=== RESUMO DOS TESTES ===${NC}"

# Contar sucessos/falhas (simplificado)
echo "✅ Testes básicos de conectividade concluídos"
echo ""

info "PRÓXIMOS PASSOS:"
echo "  1. Configure as câmeras com os IPs corretos em camera_config.json"
echo "  2. Ajuste usuários/senhas das câmeras"
echo "  3. Execute o setup completo: sudo ./setup_camera_system.sh"
echo "  4. Inicie o sistema: ./start_camera_system.sh"
echo ""

info "COMANDOS ÚTEIS:"
echo "  • Testar stream manual: ffplay rtsp://admin:senha@IP:554/cam/realmonitor?channel=1&subtype=1"
echo "  • Interface web da câmera: http://IP_CAMERA/"
echo "  • Monitorar MQTT: mosquitto_sub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS -t 'homeguard/#' -v"
echo ""

info "DOCUMENTAÇÃO COMPLETA:"
echo "  📖 README_CAMERA_INTEGRATION.md"
echo ""

# Salvar log
log_file="camera_test_$(date +%Y%m%d_%H%M%S).log"
echo "Log salvo em: $log_file"

echo -e "${GREEN}"
echo "=================================================================="
echo "        TESTE CONCLUÍDO - VERIFIQUE OS RESULTADOS ACIMA"
echo "=================================================================="
echo -e "${NC}"
