# HomeGuard Advanced Relay Controller

## 📋 Visão Geral

Esta pasta contém a versão avançada do controlador de relé HomeGuard, uma evolução significativa do `relay.ino` original com mensagens JSON, identificação de dispositivo e recursos avançados de monitoramento.

## 📁 Estrutura da Pasta

```
advanced_relay/
├── advanced_relay.ino              # Sketch principal do Arduino
├── advanced_relay_controller.py    # Script Python para controle e monitoramento
├── examples.py                     # Exemplos de uso do controlador Python
├── requirements.txt                # Dependências Python
├── README.md                       # Este arquivo (documentação completa)
├── COMPARISON.md                   # Comparação com versão original
└── test_advanced_relay.sh         # Script de teste automatizado
```

O `advanced_relay.ino` é uma versão aprimorada do controlador de relé original, incorporando mensagens JSON, identificação de dispositivo e recursos avançados de monitoramento.

## ✨ Principais Melhorias

### 🔄 **Mensagens JSON**
- Todas as mensagens MQTT agora usam formato JSON estruturado
- Facilita integração com sistemas Python, Node.js e plataformas IoT
- Mensagens legíveis para humanos e facilmente parseáveis

### 🆔 **Identificação de Dispositivo**
- ID único baseado no MAC address: `relay_xxxxxx`
- Localização configurável do dispositivo
- Informações detalhadas de status

### 💓 **Heartbeat e Monitoramento**
- Heartbeat automático configurável (padrão: 60s)
- Status detalhado com uptime, RSSI, IP
- Detecção de mudanças externas no relé

### 🎛️ **Comandos Avançados**
- Suporte a múltiplos formatos de comando
- Configuração remota de parâmetros
- LED de status opcional

## � Script Python para Controle

### Instalação das Dependências
```bash
cd advanced_relay
pip install -r requirements.txt
```

### Uso Básico do Script Python

#### Modo Interativo (Recomendado)
```bash
python advanced_relay_controller.py
```

O modo interativo oferece uma interface CLI completa com comandos:
- `on/off/toggle` - Controla o relé
- `status` - Solicita status do dispositivo
- `info` - Mostra informações detalhadas
- `history [n]` - Mostra últimos n eventos
- `location <name>` - Define localização
- `heartbeat on/off` - Controla heartbeat
- `led on/off` - Controla LED de status
- `monitor on/off` - Liga/desliga monitoramento
- `quit` - Sair

#### Comandos Rápidos
```bash
# Comando único
python advanced_relay_controller.py --command on
python advanced_relay_controller.py --command off
python advanced_relay_controller.py --command status

# Definir localização
python advanced_relay_controller.py --location Kitchen

# Apenas monitoramento
python advanced_relay_controller.py --monitor-only
```

#### Exemplos Práticos
```bash
# Executar exemplos interativos
python examples.py
```

### Funcionalidades do Script Python

#### 🎛️ **Controle Completo**
- Controle de relé (ON/OFF/TOGGLE)
- Configuração remota (localização, heartbeat, LED)
- Solicitação de status detalhado
- Reinicialização remota

#### 📊 **Monitoramento Avançado**
- Monitoramento em tempo real de eventos
- Histórico de eventos com timestamps
- Informações detalhadas do dispositivo
- Monitoramento de heartbeat

#### 🔧 **Interface Amigável**
- CLI interativo com comandos intuitivos
- Modo monitor-only para observação
- Execução de comandos únicos
- Exemplos práticos incluídos

#### 🚀 **Recursos Técnicos**
- Reconexão automática MQTT
- Parsing completo de mensagens JSON
- Threading para interface não-bloqueante
- Tratamento robusto de erros

## �🔌 Conexões de Hardware

```
ESP-01S Pinout:
├── GPIO0 (PIN 0) ──── Relay Module IN
├── GPIO2 (PIN 2) ──── Status LED (opcional)
├── 3.3V ──────────── Relay Module VCC
└── GND ───────────── Relay Module GND
```

## 📡 Tópicos MQTT

| Tópico | Descrição | Exemplo |
|--------|-----------|---------|
| `home/relay1/cmnd` | Comandos para o relé | `ON`, `OFF`, `STATUS` |
| `home/relay1/status` | Status geral do dispositivo | JSON com informações completas |
| `home/relay1/relay` | Eventos do relé | JSON com mudanças de estado |
| `home/relay1/heartbeat` | Heartbeat periódico | JSON com status online |
| `home/relay1/config` | Confirmações de configuração | Respostas a comandos config |

