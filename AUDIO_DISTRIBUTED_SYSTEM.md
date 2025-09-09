# 🏠 HomeGuard - Sistema de Áudio Distribuído

Sistema completo de simulação de presença por áudio distribuído entre dois andares da casa, usando Raspberry Pi 3 (térreo) e Raspberry Pi 2 (primeiro andar).

## 🏗️ **Arquitetura do Sistema**

```
🏠 Casa HomeGuard - Sistema Distribuído
├── 📶 MQTT Broker (192.168.1.102:1883)
├── 
├── 🏠 TÉRREO (Raspberry Pi 3)
│   ├── 📁 raspberry_pi3/
│   ├── 🎵 Audio: Sala, cozinha, entrada, varanda
│   ├── 📡 Tópicos: home/audio/ground/*
│   ├── ⏰ Horários: 07:00, 19:00, 22:30
│   └── 🔊 Sons: Cachorro, passos, portas, TV, banheiro
│
├── 🏠 PRIMEIRO ANDAR (Raspberry Pi 2)  
│   ├── 📁 raspberry_pi2/
│   ├── 🎵 Audio: Quartos, banheiros, corredor
│   ├── 📡 Tópicos: home/audio/first/*
│   ├── ⏰ Horários: 07:15, 14:30, 21:30, 23:45
│   └── 🔊 Sons: Passos, chuveiro, TV quartos, portas
│
└── 🎛️ COORDENAÇÃO
    ├── 📡 Tópico: home/audio/coordination
    ├── ⚡ Delay: 2-5 minutos entre andares
    ├── 🎯 Probabilidade: 80% resposta
    └── 🤖 Controller: audio_coordination_controller.py
```

## 📡 **Tópicos MQTT por Andar**

### **🏠 Térreo (Ground Floor) - Raspberry Pi 3:**
```bash
home/audio/ground/cmnd        # Comandos
home/audio/ground/status      # Status do sistema  
home/audio/ground/events      # Eventos de áudio
home/audio/ground/heartbeat   # Heartbeat
home/audio/ground/control     # Controle direto
```

### **🏠 Primeiro Andar (First Floor) - Raspberry Pi 2:**
```bash
home/audio/first/cmnd         # Comandos
home/audio/first/status       # Status do sistema
home/audio/first/events       # Eventos de áudio  
home/audio/first/heartbeat    # Heartbeat
home/audio/first/control      # Controle direto
```

### **🤝 Coordenação entre Andares:**
```bash
home/audio/coordination       # Coordenação automática
home/audio/controller         # Status do controlador
homeguard/motion/+/detected        # Sensores movimento (global)
homeguard/relay/+/status           # Estados dos relays (global)
homeguard/emergency/+              # Emergências (global)
```

## ⚙️ **Setup Completo do Sistema**

### **1. Raspberry Pi 3 (Térreo):**
```bash
cd raspberry_pi3/
chmod +x setup_audio_simulator.sh
./setup_audio_simulator.sh
```

### **2. Raspberry Pi 2 (Primeiro Andar):**
```bash
cd raspberry_pi2/
chmod +x setup_audio_simulator.sh  
./setup_audio_simulator.sh
```

### **3. Teste de Integração:**
```bash
python3 integration_test.py
```

## 🎵 **Categorias de Som por Andar**

### **🏠 Térreo (Ground Floor):**
- **🐕 dogs:** Latidos no quintal/sala
- **🚶 footsteps:** Passos na sala/cozinha/entrada
- **🚽 toilets:** Banheiro social/lavabo
- **📺 tv_radio:** TV da sala/cozinha
- **🚪 doors:** Porta principal/varanda
- **🏠 background:** Sons ambiente casa
- **🚨 alerts:** Alertas térreo

### **🏠 Primeiro Andar (First Floor):**
- **🚶 footsteps:** Passos quartos/corredor
- **🚪 doors:** Portas quartos/banheiros  
- **🚿 shower:** Chuveiro/água
- **🚽 toilets:** Banheiros dos quartos
- **📺 tv_radio:** TVs dos quartos
- **🛏️ bedroom:** Sons específicos quartos
- **🚨 alerts:** Alertas primeiro andar
- **🐕 dogs:** Latidos upstairs (se houver)

## ⏰ **Rotinas Coordenadas**

### **Manhã (Morning Routine):**
```
07:00 - Térreo inicia (banheiro, passos, portas)
07:15 - Primeiro andar responde (chuveiro, passos, portas)
```

### **Tarde (Afternoon):**
```
14:30 - Primeiro andar (TV quartos, descanso)
14:35 - Térreo pode responder (TV sala, movimento leve)
```

### **Noite (Evening Routine):**
```
19:00 - Térreo inicia (TV, portas, movimento)
21:30 - Primeiro andar intensifica (TV quartos, chuveiro)
22:30 - Térreo reduz atividade  
23:45 - Primeiro andar (banheiro noturno)
```

## 🎮 **Comandos de Controle**

### **Comandos Individuais por Andar:**
```bash
# Térreo
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/ground/cmnd -m "DOGS"

# Primeiro Andar  
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/first/cmnd -m "SHOWER"
```

### **Comandos JSON Avançados:**
```bash
# Rotina coordenada
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/ground/cmnd \
  -m '{"action":"ROUTINE","routine":"morning_routine"}'

# Modo da casa inteira
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/coordination \
  -m '{"action":"MODE","mode":"away","target":"all"}'
```

