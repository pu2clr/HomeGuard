# 🎥 HomeGuard Camera Integration - Sistema de Câmeras Intelbras

Integração completa de câmeras IP Intelbras ao sistema HomeGuard com monitoramento inteligente, detecção de movimento e controle via MQTT.

## 🎯 Funcionalidades Principais

### 📹 **Monitoramento de Vídeo**
- **Stream RTSP** de câmeras Intelbras em tempo real
- **Detecção de movimento** inteligente com OpenCV
- **Captura automática** de snapshots em eventos
- **Gravação** em situações de emergência
- **Interface web** para visualização e controle

### 🏠 **Integração HomeGuard**
- **Sincronização com sensores** de movimento existentes
- **Ativação automática** de relés e luzes
- **Coordenação com sistema de áudio** para simulação de presença
- **Dados unificados** no banco SQLite
- **Dashboard Flask** com visualização de câmeras

### 🤖 **Controle Inteligente**
- **Comandos MQTT** para controle remoto
- **PTZ automático** para câmeras compatíveis
- **Agendamento** de gravações
- **Detecção de zona** configurável
- **Alertas** via MQTT e webhook

## 🏗️ Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    RASPBERRY PI 3/4                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  Camera System  │  │   MQTT Broker   │  │ Web Interface│ │
│  │                 │  │                 │  │              │ │
│  │ • RTSP Streams  │  │ • Commands      │  │ • Live View  │ │
│  │ • Motion Det.   │  │ • Events        │  │ • Controls   │ │
│  │ • Snapshots     │  │ • Integration   │  │ • History    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                               │
                   ┌───────────┼───────────┐
                   │           │           │
            ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
            │   CAM_001   │ │   CAM_002   │ │   CAM_003   │
            │             │ │             │ │             │
            │ Entrada     │ │ Quintal     │ │ Sala        │
            │ RTSP Stream │ │ PTZ Control │ │ Privacy     │
            │ Motion Det. │ │ Snapshots   │ │ Scheduled   │
            └─────────────┘ └─────────────┘ └─────────────┘
```

## 🚀 Instalação Rápida

### 1. **Executar Setup Automático**
```bash
# No Raspberry Pi, navegue até o diretório do projeto
cd /home/pi/HomeGuard/raspberry_pi3

# Executar instalação completa
sudo ./setup_camera_system.sh
```

### 2. **Configurar Câmeras**
```bash
# Editar configuração das câmeras
nano camera_config.json
```

**Exemplo de configuração:**
```json
{
  "mqtt": {
    "host": "192.168.18.198",
    "port": 1883,
    "username": "homeguard",
    "password": "pu2clr123456"
  },
  "cameras": [
    {
      "id": "CAM_ENTRADA",
      "name": "Câmera Entrada Principal",
      "location": "Entrada/Portão",
      "ip": "192.168.1.100",
      "username": "admin",
      "password": "sua_senha_camera",
      "ptz_capable": false,
      "motion_detection": true,
      "enabled": true
    }
  ]
}
```

### 3. **Iniciar Sistema**
```bash
# Teste manual
./start_camera_system.sh

# Ou serviço automático
sudo systemctl start homeguard-cameras
sudo systemctl enable homeguard-cameras
```

### 4. **Acessar Interface Web**
```
http://192.168.1.102:8080/
```

## 📋 Configuração Detalhada

### **Configuração de Câmeras Intelbras**

#### **1. Habilitar RTSP na Câmera**
```bash
# Acessar interface web da câmera
http://IP_DA_CAMERA

# Navegar para: Configurar > Rede > RTSP
# Habilitar: Serviço RTSP
# Porta: 554 (padrão)
# Autenticação: Básica
```

#### **2. Configurar Usuário e Senha**
```bash
# Interface da câmera > Configurar > Sistema > Conta
# Criar usuário: admin
# Senha: definir uma senha segura
```

#### **3. URLs de Stream Intelbras**
```bash
# Stream Principal (alta qualidade)
rtsp://admin:senha@IP_CAMERA:554/cam/realmonitor?channel=1&subtype=0

