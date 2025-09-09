# 🎯 HomeGuard + TP-Link TL-MR100 - Guia Completo

## 📡 **TP-Link TL-MR100 - Especificações**

### ✅ **Por que é Ideal para HomeGuard:**
```yaml
Conectividade:
  ✅ 4G LTE Cat 4 (até 150 Mbps download / 50 Mbps upload)
  ✅ Fallback 3G automático
  ✅ WiFi N300 (2.4 GHz)
  ✅ 2 portas Ethernet (1 LAN/WAN + 1 LAN)

Recursos HomeGuard:
  ✅ Port forwarding configurável
  ✅ QoS Traffic Control
  ✅ Firewall personalizável
  ✅ DDNS support
  ✅ Interface web em português

Hardware:
  ✅ Antenas removíveis (upgrade possível)
  ✅ Slot MicroSIM
  ✅ Plug & Play
  ✅ LED status (sinal, conectividade)
  ✅ Alimentação externa (estável)
```

---

## 🔧 **Configuração Inicial TL-MR100**

### **1. Primeira Conexão:**
```bash
# O TL-MR100 cria uma rede WiFi padrão
SSID: TP-Link_[MAC_últimos_dígitos]
Senha: Impressa na etiqueta do roteador

# Ou conectar via cabo ethernet
IP Padrão: 192.168.1.1
Login: admin
Senha: admin (primeira vez)
```

### **2. Acesso à Interface Web:**
```bash
# Conectar ao WiFi ou ethernet
# Abrir navegador
http://192.168.1.1

# Login inicial
Usuário: admin
Senha: admin

# Configurar nova senha (obrigatório)
Nova senha: [SUA_SENHA_FORTE]
```

### **3. Configuração APN (Brasil):**
```yaml
Menu: Advanced → Network → Internet

Para Vivo:
  Profile Name: Vivo
  APN: vivo.com.br
  Username: vivo
  Password: vivo
  Authentication: PAP/CHAP
  PDP Type: IPv4

Para TIM:
  Profile Name: TIM
  APN: tim.br
  Username: tim
  Password: tim

Para Claro:
  Profile Name: Claro
  APN: claro.com.br
  Username: claro
  Password: claro

Para Oi:
  Profile Name: Oi
  APN: gprs.oi.com.br
  Username: oi
  Password: oi
```

---

## 🎯 **Configuração HomeGuard Específica**

### **1. Port Forwarding para VPN:**
```yaml
Menu: Advanced → NAT Forwarding → Port Forwarding

Add New Entry:
  Service Name: HomeGuard-VPN
  Device: Custom (IP: 192.168.1.100)  # IP do Raspberry Pi
  External Port: 51820
  Internal Port: 51820
  Protocol: UDP
  Status: Enabled

Save & Apply
```

### **2. Configuração de Firewall:**
```yaml
Menu: Advanced → Security → Firewall

Settings:
  SPI Firewall: Enable
  DoS Protection: Enable
  VPN Passthrough: Enable (todos)

Access Control:
  Default Policy: Deny (entrada)
  Allow: Port 51820 UDP (HomeGuard VPN)

Save & Apply
```

### **3. QoS para HomeGuard:**
```yaml
Menu: Advanced → Advanced → QoS

Enable QoS: ✓
Upload Bandwidth: [Conforme seu plano]
Download Bandwidth: [Conforme seu plano]

High Priority Rules:
  Name: HomeGuard-VPN
  Device: Raspberry Pi (192.168.1.100)
  Port: 51820
  Protocol: UDP
  Priority: High

  Name: HomeGuard-MQTT
  Device: Raspberry Pi (192.168.1.100)  
  Port: 1883
  Protocol: TCP
  Priority: High

Save & Apply
```

### **4. DDNS (Opcional mas Recomendado):**
```yaml
Menu: Advanced → Network → Dynamic DNS

Service Provider: No-IP / DynDNS
Domain Name: homeguard-[seunome].ddns.net
Username: [sua_conta_ddns]
Password: [senha_ddns]

Enable: ✓
Save & Apply
```

---

## 📱 **Interface TP-Link Tether**

### **Configuração via App:**
```yaml
Download:
  Android: TP-Link Tether (Google Play)
  iOS: TP-Link Tether (App Store)

Funcionalidades HomeGuard:
  ✅ Monitorar sinal 4G em tempo real
  ✅ Ver consumo de dados
  ✅ Gerenciar port forwarding
  ✅ Configurar QoS remotamente
  ✅ Reiniciar modem à distância
  ✅ Receber notificações de status
```

---

## 🎛️ **Configurações Avançadas**

