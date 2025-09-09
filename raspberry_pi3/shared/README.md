# HomeGuard Audio Presence Simulator - Raspberry Pi 3

## 🎵 Visão Geral

Este sistema transforma um Raspberry Pi 3 em uma **central de áudio inteligente** que simula presença humana em casa através de sons realistas como latidos de cachorro, passos, descargas de vaso sanitário, TV/rádio e outros ruídos domésticos.

## 🎯 Funcionalidades Principais

### 🏠 **Simulação de Presença**
- **Latidos de cachorro** para alertas de segurança
- **Passos dentro de casa** em resposta a movimento
- **Sons de banheiro** (descarga, torneira) em rotinas
- **TV/Rádio** como ruído de fundo
- **Portas abrindo/fechando** para simular entrada/saída
- **Ruídos gerais** para ambiente vivido

### 🤖 **Integração Inteligente**
- **Integração MQTT** com sistema HomeGuard
- **Resposta automática** a sensores de movimento
- **Rotinas programadas** (manhã, tarde, noite)
- **Modos de operação** (casa, fora, noite, férias)
- **Controle remoto** via MQTT

### ⏰ **Automação por Horário**
- **Rotina matinal**: Banheiro → Passos → Portas
- **Rotina noturna**: Portas → Passos → TV
- **Atividades aleatórias** durante o dia
- **Programação personalizável**

## 📁 Estrutura de Arquivos

```
raspberry_pi/
├── audio_presence_simulator.py  # Script principal de áudio
├── audio_config.json            # Configuração de áudio
├── requirements.txt             # Dependências Python
├── setup_audio_simulator.sh     # Script de instalação de áudio
├── setup_vpn_server.sh         # Script de instalação VPN/acesso remoto
├── integration_test.py         # Teste de integração do sistema
├── README.md                   # Este arquivo
├── MOBILE_APPS_GUIDE.md        # Guia de apps para celular/desktop
└── audio_files/                # Arquivos de áudio
    ├── dogs/                   # Latidos de cachorro
    ├── footsteps/              # Passos
    ├── toilets/                # Banheiro
    ├── tv_radio/               # TV/Rádio
    ├── doors/                  # Portas
    ├── background/             # Ruído de fundo
    └── alerts/                 # Alertas
```

## 🚀 Instalação Rápida

### 1. **Preparar Raspberry Pi 3**
```bash
# No Raspberry Pi
git clone <repo_url>
cd HomeGuard/raspberry_pi3

# Executar script de instalação
sudo ./setup_audio_simulator.sh
```

### 2. **Adicionar Arquivos de Áudio**
```bash
# Adicione seus arquivos de áudio nas pastas correspondentes
cp seus_latidos.mp3 audio_files/dogs/
cp seus_passos.wav audio_files/footsteps/
# etc...
```

### 3. **Testar Sistema**
```bash
./test_audio_system.sh
```

### 4. **Iniciar Serviço Automaticamente**

#### Opção 1: Usando cron (@reboot)
Edite o crontab do usuário `homeguard`:
```bash
crontab -e
```
Adicione a linha abaixo ao final do arquivo:
```bash
@reboot cd /home/homeguard/HomeGuard/raspberry_pi3 && source homeguard-audio-env/bin/activate && python audio_presence_simulator.py
```
Assim, o serviço de áudio será iniciado automaticamente a cada boot.

#### Opção 2: Usando systemd user service
Crie o arquivo `~/.config/systemd/user/homeguard-audio.service` com o conteúdo:
```ini
[Unit]
Description=HomeGuard Audio Presence Simulator

[Service]
Type=simple
WorkingDirectory=/home/homeguard/HomeGuard/raspberry_pi3
Environment="PATH=/home/homeguard/HomeGuard/raspberry_pi3/homeguard-audio-env/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="SDL_AUDIODRIVER=alsa"
ExecStart=/home/homeguard/HomeGuard/raspberry_pi3/homeguard-audio-env/bin/python audio_presence_simulator.py
Restart=always

[Install]
WantedBy=default.target
```
Ative e inicie o serviço:
```bash
systemctl --user daemon-reload
systemctl --user enable homeguard-audio
systemctl --user start homeguard-audio
```
Para que serviços de usuário iniciem automaticamente no boot, execute:
```bash
loginctl enable-linger homeguard
```

