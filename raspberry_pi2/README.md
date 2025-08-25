# 🏠 HomeGuard Audio System - First Floor (Raspberry Pi 2)

Sistema de simulação de presença por áudio para o **primeiro andar** da casa, coordenado com o sistema do térreo.

## 🎯 **Visão Geral**

Este sistema simula presença humana no primeiro andar da casa através de:
- 🚶 Sons de passos em corredores e quartos
- 🚪 Portas de quartos e banheiros abrindo/fechando
- 🚿 Chuveiro e sons de banheiro
- 📺 TV e rádio nos quartos
- 🐕 Latidos de cães (quando apropriado)
- 🔔 Alertas de segurança

## 📡 **Tópicos MQTT - Primeiro Andar**

### **Controle e Status:**
- `homeguard/audio/first/cmnd` - Comandos diretos
- `homeguard/audio/first/status` - Status do sistema
- `homeguard/audio/first/events` - Eventos de áudio
- `homeguard/audio/first/heartbeat` - Heartbeat do sistema

### **Triggers:**
- `homeguard/motion/+/detected` - Detectores de movimento
- `homeguard/relay/+/status` - Estado dos relays
- `homeguard/emergency/+` - Emergências

### **Coordenação:**
- `homeguard/audio/coordination` - Coordenação entre andares

## 🏗️ **Arquitetura do Sistema**

```
Casa HomeGuard - Sistema de Áudio Distribuído
├── 🏠 Térreo (Raspberry Pi 3)
│   ├── raspberry_pi3/
│   ├── Tópicos: homeguard/audio/ground/*
│   └── Sons: Sala, cozinha, entrada
│
└── 🏠 Primeiro Andar (Raspberry Pi 2)
    ├── raspberry_pi2/
    ├── Tópicos: homeguard/audio/first/*
    └── Sons: Quartos, banheiros, corredor
```

## ⚙️ **Instalação**

### **1. Setup Automático:**
```bash
cd raspberry_pi2
chmod +x setup_audio_simulator.sh
./setup_audio_simulator.sh
```

### **2. Setup Manual:**
```bash
# Instalar dependências Python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configurar áudio (Raspberry Pi)
sudo apt install alsa-utils pulseaudio
amixer set Master 80%

# Testar sistema
python3 test_first_floor_audio.py
```

## 🎵 **Arquivos de Áudio**

### **Estrutura de Diretórios:**
```
audio_files/
├── footsteps/     # Passos em quartos/corredores
├── doors/         # Portas de quartos/banheiros
├── shower/        # Chuveiro e água
├── toilets/       # Sons de banheiro
├── tv_radio/      # TV/rádio dos quartos
├── bedroom/       # Sons específicos de quarto
├── dogs/          # Latidos (primeiro andar)
└── alerts/        # Alertas de segurança
```

### **Formatos Suportados:**
- WAV (recomendado)
- MP3
- M4A
- OGG

## 🎮 **Comandos MQTT**

### **Comandos Simples:**
```bash
# Reproduzir categoria específica
mosquitto_pub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/cmnd -m "FOOTSTEPS"

mosquitto_pub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/cmnd -m "SHOWER"
```

### **Comandos JSON:**
```bash
# Reproduzir com volume específico
mosquitto_pub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/cmnd \
  -m '{"action":"PLAY","category":"doors","volume":0.5}'

# Iniciar rotina
mosquitto_pub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/cmnd \
  -m '{"action":"ROUTINE","routine":"morning_routine"}'

# Mudar modo
mosquitto_pub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/cmnd \
  -m '{"action":"MODE","mode":"away"}'
```

## ⏰ **Rotinas Programadas**

### **Rotinas Padrão (Primeiro Andar):**
- **07:15** - Rotina matinal (chuveiro, passos, portas)
- **14:30** - Descanso da tarde (TV, passos leves)
- **21:30** - Atividades noturnas (TV, passos, portas)
- **23:45** - Ida ao banheiro (banheiro, passos)

### **Coordenação com Térreo:**
- Atraso de 2-5 minutos após atividade do térreo
- Respostas baseadas em probabilidade (80%)
- Volume coordenado entre andares

## 🔍 **Monitoramento**

### **Status do Sistema:**
```bash
# Verificar status
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/status

# Monitorar eventos
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/events

# Heartbeat
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/heartbeat
```