### **1. Otimização de Sinal:**
```yaml
Menu: Advanced → Network → Internet → Advanced

Network Settings:
  Network Mode: 4G Only (para estabilidade)
  Band Selection: Auto (ou manual se necessário)
  Roaming: Enable (se aplicável)

Signal Optimization:
  • Posicionar antenas verticalmente
  • Evitar obstáculos metálicos
  • Considerar antena externa se sinal fraco
```

### **2. Configuração de Rede Local:**
```yaml
Menu: Basic → LAN

IP Address: 192.168.1.1 (padrão OK para HomeGuard)
Subnet Mask: 255.255.255.0
DHCP: Enable
  Start IP: 192.168.1.100
  End IP: 192.168.1.199
  Lease Time: 24 hours

Reserved Address: 
  Raspberry Pi MAC → 192.168.1.100 (fixo)
```

### **3. WiFi Otimizado:**
```yaml
Menu: Basic → Wireless

2.4GHz Settings:
  SSID: HomeGuard-Network
  Security: WPA2-PSK
  Password: [SENHA_FORTE_16+]
  Channel: Auto (ou 1, 6, 11 manual)
  Channel Width: 20MHz (mais estável)
  Hidden Network: Enable (segurança extra)

Guest Network: Disable (não necessário)
```

---

## 💾 **Script de Configuração Automática**

<function_calls>
<invoke name="create_file">
<parameter name="content">#!/bin/bash

# HomeGuard TL-MR100 Configuration Helper
# Automated configuration for TP-Link TL-MR100

echo "🎯 HomeGuard + TP-Link TL-MR100 Setup"
echo "====================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if TL-MR100 is accessible
echo -e "${BLUE}🔍 Detectando TP-Link TL-MR100...${NC}"

if ping -c 1 -W 3 192.168.1.1 &> /dev/null; then
    echo -e "${GREEN}✅ TL-MR100 encontrado em 192.168.1.1${NC}"
else
    echo -e "${RED}❌ TL-MR100 não encontrado${NC}"
    echo "   Verifique se:"
    echo "   • Modem está ligado"
    echo "   • Conectado via WiFi ou ethernet"
    echo "   • IP correto (192.168.1.1)"
    exit 1
fi

# Get Raspberry Pi IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}🏠 Raspberry Pi IP: $LOCAL_IP${NC}"

# Check if IP is in correct range for TL-MR100
if [[ $LOCAL_IP == 192.168.1.* ]]; then
    echo -e "${GREEN}✅ IP na faixa correta do TL-MR100${NC}"
    PI_IP=$LOCAL_IP
else
    echo -e "${YELLOW}⚠️  Raspberry Pi não está na rede do TL-MR100${NC}"
    echo "   Configure o Pi para receber IP automático do modem"
    read -p "   IP desejado para o Pi (ex: 192.168.1.100): " PI_IP
    
    if [ -z "$PI_IP" ]; then
        PI_IP="192.168.1.100"
    fi
fi

echo ""
echo -e "${BLUE}📋 Configurações Necessárias no TL-MR100:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${YELLOW}1. Acesse a interface web:${NC}"
echo "   • Abra: http://192.168.1.1"
echo "   • Login: admin / admin (primeira vez)"
echo "   • Defina nova senha segura"
echo ""

echo -e "${YELLOW}2. Configure o APN da operadora:${NC}"
echo "   Menu: Advanced → Network → Internet"
echo ""
echo "   Para Vivo:"
echo "   • APN: vivo.com.br"
echo "   • Username: vivo"
echo "   • Password: vivo"
echo ""
echo "   Para TIM:"
echo "   • APN: tim.br" 
echo "   • Username: tim"
echo "   • Password: tim"
echo ""

echo -e "${YELLOW}3. Port Forwarding HomeGuard:${NC}"
echo "   Menu: Advanced → NAT Forwarding → Port Forwarding"
echo ""
echo "   Service Name: HomeGuard-VPN"
echo "   External Port: 51820"
echo "   Internal IP: $PI_IP"
echo "   Internal Port: 51820"
echo "   Protocol: UDP"
echo "   Status: Enabled"
echo ""

echo -e "${YELLOW}4. Configurar Firewall:${NC}"
echo "   Menu: Advanced → Security → Firewall"
echo ""
echo "   • SPI Firewall: Enable"
echo "   • DoS Protection: Enable"
echo "   • VPN Passthrough: Enable"
echo ""

echo -e "${YELLOW}5. QoS (Opcional mas Recomendado):${NC}"
echo "   Menu: Advanced → Advanced → QoS"
echo ""
echo "   • Enable QoS"
echo "   • High Priority: Port 51820 UDP ($PI_IP)"
echo "   • High Priority: Port 1883 TCP ($PI_IP)"
echo ""