# Stream Secundário (baixa qualidade - recomendado)
rtsp://admin:senha@IP_CAMERA:554/cam/realmonitor?channel=1&subtype=1
```

### **Configuração de Rede**

#### **IPs Fixos Recomendados**
```bash
# Configurar IPs fixos para as câmeras no roteador
CAM_ENTRADA:  192.168.1.100
CAM_QUINTAL:  192.168.1.101
CAM_SALA:     192.168.1.102
CAM_GARAGEM:  192.168.1.103
```

#### **Teste de Conectividade**
```bash
# Testar ping
ping 192.168.1.100

# Testar RTSP
ffplay rtsp://admin:senha@192.168.1.100:554/cam/realmonitor?channel=1&subtype=1

# Testar HTTP API
curl -u admin:senha http://192.168.1.100/cgi-bin/magicBox.cgi?action=getDeviceType
```

## 🎛️ Controle via MQTT

### **Tópicos de Comando**
```bash
# Capturar snapshot
mosquitto_pub -h 192.168.18.198 -u homeguard -P pu2clr123456 \
  -t "homeguard/cameras/CAM_ENTRADA/cmd" \
  -m '{"command":"snapshot"}'

# Controle PTZ
mosquitto_pub -h 192.168.18.198 -u homeguard -P pu2clr123456 \
  -t "homeguard/cameras/CAM_QUINTAL/cmd" \
  -m '{"command":"ptz","action":"up","speed":5}'

# Iniciar gravação
mosquitto_pub -h 192.168.18.198 -u homeguard -P pu2clr123456 \
  -t "homeguard/cameras/CAM_ENTRADA/cmd" \
  -m '{"command":"recording","enabled":true}'
```

### **Tópicos de Eventos**
```bash
# Monitorar todos os eventos de câmeras
mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 \
  -t "homeguard/cameras/#" -v

# Eventos de movimento específicos
mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 \
  -t "homeguard/cameras/+/motion" -v

# Status das câmeras
mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 \
  -t "homeguard/cameras/+/status" -v
```

## 🔗 Integração com Sistema Existente

### **1. Integração com Sensores de Movimento**
O sistema automaticamente detecta eventos de movimento dos sensores ESP01 existentes e ativa as câmeras correspondentes:

```python
# Quando sensor de movimento detecta atividade:
# Topic: homeguard/motion/MOTION_02/event
# Payload: {"motion":1,"device_id":"MOTION_02","location":"Varanda"}

# Sistema de câmeras responde:
# 1. Identifica câmeras próximas pela localização
# 2. Captura snapshot automaticamente
# 3. Inicia gravação se configurado
# 4. PTZ move para posição padrão
```

### **2. Integração com Sistema de Áudio**
```python
# Configuração no camera_config.json
"integration": {
  "audio_system": {
    "enabled": true,
    "motion_triggers": {
      "CAM_ENTRADA": ["dogs", "footsteps"],
      "CAM_QUINTAL": ["dogs", "alerts"],
      "CAM_SALA": ["tv_radio", "footsteps"]
    }
  }
}
```

### **3. Integração com Relés**
```python
# Ativação automática de luzes
"relay_control": {
  "enabled": true,
  "motion_triggers": {
    "CAM_ENTRADA": "ESP01_RELAY_ENTRADA",
    "CAM_QUINTAL": "ESP01_RELAY_QUINTAL"
  },
  "activation_duration": 300
}
```

## 💾 Banco de Dados

### **Tabelas Criadas Automaticamente**
```sql
-- Eventos de câmeras
CREATE TABLE camera_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    camera_id TEXT NOT NULL,
    event_type TEXT NOT NULL,  -- 'motion', 'snapshot', 'recording'
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    confidence REAL,           -- Confiança da detecção (0.0-1.0)
    bbox_x INTEGER,            -- Bounding box do movimento
    bbox_y INTEGER,
    bbox_w INTEGER,
    bbox_h INTEGER,
    snapshot_path TEXT,        -- Caminho do snapshot
    processed BOOLEAN DEFAULT FALSE
);

