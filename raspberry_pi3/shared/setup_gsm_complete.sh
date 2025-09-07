#!/bin/bash

# HomeGuard GSM Setup Complete
# Automated setup for GSM connection with full control

echo "🇧🇷 HomeGuard GSM Setup - Brasil"
echo "================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}📡 Configuração GSM Detectada${NC}"
echo "✅ Conexão isolada do provedor principal"
echo "✅ Controle total do modem/roteador"  
echo "✅ Backup independente de internet"
echo "✅ Segurança profissional"
echo ""

# Check prerequisites
echo -e "${BLUE}📋 Verificando Pré-requisitos...${NC}"

if ! command -v wg &> /dev/null; then
    echo -e "${YELLOW}⚠️  WireGuard não encontrado. Execute primeiro:${NC}"
    echo "./setup_vpn_server.sh"
    read -p "Pressione Enter para continuar ou Ctrl+C para sair..."
fi

# GSM Modem Detection
echo -e "${CYAN}🔍 Detectando Modem GSM...${NC}"

# Common GSM router IPs
GSM_IPS=("192.168.8.1" "192.168.1.1" "192.168.0.1" "192.168.88.1")
DETECTED_MODEM=""

for IP in "${GSM_IPS[@]}"; do
    if ping -c 1 -W 1 $IP &> /dev/null; then
        echo -e "${GREEN}✅ Modem encontrado: $IP${NC}"
        
        # Try to identify brand
        if curl -s --connect-timeout 2 "http://$IP" | grep -i "huawei" &> /dev/null; then
            DETECTED_MODEM="Huawei ($IP)"
        elif curl -s --connect-timeout 2 "http://$IP" | grep -i "tp-link\|tplink" &> /dev/null; then
            DETECTED_MODEM="TP-Link ($IP)"
        elif curl -s --connect-timeout 2 "http://$IP" | grep -i "zte" &> /dev/null; then
            DETECTED_MODEM="ZTE ($IP)"
        elif curl -s --connect-timeout 2 "http://$IP" | grep -i "mikrotik" &> /dev/null; then
            DETECTED_MODEM="Mikrotik ($IP)"
        else
            DETECTED_MODEM="Desconhecido ($IP)"
        fi
        break
    fi
done

if [ -z "$DETECTED_MODEM" ]; then
    echo -e "${YELLOW}⚠️  Nenhum modem GSM detectado nas faixas comuns${NC}"
    echo "   Verifique se o modem está ligado e conectado"
    read -p "   IP manual do modem GSM: " MANUAL_IP
    DETECTED_MODEM="Manual ($MANUAL_IP)"
fi

echo -e "${GREEN}📡 Modem GSM: $DETECTED_MODEM${NC}"

# Get GSM external IP
echo -e "${CYAN}🌐 Detectando IP Externo GSM...${NC}"

EXTERNAL_IP=$(curl -s --connect-timeout 5 ifconfig.me || curl -s --connect-timeout 5 ipinfo.io/ip)
if [ -n "$EXTERNAL_IP" ]; then
    echo -e "${GREEN}🌍 IP Externo: $EXTERNAL_IP${NC}"
else
    echo -e "${YELLOW}⚠️  Não foi possível detectar IP externo${NC}"
    EXTERNAL_IP="[IP_GSM_EXTERNO]"
fi

# Get local Raspberry Pi IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}🏠 Raspberry Pi IP: $LOCAL_IP${NC}"

echo ""
echo -e "${BLUE}📋 Configurações Necessárias no Modem GSM:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Port Forwarding:${NC}"
echo "  Serviço: HomeGuard-VPN"
echo "  Porta Externa: 51820 (UDP)"
echo "  IP Interno: $LOCAL_IP"
echo "  Porta Interna: 51820 (UDP)"
echo ""
echo -e "${YELLOW}Firewall:${NC}"
echo "  Permitir: Porta 51820 UDP (entrada)"
echo "  Bloquear: Todas outras portas de entrada"
echo ""
echo -e "${YELLOW}QoS/Priorização:${NC}"
echo "  Alta: VPN (porta 51820)"
echo "  Baixa: Outros tráfegos"
echo ""