## 🔒 **Acesso Remoto via VPN**

### **Instalação do Servidor VPN (WireGuard)**
```bash
# Instalar e configurar servidor VPN
sudo ./setup_vpn_server.sh

# Gerar cliente para seu dispositivo
./generate_wireguard_client.sh seu_celular

# Verificar status do VPN
./wireguard_status.sh
```

### **Configuração do Router**
```bash
# Configurar redirecionamento de porta no seu roteador:
# Porta: 51820 UDP → IP do Raspberry Pi
```

### **Apps Recomendados para Acesso Remoto**

#### **📱 iOS/Android:**
- **WireGuard** (VPN client - gratuito)
- **MQTTAnalyzer** (iOS) ou **MQTT Dash** (Android)
- **IoT MQTT Panel** (Dashboard customizável)

#### **💻 macOS/Windows:**
- **WireGuard** (VPN client oficial)
- **MQTT Explorer** (cliente desktop completo)

### **Configuração MQTT Remota**
```bash
# Após conectar na VPN, use:
# Host: 192.168.18.198 (IP do Raspberry Pi)
# Port: 1883
# User: homeguard
# Pass: pu2clr123456
```

Para guia completo de apps: `cat MOBILE_APPS_GUIDE.md`

## 🎛️ Controle via MQTT

### **Comandos Básicos**
```bash
# Broker MQTT: 192.168.18.198
# Tópico: home/audio/cmnd

# Latidos de cachorro
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "DOGS" -u homeguard -P pu2clr123456
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "DOGS" -u homeguard -P pu2clr123456

# Passos
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "FOOTSTEPS" -u homeguard -P pu2clr123456

# Banheiro
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "TOILET" -u homeguard -P pu2clr123456


mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "FOOTSTEPS" -u homeguard -P pu2clr123456


# TV de fundo
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "TV" -u homeguard -P pu2clr123456

# Rotina matinal
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "MORNING" -u homeguard -P pu2clr123456


# Alerts

 mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "ALERT" -u homeguard -P pu2clr123456


```

### **Modos de Operação**
```bash
# Modo Casa (resposta baixa a movimento)
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "MODE_HOME" -u homeguard -P pu2clr123456

# Modo Fora (resposta alta a movimento)
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "MODE_AWAY" -u homeguard -P pu2clr123456

# Modo Noite (volume reduzido)
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "MODE_NIGHT" -u homeguard -P pu2clr123456

# Modo Férias (atividade máxima)
mosquitto_pub -h 192.168.18.198 -t home/audio/ground/cmnd -m "MODE_VACATION" -u homeguard -P pu2clr123456
```

## 📊 Integração com HomeGuard

### **Resposta Automática a Sensores**

O sistema monitora automaticamente:

- **Sensores de movimento**: `home/+/motion`
- **Relés (luzes)**: `home/+/relay`
- **Outros dispositivos**: Configurável

```json
// Quando detecta movimento
{
  "device_id": "motion_abc123",
  "event": "MOTION_DETECTED",
  "location": "Living Room"
}

// Sistema responde com som apropriado baseado no modo:
// - AWAY: Latidos + Passos (simula chegada)
// - HOME: Passos ocasionais (30% chance)
// - NIGHT: Resposta reduzida
```

## ⚙️ Configuração

### **audio_config.json**
```json
{
    "mqtt_broker": "192.168.18.198",
    "location": "Living Room",
    "default_mode": "home",
    "motion_triggered": true,
    "schedules": {
        "morning_routine": {
            "time": "07:30",
            "sounds": ["toilets", "footsteps", "doors"]
        },
        "evening_routine": {
            "time": "19:00",
            "sounds": ["doors", "footsteps", "tv_radio"]
        }
    },
    "volume_levels": {
        "dogs": 0.8,
        "footsteps": 0.6,
        "toilets": 0.7,
        "tv_radio": 0.4
    }
}
```

