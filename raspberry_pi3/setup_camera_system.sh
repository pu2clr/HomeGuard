#!/bin/bash

# HomeGuard Camera Integration Setup
# Script de instalação e configuração do sistema de câmeras Intelbras
# Compatível com Raspberry Pi 3/4

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_PATH="$SCRIPT_DIR/venv_camera"
CAMERA_SERVICE="homeguard-cameras"

echo -e "${CYAN}🎥 HomeGuard Camera Integration Setup${NC}"
echo "=================================================="
echo ""

# Função para logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Verificar se está rodando no Raspberry Pi
check_raspberry_pi() {
    log_step "Verificando plataforma..."
    
    if [[ $(uname -m) == arm* ]] || [[ $(uname -m) == aarch64 ]]; then
        log_info "Raspberry Pi detectado: $(uname -m)"
        
        # Verificar modelo
        if [ -f /proc/cpuinfo ]; then
            MODEL=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)
            log_info "Modelo: $MODEL"
        fi
    else
        log_warn "Este script é otimizado para Raspberry Pi, mas pode funcionar em outras plataformas"
    fi
}

# Atualizar sistema
update_system() {
    log_step "Atualizando sistema..."
    
    sudo apt update
    sudo apt upgrade -y
    
    log_info "Sistema atualizado"
}

# Instalar dependências do sistema
install_system_dependencies() {
    log_step "Instalando dependências do sistema..."
    
    # Pacotes essenciais
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        cmake \
        pkg-config \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libv4l-dev \
        libxvidcore-dev \
        libx264-dev \
        libgtk-3-dev \
        libatlas-base-dev \
        gfortran \
        ffmpeg \
        libopencv-dev \
        python3-opencv \
        mosquitto-clients \
        sqlite3
    
    # Instalar dependências específicas do Raspberry Pi
    if [[ $(uname -m) == arm* ]] || [[ $(uname -m) == aarch64 ]]; then
        log_info "Instalando dependências específicas do Raspberry Pi..."
        
        # Habilitar câmera se disponível
        if command -v raspi-config >/dev/null 2>&1; then
            sudo raspi-config nonint do_camera 0 || true
        fi
        
        # Instalar ferramentas de vídeo
        sudo apt install -y \
            libraspberrypi-dev \
            libraspberrypi0 \
            v4l-utils
    fi
    
    log_info "Dependências do sistema instaladas"
}

# Criar ambiente virtual Python
create_python_environment() {
    log_step "Criando ambiente virtual Python..."
    
    # Remover ambiente existente se houver
    if [ -d "$VENV_PATH" ]; then
        log_warn "Removendo ambiente virtual existente..."
        rm -rf "$VENV_PATH"
    fi
    
    # Criar novo ambiente
    python3 -m venv "$VENV_PATH"
    source "$VENV_PATH/bin/activate"
    
    # Atualizar pip
    pip install --upgrade pip
    
    log_info "Ambiente virtual criado: $VENV_PATH"
}

# Instalar dependências Python
install_python_dependencies() {
    log_step "Instalando dependências Python..."
    
    source "$VENV_PATH/bin/activate"
    
    # Lista de pacotes necessários
    cat > "$SCRIPT_DIR/requirements_camera.txt" << EOF
# Visão computacional e processamento de imagem
opencv-python==4.8.1.78
numpy>=1.21.0
Pillow>=8.3.0

# Comunicação e rede
paho-mqtt>=1.6.0
requests>=2.25.0

# Processamento de vídeo
imageio>=2.9.0
imageio-ffmpeg>=0.4.0

# Banco de dados
sqlite3

# Utilitários
python-dateutil>=2.8.0
pytz>=2021.1
configparser>=5.0.0

# Monitoramento e logs
psutil>=5.8.0

# Interface web (opcional)
flask>=2.0.0
flask-cors>=3.0.0

# Processamento assíncrono
asyncio
threading
queue
EOF
    
    # Instalar com retry em caso de falha
    for attempt in {1..3}; do
        log_info "Tentativa $attempt de instalação das dependências..."
        
        if pip install -r "$SCRIPT_DIR/requirements_camera.txt"; then
            log_info "Dependências Python instaladas com sucesso"
            break
        else
            log_warn "Falha na tentativa $attempt"
            if [ $attempt -eq 3 ]; then
                log_error "Falha ao instalar dependências Python após 3 tentativas"
                exit 1
            fi
            sleep 5
        fi
    done
}