-- Status das câmeras
CREATE TABLE camera_status (
    camera_id TEXT PRIMARY KEY,
    name TEXT,
    location TEXT,
    ip TEXT,
    status TEXT,               -- 'online', 'offline'
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    fps REAL,
    resolution TEXT,
    uptime_seconds INTEGER
);
```

### **Integração com Dashboard Flask**
```python
# Adicionar ao dashboard.py existente
@app.route('/api/cameras/events')
def api_camera_events():
    """API para eventos de câmeras no dashboard principal"""
    query = """
        SELECT camera_id, event_type, timestamp, confidence, snapshot_path
        FROM camera_events 
        WHERE timestamp >= datetime('now', '-24 hours')
        ORDER BY timestamp DESC 
        LIMIT 50
    """
    # ... código de consulta
```

## 🌐 Interface Web

### **Funcionalidades da Interface**
- **Dashboard principal** com todas as câmeras
- **Stream ao vivo** de cada câmera
- **Controle PTZ** para câmeras compatíveis
- **Captura de snapshots** manual
- **Histórico de eventos** com filtros
- **Status do sistema** em tempo real

### **URLs Disponíveis**
```bash
# Dashboard principal
http://192.168.1.102:8080/

# Visualização individual
http://192.168.1.102:8080/camera/CAM_ENTRADA

# APIs REST
http://192.168.1.102:8080/api/cameras
http://192.168.1.102:8080/api/camera/CAM_ENTRADA/snapshot
http://192.168.1.102:8080/api/camera/CAM_ENTRADA/events
```

## 📊 Monitoramento e Logs

### **Logs do Sistema**
```bash
# Ver logs em tempo real
journalctl -u homeguard-cameras -f

# Logs detalhados
tail -f ~/HomeGuard/raspberry_pi3/logs/camera_system.log

# Status do serviço
sudo systemctl status homeguard-cameras
```

### **Métricas de Performance**
```bash
# Uso de CPU/Memória
top -p $(pgrep -f camera_integration)

# Uso de disco (snapshots/gravações)
du -sh ~/HomeGuard/raspberry_pi3/snapshots/
du -sh ~/HomeGuard/raspberry_pi3/recordings/

# Velocidade da rede
iftop -i wlan0
```

## ⚙️ Configurações Avançadas

### **Detecção de Movimento Personalizada**
```json
{
  "motion_detection": {
    "threshold": 1000,           // Área mínima para movimento
    "min_confidence": 0.3,       // Confiança mínima
    "background_learning_rate": 0.01,
    "noise_reduction": true
  }
}
```

### **Zonas de Detecção**
```json
{
  "cameras": [
    {
      "id": "CAM_ENTRADA",
      "zones": [
        {
          "name": "Área de Entrada",
          "coordinates": [[100,100], [500,100], [500,400], [100,400]],
          "sensitivity": 0.7
        }
      ]
    }
  ]
}
```

### **Agendamento de Gravações**
```json
{
  "recording": {
    "enabled": true,
    "schedule": {
      "monday": [{"start": "18:00", "end": "06:00"}],
      "tuesday": [{"start": "18:00", "end": "06:00"}]
    },
    "trigger_events": ["motion", "manual"],
    "duration_seconds": 30
  }
}
```

## 🔒 Segurança

### **Autenticação**
```json
{
  "web_interface": {
    "auth_required": true,
    "username": "homeguard",
    "password": "homeguard123"
  }
}
```

### **Acesso Remoto via VPN**
```bash
# Configurar WireGuard (se ainda não tiver)
sudo ./setup_vpn_server.sh

# Gerar configuração para dispositivo móvel
./generate_wireguard_client.sh meu_celular

# Depois de conectar via VPN, acessar:
http://192.168.1.102:8080/
```

## 🚨 Troubleshooting

### **Problemas Comuns**

#### **Stream não aparece**
```bash
# Verificar conectividade RTSP
ffplay rtsp://admin:senha@IP_CAMERA:554/cam/realmonitor?channel=1&subtype=1

# Verificar se câmera suporta RTSP
curl -u admin:senha http://IP_CAMERA/cgi-bin/magicBox.cgi?action=getDeviceType

# Testar diferentes URLs de stream
# Para modelos diferentes, pode ser:
# /cam/realmonitor?channel=1&subtype=0  (principal)
# /live                                (alguns modelos)
# /videostream.cgi?user=admin&pwd=senha (modelos antigos)
```

#### **Detecção de movimento não funciona**
```bash
# Ajustar threshold no config
"motion_detection": {
    "threshold": 500,  // Reduzir para mais sensibilidade
    "min_confidence": 0.1
}

