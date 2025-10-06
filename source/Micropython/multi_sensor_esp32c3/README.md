# MicroPython Multi-Sensor Monitor para ESP32-C3

Script MicroPython integrado para ESP32-C3 que combina:
- **Sensor de movimento PIR/IR**
- **Controle de relé via MQTT**
- **Monitoramento de temperatura/umidade (DHT11/DHT22)**

## 🔧 Hardware Necessário

- **ESP32-C3 Super Mini**
- **Sensor PIR/IR** (módulo padrão de movimento)
- **DHT11 ou DHT22** (sensor de temperatura/umidade)
- **Módulo relé 3.3V**
- **Resistor 10kΩ** (pull-up para DHT)
- **LED** (opcional, para status)

## 📐 Conexões do Hardware

```
ESP32-C3 Pin    Sensor/Módulo
-----------     -------------
GPIO0      -->  DHT11/DHT22 DATA (+ pull-up 10kΩ para 3.3V)
GPIO1      -->  PIR Sensor OUT
GPIO5      -->  Relay IN (controle)
GPIO8      -->  LED Status (opcional)
GPIO10     -->  Reserva para expansão
3.3V       -->  VCC de todos os módulos
GND        -->  GND comum
```

## ⚙️ Configuração

### 1. **Parâmetros de Rede**
```python
WIFI_SSID = 'Homeguard'
WIFI_PASS = 'pu2clr123456'
```

### 2. **Broker MQTT**
```python
MQTT_SERVER = '192.168.1.102'
MQTT_USER = 'homeguard'
MQTT_PASS = 'pu2clr123456'
```

### 3. **Tipo de Sensor DHT**
```python
DHT_TYPE = dht.DHT11    # Altere para dht.DHT22 se usar DHT22
```

### 4. **Device ID**
```python
DEVICE_ID = 'MULTI_SENSOR_C3A'  # Altere conforme necessário
```

## 📡 Tópicos MQTT

### **Dados publicados automaticamente:**

| Tópico | Descrição | Retain |
|--------|-----------|--------|
| `home/multisensor/MULTI_SENSOR_C3A/temperature` | Dados de temperatura | ✅ |
| `home/multisensor/MULTI_SENSOR_C3A/humidity` | Dados de umidade | ✅ |
| `home/multisensor/MULTI_SENSOR_C3A/motion` | Eventos de movimento | ❌ |
| `home/multisensor/MULTI_SENSOR_C3A/relay/status` | Status do relé | ✅ |
| `home/multisensor/MULTI_SENSOR_C3A/status` | Status geral | ✅ |
| `home/multisensor/MULTI_SENSOR_C3A/heartbeat` | Heartbeat (5 min) | ❌ |
| `home/multisensor/MULTI_SENSOR_C3A/info` | Info do dispositivo | ❌ |

### **Comandos aceitos:**

| Tópico | Comando | Descrição |
|--------|---------|-----------|
| `home/multisensor/MULTI_SENSOR_C3A/relay/command` | `ON` / `OFF` | Liga/desliga relé |
| `home/multisensor/MULTI_SENSOR_C3A/command` | `READ` | Força leitura dos sensores |
| `home/multisensor/MULTI_SENSOR_C3A/command` | `STATUS` | Solicita status |
| `home/multisensor/MULTI_SENSOR_C3A/command` | `INFO` | Solicita informações |

## 📊 Formato dos Dados JSON

### **Temperatura:**
```json
{
  "device_id": "MULTI_SENSOR_C3A",
  "sensor_type": "DHT11",
  "temperature": 25.6,
  "unit": "°C",
  "timestamp": 123456789,
  "uptime": 3600,
  "reading_count": 150
}
```

### **Umidade:**
```json
{
  "device_id": "MULTI_SENSOR_C3A",
  "sensor_type": "DHT11",
  "humidity": 65.2,
  "unit": "%",
  "timestamp": 123456789,
  "uptime": 3600,
  "reading_count": 150
}
```

### **Movimento:**
```json
{
  "device_id": "MULTI_SENSOR_C3A",
  "event": "MOTION_DETECTED",
  "timestamp": 123456789,
  "uptime": 3600,
  "motion_count": 25
}
```

### **Relé:**
```json
{
  "device_id": "MULTI_SENSOR_C3A",
  "relay_state": "ON",
  "timestamp": 123456789,
  "uptime": 3600,
  "toggle_count": 10
}
```

## 🚀 Como Usar

### 1. **Preparar o ESP32-C3**
- Instalar MicroPython firmware
- Copiar `main.py` para o dispositivo
- **DHT**: Já incluído no MicroPython ESP32 (sem instalação adicional!)
- **MQTT**: Instalar `umqtt.simple` se não incluído:
  ```python
  import upip
  upip.install('micropython-umqtt.simple')
  ```