# Ask for configuration
read -p "Você já configurou o port forwarding no modem GSM? (s/n): " PORT_CONFIGURED

if [ "$PORT_CONFIGURED" != "s" ] && [ "$PORT_CONFIGURED" != "S" ]; then
    echo ""
    echo -e "${CYAN}📚 Consulte o guia específico para seu modem:${NC}"
    echo "   cat GSM_BRASIL_GUIDE.md"
    echo ""
    echo -e "${YELLOW}⏳ Configure o modem e execute este script novamente${NC}"
    exit 1
fi

# Run GSM optimization
echo -e "${BLUE}🔧 Aplicando Otimizações GSM...${NC}"
if [ -f "./optimize_gsm_connection.sh" ]; then
    chmod +x ./optimize_gsm_connection.sh
    ./optimize_gsm_connection.sh
else
    echo -e "${RED}❌ Arquivo optimize_gsm_connection.sh não encontrado${NC}"
    exit 1
fi

# Generate client configuration
echo ""
echo -e "${BLUE}📱 Gerando Configuração de Cliente...${NC}"
read -p "Nome do seu dispositivo (ex: iphone_ricardo): " CLIENT_NAME

if [ -z "$CLIENT_NAME" ]; then
    CLIENT_NAME="mobile_device"
fi

# Run client generator
if [ -f "$HOME/generate_gsm_client.sh" ]; then
    $HOME/generate_gsm_client.sh "$CLIENT_NAME" "$EXTERNAL_IP"
else
    echo -e "${RED}❌ Gerador de cliente não encontrado${NC}"
    exit 1
fi

# Final instructions
echo ""
echo -e "${GREEN}✅ Configuração GSM Completa!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}📱 Próximos Passos:${NC}"
echo ""
echo "1. ${YELLOW}Instalar WireGuard no seu celular:${NC}"
echo "   • Android: Google Play Store"
echo "   • iPhone: App Store"
echo ""
echo "2. ${YELLOW}Configurar cliente VPN:${NC}"
echo "   • Abrir WireGuard app"
echo "   • Escanear QR code gerado"
echo "   • Ou importar arquivo: /etc/wireguard/clients/${CLIENT_NAME}.conf"
echo ""
echo "3. ${YELLOW}Testar conexão:${NC}"
echo "   • Desconectar WiFi (usar dados móveis)"
echo "   • Ativar VPN no WireGuard"
echo "   • Testar acesso: http://192.168.1.102:8080"
echo ""
echo "4. ${YELLOW}Monitoramento:${NC}"
echo "   • Verificar consumo de dados GSM"
echo "   • Logs: journalctl -u wg-quick@wg0"
echo "   • Status: sudo wg show"
echo ""

# Data usage monitoring
echo -e "${BLUE}📊 Monitoramento de Dados GSM:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Consumo Estimado HomeGuard (mensal):${NC}"
echo "  • Básico (apenas status): 50-100 MB"
echo "  • Normal (uso regular): 200-300 MB"  
echo "  • Intensivo (comandos frequentes): 500MB-1GB"
echo ""

# Security reminder
echo -e "${BLUE}🛡️  Segurança GSM:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Vantagens da sua configuração:${NC}"
echo "  • Rede isolada do provedor principal"
echo "  • Controle total do roteador"
echo "  • Criptografia WireGuard (militar)"
echo "  • Backup de internet automático"
echo "  • Acesso remoto seguro"
echo ""

# Support info
echo -e "${BLUE}📚 Documentação e Suporte:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• Guia modems brasileiros: cat GSM_BRASIL_GUIDE.md"
echo "• Configuração avançada: cat GSM_Router_Configuration.md"
echo "• Gerar novos clientes: ~/generate_gsm_client.sh nome_cliente"
echo "• Status do sistema: sudo systemctl status wg-quick@wg0"
echo ""

echo -e "${GREEN}🎉 HomeGuard GSM está pronto para uso!${NC}"
echo -e "${CYAN}🌟 Você agora tem uma central de segurança profissional com acesso remoto seguro via GSM!${NC}"
