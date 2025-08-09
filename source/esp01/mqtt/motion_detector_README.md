# HomeGuard Motion Detector Module

Este sketch transforma o ESP-01S em um detector de movimento inteligente, baseado no código `mqtt.ino` que já está funcionando perfeitamente em seu ambiente.

## Características

- **Detecção de Movimento:** Usando sensor PIR para monitoramento de presença
- **Comunicação MQTT:** Integração completa com broker Mosquitto
- **Configuração Remota:** Ajuste de sensibilidade e timeout via MQTT
- **Identificação Única:** ID baseado no MAC address do dispositivo
- **Monitoramento em Tempo Real:** Status e eventos via MQTT
- **Heartbeat:** Verificação periódica de conectividade

## Hardware Necessário

### Componentes:
- 1x ESP-01S
- 1x Sensor PIR (HC-SR501 ou similar)
- 1x Fonte 3.3V estável
- Cabos de conexão

### Conexões:

```
ESP-01S          PIR Sensor
-------          ----------
3.3V      <----> VCC
GND       <----> GND
GPIO2     <----> OUT

Opcional (LED de status):
GPIO0     <----> LED (através de resistor 220Ω)
```

**⚠️ IMPORTANTE:** Use apenas 3.3V! Nunca 5V no ESP-01S.

## Configuração do Código

### IP e Rede (baseado no seu mqtt.ino funcionando):
```cpp
const char* ssid = "APRC";
const char* password = "Ap69Rc642023";
IPAddress local_IP(192, 168, 18, 193);  // IP diferente do relé
```

### Broker MQTT (mesmas configurações que funcionam):
```cpp
const char* mqtt_server = "192.168.18.6";
const char* mqtt_user = "homeguard";
const char* mqtt_pass = "pu2clr123456";
```

## Estrutura dos Tópicos MQTT

```
home/motion1/
├── cmnd        # Comandos para o dispositivo
├── status      # Status geral do dispositivo (JSON)
├── motion      # Eventos de movimento (JSON)
├── heartbeat   # Heartbeat do dispositivo (JSON)
└── config      # Confirmações de configuração
```

## Comandos MQTT Disponíveis

### Monitoramento Geral:
```bash
# Monitorar todos os eventos do detector
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/motion1/#" -v

# Monitorar apenas detecções de movimento
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/motion1/motion" -v
```

### Comandos de Controle:
```bash
# Obter status completo do dispositivo
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "STATUS" -u homeguard -P pu2clr123456

# Reiniciar o dispositivo
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "RESET" -u homeguard -P pu2clr123456

# Configurar localização
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "LOCATION_Kitchen" -u homeguard -P pu2clr123456
```

### Configuração de Sensibilidade:
```bash
# Alta sensibilidade (1 segundo de debounce)
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "SENSITIVITY_HIGH" -u homeguard -P pu2clr123456

# Sensibilidade normal (2 segundos de debounce) 
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "SENSITIVITY_NORMAL" -u homeguard -P pu2clr123456

# Baixa sensibilidade (5 segundos de debounce)
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "SENSITIVITY_LOW" -u homeguard -P pu2clr123456
```

### Configuração de Timeout:
```bash
# Definir timeout de movimento para 30 segundos
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "TIMEOUT_30" -u homeguard -P pu2clr123456

# Definir timeout de movimento para 60 segundos
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "TIMEOUT_60" -u homeguard -P pu2clr123456
```

### Controle de Heartbeat:
```bash
# Habilitar heartbeat
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "HEARTBEAT_ON" -u homeguard -P pu2clr123456

# Desabilitar heartbeat
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "HEARTBEAT_OFF" -u homeguard -P pu2clr123456
```

## Exemplos de Mensagens

### Status do Dispositivo:
```json
{
  "device_id": "motion_a1b2c3",
  "location": "Living Room",
  "mac": "AA:BB:CC:DD:EE:FF",
  "ip": "192.168.18.193",
  "motion": "CLEAR",
  "last_motion": "45s ago",
  "timeout": "30s",
  "sensitivity": "2s",
  "uptime": "3600s",
  "rssi": "-45dBm"
}
```

### Evento de Movimento Detectado:
```json
{
  "device_id": "motion_a1b2c3",
  "location": "Living Room",
  "event": "MOTION_DETECTED",
  "timestamp": "123456789",
  "rssi": "-45dBm"
}
```