# Configurar diretórios
setup_directories() {
    log_step "Configurando diretórios..."
    
    # Criar diretórios necessários
    mkdir -p "$SCRIPT_DIR/snapshots"
    mkdir -p "$SCRIPT_DIR/recordings"
    mkdir -p "$SCRIPT_DIR/logs"
    mkdir -p "$SCRIPT_DIR/config"
    
    # Configurar permissões
    chmod 755 "$SCRIPT_DIR/snapshots"
    chmod 755 "$SCRIPT_DIR/recordings"
    chmod 755 "$SCRIPT_DIR/logs"
    
    log_info "Diretórios configurados"
}

# Criar script de inicialização
create_startup_script() {
    log_step "Criando script de inicialização..."
    
    cat > "$SCRIPT_DIR/start_camera_system.sh" << 'EOF'
#!/bin/bash

# HomeGuard Camera System Startup Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PATH="$SCRIPT_DIR/venv_camera"
PYTHON_SCRIPT="$SCRIPT_DIR/camera_integration.py"
LOG_FILE="$SCRIPT_DIR/logs/camera_system.log"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🎥 Iniciando HomeGuard Camera System...${NC}"

# Verificar se o ambiente virtual existe
if [ ! -d "$VENV_PATH" ]; then
    echo -e "${RED}Erro: Ambiente virtual não encontrado em $VENV_PATH${NC}"
    echo "Execute o setup primeiro: ./setup_camera_system.sh"
    exit 1
fi

# Ativar ambiente virtual
source "$VENV_PATH/bin/activate"

# Verificar se o script principal existe
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo -e "${RED}Erro: Script principal não encontrado: $PYTHON_SCRIPT${NC}"
    exit 1
fi

# Criar diretório de logs se não existir
mkdir -p "$(dirname "$LOG_FILE")"

# Iniciar sistema
echo "Iniciando sistema de câmeras..."
echo "Log: $LOG_FILE"
echo "Para parar: Ctrl+C"
echo ""

# Executar com logs
python3 "$PYTHON_SCRIPT" 2>&1 | tee -a "$LOG_FILE"
EOF
    
    chmod +x "$SCRIPT_DIR/start_camera_system.sh"
    
    log_info "Script de inicialização criado: start_camera_system.sh"
}

# Criar serviço systemd
create_systemd_service() {
    log_step "Criando serviço systemd..."
    
    cat > "/tmp/${CAMERA_SERVICE}.service" << EOF
[Unit]
Description=HomeGuard Camera Integration System
After=network.target mosquitto.service
Wants=network.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=$SCRIPT_DIR
Environment=PYTHONPATH=$SCRIPT_DIR
ExecStart=$VENV_PATH/bin/python $SCRIPT_DIR/camera_integration.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Configurações de segurança
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$SCRIPT_DIR/snapshots $SCRIPT_DIR/recordings $SCRIPT_DIR/logs

[Install]
WantedBy=multi-user.target
EOF
    
    # Instalar serviço
    sudo mv "/tmp/${CAMERA_SERVICE}.service" "/etc/systemd/system/"
    sudo systemctl daemon-reload
    sudo systemctl enable "$CAMERA_SERVICE"
    
    log_info "Serviço systemd criado: $CAMERA_SERVICE"
}

# Testar instalação
test_installation() {
    log_step "Testando instalação..."
    
    source "$VENV_PATH/bin/activate"
    
    # Testar importações Python
    python3 -c "
import cv2
import numpy as np
import paho.mqtt.client as mqtt
import requests
import sqlite3
print('✅ Todas as dependências Python importadas com sucesso')
"
    
    # Testar conexão MQTT (se broker estiver rodando)
    if command -v mosquitto_pub >/dev/null 2>&1; then
        log_info "Testando conexão MQTT..."
        if timeout 5 mosquitto_pub -h 192.168.18.198 -t "test/camera" -m "test" -u homeguard -P pu2clr123456 2>/dev/null; then
            log_info "✅ Conexão MQTT funcionando"
        else
            log_warn "⚠️  Broker MQTT não acessível (normal se não estiver configurado ainda)"
        fi
    fi
    
    # Verificar OpenCV
    python3 -c "
import cv2
print(f'OpenCV versão: {cv2.__version__}')

# Testar codecs de vídeo
fourcc = cv2.VideoWriter_fourcc(*'MJPG')
print('✅ Codec MJPG disponível')

fourcc = cv2.VideoWriter_fourcc(*'XVID')
print('✅ Codec XVID disponível')
"
    
    log_info "✅ Teste de instalação concluído com sucesso"
}

