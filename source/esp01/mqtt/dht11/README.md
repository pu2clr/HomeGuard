# HomeGuard DHT11 Temperature & Humidity Monitor

Monitor de temperatura e umidade usando ESP-01S com sensor DHT11, integrado ao sistema HomeGuard via MQTT.

## 🔧 Hardware Necessário

- **ESP-01S** (ESP8266)
- **Sensor DHT11** 
- **Resistor 10kΩ** (pull-up para o pino DATA do DHT11)
- **Regulador de tensão 3.3V** (se alimentar com 5V)
- **Breadboard e jumpers**

## 📐 Conexões do Hardware

```
DHT11 Sensor:
├── VCC  → ESP-01S 3.3V
├── GND  → ESP-01S GND
└── DATA → ESP-01S GPIO2 (PIN 2) + Resistor 10kΩ para 3.3V

ESP-01S:
├── GPIO0 (PIN 0) → LED status (opcional)
├── GPIO2 (PIN 2) → DHT11 DATA + 10kΩ pull-up
├── VCC           → 3.3V (regulado)
└── GND           → GND comum
```

## ⚙️ Configuração do Sketch

### 1. **Selecionar dispositivo**
Descomente apenas UMA linha no código:

```cpp
#define SENSOR_001  // Monitor Sala (IP: 192.168.1.195)
// #define SENSOR_002  // Monitor Cozinha (IP: 192.168.1.196)  
// #define SENSOR_003  // Monitor Quarto (IP: 192.168.1.197)
```

### 2. **Configurações de rede**
```cpp
const char* ssid = "SUA_REDE_WIFI";
const char* password = "SUA_SENHA_WIFI";
```

### 3. **Broker MQTT**
```cpp
const char* mqtt_server = "192.168.1.102";  // IP do Raspberry Pi
const char* mqtt_user = "homeguard";
const char* mqtt_pass = "pu2clr123456";
```

## 📡 Tópicos MQTT

### **Dados publicados pelo sensor:**

| Tópico | Payload | Descrição |
|--------|---------|-----------|
| `home/sensor/ESP01_DHT11_001/data` | JSON | **Dados combinados de temperatura E umidade** |
| `home/sensor/ESP01_DHT11_001/status` | `online`/`error` | Status do sensor |
| `home/sensor/ESP01_DHT11_001/info` | JSON | Informações do dispositivo |

### **Comandos aceitos:**

| Tópico | Comando | Descrição |
|--------|---------|-----------|
| `home/sensor/ESP01_DHT11_001/command` | `STATUS` | Solicita status atual |
| `home/sensor/ESP01_DHT11_001/command` | `READ` | Força leitura imediata |
| `home/sensor/ESP01_DHT11_001/command` | `INFO` | Solicita informações do dispositivo |

## 📊 Formato dos Dados JSON

### **Dados do Sensor (Temperatura + Umidade):**
```json
{
  "device_id": "ESP01_DHT11_001",
  "device_name": "Monitor Sala",
  "location": "Sala",
  "sensor_type": "DHT11",
  "temperature": 25.6,
  "temperature_unit": "°C",
  "humidity": 65.2,
  "humidity_unit": "%",
  "rssi": -45,
  "uptime": 123456,
  "timestamp": 123456
}
```

## 🚀 Como Usar

### 1. **Preparar Arduino IDE**
```bash
# Instalar biblioteca DHT sensor library
# Tools > Manage Libraries > Search "DHT sensor library" by Adafruit
# Instalar também "Adafruit Unified Sensor"
```

### 2. **Compilar e fazer upload**
- Configurar board: "Generic ESP8266 Module"
- Flash Size: "1MB (FS:64KB OTA:~470KB)"
- Upload Speed: "115200"

### 3. **Testar conexão MQTT**

**Monitorar todos os dados:**
```bash
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/sensor/ESP01_DHT11_001/+" -v
```

**Monitorar apenas dados do sensor:**
```bash
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/sensor/ESP01_DHT11_001/data" -v
```

**Solicitar leitura imediata:**
```bash
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/sensor/ESP01_DHT11_001/command" -m "READ"
```

## ⏱️ Temporização

- **Leitura do sensor**: Cada 5 segundos
- **Envio de dados**: Cada 60 segundos OU quando há mudança significativa
- **Heartbeat**: Cada 30 segundos
- **Threshold temperatura**: ±0.5°C
- **Threshold umidade**: ±2.0%

## 🔍 Diagnóstico

### **LED de Status:**
- **ON constante**: Sensor funcionando normalmente
- **Piscando**: Erro na leitura do DHT11 ou conectando ao WiFi
- **OFF**: Muitas falhas consecutivas (>10)

### **Serial Monitor (115200 baud):**
```
ESP01 DHT11 Monitor iniciando...
Conectando ao WiFi.....
WiFi conectado! IP: 192.168.1.195
MQTT conectado!
Temperatura: 25.1°C, Umidade: 60.2%
Dados enviados via MQTT - Temp: 25.1°C, Humid: 60.2%
```

## 🛠️ Troubleshooting

### **Sensor sempre retorna NAN:**
- Verificar conexão do pino DATA (GPIO2)
- Confirmar resistor pull-up de 10kΩ
- Verificar alimentação 3.3V estável
- Aguardar 2 segundos após ligar para estabilizar

### **MQTT não conecta:**
- Verificar IP do broker (192.168.1.102)
- Confirmar credenciais (homeguard:pu2clr123456)
- Testar conectividade de rede

### **Leituras instáveis:**
- DHT11 tem precisão limitada (±2°C, ±5%RH)
- Evitar leituras muito frequentes (mínimo 2 segundos)
- Proteger o sensor de correntes de ar

## 🌐 Integração com Dashboard

O sensor é automaticamente detectado pelo sistema HomeGuard Flask. Os dados aparecem em:

- **Dashboard principal**: Gráficos de temperatura e umidade
- **Logs**: Histórico de todas as leituras
- **API**: Endpoints REST para integração

---

**Dispositivos suportados:**
- ESP01_DHT11_001 (Sala) - IP: 192.168.1.195
- ESP01_DHT11_002 (Cozinha) - IP: 192.168.1.196  
- ESP01_DHT11_003 (Quarto) - IP: 192.168.1.197
