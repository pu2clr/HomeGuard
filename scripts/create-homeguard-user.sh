#!/bin/bash

# =============================================================================
# SCRIPT PARA CRIAR USUÁRIO HOMEGUARD NO SISTEMA
# =============================================================================
# Script para criar e configurar o usuário "homeguard" no Raspberry Pi
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
echo "             CRIAÇÃO DO USUÁRIO HOMEGUARD"
echo "=================================================================="
echo -e "${NC}"

# Verificar se está executando como root
if [[ $EUID -ne 0 ]]; then
    error "Este script deve ser executado como root ou com sudo"
    error "Use: sudo $0"
    exit 1
fi

# Configurações
USERNAME="homeguard"
HOME_DIR="/home/$USERNAME"
PROJECT_DIR="$HOME_DIR/HomeGuard"

# Verificar se usuário já existe
if id "$USERNAME" &>/dev/null; then
    log "✓ Usuário '$USERNAME' já existe"
    
    # Mostrar informações do usuário
    USER_INFO=$(id "$USERNAME")
    log "Informações: $USER_INFO"
    
    USER_HOME=$(eval echo ~$USERNAME)
    log "Diretório home: $USER_HOME"
    
    echo ""
    read -p "Deseja reconfigurar as permissões do usuário existente? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Configuração de usuário pulada."
        exit 0
    fi
else
    echo ""
    info "=== CRIANDO USUÁRIO HOMEGUARD ==="
    
    # Criar usuário com diretório home
    log "Criando usuário '$USERNAME'..."
    useradd -m -s /bin/bash "$USERNAME"
    
    # Definir senha
    echo ""
    info "Defina uma senha para o usuário '$USERNAME':"
    passwd "$USERNAME"
    
    log "✓ Usuário '$USERNAME' criado com sucesso"
fi

# =============================================================================
# CONFIGURAR GRUPOS E PERMISSÕES
# =============================================================================
echo ""
info "=== CONFIGURANDO GRUPOS E PERMISSÕES ==="

# Adicionar aos grupos necessários
GROUPS=(
    "sudo"          # Acesso administrativo
    "gpio"          # Acesso GPIO (Raspberry Pi)
    "i2c"           # Acesso I2C
    "spi"           # Acesso SPI
    "dialout"       # Acesso serial
)

for group in "${GROUPS[@]}"; do
    if getent group "$group" >/dev/null 2>&1; then
        if groups "$USERNAME" | grep -q "\b$group\b"; then
            log "✓ Usuário já está no grupo: $group"
        else
            usermod -a -G "$group" "$USERNAME"
            log "✓ Adicionado ao grupo: $group"
        fi
    else
        warn "⚠ Grupo não encontrado: $group (normal em alguns sistemas)"
    fi
done

# =============================================================================
# CONFIGURAR DIRETÓRIO HOME
# =============================================================================
echo ""
info "=== CONFIGURANDO DIRETÓRIO HOME ==="

# Garantir que diretório home existe
if [[ ! -d "$HOME_DIR" ]]; then
    mkdir -p "$HOME_DIR"
    log "✓ Diretório home criado: $HOME_DIR"
fi

# Definir permissões corretas
chown "$USERNAME:$USERNAME" "$HOME_DIR"
chmod 755 "$HOME_DIR"
log "✓ Permissões do diretório home configuradas"

# Criar diretórios básicos
BASIC_DIRS=(
    "$HOME_DIR/.ssh"
    "$HOME_DIR/bin"
    "$HOME_DIR/logs"
)

for dir in "${BASIC_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chown "$USERNAME:$USERNAME" "$dir"
        log "✓ Diretório criado: $(basename "$dir")"
    fi
done

# Configurar permissões SSH se existir
if [[ -d "$HOME_DIR/.ssh" ]]; then
    chmod 700 "$HOME_DIR/.ssh"
    log "✓ Permissões SSH configuradas"
fi

# =============================================================================
# CONFIGURAR AMBIENTE SHELL
# =============================================================================
echo ""
info "=== CONFIGURANDO AMBIENTE SHELL ==="