### **Controlador Interativo:**
```bash
cd raspberry_pi2/
python3 audio_coordination_controller.py

# Console interativo:
HomeGuard> status                    # Status do sistema
HomeGuard> ground FOOTSTEPS          # Comando para térreo
HomeGuard> first SHOWER              # Comando para primeiro andar  
HomeGuard> all STOP                  # Parar todos os andares
HomeGuard> mode away                 # Modo away para toda casa
HomeGuard> emergency security_breach # Alerta de emergência
```

## 🔍 **Monitoramento do Sistema**

### **Status em Tempo Real:**
```bash
# Status térreo
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/ground/status

# Status primeiro andar
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/first/status

# Eventos de coordenação
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/coordination
```

### **Logs dos Serviços:**
```bash
# Térreo (se instalado como serviço)
sudo journalctl -u homeguard-audio-ground -f

# Primeiro andar (se instalado como serviço)
sudo journalctl -u homeguard-audio-first -f
```

## 🚨 **Sistema de Emergência**

### **Tipos de Emergência:**
- **security_breach:** Invasão detectada
- **fire_alarm:** Alarme de incêndio
- **medical_emergency:** Emergência médica
- **intrusion_detected:** Intrusão confirmada

### **Resposta Coordenada:**
```bash
# Emergência dispara em ambos os andares simultaneamente
# Volume máximo em todos os dispositivos
# Sons contínuos até cancelamento manual

# Cancelar emergência
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/ground/cmnd -m "STOP"
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/first/cmnd -m "STOP"
```

## 🎯 **Integração com Sensores**

### **Resposta a Movimento:**
```bash
# Movimento no térreo → resposta térreo imediata
# Movimento primeiro andar → resposta primeiro andar imediata  
# Coordenação cruzada com delay 2-5 minutos

# Exemplo: Movimento na sala
homeguard/motion/living_room/detected → 
  → home/audio/ground/* (imediato)
  → home/audio/first/* (delay 3min, 80% chance)
```

### **Resposta a Relays:**
```bash
# Luz acesa → simula pessoa no ambiente
# Relay específico por localização

# Exemplo: Luz do quarto
homeguard/relay/bedroom_light/status = "ON" →
  → home/audio/first/* (sons de quarto)
  → home/audio/ground/* (delay, pessoa descendo)
```

## 📊 **Performance e Estatísticas**

### **Latências Esperadas:**
- **Comando → Resposta:** < 2 segundos
- **Coordenação entre andares:** 2-5 minutos  
- **Movimento → Som:** 1-3 segundos
- **Emergência → Resposta:** < 1 segundo

### **Consumo de Recursos:**
```
Por Raspberry Pi:
- CPU: < 5% (reprodução)
- RAM: < 50MB
- Armazenamento: 100MB-1GB (arquivos de áudio)
- Rede: < 1MB/dia (MQTT)
```

### **Confiabilidade:**
- **Uptime esperado:** > 99%
- **Reconexão automática:** MQTT + WiFi
- **Heartbeat:** A cada 5 minutos
- **Auto-restart:** Em caso de falha

## 🛠️ **Manutenção**

### **Verificações Diárias:**
```bash
# Status dos sistemas
python3 integration_test.py

# Conectividade MQTT
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/+/heartbeat -C 2
```

### **Backup dos Arquivos:**
```bash
# Configurações
cp raspberry_pi3/audio_config.json backup/
cp raspberry_pi2/audio_config.json backup/

# Arquivos de áudio (se personalizados)
tar -czf audio_backup_$(date +%Y%m%d).tar.gz \
  raspberry_pi3/audio_files/ raspberry_pi2/audio_files/
```

### **Update do Sistema:**
```bash
# Atualizar ambos os sistemas
cd raspberry_pi3 && git pull && sudo systemctl restart homeguard-audio-ground
cd raspberry_pi2 && git pull && sudo systemctl restart homeguard-audio-first
```

## 🚀 **Início Rápido**

### **Setup Completo (5 minutos):**
```bash
# 1. Clone o repositório (se ainda não tiver)
git clone https://github.com/pu2clr/HomeGuard.git
cd HomeGuard

# 2. Setup térreo (Raspberry Pi 3)
cd raspberry_pi3
./setup_audio_simulator.sh
python3 audio_presence_simulator.py &

# 3. Setup primeiro andar (Raspberry Pi 2) 
cd ../raspberry_pi2
./setup_audio_simulator.sh  
python3 audio_presence_simulator.py &

# 4. Teste integração
cd ..
python3 integration_test.py

# 5. Controller interativo
cd raspberry_pi2
python3 audio_coordination_controller.py
```

### **Teste Rápido:**
```bash
# Comando simples
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/ground/cmnd -m "FOOTSTEPS"

# Status dos sistemas
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t home/audio/+/status -C 2
```

## 🎉 **Resultado Final**

Com este sistema, você terá:
- ✅ **Simulação realística** de presença em toda a casa
- ✅ **Coordenação inteligente** entre andares  
- ✅ **Respostas automáticas** a sensores e eventos
- ✅ **Controle remoto completo** via MQTT
- ✅ **Integração total** com sistema HomeGuard
- ✅ **Monitoramento profissional** 24/7
- ✅ **Escalabilidade** para mais dispositivos

**🏠 Sua casa ficará "viva" com atividade realística distribuída pelos andares!** 🎵
