# HomeGuard Remote Access - Mobile Apps Guide

## 📱 Aplicações Recomendadas

### 🔒 **VPN Client (Obrigatório)**

#### iOS (iPhone/iPad):
- **WireGuard** (App Store)
  - Gratuito e oficial
  - Melhor performance
  - Menor consumo de bateria

#### Android:
- **WireGuard** (Google Play)
  - Gratuito e oficial
  - Interface simples
  - Conexão automática

#### macOS:
- **WireGuard** (Mac App Store)
  - Interface nativa macOS
  - Menu bar integration
- **Tunnelblick** (alternativa OpenVPN)

#### Windows:
- **WireGuard** (wireguard.com)
  - Cliente oficial desktop

### 📡 **MQTT Clients**

#### iOS:
1. **MQTTAnalyzer** (Pago - $4.99)
   - Interface profissional
   - Suporte completo MQTT
   - Ideal para HomeGuard

2. **IoT MQTT Panel** (Gratuito)
   - Dashboard customizável
   - Widgets para controle
   - Perfeito para automação

3. **MQTT Client** (Gratuito)
   - Simples e funcional
   - Boa para testes

#### Android:
1. **MQTT Dash** (Freemium)
   - Dashboard personalizável
   - Widgets visuais
   - Ideal para controle doméstico

2. **IoT MQTT Panel** (Gratuito)
   - Cross-platform
   - Interface limpa

3. **MyMQTT** (Freemium)
   - Cliente completo
   - Histórico de mensagens

#### macOS:
1. **MQTT Explorer** (Gratuito)
   - Aplicação desktop completa
   - Visualização hierárquica
   - Ideal para desenvolvimento

2. **MQTTLens** (Gratuito)
   - Interface moderna
   - Múltiplas conexões

### 🏠 **Home Automation Apps**

#### iOS/Android:
1. **Home Assistant** (Gratuito)
   - Plataforma completa
   - Integração MQTT nativa
   - Dashboards avançados

2. **OpenHAB** (Gratuito)
   - Open source
   - Suporte MQTT
   - Altamente configurável

## 🔧 **Configuração de Apps**

### WireGuard Setup:

#### Configuração Típica:
```ini
[Interface]
PrivateKey = [CLIENT_PRIVATE_KEY]
Address = 10.200.200.2/32
DNS = 8.8.8.8

[Peer]
PublicKey = [SERVER_PUBLIC_KEY]
Endpoint = YOUR_EXTERNAL_IP:51820
AllowedIPs = 10.200.200.0/24, 192.168.18.0/24
PersistentKeepalive = 25
```

### MQTT Client Configuration:

#### Configuração HomeGuard:
- **Host**: 192.168.18.198
- **Port**: 1883
- **Username**: homeguard
- **Password**: pu2clr123456
- **Client ID**: mobile_client_[random]

#### Tópicos para Subscribe:
```
home/+/status          # Status de todos dispositivos
home/+/heartbeat       # Heartbeat de dispositivos
home/motion1/motion    # Eventos de movimento
home/relay1/relay      # Eventos do relé
home/audio/events      # Eventos de áudio
```

#### Tópicos para Publish (Comandos):
```
home/relay1/cmnd       # Controlar relé
home/audio/cmnd        # Controlar áudio
home/motion1/cmnd      # Configurar sensor
```

## 📲 **Dashboard Configuration**

### IoT MQTT Panel - Widget Examples:

#### 1. Relay Control:
```json
{
  "type": "switch",
  "topic_pub": "home/relay1/cmnd",
  "topic_sub": "home/relay1/status",
  "payload_on": "ON",
  "payload_off": "OFF",
  "title": "Main Relay"
}
```

#### 2. Motion Status:
```json
{
  "type": "indicator",
  "topic_sub": "home/motion1/motion",
  "title": "Motion Detected",
  "color_on": "#FF0000",
  "color_off": "#00FF00"
}
```

#### 3. Audio Commands:
```json
{
  "type": "button",
  "topic_pub": "home/audio/cmnd",
  "payload": "DOGS",
  "title": "Dog Alert"
}
```

#### 4. System Status:
```json
{
  "type": "text",
  "topic_sub": "home/+/heartbeat",
  "title": "Device Status",
  "format": "Last seen: {timestamp}"
}
```

### MQTT Dash - Example Dashboard:

#### Controls Panel:
- **Switch**: Relay ON/OFF
- **Button**: Dog Alert
- **Button**: Morning Routine
- **Slider**: Audio Volume (future)

#### Status Panel:
- **Text**: Motion Status
- **Text**: Relay Status
- **Text**: Audio Mode
- **Graph**: Signal Strength (RSSI)

## 🛡️ **Security Configuration**

### VPN Security:
1. **Always On VPN** (iOS/Android)
2. **Kill Switch** enabled
3. **Auto-connect** on untrusted networks
4. **DNS leak protection**

### MQTT Security:
1. **Change default credentials**
2. **Use client certificates** (advanced)
3. **Enable TLS** (future upgrade)
4. **Restrict topic access** (ACL)

## 📋 **Quick Setup Checklist**

### Mobile Device Setup:
- [ ] Install WireGuard app
- [ ] Import VPN configuration
- [ ] Test VPN connection
- [ ] Install MQTT client app
- [ ] Configure MQTT connection
- [ ] Test HomeGuard commands
- [ ] Setup dashboard widgets
- [ ] Configure notifications

### Security Checklist:
- [ ] Change MQTT password
- [ ] Enable VPN auto-connect
- [ ] Test from external network
- [ ] Configure router port forwarding
- [ ] Setup dynamic DNS (if needed)
- [ ] Document client configurations

## 🔗 **Download Links**

### iOS:
- WireGuard: https://apps.apple.com/app/wireguard/id1451685025
- MQTTAnalyzer: https://apps.apple.com/app/mqttanalyzer/id1493015317
- IoT MQTT Panel: https://apps.apple.com/app/iot-mqtt-panel/id1445960816

### Android:
- WireGuard: https://play.google.com/store/apps/details?id=com.wireguard.android
- MQTT Dash: https://play.google.com/store/apps/details?id=net.routix.mqttdash
- IoT MQTT Panel: https://play.google.com/store/apps/details?id=snr.lab.iotmqttpanel

### macOS:
- WireGuard: https://apps.apple.com/app/wireguard/id1451685025
- MQTT Explorer: https://mqtt-explorer.com/

## 💡 **Pro Tips**

1. **Use meaningful client names** in VPN (e.g., "ricardo_iphone")
2. **Create separate dashboards** for different users
3. **Use widgets for quick actions** (dog alert, lights)
4. **Set up notifications** for security events
5. **Test remote access** before leaving home
6. **Keep backup of VPN configs** in secure location
7. **Monitor VPN connection logs** regularly

## 🆘 **Troubleshooting**

### VPN Not Connecting:
1. Check router port forwarding (51820 UDP)
2. Verify external IP in config
3. Check firewall settings
4. Test with mobile data vs WiFi

### MQTT Not Working:
1. Verify VPN is connected first
2. Check MQTT broker IP (192.168.18.198)
3. Test with mosquitto_sub/pub commands
4. Verify credentials

### Can't Access HomeGuard:
1. Ping HomeGuard devices through VPN
2. Check device IPs (192.168.18.x)
3. Verify MQTT broker is running
4. Check device heartbeats