# Verificar logs
journalctl -u homeguard-cameras -f | grep motion
```

#### **PTZ não responde**
```bash
# Verificar se câmera suporta PTZ
curl -u admin:senha \
  "http://IP_CAMERA/cgi-bin/ptz.cgi?action=getCurrentProtocolCaps&channel=0"

# Testar comando PTZ manual
curl -u admin:senha \
  "http://IP_CAMERA/cgi-bin/ptz.cgi?action=start&channel=0&code=Up&arg1=5&arg2=5"
```

#### **Alta latência de stream**
```bash
# Usar stream secundário (menor qualidade)
"sub_stream": "cam/realmonitor?channel=1&subtype=1"

# Reduzir qualidade na câmera
# Interface web > Configurar > Vídeo > Stream Secundário
# Resolução: 640x480
# FPS: 10
# Bitrate: 512 Kbps
```

### **Otimização para Raspberry Pi**

#### **Performance**
```bash
# Aumentar split de memória GPU
sudo raspi-config
# Advanced Options > Memory Split > 128

# Overclock (cuidado com temperatura)
sudo raspi-config
# Advanced Options > Overclock > Medium

# Verificar temperatura
vcgencmd measure_temp
```

#### **Armazenamento**
```bash
# Configurar rotação automática de snapshots
# Adicionar ao crontab:
0 2 * * * find ~/HomeGuard/raspberry_pi3/snapshots -name "*.jpg" -mtime +7 -delete

# Usar cartão SD rápido (Classe 10, UHS-I)
# Ou USB SSD para melhor performance
```

## 📱 Apps Móveis Recomendados

### **Visualização Remota**
- **VLC for Mobile** - Stream RTSP direto
- **IP Cam Viewer** - Multiple câmeras
- **tinyCam Monitor** - Android com gravação
- **MQTTAnalyzer** - Controle via MQTT

### **Configuração no App**
```
# Após conectar VPN:
RTSP URL: rtsp://admin:senha@192.168.1.100:554/cam/realmonitor?channel=1&subtype=1
Web Interface: http://192.168.1.102:8080/
MQTT Broker: 192.168.1.102:1883
```

## 📈 Casos de Uso

### **1. Monitoramento Residencial**
- Câmeras nas entradas principais
- Detecção automática de movimento
- Alertas via MQTT para celular
- Gravação em eventos suspeitos

### **2. Simulação de Presença**
- Integração com sistema de áudio
- Ativação automática de luzes
- Padrões de movimento realistas
- Coordenação entre sensores e câmeras

### **3. Segurança Comercial**
- Múltiplas câmeras PTZ
- Gravação contínua
- Monitoramento remoto
- Integração com sistema de alarme

## 🔄 Atualizações e Manutenção

### **Backup de Configurações**
```bash
# Backup automático
tar -czf ~/camera_backup_$(date +%Y%m%d).tar.gz \
    ~/HomeGuard/raspberry_pi3/camera_config.json \
    ~/HomeGuard/raspberry_pi3/snapshots/ \
    ~/HomeGuard/db/homeguard.db

# Restaurar backup
tar -xzf camera_backup_YYYYMMDD.tar.gz -C /
```

### **Atualização do Sistema**
```bash
# Parar serviços
sudo systemctl stop homeguard-cameras

# Atualizar código
cd ~/HomeGuard
git pull origin main

# Reinstalar dependências se necessário
cd raspberry_pi3
source venv_camera/bin/activate
pip install -r requirements_camera.txt

# Reiniciar serviços
sudo systemctl start homeguard-cameras
```

---

## 📞 Suporte

Para problemas específicos:

1. **Verificar logs**: `journalctl -u homeguard-cameras -f`
2. **Testar conectividade**: `ping IP_CAMERA`
3. **Verificar RTSP**: `ffplay rtsp://...`
4. **Consultar documentação Intelbras** do modelo específico

Este sistema oferece **integração completa** das câmeras Intelbras com o HomeGuard, proporcionando monitoramento inteligente e controle unificado! 🎥🏠
