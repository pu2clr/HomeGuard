# 🔌 HomeGuard ESP01 Relay - Configuração Multi-Device

## 📋 **Resumo**

Este sketch foi atualizado para ser **100% compatível** com o sistema Flask Dashboard HomeGuard. Cada ESP01 pode controlar um relé independente com comunicação MQTT bidirecional.

---

## ⚙️ **Configuração por Relé**

### **🔧 Para cada ESP01, altere estas linhas:**

```cpp
// ======== Device Configuration (CHANGE FOR EACH RELAY) ========
const char* DEVICE_ID = "ESP01_RELAY_001";        // ESP01_RELAY_001, ESP01_RELAY_002, etc
const char* DEVICE_NAME = "Luz da Sala";          // Nome amigável do relé
const char* DEVICE_LOCATION = "Sala";             // Localização física

// ======== IP Configuration ========  
IPAddress local_IP(192, 168, 18, 192);            // .192, .193, .194, etc (um IP por ESP01)
```

### **📊 Configuração Recomendada:**

| ESP01 | DEVICE_ID | DEVICE_NAME | LOCATION | IP |
|-------|-----------|-------------|----------|-----|
| #1 | `ESP01_RELAY_001` | `Luz da Sala` | `Sala` | `192.168.1.192` |
| #2 | `ESP01_RELAY_002` | `Luz da Cozinha` | `Cozinha` | `192.168.1.193` |  
| #3 | `ESP01_RELAY_003` | `Bomba d'Água` | `Externa` | `192.168.1.194` |

---

## 📡 **Tópicos MQTT Automáticos**

O sketch automaticamente cria os tópicos baseados no `DEVICE_ID`:

```cpp
// Para ESP01_RELAY_001:
TOPIC_COMMAND = "homeguard/relay/ESP01_RELAY_001/command"  // Flask → ESP01
TOPIC_STATUS = "homeguard/relay/ESP01_RELAY_001/status"    // ESP01 → Flask  
TOPIC_INFO = "homeguard/relay/ESP01_RELAY_001/info"        // ESP01 → Flask (info detalhada)
```

---

## 🎯 **Comandos MQTT Suportados**

### **📤 Comandos (Flask → ESP01):**
```bash
# Ligar relé
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/command" -m "ON"

# Desligar relé  
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/command" -m "OFF"

# Alternar estado
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/command" -m "TOGGLE"

# Solicitar status
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/command" -m "STATUS"
```

### **📩 Respostas (ESP01 → Flask):**
```bash
# Status do relé (on/off)  
homeguard/relay/ESP01_RELAY_001/status → "on" ou "off"

# Informações detalhadas (JSON)
homeguard/relay/ESP01_RELAY_001/info → {"device_id":"ESP01_RELAY_001",...}
```

---

## 📊 **Recursos Avançados**

### **✅ Funcionalidades Implementadas:**
- **🔄 Reconexão Automática**: Wi-Fi e MQTT com backoff exponencial
- **💓 Heartbeat**: Envia status a cada 30 segundos
- **📡 Status em Tempo Real**: Status enviado imediatamente após mudança
- **🔍 Device Info**: JSON com informações detalhadas do ESP01
- **⚡ LED de Status**: GPIO2 indica estado do relé
- **🛡️ Error Handling**: Tratamento robusto de erros

### **📋 Status LED (GPIO2):**
- **OFF**: Relé desligado
- **ON**: Relé ligado  
- **Blink**: Conectando Wi-Fi

---

## 🔧 **Hardware Connections**

### **ESP-01S Pinout:**
```
      ESP-01S
    ┌─────────┐
    │ □ VCC   │ ← 3.3V
    │ RST   □ │
    │ EN    □ │ 
    │ GPIO0 □ │ ← Relay IN (PIN 0)
    │ GPIO2 □ │ ← Status LED (PIN 2) [Optional]
    │ GND   □ │ ← Ground
    │ TXD   □ │
    │ RXD   □ │
    └─────────┘
```

### **Relay Module Connections:**
```cpp
// Relay Module Pinout:
VCC  → ESP01 3.3V (or external 5V)
GND  → ESP01 GND  
IN   → ESP01 GPIO0 (PIN 0)
NO   → Load positive (normally open)
COM  → Power source positive
NC   → Not used (normally closed)
```

---

## 🧪 **Testing e Debug**

### **1. Monitor MQTT Topics:**
```bash
# Monitor todos os tópicos
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "#" -v

# Monitor apenas um relé
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/#" -v
```

### **2. Test Individual Relay:**
```bash
# Testar ESP01_RELAY_001
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/command" -m "ON"
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/command" -m "OFF"
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/command" -m "TOGGLE"
```

### **3. Check Device Info:**
```bash
# Solicitar informações detalhadas
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/command" -m "STATUS"

# Ver resposta em JSON
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "homeguard/relay/ESP01_RELAY_001/info" -v
```

---

## 🚀 **Deployment Checklist**

### **📋 Para cada ESP01:**

```cpp
☐ 1. Alterar DEVICE_ID único
☐ 2. Configurar DEVICE_NAME descritivo  
☐ 3. Definir DEVICE_LOCATION
☐ 4. Configurar IP único (192.168.1.192, .193, .194...)
☐ 5. Verificar conexões de hardware
☐ 6. Upload do código
☐ 7. Testar comandos MQTT
☐ 8. Confirmar no Flask Dashboard
```

### **🔌 Verificação Flask:**
```bash
# Verificar se o Flask reconhece os relés
curl http://192.168.1.102:5000/api/relays

# Controlar via Flask
curl http://192.168.1.102:5000/api/relay/ESP01_RELAY_001/on
```

---

## 🐛 **Troubleshooting**

### **Problemas Comuns:**

| Problema | Solução |
|----------|---------|
| **Relé não responde** | Verificar tópico MQTT e DEVICE_ID |
| **Status LED não funciona** | GPIO2 pode ter pull-up, normal em alguns módulos |
| **Conflito de IP** | Cada ESP01 deve ter IP único |
| **MQTT não conecta** | Verificar credenciais e broker IP |
| **Relé invertido** | Alterar `RELAY_ACTIVE_LOW` para `false` |

### **Debug via Serial:**
Para debug, adicione no início do `setup()`:
```cpp
Serial.begin(115200);
Serial.println("HomeGuard Relay Starting...");
```

---

## 📊 **JSON Info Response Example**

```json
{
  "device_id": "ESP01_RELAY_001",
  "name": "Luz da Sala", 
  "location": "Sala",
  "ip": "192.168.1.192",
  "rssi": -45,
  "uptime": 123456,
  "relay_state": "on",
  "last_command": "ON",
  "firmware": "HomeGuard_v1.0"
}
```

---

**🎯 O sketch agora está 100% compatível com o Flask Dashboard HomeGuard!**