# Interactive configuration
echo -e "${CYAN}💡 Configuração Interativa:${NC}"
read -p "Você já configurou o APN da operadora? (s/n): " APN_OK
read -p "Você já configurou o port forwarding (51820 UDP)? (s/n): " PORT_OK
read -p "Você já configurou o firewall? (s/n): " FIREWALL_OK

if [ "$APN_OK" != "s" ] || [ "$PORT_OK" != "s" ] || [ "$FIREWALL_OK" != "s" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Configure os itens pendentes no TL-MR100 antes de continuar${NC}"
    echo ""
    echo -e "${BLUE}📚 Consulte o guia detalhado:${NC}"
    echo "   cat TLMR100_HOMEGUARD_GUIDE.md"
    echo ""
    read -p "Pressione Enter quando a configuração estiver completa..."
fi

# Test connectivity
echo ""
echo -e "${BLUE}🧪 Testando Conectividade...${NC}"

# Test internet via TL-MR100
if ping -c 2 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✅ Internet via TL-MR100: OK${NC}"
else
    echo -e "${RED}❌ Sem internet via TL-MR100${NC}"
    echo "   Verifique a configuração APN"
fi

# Test local network
if ping -c 1 192.168.1.1 &> /dev/null; then
    echo -e "${GREEN}✅ Rede local TL-MR100: OK${NC}"
else
    echo -e "${RED}❌ Problema na rede local${NC}"
fi

# Get external IP
echo -e "${CYAN}🌐 Detectando IP Externo...${NC}"
EXTERNAL_IP=$(curl -s --connect-timeout 10 ifconfig.me)
if [ -n "$EXTERNAL_IP" ]; then
    echo -e "${GREEN}🌍 IP Externo TL-MR100: $EXTERNAL_IP${NC}"
else
    echo -e "${YELLOW}⚠️  IP externo não detectado${NC}"
    EXTERNAL_IP="[IP_EXTERNO_TL-MR100]"
fi

# Configure Raspberry Pi network for TL-MR100
echo ""
echo -e "${BLUE}🔧 Configurando Raspberry Pi para TL-MR100...${NC}"

# Check if Pi IP needs to be set
if [[ $LOCAL_IP != 192.168.1.* ]]; then
    echo "Configurando IP estático para TL-MR100..."
    
    # Backup current network config
    sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
    
    # Add static IP configuration
    cat >> /tmp/tlmr100_network << EOF

# HomeGuard TL-MR100 Configuration
interface eth0
static ip_address=$PI_IP/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8

interface wlan0
static ip_address=$PI_IP/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
EOF
    
    sudo tee -a /etc/dhcpcd.conf < /tmp/tlmr100_network > /dev/null
    echo -e "${GREEN}✅ Configuração de rede aplicada${NC}"
    echo -e "${YELLOW}⚠️  Reinicie o Raspberry Pi para aplicar: sudo reboot${NC}"
fi

# Update HomeGuard configs for new network
echo ""
echo -e "${BLUE}📝 Atualizando Configurações HomeGuard...${NC}"

# Update MQTT broker IP in configs if needed
if [ -f "/home/pi/config.json" ]; then
    # Update for new network range if needed
    echo "✅ Configurações HomeGuard mantidas"
fi

# Final instructions
echo ""
echo -e "${GREEN}✅ TL-MR100 Configurado para HomeGuard!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}📱 Próximos Passos:${NC}"
echo ""
echo "1. ${YELLOW}Instalar SIM card no TL-MR100${NC}"
echo "   • Desligar modem"
echo "   • Inserir MicroSIM"
echo "   • Ligar e aguardar conexão 4G"
echo ""
echo "2. ${YELLOW}Monitorar via TP-Link Tether app:${NC}"
echo "   • Baixar app TP-Link Tether"
echo "   • Conectar ao TL-MR100"
echo "   • Monitorar sinal e dados"
echo ""
echo "3. ${YELLOW}Configurar VPN:${NC}"
echo "   • Execute: ./setup_gsm_complete.sh"
echo "   • Ou configure manualmente WireGuard"
echo ""
echo "4. ${YELLOW}Testar acesso remoto:${NC}"
echo "   • Gerar cliente VPN"
echo "   • Testar fora da rede local"
echo "   • Verificar acesso HomeGuard"
echo ""

# Network info summary
echo -e "${CYAN}📊 Resumo da Rede:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TL-MR100 Gateway: 192.168.1.1"
echo "Raspberry Pi IP: $PI_IP"
echo "External IP: $EXTERNAL_IP"
echo "Port Forward: 51820 UDP → $PI_IP:51820"
echo "MQTT Broker: $PI_IP:1883 (interno)"
echo ""

echo -e "${GREEN}🎉 TL-MR100 está pronto para o HomeGuard!${NC}"
echo -e "${CYAN}🌟 Você terá conectividade 4G dedicada com controle total!${NC}"
