# 📡 HomeGuard GSM - Guia de Modems Brasileiros

## 🇧🇷 **Modems GSM/4G Recomendados no Brasil**

### **📱 Huawei (Mais Comuns)**
```
Modelos: B315, B525, B612, B618, E5776
IP Padrão: 192.168.8.1
Login: admin/admin ou admin/[senha do WiFi]
Vantagens:
✅ Muito estável para IoT
✅ Interface web completa  
✅ Suporte a antena externa
✅ QoS configurável
```

### **🔧 TP-Link (Boa Relação Custo/Benefício)**
```
Modelos: M7300, M7350, MR6400, Archer MR500
IP Padrão: 192.168.1.1
Login: admin/admin
Vantagens:
✅ Interface amigável
✅ Preços acessíveis
✅ Boa documentação em português
```

### **⚡ ZTE (Operadoras)**
```
Modelos: MF971R, MF286, MF286R
IP Padrão: 192.168.0.1
Login: admin/admin
Vantagens:
✅ Certificado pelas operadoras
✅ Firmware otimizado
✅ Suporte técnico local
```

### **🏢 Mikrotik (Profissional)**
```
Modelos: LtAP mini LTE, SXT LTE6, wAP LTE
IP Padrão: 192.168.88.1
Login: admin/[sem senha]
Vantagens:
✅ RouterOS avançado
✅ Controle total
✅ Monitoramento profissional
✅ VPN nativo
```

---

## 🎯 **Configuração Ideal para HomeGuard**

### **Especificações Mínimas:**
```yaml
Conectividade:
  - 4G/LTE Cat 4+ (150 Mbps download)
  - Dual-band WiFi (2.4/5 GHz)
  - Ethernet: 4 portas mínimo

Recursos Essenciais:
  - Port forwarding configurável
  - QoS/Traffic Control
  - Firewall personalizável
  - DDNS support
  - Bridge mode option

Antenas:
  - 2x2 MIMO LTE mínimo
  - Conectores para antena externa
  - Ganho ≥ 5dBi recomendado
```

---

## 📋 **Configuração Passo-a-Passo**

### **1. Acesso Inicial:**
```bash
# Conectar cabo ethernet ou WiFi ao modem
# Descobrir IP do gateway
ip route | grep default

# Acessar interface web
firefox http://192.168.8.1  # Huawei
firefox http://192.168.1.1  # TP-Link
firefox http://192.168.0.1  # ZTE
```

### **2. Configuração APN (Operadoras Brasileiras):**
```yaml
Vivo:
  APN: vivo.com.br
  Usuário: vivo
  Senha: vivo

TIM:
  APN: tim.br
  Usuário: tim
  Senha: tim

Claro:
  APN: claro.com.br
  Usuário: claro
  Senha: claro

Oi:
  APN: gprs.oi.com.br
  Usuário: oi
  Senha: oi
```

### **3. Port Forwarding HomeGuard:**
```yaml
Configuração:
  Nome: HomeGuard-VPN
  Protocolo: UDP
  Porta Externa: 51820
  IP Interno: 192.168.8.100  # IP do Raspberry Pi
  Porta Interna: 51820
  Status: Habilitado
```

### **4. QoS/Priorização:**
```yaml
Alta Prioridade:
  - VPN (porta 51820)
  - MQTT (porta 1883 - interno)
  - SSH (porta 22 - interno)

Média Prioridade:
  - HTTP/HTTPS (80/443)
  - DNS (53)

Baixa Prioridade:
  - Streaming/Downloads
  - P2P
```

---

## 💰 **Planos de Dados Recomendados**

### **📊 Consumo Estimado HomeGuard:**
```yaml
Por mês (3 dispositivos):
  Básico: 50-100 MB
    - Status heartbeat
    - Comandos esporádicos
    
  Normal: 200-300 MB
    - Monitoramento regular
    - Alguns comandos de áudio
    
  Intensivo: 500MB-1GB
    - Comandos frequentes
    - Logs detalhados
    - Múltiplas conexões VPN
```

### **🎯 Planos IoT Recomendados:**
```yaml
Vivo IoT:
  - 1GB: R$ 25/mês
  - IP fixo: +R$ 15/mês
  - Boa cobertura nacional

TIM IoT:
  - 500MB: R$ 20/mês  
  - 1GB: R$ 30/mês
  - Latência baixa

Claro Negócios:
  - 1GB: R$ 35/mês
  - IP dedicado disponível
  - Suporte técnico 24/7
```