# Criar arquivo de configuração de exemplo
create_example_config() {
    log_step "Criando configuração de exemplo..."
    
    if [ ! -f "$SCRIPT_DIR/camera_config.json" ]; then
        log_info "Arquivo de configuração já existe: camera_config.json"
    else
        log_info "Use o arquivo camera_config.json já existente"
    fi
    
    # Criar arquivo de exemplo com suas configurações
    cat > "$SCRIPT_DIR/camera_config_example.json" << 'EOF'
{
  "mqtt": {
    "host": "SEU_IP_MQTT_BROKER",
    "port": 1883,
    "username": "homeguard",
    "password": "pu2clr123456",
    "base_topic": "homeguard/cameras"
  },
  "cameras": [
    {
      "id": "CAM_001",
      "name": "Câmera Entrada",
      "location": "Entrada Principal",
      "ip": "192.168.1.100",
      "username": "admin",
      "password": "SUA_SENHA_CAMERA",
      "ptz_capable": false,
      "enabled": true
    }
  ]
}
EOF
    
    log_info "Arquivo de exemplo criado: camera_config_example.json"
}

# Mostrar informações finais
show_final_info() {
    echo ""
    echo "=================================================="
    echo -e "${GREEN}🎉 Instalação Concluída com Sucesso!${NC}"
    echo "=================================================="
    echo ""
    echo -e "${CYAN}📋 Próximos Passos:${NC}"
    echo ""
    echo "1. 📝 Editar configuração das câmeras:"
    echo "   nano $SCRIPT_DIR/camera_config.json"
    echo ""
    echo "2. 🔧 Configurar IPs das suas câmeras Intelbras:"
    echo "   - Definir IPs fixos para as câmeras"
    echo "   - Configurar usuário/senha de acesso"
    echo "   - Habilitar RTSP nas câmeras"
    echo ""
    echo "3. 🚀 Iniciar sistema:"
    echo "   # Teste manual:"
    echo "   $SCRIPT_DIR/start_camera_system.sh"
    echo ""
    echo "   # Ou iniciar serviço:"
    echo "   sudo systemctl start $CAMERA_SERVICE"
    echo "   sudo systemctl status $CAMERA_SERVICE"
    echo ""
    echo "4. 📊 Monitoramento:"
    echo "   # Ver logs:"
    echo "   journalctl -u $CAMERA_SERVICE -f"
    echo ""
    echo "   # Ver snapshots:"
    echo "   ls -la $SCRIPT_DIR/snapshots/"
    echo ""
    echo "5. 🔗 Integração MQTT:"
    echo "   # Monitorar eventos:"
    echo "   mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t 'homeguard/cameras/#' -v"
    echo ""
    echo "   # Comandos de teste:"
    echo "   mosquitto_pub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t 'homeguard/cameras/CAM_001/cmd' -m '{\"command\":\"snapshot\"}'"
    echo ""
    echo -e "${YELLOW}⚠️  Importante:${NC}"
    echo "- Configure as senhas das câmeras no arquivo de configuração"
    echo "- Teste a conectividade RTSP das câmeras antes de usar"
    echo "- Monitore o uso de CPU/memória no Raspberry Pi"
    echo "- Configure rotação de logs se necessário"
    echo ""
    echo -e "${GREEN}📚 Documentação completa: README_CAMERA_INTEGRATION.md${NC}"
    echo ""
}

# Função principal
main() {
    echo -e "${CYAN}Iniciando instalação do sistema de câmeras...${NC}"
    echo ""
    
    check_raspberry_pi
    update_system
    install_system_dependencies
    create_python_environment
    install_python_dependencies
    setup_directories
    create_startup_script
    create_systemd_service
    test_installation
    create_example_config
    show_final_info
    
    log_info "Setup concluído! 🎉"
}

# Verificar se está sendo executado como script principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
