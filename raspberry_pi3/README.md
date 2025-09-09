# HomeGuard Audio Presence System - Dual Raspberry Pi 3 Architecture

## 🏗️ Arquitetura

Sistema de simulação de presença por áudio distribuído em dois Raspberry Pi 3:
- **Raspberry Pi 3A (Térreo)**: Simulação do andar térreo
- **Raspberry Pi 3B (Primeiro Andar)**: Simulação do primeiro andar

## 📁 Estrutura de Diretórios

```
raspberry_pi3/
├── shared/                     # Código compartilhado
│   └── base_audio_simulator.py # Classe base comum
├── ground/                     # Térreo (Pi 3A)
│   ├── audio_ground.py        # Simulador específico do térreo
│   ├── ground_config.json     # Configuração do térreo
│   ├── start_ground_floor.sh  # Script de inicialização
│   └── audio_files/           # Arquivos de áudio do térreo
│       ├── dogs/
│       ├── doors/
│       ├── footsteps/
│       ├── tv_radio/
│       └── alerts/
├── first/                      # Primeiro Andar (Pi 3B)
│   ├── audio_first.py         # Simulador específico do 1º andar
│   ├── first_config.json      # Configuração do 1º andar
│   ├── start_first_floor.sh   # Script de inicialização
│   └── audio_files/           # Arquivos de áudio do 1º andar
│       ├── doors/
│       ├── footsteps/
│       ├── toilets/
│       ├── shower/
│       ├── bedroom/
│       └── alerts/
└── logs/                       # Logs compartilhados
```

## 🎵 Categorias de Som por Andar

### Térreo (Ground Floor)
- **dogs**: Sons de cães (entrada, quintal)
- **doors**: Portas (entrada, cozinha, garagem)
- **footsteps**: Passos (sala, cozinha, corredor)
- **tv_radio**: TV e rádio (sala de estar)
- **alerts**: Alertas de segurança

### Primeiro Andar (First Floor)
- **doors**: Portas dos quartos
- **footsteps**: Passos no corredor e quartos
- **toilets**: Sons de banheiro
- **shower**: Sons de chuveiro
- **bedroom**: Sons de quarto (cama, roupas)
- **alerts**: Alertas de segurança

## 🚀 Como Usar

### Instalação Inicial

1. **Clonar repositório em ambos os Pi3**:
```bash
git clone [repo-url] /home/pi/HomeGuard
cd /home/pi/HomeGuard/raspberry_pi3
```

2. **Instalar dependências**:
```bash
sudo apt update
sudo apt install python3-pip pulseaudio
pip3 install pygame paho-mqtt schedule
```

### Configuração por Andar

#### Térreo (Pi 3A)
```bash
cd ground/
# Editar configuração se necessário
nano ground_config.json
# Fazer script executável
chmod +x start_ground_floor.sh
# Executar
./start_ground_floor.sh
```

#### Primeiro Andar (Pi 3B)
```bash
cd first/
# Editar configuração se necessário
nano first_config.json
# Fazer script executável
chmod +x start_first_floor.sh
# Executar
./start_first_floor.sh
```

## 📡 Tópicos MQTT

### Térreo
- Comandos: `homeguard/audio/ground/command`
- Status: `homeguard/audio/ground/status`
- Eventos: `homeguard/audio/ground/events`
- Coordenação: `homeguard/audio/coordination`

### Primeiro Andar
- Comandos: `homeguard/audio/first/command`
- Status: `homeguard/audio/first/status`
- Eventos: `homeguard/audio/first/events`
- Coordenação: `homeguard/audio/coordination`

## ⚙️ Configuração de Sensores

### Resposta a Movimento

#### Térreo
- **Entrada**: Cães + passos
- **Sala**: TV/rádio + passos
- **Cozinha**: Passos + portas
- **Garagem**: Portas + passos
- **Quintal**: Cães

#### Primeiro Andar
- **Quarto Principal**: Quarto + passos + portas
- **Quartos**: Quarto + passos
- **Corredor**: Passos + portas
- **Banheiro**: Banheiro + passos
- **Banheiro Suíte**: Chuveiro + banheiro

### Resposta a Relés

#### Térreo
- **Luz Entrada**: Passos
- **Luz Sala**: TV/rádio
- **Luz Cozinha**: Passos
- **Luz Garagem**: Portas
- **Luz Quintal**: Cães

#### Primeiro Andar
- **Luz Quarto**: Quarto + passos
- **Luz Corredor**: Passos
- **Luz Banheiro**: Banheiro
- **Luz Suíte**: Quarto + portas

## 🤝 Sistema de Coordenação

Os dois Pi3 se coordenam via MQTT:
- **Probabilidade de resposta conjunta**: 80% (térreo) / 70% (primeiro andar)
- **Delay de coordenação**: 2-5 minutos
- **Tópico de coordenação**: `homeguard/audio/coordination`

## 🔧 Comandos MQTT de Controle

### Comandos Básicos
```json
{"command": "start"}          # Iniciar simulação
{"command": "stop"}           # Parar simulação
{"command": "pause"}          # Pausar
{"command": "resume"}         # Retomar
{"command": "status"}         # Status atual
```

### Comandos de Som
```json
{"command": "play", "category": "dogs"}        # Térreo
{"command": "play", "category": "bedroom"}     # Primeiro andar
{"command": "volume", "level": 0.8}            # Ajustar volume
```

### Comandos de Modo
```json
{"command": "mode", "value": "home"}     # Modo casa
{"command": "mode", "value": "away"}     # Modo ausente
{"command": "mode", "value": "sleep"}    # Modo dormir
```

## 📊 Logs e Monitoramento

- **Logs**: `raspberry_pi3/logs/`
- **Formato**: `[andar]_floor_YYYYMMDD_HHMMSS.log`
- **Rotação**: Diária automática

## 🔄 Manutenção

### Atualizar Sistema
```bash
cd /home/pi/HomeGuard
git pull
# Reiniciar serviços se necessário
```

### Backup de Configuração
```bash
cp ground/ground_config.json ground/ground_config.json.backup
cp first/first_config.json first/first_config.json.backup
```

### Verificar Status
```bash
# Via MQTT
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
    -t "homeguard/audio/ground/command" -m '{"command": "status"}'
    
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
    -t "homeguard/audio/first/command" -m '{"command": "status"}'
```

## 🆘 Troubleshooting

### Problemas Comuns

1. **Import Error**: Verificar PYTHONPATH nos scripts
2. **MQTT Connection**: Verificar credenciais e conectividade
3. **Audio Issues**: Verificar PulseAudio e permissões
4. **File Not Found**: Verificar estrutura de diretórios de áudio

### Debug Mode
Adicionar `"debug": true` nas configurações JSON para logs detalhados.

---

**Versão**: 2.0 (Dual Pi3 Architecture)  
**Última Atualização**: Janeiro 2024