### **Logs do Sistema:**
```bash
# Se instalado como serviço
sudo journalctl -u homeguard-audio-first -f

# Execução manual
python3 audio_presence_simulator.py
```

## 🎯 **Respostas a Sensores**

### **Movimento nos Quartos:**
- **Quarto principal:** passos + portas + TV
- **Quartos secundários:** passos + TV
- **Corredor:** passos + portas
- **Banheiros:** banheiro + chuveiro

### **Ativação de Relays:**
- **Luz do quarto:** passos + portas
- **Luz do corredor:** passos
- **Luz do banheiro:** banheiro + passos

## 🚨 **Emergências**

### **Tipos de Emergência:**
- **security_breach:** alertas + latidos
- **fire_alarm:** alertas máximo volume
- **medical_emergency:** alertas contínuos
- **intrusion_detected:** alertas + latidos

### **Coordenação de Emergência:**
```python
# Ambos os andares respondem simultaneamente
# Volume máximo em todos os dispositivos
# Sons de alerta contínuos até cancelamento
```

## 🔧 **Configuração Avançada**

### **Arquivo `audio_config.json`:**
```json
{
  "floor": "first",
  "location": "First Floor",
  "coordinated_mode": true,
  "volume": 0.7,
  "motion_triggered": true,
  
  "coordination_settings": {
    "delay_min": 120,
    "delay_max": 300,
    "response_probability": 0.8
  }
}
```

### **Perfis por Período:**
- **Manhã (06:00-09:00):** chuveiro, passos, portas
- **Dia (09:00-17:00):** TV baixo, passos ocasionais
- **Tarde (17:00-22:00):** TV, passos, portas, chuveiro
- **Noite (22:00-06:00):** banheiro, passos leves

## 🤝 **Integração com Sistema**

### **Componentes Integrados:**
- ✅ Sensores de movimento PIR
- ✅ Controle de relays
- ✅ Sistema MQTT central
- ✅ Interface web Flask
- ✅ Apps mobile via VPN

### **Comunicação entre Andares:**
```python
# Térreo → Primeiro Andar
homeguard/audio/coordination → {
  "action": "ROUTINE_START",
  "routine_type": "morning_routine", 
  "floor": "ground"
}

# Primeiro Andar → Resposta atrasada
# Delay: 2-5 minutos
# Probabilidade: 80%
```

## 🛠️ **Manutenção**

### **Verificações Regulares:**
```bash
# Status do serviço
sudo systemctl status homeguard-audio-first

# Espaço em disco (arquivos de áudio)
du -sh audio_files/

# Conectividade MQTT
python3 -c "import paho.mqtt.client as mqtt; 
client = mqtt.Client(); 
client.connect('192.168.18.6', 1883, 60); 
print('✅ MQTT OK')"
```

### **Backup dos Arquivos:**
```bash
# Backup configuração
cp audio_config.json audio_config.backup.json

# Backup arquivos de áudio
tar -czf audio_backup_$(date +%Y%m%d).tar.gz audio_files/
```

## 📊 **Estatísticas**

### **Performance Esperada:**
- **Latência MQTT:** < 100ms
- **Resposta a movimento:** 1-3 segundos
- **Coordenação entre andares:** 2-5 minutos
- **Uso de CPU:** < 5% (reprodução)
- **Uso de RAM:** < 50MB

### **Consumo de Dados:**
- **MQTT heartbeat:** ~500 bytes/5min
- **Status updates:** ~1KB cada
- **Event logs:** ~2KB cada
- **Total mensal:** < 10MB

## 🏆 **Resultados**

### **Simulação Realística:**
- ✅ Atividade distribuída pelos andares
- ✅ Coordenação temporal natural
- ✅ Respostas contextuais por ambiente
- ✅ Variação de horários e intensidade

### **Segurança Aprimorada:**
- ✅ Simulação de presença 24/7
- ✅ Respostas automáticas a eventos
- ✅ Alertas de emergência coordenados
- ✅ Monitoramento remoto completo

---

## 🚀 **Início Rápido**

```bash
# 1. Setup
./setup_audio_simulator.sh

# 2. Adicionar arquivos de áudio
cp seus_audios/* audio_files/categoria/

# 3. Iniciar sistema
python3 audio_presence_simulator.py

# 4. Testar comando
mosquitto_pub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
  -t homeguard/audio/first/cmnd -m "FOOTSTEPS"
```

**🎉 Sistema do primeiro andar configurado e coordenado com o térreo!** 🏠