# Criar .bashrc básico se não existir
BASHRC_FILE="$HOME_DIR/.bashrc"
if [[ ! -f "$BASHRC_FILE" ]]; then
    cat > "$BASHRC_FILE" << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Basic shell options
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
shopt -s checkwinsize

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Some useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# HomeGuard aliases
alias hg-status='systemctl status homeguard-mqtt'
alias hg-logs='journalctl -u homeguard-mqtt -f'
alias hg-restart='sudo systemctl restart homeguard-mqtt'

# Add local bin to PATH
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Welcome message
echo "Bem-vindo ao HomeGuard System!"
echo "Use 'hg-status' para ver status do serviço MQTT"
EOF

    chown "$USERNAME:$USERNAME" "$BASHRC_FILE"
    log "✓ Arquivo .bashrc criado"
fi

# =============================================================================
# CONFIGURAR SUDO (OPCIONAL)
# =============================================================================
echo ""
read -p "Deseja permitir que o usuário '$USERNAME' execute sudo sem senha para comandos do HomeGuard? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "=== CONFIGURANDO SUDO SEM SENHA ==="
    
    SUDOERS_FILE="/etc/sudoers.d/homeguard"
    cat > "$SUDOERS_FILE" << EOF
# Allow homeguard user to manage HomeGuard services without password
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl start homeguard-mqtt
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl stop homeguard-mqtt
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl restart homeguard-mqtt
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl status homeguard-mqtt
$USERNAME ALL=(ALL) NOPASSWD: /bin/journalctl -u homeguard-mqtt*
EOF
    
    chmod 440 "$SUDOERS_FILE"
    log "✓ Configuração sudo sem senha para serviços HomeGuard"
fi

# =============================================================================
# PREPARAR PARA PROJETO HOMEGUARD
# =============================================================================
echo ""
info "=== PREPARANDO PARA PROJETO HOMEGUARD ==="

# Verificar se projeto já existe
if [[ -d "$PROJECT_DIR" ]]; then
    warn "Diretório do projeto já existe: $PROJECT_DIR"
else
    log "Projeto será clonado em: $PROJECT_DIR"
fi

# Dar permissões para o usuário criar/modificar o projeto
chown "$USERNAME:$USERNAME" "$HOME_DIR"
log "✓ Permissões preparadas para projeto HomeGuard"

# =============================================================================
# INFORMAÇÕES FINAIS
# =============================================================================
echo ""
echo -e "${GREEN}"
echo "=================================================================="
echo "           USUÁRIO HOMEGUARD CONFIGURADO COM SUCESSO!"
echo "=================================================================="
echo -e "${NC}"

echo ""
info "INFORMAÇÕES DO USUÁRIO:"
echo "  • Nome: $USERNAME"
echo "  • Home: $HOME_DIR"
echo "  • Shell: /bin/bash"
echo "  • Grupos: $(groups "$USERNAME" | cut -d: -f2)"

echo ""
info "PRÓXIMOS PASSOS:"
echo "  1. Fazer login como usuário homeguard:"
echo "     su - $USERNAME"
echo ""
echo "  2. Clonar o projeto HomeGuard:"
echo "     cd ~"
echo "     git clone https://github.com/pu2clr/HomeGuard.git"
echo ""
echo "  3. Executar instalação do serviço MQTT:"
echo "     cd HomeGuard"
echo "     sudo ./scripts/setup-mqtt-service.sh"

echo ""
info "COMANDOS ÚTEIS:"
echo "  • Trocar para usuário: su - $USERNAME"
echo "  • Ver status MQTT: hg-status"
echo "  • Ver logs MQTT: hg-logs"
echo "  • Reiniciar serviço: hg-restart"

echo ""
warn "IMPORTANTE:"
echo "  • Anote a senha do usuário '$USERNAME'"
echo "  • Configure chaves SSH se necessário"
echo "  • Teste o acesso antes de continuar"

echo ""
log "Configuração do usuário HomeGuard concluída!"