## 🔧 Hardware Recomendado

### **Raspberry Pi 3 Setup**
- **Raspberry Pi 3B/3B+**
- **MicroSD 16GB+** (Classe 10)
- **Fonte 5V 2.5A**
- **Caixa de som** (3.5mm jack, HDMI, ou USB)

### **Conectores de Áudio**
```
Raspberry Pi 3:
├── 3.5mm Jack ──── Caixas de som pequenas
├── HDMI ────────── TV/Monitor com som
├── USB ─────────── Caixas USB (melhor qualidade)
└── GPIO ────────── Amplificadores externos
```

## 📈 Cenários de Uso

### **🏠 Casa Ocupada (MODE_HOME)**
- Resposta baixa a movimento (30%)
- Rotinas normais
- Volume moderado
- Atividades aleatórias desabilitadas

### **✈️ Casa Vazia (MODE_AWAY)**  
- Resposta alta a movimento (80%)
- Simula chegada em casa
- Atividades aleatórias habilitadas
- Ruído de fundo ligado

### **🌙 Período Noturno (MODE_NIGHT)**
- Volume reduzido (50%)
- Resposta moderada (50%)
- Apenas sons suaves

### **🏖️ Férias (MODE_VACATION)**
- Simulação máxima
- Rotinas enhanced
- Resposta 90% a movimento
- Atividade contínua

## 📋 Monitoramento

### **Logs do Sistema**
```bash
# Ver logs em tempo real
sudo journalctl -u homeguard-audio -f

# Status do serviço
sudo systemctl status homeguard-audio

# Monitorar MQTT
mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "home/audio/#" -v
```

### **Tópicos MQTT**
- `home/audio/status` - Status do sistema
- `home/audio/events` - Eventos de áudio
- `home/audio/heartbeat` - Heartbeat (60s)
- `home/audio/cmnd` - Comandos

## 🎵 Obtendo Arquivos de Áudio

### **Fontes Gratuitas**
- **Freesound.org** - Biblioteca gratuita
- **Zapsplat.com** - Sons profissionais
- **BBC Sound Effects** - Efeitos da BBC

### **Tipos de Arquivo Suportados**
- MP3, WAV, OGG
- Qualidade recomendada: 44.1kHz, 16-bit
- Duração ideal: 1-10 segundos

### **Exemplos de Sons Necessários**

#### 🐕 **Dogs (3-5 arquivos)**
- Latido de alerta
- Latido de proteção
- Rosnado baixo

#### 👣 **Footsteps (5-10 arquivos)**
- Passos no piso de madeira
- Passos no carpete
- Passos subindo escada

#### 🚽 **Toilets (3-5 arquivos)**
- Descarga completa
- Torneira abrindo/fechando
- Porta do banheiro

#### 📺 **TV/Radio (2-3 longos)**
- Murmúrio de TV distante
- Rádio com música baixa
- Conversa de fundo

## 🔒 Segurança

### **Autenticação MQTT**
- Usuário/senha configuráveis
- Tópicos protegidos
- Validação de comandos

### **Proteção do Sistema**
- Serviço systemd com restart automático
- Logs rotativos
- Controle de volume

## 🚨 Troubleshooting

### **Áudio Não Funciona**
```bash
# Testar saída de áudio
speaker-test -t sine -f 1000 -l 2

# Verificar dispositivos
aplay -l

# Configurar saída
sudo raspi-config # Advanced Options > Audio
```

### **MQTT Não Conecta**
```bash
# Testar conexão MQTT
mosquitto_pub -h 192.168.18.198 -t test -m "hello" -u homeguard -P pu2clr123456
```

### **Serviço Não Inicia**
```bash
# Verificar logs
sudo journalctl -u homeguard-audio --no-pager

# Verificar permissões
ls -la audio_presence_simulator.py
```

Este sistema oferece uma **solução completa e profissional** para simular presença em casa usando áudio inteligente integrado ao sistema HomeGuard! 🎵🏠
