# 🔌 HomeGuard Simple Power Monitor

Monitor simplificado de energia elétrica baseado no ESP8266 + ZMPT101B, focado especificamente na detecção de falhas de energia e acionamento de relé.

## 📋 Características

- **🎯 Foco específico:** Detecção de falta de energia
- **⚡ Ação automática:** Aciona relé quando detecta falta de energia
- **📡 Alertas MQTT:** Envia alertas detalhados com timestamp
- **💓 Heartbeat:** Status do sistema a cada 5 minutos
- **🔧 Controle remoto:** Comandos MQTT para teste e manutenção
- **📊 Estatísticas:** Contabiliza falhas e duração

## 🔧 Hardware Necessário

- **ESP8266** (NodeMCU, Wemos D1, etc.)
- **ZMPT101B** - Sensor de tensão AC
- **Módulo Relé 5V**
- **Transistor NPN** (2N2222, BC547, BC337)
- **Resistor 1kΩ**

## 📐 Conexões de Hardware

### ZMPT101B (Sensor de Tensão)
```
ZMPT101B VCC  -> ESP8266 3.3V
ZMPT101B GND  -> ESP8266 GND  
ZMPT101B OUT  -> ESP8266 A0
```

### Relé com Driver Transistor (IMPORTANTE!)
```
ESP8266 GPIO5 ----[1kΩ]----|>B   2N2222/BC547 NPN
                           |      
                          C|----- IN do módulo relé
                           |
                          E|
                           |
                         GND (comum ESP e relé)

Módulo Relé VCC -> 5V
Módulo Relé GND -> GND (comum)
```

**⚠️ IMPORTANTE:** Nunca conecte o relé diretamente ao GPIO! Use sempre o transistor driver.

## ⚙️ Configuração

### 1. Editar Parâmetros no Código

```cpp
// Device Configuration
#define DEVICE_ID           "POWER_MONITOR_01"    // ID único
#define DEVICE_NAME         "Monitor Energia"     // Nome amigável
#define DEVICE_LOCATION     "Quadro Principal"    // Localização

// Network Configuration  
#define LOCAL_IP_4          91                    // Último octeto do IP

// WiFi Configuration
#define WIFI_SSID           "Homeguard"           // Nome da rede WiFi
#define WIFI_PASSWORD       "pu2clr123456"        // Senha WiFi

// MQTT Configuration
#define MQTT_SERVER         "192.168.1.102"       // IP do broker MQTT
```

### 2. Ajustar Threshold de Detecção

```cpp
#define POWER_THRESHOLD     950    // Ajustar conforme sua tensão
```

**Como ajustar:**
1. Conecte o monitor com energia normal
2. Observe os valores no Serial Monitor
3. Ajuste `POWER_THRESHOLD` para ~80% do valor normal

## 📡 Tópicos MQTT

### Tópicos de Saída (Monitor -> Broker)

| Tópico | Descrição | Frequência |
|--------|-----------|------------|
| `home/power/POWER_MONITOR_01/status` | Status geral do sistema | A cada 5 min |
| `home/power/POWER_MONITOR_01/alert` | Alertas de falta/retorno energia | Eventos |
| `home/power/POWER_MONITOR_01/info` | Informações detalhadas do dispositivo | Sob demanda |

### Tópicos de Entrada (Comandos)

| Comando | Descrição |
|---------|-----------|
| `INFO` | Solicita informações do dispositivo |
| `STATUS` | Solicita status atual |
| `ON` | Liga relé manualmente |
| `OFF` | Desliga relé manualmente |
| `AUTO` | Volta ao modo automático |
| `READ` | Força leitura do sensor |

## 📊 Exemplo de Mensagens MQTT

### Alert de Falta de Energia
```json
{
  "device_id": "POWER_MONITOR_01",
  "device_name": "Monitor Energia",
  "location": "Quadro Principal",
  "alert_type": "POWER_FAILURE",
  "timestamp": 1694692800000,
  "sensor_value": 120,
  "relay_activated": true,
  "uptime": 3600000,
  "rssi": -45
}
```

### Status Heartbeat
```json
{
  "device_id": "POWER_MONITOR_01",
  "device_name": "Monitor Energia", 
  "location": "Quadro Principal",
  "power_status": "online",
  "sensor_value": 980,
  "relay_state": false,
  "relay_mode": "auto",
  "uptime": 7200000,
  "rssi": -42,
  "failed_readings": 0
}
```

## 🧪 Comandos de Teste

### Monitorar Alertas
```bash
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t "home/power/POWER_MONITOR_01/alert" -v
```