### 2. **Configurar hardware**
- Conectar sensores conforme diagrama
- Verificar alimentação 3.3V estável
- Confirmar pull-up de 10kΩ no DHT

### 3. **Testar funcionalidade**
```bash
# Monitorar todos os dados:
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/#" -v

# Controlar relé:
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/relay/command" -m "ON"
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/relay/command" -m "OFF"

# Solicitar leitura:
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/multisensor/MULTI_SENSOR_C3A/command" -m "READ"
```

## ⏱️ Temporização

- **Leitura de sensores:** 5 segundos
- **Envio forçado:** 60 segundos
- **Verificação de movimento:** 100ms
- **Heartbeat:** 5 minutos
- **Debounce PIR:** 200ms
- **Timeout movimento:** 30 segundos

## 🔧 Configurações Avançadas

### **Thresholds de mudança:**
```python
TEMP_THRESHOLD = 0.5    # °C - mudança mínima para enviar
HUMID_THRESHOLD = 2.0   # % - mudança mínima para enviar
```

### **Intervalos personalizados:**
```python
SENSOR_READ_INTERVAL = 5000    # ms - leitura dos sensores
DATA_SEND_INTERVAL = 60000     # ms - envio forçado
HEARTBEAT_INTERVAL = 300000    # ms - heartbeat
```

### **GPIO customizado:**
```python
DHT_PIN = 0         # GPIO0 - DHT11/DHT22
PIR_PIN = 1         # GPIO1 - Sensor PIR/IR
RELAY_PIN = 5       # GPIO5 - Controle do relé
LED_PIN = 8         # GPIO8 - LED de status
```

## 🔍 Diagnóstico

### **LED de Status:**
- **Ligado constante**: WiFi conectado
- **Piscando lento**: Conectando ao WiFi
- **Piscada rápida**: Atividade de sensores
- **Múltiplas piscadas**: Controle de relé

### **Serial Monitor (115200 baud):**
```
=== ESP32-C3 Multi-Sensor Monitor ===
Device ID: MULTI_SENSOR_C3A
DHT Type: DHT11
GPIO - DHT: 0, PIR: 1, Relay: 5, LED: 8
Conectando ao WiFi...
WiFi conectado! IP: 192.168.1.150
MQTT conectado!
Temp: 25.6°C, Humid: 65.2%
MOVIMENTO DETECTADO!
Relé LIGADO
```

## 🛠️ Troubleshooting

### **DHT sempre retorna erro:**
- Verificar conexão GPIO0
- Confirmar resistor pull-up 10kΩ
- Aguardar 2 segundos após power-on
- Verificar tipo de sensor (DHT11 vs DHT22)

### **PIR não detecta movimento:**
- Verificar conexão GPIO1
- Aguardar tempo de estabilização do PIR (30-60s)
- Verificar sensitivity do módulo PIR
- Confirmar alimentação 3.3V

### **Relé não responde:**
- Verificar conexão GPIO5
- Confirmar se módulo relé é 3.3V compatível
- Testar comando manual via MQTT
- Verificar alimentação do módulo relé

### **MQTT não conecta:**
- Verificar IP do broker (192.168.1.102)
- Confirmar credenciais (homeguard:pu2clr123456)
- Testar conectividade de rede
- Verificar firewall do broker

## 🌐 Integração com Dashboard

O dispositivo é automaticamente detectado pelo sistema HomeGuard Flask:

- **Dashboard principal**: Gráficos de temperatura, umidade e movimento
- **Controle de relé**: Interface web para ON/OFF
- **Logs**: Histórico de todos os eventos
- **API**: Endpoints REST para integração
- **Alertas**: Notificações de movimento e mudanças de temperatura

## 📝 Notas Técnicas

- **Compatibilidade**: ESP32-C3 com MicroPython 1.19+
- **Memória**: ~30KB RAM, ~50KB Flash
- **Consumo**: ~80mA em operação normal
- **Autonomia**: Depende da fonte de alimentação
- **Temperatura operacional**: -10°C a +50°C (limitado pelo DHT)
- **Precisão DHT11**: ±2°C, ±5%RH
- **Precisão DHT22**: ±0.5°C, ±2%RH

## 🔄 Manutenção

- **Reset automático**: Em caso de falha crítica
- **Reconexão automática**: WiFi e MQTT
- **Watchdog**: Proteção contra travamentos
- **Logs**: Informações de debug via serial
- **Heartbeat**: Monitoramento de saúde do dispositivo