---

## 🔧 **Scripts de Automação**

### **Monitoramento de Conexão:**
```bash
#!/bin/bash
# check_gsm_health.sh

# Verificar sinal GSM
SIGNAL=$(curl -s "http://192.168.8.1/api/device/signal" | grep -o "SignalStrength.[0-9]*")
echo "Sinal GSM: $SIGNAL"

# Verificar uso de dados
DATA_USAGE=$(curl -s "http://192.168.8.1/api/monitoring/traffic-statistics")
echo "Dados utilizados: $DATA_USAGE"

# Testar conectividade
ping -c 1 8.8.8.8 > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Internet OK"
else
    echo "❌ Sem internet - reiniciando modem"
    # Reiniciar modem via API
    curl -s "http://192.168.8.1/api/device/control" -d "action=restart"
fi
```

### **Backup de Configuração:**
```bash
#!/bin/bash
# backup_gsm_config.sh

DATE=$(date +%Y%m%d_%H%M)
mkdir -p ~/gsm_backups

# Backup configuração do modem
curl -s "http://192.168.8.1/api/config/global" > ~/gsm_backups/config_$DATE.json
curl -s "http://192.168.8.1/api/security/firewall" > ~/gsm_backups/firewall_$DATE.json

echo "✅ Backup salvo em ~/gsm_backups/"
```

---

## 📱 **Aplicativo de Monitoramento**

### **Huawei HiLink App:**
```yaml
Funcionalidades:
  - Monitorar sinal e dados
  - Reiniciar modem remotamente  
  - Ver dispositivos conectados
  - Configurar WiFi guest

Download:
  - Android: Huawei HiLink
  - iOS: Huawei Mobile WiFi
```

### **TP-Link Tether:**
```yaml
Funcionalidades:
  - Controle completo do modem
  - Estatísticas de uso
  - Gerenciar port forwarding
  - QoS mobile-friendly

Download:
  - Android/iOS: TP-Link Tether
```

---

## 🛡️ **Segurança GSM Aprimorada**

### **Configurações Essenciais:**
```yaml
WiFi:
  - WPA3 ou WPA2-PSK AES
  - Senha forte (16+ caracteres)
  - Ocultar SSID
  - MAC filtering (opcional)

Firewall:
  - Bloquear todas portas por padrão
  - Permitir apenas porta 51820 (VPN)
  - Log de tentativas de acesso
  - DoS protection habilitado

Administração:
  - Alterar senha padrão
  - Desabilitar WPS
  - Limitar tentativas de login
  - HTTPS only para admin
```

### **Monitoramento de Intrusão:**
```bash
# Verificar tentativas de acesso
grep "failed login" /var/log/gsm-router.log

# Dispositivos conectados não autorizados
curl -s "http://192.168.8.1/api/wlan/host-list" | grep -v "known_device"
```

---

## 🚀 **Otimizações Avançadas**

### **Antenas Externas:**
```yaml
Para Área Rural:
  - Yagi direcional 18dBi
  - Cabo coaxial RG-58 ≤ 5m
  - Apontar para ERB mais próxima

Para Área Urbana:  
  - Omnidirecional 8dBi
  - Instalação elevada
  - Evitar obstáculos metálicos
```

### **Backup Power:**
```yaml
No-break:
  - 12V para modem GSM
  - Autonomia 4-8 horas
  - Raspberry Pi incluso

Solar:
  - Painel 50W mínimo
  - Bateria 12V 40Ah
  - Controlador MPPT
```

---

## ✅ **Checklist Instalação Final**

```yaml
Hardware:
  □ Modem GSM configurado
  □ Chip ativado com plano de dados
  □ Antenas posicionadas
  □ Raspberry Pi conectado

Software:
  □ WireGuard VPN funcionando
  □ Port forwarding 51820 ativo
  □ QoS configurado
  □ Firewall habilitado

Testes:
  □ Conexão VPN externa OK
  □ MQTT via VPN OK
  □ HomeGuard app conectando
  □ Consumo de dados monitorado

Monitoramento:
  □ Scripts de saúde rodando
  □ Backup automático ativo
  □ Alertas de falha configurados
```

**🎯 Com essa configuração você terá um sistema HomeGuard profissional via GSM, com total controle e segurança!**