### Evento de Movimento Limpo:
```json
{
  "device_id": "motion_a1b2c3",
  "location": "Living Room", 
  "event": "MOTION_CLEARED",
  "timestamp": "123456820",
  "duration": "31s"
}
```

### Heartbeat:
```json
{
  "device_id": "motion_a1b2c3",
  "timestamp": "123456789",
  "status": "ONLINE",
  "location": "Living Room",
  "rssi": "-45dBm"
}
```

## Configurações Padrão

| Parâmetro | Valor Padrão | Descrição |
|-----------|--------------|-----------|
| IP Address | 192.168.18.193 | IP fixo (diferente do relé) |
| Motion Timeout | 30 segundos | Tempo para limpar detecção |
| Debounce Delay | 2 segundos | Delay anti-ruído |
| Heartbeat Interval | 60 segundos | Intervalo do heartbeat |
| Location | "Living Room" | Localização configurável |

## Instalação e Teste

### 1. Programação:
```
1. Conecte GPIO0 ao GND
2. Faça upload do sketch motion_detector.ino
3. Desconecte GPIO0 do GND
4. Reinicie o ESP-01S
```

### 2. Verificação:
```bash
# Verifique se o dispositivo está online
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/motion1/status" -v

# Teste um comando
mosquitto_pub -h 192.168.18.6 -t home/motion1/cmnd -m "STATUS" -u homeguard -P pu2clr123456
```

### 3. Monitoramento:
```bash
# Monitore detecções de movimento em tempo real
mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/motion1/motion" -v
```

## Ajustes do Sensor PIR

### Configurações Físicas do HC-SR501:
- **Sensitivity (Sens):** Ajusta distância de detecção (3-7 metros)
- **Time Delay (Time):** Ajusta tempo de saída alta (5s-300s)
- **Trigger Mode:** 
  - H = Repeatable trigger (recomendado)
  - L = Non-repeatable trigger

### Recomendações:
- **Sensitivity:** Medio (posição central do potenciômetro)
- **Time Delay:** Mínimo (totalmente anti-horário)
- **Trigger Mode:** H (jumper na posição H)

*O timeout é controlado via software, não pelo sensor.*

## Troubleshooting

### Problemas Comuns:

1. **Sensor não detecta movimento:**
   - Verifique conexões (VCC, GND, OUT)
   - Aguarde 1-2 minutos para calibração inicial do PIR
   - Ajuste sensitivity no sensor fisicamente

2. **Muitos falsos positivos:**
   - Use comando `SENSITIVITY_LOW`
   - Verifique interferências (calor, luz solar)
   - Ajuste posição do sensor

3. **Dispositivo não aparece no MQTT:**
   - Verifique IP (deve ser diferente do relé: 192.168.18.193)
   - Teste conexão: `ping 192.168.18.193`
   - Verifique logs no Serial Monitor

4. **Detecção muito rápida:**
   - Ajuste timeout: `TIMEOUT_60` para 60 segundos
   - Use `SENSITIVITY_NORMAL` ou `SENSITIVITY_LOW`

### Debug via Serial:
```
115200 baud
Mensagens incluem:
- Status de conexão WiFi/MQTT
- Eventos de movimento detectados
- Confirmações de comandos recebidos
```

## Integração com Sistema Existente

### Script Python para Monitoramento:
```python
import paho.mqtt.client as mqtt
import json
from datetime import datetime

def on_message(client, userdata, msg):
    if "motion" in msg.topic:
        data = json.loads(msg.payload.decode())
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {data['location']}: {data['event']}")

client = mqtt.Client()
client.username_pw_set("homeguard", "pu2clr123456")
client.on_message = on_message
client.connect("192.168.18.6", 1883, 60)
client.subscribe("home/motion1/motion")
client.loop_forever()
```

### Integração com Home Assistant:
```yaml
# configuration.yaml
binary_sensor:
  - platform: mqtt
    name: "Living Room Motion"
    state_topic: "home/motion1/motion"
    payload_on: "MOTION_DETECTED"
    payload_off: "MOTION_CLEARED"
    value_template: "{{ value_json.event }}"
    device_class: motion
```

## Próximos Passos

1. **Teste o sensor PIR** separadamente antes da integração
2. **Configure a localização** adequada via comando MQTT
3. **Ajuste sensibilidade** conforme necessário
4. **Monitore por algumas horas** para validar funcionamento
5. **Integre com sistema de automação** existente

O código está baseado exatamente no seu `mqtt.ino` funcionando, apenas adaptado para detecção de movimento em vez de controle de relé.