### Monitorar Status
```bash  
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t "home/power/POWER_MONITOR_01/status" -v
```

### Solicitar Informações
```bash
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t "home/power/POWER_MONITOR_01/command" -m "INFO"
```

### Controle Manual do Relé
```bash
# Ligar relé manualmente
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t "home/power/POWER_MONITOR_01/command" -m "ON"

# Desligar relé
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t "home/power/POWER_MONITOR_01/command" -m "OFF"

# Voltar ao automático
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 \
  -t "home/power/POWER_MONITOR_01/command" -m "AUTO"
```

## 🔧 Instalação e Upload

### 1. Configurar Arduino IDE
- Instalar ESP8266 Board Package
- Instalar biblioteca PubSubClient
- Selecionar placa correta (NodeMCU, Wemos D1, etc.)

### 2. Configurar Código
- Editar parâmetros de configuração no início do arquivo
- Ajustar `POWER_THRESHOLD` conforme necessário
- Verificar IPs e credenciais

### 3. Upload
- Conectar ESP8266 via USB
- Selecionar porta correta
- Fazer upload do código

### 4. Teste
- Abrir Serial Monitor (115200 baud)
- Verificar conexão WiFi e MQTT
- Testar comandos MQTT

## 🚨 Comportamento do Sistema

### Operação Normal (Energia OK)
- ✅ LED interno aceso
- ✅ Relé desligado  
- ✅ Heartbeat a cada 5 minutos
- ✅ Sensor monitora continuamente

### Falta de Energia Detectada
- 🚨 Alerta MQTT enviado imediatamente
- 🔄 Relé acionado automaticamente
- 💡 LED interno piscando
- 📊 Contador de falhas incrementado

### Energia Restaurada
- ✅ Alerta MQTT de restauração
- 🔄 Relé desligado automaticamente
- ✅ LED interno aceso
- 📊 Duração da falha calculada

## 📈 Integração com Dashboard

O monitor envia dados compatíveis com o dashboard HomeGuard existente. As mensagens MQTT serão automaticamente capturadas pelo `mqtt_activity_logger.py` e estarão disponíveis no painel web.

### Visualização Esperada
- Gráfico de status de energia
- Histórico de falhas
- Estatísticas de disponibilidade
- Controle remoto do relé

## 🔍 Troubleshooting

### Problema: Sensor não detecta energia
**Solução:**
1. Verificar conexões ZMPT101B
2. Ajustar `POWER_THRESHOLD`
3. Verificar se ZMPT101B está conectado à fase (não neutro)

### Problema: Relé não aciona
**Solução:**
1. Verificar circuito transistor NPN
2. Testar comando manual via MQTT
3. Verificar tensão no GPIO5

### Problema: Falsos alertas
**Solução:**  
1. Aumentar `DETECTION_DELAY`
2. Ajustar `POWER_THRESHOLD`
3. Verificar estabilidade da alimentação

### Problema: Não conecta MQTT
**Solução:**
1. Verificar credenciais MQTT
2. Verificar IP do broker
3. Testar conectividade de rede

## 📝 Logs Úteis

O sistema fornece logs detalhados via Serial Monitor:

```
🚀 HomeGuard Power Monitor Starting...
📋 Device: Monitor Energia (POWER_MONITOR_01)
📍 Location: Quadro Principal
🔧 Relay initialized on GPIO5: OFF
✅ WiFi connected! IP: 192.168.1.91
✅ MQTT connected!
🔌 Power reading: 980 (threshold: 950) -> ONLINE
💓 Heartbeat sent
```

## 🎯 Diferenças do grid_monitor.ino

| Aspecto | grid_monitor.ino | simple_power_monitor.ino |
|---------|------------------|---------------------------|
| **Foco** | Monitoramento geral | Apenas falta de energia |
| **Heartbeat** | 1 minuto | 5 minutos |
| **Alertas** | Status contínuo | Apenas eventos críticos |
| **Complexidade** | Média | Baixa |
| **Recursos** | Múltiplas funções | Função específica |
| **Configuração** | Mais parâmetros | Parâmetros essenciais |

## 🏗️ Casos de Uso

- **🏠 Residencial:** Acionamento de luz de emergência
- **🏢 Comercial:** Alerta para falhas de energia  
- **🏭 Industrial:** Trigger para backup systems
- **💻 Data Center:** Monitoramento de UPS
- **🔧 Manutenção:** Detecção de interrupções

---

**Versão:** 1.0  
**Data:** 14 de setembro de 2025  
**Autor:** HomeGuard System