## 🎯 Comandos Disponíveis

### Controle Básico
```bash
# Ligar relé
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456

# Desligar relé  
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "OFF" -u homeguard -P pu2clr123456

# Alternar estado
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "TOGGLE" -u homeguard -P pu2clr123456

# Status do dispositivo
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "STATUS" -u homeguard -P pu2clr123456
```

### Configuração
```bash
# Definir localização
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "LOCATION_Kitchen" -u homeguard -P pu2clr123456

# Controlar heartbeat
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "HEARTBEAT_ON" -u homeguard -P pu2clr123456
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "HEARTBEAT_OFF" -u homeguard -P pu2clr123456

# Definir intervalo de heartbeat (em segundos)
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "HEARTBEAT_30" -u homeguard -P pu2clr123456

# Controlar LED de status
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "LED_ON" -u homeguard -P pu2clr123456
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "LED_OFF" -u homeguard -P pu2clr123456

# Reiniciar dispositivo
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "RESET" -u homeguard -P pu2clr123456
```

### Comandos JSON (Futuro)
```bash
# Comando JSON
mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m '{"relay":"ON","reason":"automation"}' -u homeguard -P pu2clr123456
```

## 📊 Exemplos de Mensagens JSON

### Status do Dispositivo
```json
{
  "device_id": "relay_a1b2c3",
  "location": "Kitchen",
  "mac": "AA:BB:CC:DD:EE:FF",
  "ip": "192.168.18.192",
  "relay_state": "ON",
  "last_change": "5s ago",
  "uptime": "3600s",
  "heartbeat_enabled": "true",
  "heartbeat_interval": "60s",
  "rssi": "-45dBm"
}
```

### Evento do Relé
```json
{
  "device_id": "relay_a1b2c3",
  "location": "Kitchen",
  "event": "RELAY_ON",
  "state": "ON",
  "timestamp": "123456789",
  "reason": "REMOTE_COMMAND",
  "rssi": "-45dBm"
}
```

### Heartbeat
```json
{
  "device_id": "relay_a1b2c3",
  "timestamp": "123456789",
  "status": "ONLINE",
  "location": "Kitchen",
  "relay_state": "ON",
  "uptime": "3600s",
  "rssi": "-45dBm"
}
```

## 🔍 Monitoramento

### Monitorar todos os tópicos
```bash
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/relay1/#" -v
```

### Monitorar apenas eventos do relé
```bash
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/relay1/relay" -v
```

### Monitorar heartbeat
```bash
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/relay1/heartbeat" -v
```

## 🆚 Comparação com Versão Original

| Recurso | Relay Original | Advanced Relay |
|---------|---------------|----------------|
| **Formato das Mensagens** | Texto simples | JSON estruturado |
| **Identificação** | Cliente fixo | ID único baseado em MAC |
| **Status** | Estado básico ON/OFF | Status completo com metadata |
| **Configuração** | Hardcoded | Configurável via MQTT |
| **Monitoramento** | Apenas estado | Heartbeat + eventos detalhados |
| **LED de Status** | Não | LED opcional configurável |
| **Localização** | Não | Configurável remotamente |
| **Debugging** | Limitado | Logs detalhados com timestamps |

## 🔧 Configuração

### Parâmetros Configuráveis
- **Localização**: Nome do local onde o dispositivo está instalado
- **Heartbeat**: Intervalo e habilitação do heartbeat
- **LED de Status**: Ativação do LED indicador
- **IP Fixo**: Mesmo IP da versão original (192.168.18.192)

### Compatibilidade
- Mantém compatibilidade com comandos básicos (`ON`, `OFF`)
- Adiciona novos recursos sem quebrar funcionalidade existente
- Mesmo hardware da versão original

## 🚀 Próximos Passos

1. **Teste o advanced_relay** em paralelo com a versão original
2. **Configure o Python monitor** para processar mensagens JSON
3. **Implemente automações** usando os dados estruturados
4. **Adicione mais dispositivos** usando o mesmo padrão JSON

## ⚠️ Notas Importantes

- O advanced_relay usa o mesmo IP (192.168.18.192) da versão original
- Para usar ambas as versões, altere o IP de uma delas
- O consumo de memória é ligeiramente maior devido ao JSON
- Todas as funcionalidades da versão original são mantidas
