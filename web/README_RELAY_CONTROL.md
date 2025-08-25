# 🔌 Guia de Configuração - Controle de Relés MQTT

## 📋 Resumo da Implementação

O sistema Flask agora inclui **controle real de relés via MQTT** com as seguintes funcionalidades:

### ✅ **Recursos Implementados:**
- **Conexão MQTT real** com broker configurável
- **Interface web** para controle manual dos relés
- **API REST** para integração externa
- **Status em tempo real** dos relés
- **Configuração flexível** de tópicos MQTT
- **Monitoramento de conexão** e timeout

---

## 🔧 **1. Configuração do IP do Broker MQTT**

### **Arquivo: `web/mqtt_relay_config.py`**

```python
MQTT_CONFIG = {
    'broker_host': '192.168.18.236',  # 🔧 ALTERE AQUI o IP do seu broker MQTT
    'broker_port': 1883,
    'username': None,  # Se precisar de autenticação
    'password': None,  # Se precisar de autenticação
    'keepalive': 60,
    'client_id': 'homeguard_flask_dashboard'
}
```

### **⚠️ Importante:** 
- **Substitua `192.168.18.236`** pelo IP real do seu broker MQTT
- Se usar **autenticação**, configure `username` e `password`
- Se usar **porta diferente**, altere `broker_port`

---

## 🎛️ **2. Configuração dos Relés**

### **No mesmo arquivo `mqtt_relay_config.py`:**

```python
RELAYS_CONFIG = [
    {
        "id": "ESP01_RELAY_001",                                    # ID único do relé
        "name": "Luz da Sala",                                      # Nome amigável
        "location": "Sala",                                         # Localização
        "mqtt_topic_command": "homeguard/relay/ESP01_RELAY_001/command", # Tópico para comandos
        "mqtt_topic_status": "homeguard/relay/ESP01_RELAY_001/status",   # Tópico para status
        "status": "unknown"
    },
    # ... adicione mais relés aqui
]
```

### **🔧 Para adicionar um novo relé:**
1. **Copie** um bloco existente
2. **Altere** o `id`, `name`, `location`
3. **Configure** os tópicos MQTT únicos
4. **Reinicie** o Flask

---

## 📡 **3. Tópicos MQTT Necessários**

### **O ESP8266 deve implementar:**

#### **📤 Receber Comandos (ESP como subscriber):**
```
Tópico: homeguard/relay/ESP01_RELAY_001/command
Payload: ON | OFF | TOGGLE
```

#### **📩 Enviar Status (ESP como publisher):**
```
Tópico: homeguard/relay/ESP01_RELAY_001/status  
Payload: on | off
```

### **💡 Exemplo de código Arduino (ESP):**
```cpp
// Inscrever-se no tópico de comando
client.subscribe("homeguard/relay/ESP01_RELAY_001/command");

// Processar comando recebido
void callback(char* topic, byte* payload, unsigned int length) {
  String command = String((char*)payload).substring(0, length);
  
  if (command == "ON") {
    digitalWrite(RELAY_PIN, HIGH);
    client.publish("homeguard/relay/ESP01_RELAY_001/status", "on");
  }
  else if (command == "OFF") {
    digitalWrite(RELAY_PIN, LOW);  
    client.publish("homeguard/relay/ESP01_RELAY_001/status", "off");
  }
}
```

---

## 🚀 **4. Instalação e Teste**

### **Passo 1: Instalar dependências**
```bash
chmod +x install_mqtt.sh
./install_mqtt.sh
```

### **Passo 2: Configurar IP do broker**
```bash
nano mqtt_relay_config.py
# Alterar broker_host para seu IP
```

### **Passo 3: Testar conexão MQTT**
```bash
python3 test_mqtt.py
```

### **Passo 4: Iniciar Flask com MQTT**
```bash
./restart_flask.sh
```

---

## 🌐 **5. Interface Web**

### **Páginas disponíveis:**
- **http://IP:5000/** - Dashboard principal
- **http://IP:5000/relays** - Controle de relés
- **http://IP:5000/events** - Histórico de eventos

### **APIs disponíveis:**
- **GET /api/relays** - Status de todos os relés
- **GET /api/relay/{id}/{action}** - Controlar relé (on/off/toggle)

---

## 🔍 **6. Monitoramento e Debug**

### **Ver logs do MQTT:**
```bash
tail -f flask.log | grep -E "(MQTT|Relay|📤|📩|✅|❌)"
```

### **Verificar status:**
```bash
./check_flask.sh
```

### **Testar comando via curl:**
```bash
curl "http://IP:5000/api/relay/ESP01_RELAY_001/on"
```

---

## ⚡ **7. Status em Tempo Real**

O sistema automaticamente:
- **📡 Monitora** tópicos de status dos relés
- **🔄 Atualiza** interface web em tempo real  
- **⏱️ Detecta** relés offline (timeout configurável)
- **📊 Exibe** último comando e timestamp

---

## 🛠️ **8. Solução de Problemas**

### **MQTT não conecta:**
- ✅ Verificar IP do broker
- ✅ Testar ping para o broker
- ✅ Verificar firewall (porta 1883)
- ✅ Confirmar que broker está rodando

### **Relé não responde:**  
- ✅ Verificar tópicos no ESP8266
- ✅ Usar cliente MQTT para testar manualmente
- ✅ Verificar logs do Flask

### **Status não atualiza:**
- ✅ Confirmar que ESP publica status
- ✅ Verificar se tópicos coincidem exatamente
- ✅ Testar com mosquitto_sub

---

## 📚 **Resumo dos Arquivos:**

| Arquivo | Função |
|---------|--------|
| `mqtt_relay_config.py` | **🔧 Configuração** (IP, tópicos, relés) |
| `flask_mqtt_controller.py` | **🎛️ Controlador MQTT** |
| `homeguard_flask.py` | **🌐 Interface Flask** (atualizada) |
| `test_mqtt.py` | **🧪 Teste de conexão** |
| `install_mqtt.sh` | **📦 Instalador de dependências** |

**🎯 Agora o controle de relés é 100% funcional via MQTT!**
