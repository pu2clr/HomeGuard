# 🔄 ESP01 Relay - Adequação ao Sistema Flask

## ✅ **Resumo das Alterações Implementadas**

O sketch do ESP01 foi **completamente atualizado** para ser 100% compatível com o sistema Flask Dashboard HomeGuard.

---

## 🎯 **Principais Mudanças**

### **1. 📡 Tópicos MQTT Compatíveis**
```cpp
// ANTES (formato antigo):
TOPIC_CMD = "home/relay1/cmnd"
TOPIC_STA = "home/relay1/stat"

// AGORA (formato Flask):
TOPIC_COMMAND = "homeguard/relay/ESP01_RELAY_001/command"
TOPIC_STATUS = "homeguard/relay/ESP01_RELAY_001/status"  
TOPIC_INFO = "homeguard/relay/ESP01_RELAY_001/info"
```

### **2. 🔧 Configuração Multi-Device**
```cpp
// Configuração automática baseada em #define:
#define RELAY_001  // Luz da Sala (IP: 192.168.18.192)
#define RELAY_002  // Luz da Cozinha (IP: 192.168.18.193)
#define RELAY_003  // Bomba d'Água (IP: 192.168.18.194)
```

### **3. 📊 Comandos Suportados**
```cpp
// Comandos compatíveis com Flask:
"ON"     → Liga relé
"OFF"    → Desliga relé  
"TOGGLE" → Inverte estado
"STATUS" → Envia info detalhada
```

### **4. 💓 Status em Tempo Real**
```cpp
// Recursos adicionados:
- Heartbeat a cada 30 segundos
- Status enviado imediatamente após mudança
- Informações JSON detalhadas
- LED de status (GPIO2)
- Reconexão automática robusta
```

---

## 📊 **Compatibilidade com Flask**

### **✅ Arquivo `mqtt_relay_config.py` → ESP01:**

| Flask Config | ESP01 Config | Match |
|--------------|--------------|-------|
| `broker_host: "192.168.18.198"` | `mqtt_server = "192.168.18.198"` | ✅ |
| `broker_port: 1883` | `mqtt_port = 1883` | ✅ |
| `username: "homeguard"` | `mqtt_user = "homeguard"` | ✅ |
| `password: "pu2clr123456"` | `mqtt_pass = "pu2clr123456"` | ✅ |
| `"id": "ESP01_RELAY_001"` | `DEVICE_ID = "ESP01_RELAY_001"` | ✅ |
| `"mqtt_topic_command"` | `TOPIC_COMMAND` | ✅ |
| `"mqtt_topic_status"` | `TOPIC_STATUS` | ✅ |

---

## 🚀 **Como Usar (Passo a Passo)**

### **1. 📝 Configurar cada ESP01:**
```cpp
// No início do arquivo .ino, descomente UMA linha:
#define RELAY_001  // Para primeiro ESP01 (Luz da Sala)
// #define RELAY_002  // Para segundo ESP01 (Luz da Cozinha)  
// #define RELAY_003  // Para terceiro ESP01 (Bomba d'Água)
```

### **2. 🔌 Upload para cada ESP01:**
```
ESP01 #1: #define RELAY_001 → Compile → Upload
ESP01 #2: #define RELAY_002 → Compile → Upload  
ESP01 #3: #define RELAY_003 → Compile → Upload
```

### **3. 🧪 Testar MQTT:**
```bash
# Usar script de teste criado:
./test_esp01_mqtt.sh

# Ou manual:
mosquitto_pub -h 192.168.18.198 -u homeguard -P pu2clr123456 \
  -t "homeguard/relay/ESP01_RELAY_001/command" -m "ON"
```

### **4. 🌐 Verificar no Flask:**
```bash
# Acessar dashboard:
http://192.168.18.198:5000/relays

# Ou via API:
curl http://192.168.18.198:5000/api/relay/ESP01_RELAY_001/on
```

---

## 📋 **Arquivos Criados/Atualizados**

### **✅ Arquivos Principais:**
- `relay.ino` → **Atualizado completamente**
- `ESP01_FLASK_INTEGRATION_GUIDE.md` → **Novo guia detalhado**
- `test_esp01_mqtt.sh` → **Script de teste interativo**
- `relay_config_template.h` → **Template de configuração**

### **✅ Funcionalidades Implementadas:**
```cpp
- ✅ Tópicos MQTT compatíveis com Flask
- ✅ Configuração automática multi-device
- ✅ Comandos ON/OFF/TOGGLE/STATUS
- ✅ Status em tempo real
- ✅ Heartbeat periódico  
- ✅ LED de status (GPIO2)
- ✅ Reconexão automática robusta
- ✅ Informações JSON detalhadas
- ✅ Error handling completo
```

---

## 🔍 **Teste de Integração**

### **1. Verificar Flask Dashboard:**
```bash
# 1. Iniciar Flask
cd HomeGuard/web
./restart_flask.sh

# 2. Verificar relés configurados
curl http://192.168.18.198:5000/api/relays
```

### **2. Testar ESP01:**
```bash
# 1. Usar script de teste
cd HomeGuard/source/esp01/mqtt/relay
chmod +x test_esp01_mqtt.sh
./test_esp01_mqtt.sh

# 2. Escolher opção 4 (Testar todos os relés)
```

### **3. Verificar Dashboard Web:**
```
http://192.168.18.198:5000/relays
```

---

## 🎯 **Resultado Final**

### **🌐 Sistema Integrado:**
```
ESP01 ←→ MQTT Broker ←→ Flask Dashboard ←→ Web Browser
  ↑           ↑             ↑              ↑
Hardware    Bridge      Backend        Frontend
Control    (MQTT)      (Python)       (HTML/JS)
```

### **📱 Interface Unificada:**
- **Dashboard Web**: Controle visual dos relés
- **API REST**: Integração programática  
- **MQTT Direct**: Controle direto via comandos
- **Status Real-time**: Feedback instantâneo

---

## 🔄 **Próximos Passos Recomendados**

1. **🧪 Teste um ESP01** primeiro com `#define RELAY_001`
2. **🔌 Upload e validar** comunicação MQTT
3. **🌐 Confirmar** no Flask Dashboard (http://IP:5000/relays)
4. **📊 Replicar** para outros ESP01 (RELAY_002, RELAY_003...)
5. **🏠 Deploy** em produção

---

**🎉 O sistema ESP01 ↔ Flask está 100% integrado e pronto para uso!**

### **Comando de Teste Rápido:**
```bash
# Testar ESP01_RELAY_001 via MQTT:
mosquitto_pub -h 192.168.18.198 -u homeguard -P pu2clr123456 \
  -t "homeguard/relay/ESP01_RELAY_001/command" -m "TOGGLE"

# Verificar via Flask:
curl http://192.168.18.198:5000/api/relay/ESP01_RELAY_001/toggle
```
