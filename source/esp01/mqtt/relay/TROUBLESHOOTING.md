# Guia de Troubleshooting - ESP01 HomeGuard

## Status do Diagnóstico
✅ ESP01 está acessível na rede (IP 192.168.18.192)  
✅ Broker MQTT está funcionando (192.168.18.236:1883)  
✅ Autenticação MQTT está funcionando (usuário: homeguard)  
❌ ESP01 não está respondendo aos comandos MQTT  

## Possíveis Causas e Soluções

### 1. **Firmware Incorreto no ESP01**
**Problema**: O firmware carregado pode não estar funcionando corretamente.
**Solução**: 
- Carregue a versão de debug: `relay_debug.ino`
- Conecte monitor serial (115200 baud) para ver mensagens de debug
- Verifique se as mensagens indicam conexão Wi-Fi e MQTT

### 2. **Configurações Wi-Fi Incorretas**
**Problema**: ESP01 não consegue se conectar à rede Wi-Fi.
**Verificar no código**:
```cpp
const char* ssid = "YOUR_SSID";            // ← Confirme se está correto
const char* password = "YOUR_PASSWORD"; // ← Confirme se está correto
```

### 3. **Problema de IP Estático**
**Problema**: Conflito de IP ou configuração de rede incorreta.
**Solução**:
- Teste primeiro sem IP estático (comente as linhas de WiFi.config)
- Verifique se o IP 192.168.18.192 não está sendo usado por outro dispositivo

### 4. **Configurações MQTT Incorretas no Código**
**Verificar no código**:
```cpp
const char* mqtt_server = "192.168.18.236"; // ← Confirme se está correto
const char* mqtt_user = "homeguard";        // ← Confirme se está correto  
const char* mqtt_pass = "pu2clr123456";     // ← Confirme se está correto
```

### 5. **Hardware do ESP01**
**Problema**: Problemas de hardware ou alimentação.
**Verificar**:
- ESP01 está recebendo 3.3V estável
- Módulo relay está funcionando
- GPIO0 e GPIO2 não estão em conflito

### 6. **Configuração do Dispositivo Errada**
**Problema**: `#define RELAY_001` pode não estar ativo.
**Verificar no código**:
```cpp
// ======== ESP01 Configuration (CHANGE FOR EACH DEVICE) ========
// Uncomment ONE line below:
#define RELAY_001  // ← Esta linha DEVE estar descomentada
// #define RELAY_002  // ← Esta linha DEVE estar comentada
// #define RELAY_003  // ← Esta linha DEVE estar comentada
```

## Passos Recomendados para Debug

### Passo 1: Carregar Firmware de Debug
1. Compile e carregue `relay_debug.ino` no ESP01
2. Conecte monitor serial (115200 baud)
3. Observe as mensagens de boot e operação

### Passo 2: Verificar Conectividade Wi-Fi
Monitor serial deve mostrar:
```
Wi-Fi connected!
IP Address: 192.168.18.192
RSSI: -XX dBm
```

### Passo 3: Verificar Conexão MQTT
Monitor serial deve mostrar:
```
MQTT connected successfully!
Subscribed to: homeguard/relay/ESP01_RELAY_001/command (success: 1)
```

### Passo 4: Testar Comandos
Execute:
```bash
mosquitto_pub -h 192.168.18.236 -u homeguard -P pu2clr123456 \
  -t "homeguard/relay/ESP01_RELAY_001/command" -m "STATUS"
```

Monitor serial deve mostrar:
```
MQTT Command received: 'STATUS' on topic: homeguard/relay/ESP01_RELAY_001/command
```

## Comandos de Teste

### Monitor Serial (conecte FTDI ao ESP01):
```bash
# Baudrate: 115200
# No Arduino IDE: Tools > Serial Monitor
```

### Test MQTT:
```bash
# Monitor todos os tópicos do ESP01:
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 \
  -t "home/relay/ESP01_RELAY_001/#" -v

# Enviar comandos:
mosquitto_pub -h 192.168.18.236 -u homeguard -P pu2clr123456 \
  -t "home/relay/ESP01_RELAY_001/command" -m "STATUS"

mosquitto_pub -h 192.168.18.236 -u homeguard -P pu2clr123456 \
  -t "home/relay/ESP01_RELAY_001/command" -m "ON"

mosquitto_pub -h 192.168.18.236 -u homeguard -P pu2clr123456 \
  -t "home/relay/ESP01_RELAY_001/command" -m "OFF"
```

### Verificar IP do ESP01:
```bash
# Deve responder em 192.168.18.192:
ping 192.168.18.192

# Verificar se há conflito de MAC/IP:
arp -a | grep 192.168.18.192
```

## Configuração Temporária Simplificada

Se nada funcionar, teste com esta configuração simplificada:

1. **Desabilite IP estático** (comente as linhas):
```cpp
// WiFi.config(local_IP, gateway, subnet);
```

2. **Use DHCP temporariamente**:
```cpp
WiFi.begin(ssid, password);
// IP será atribuído automaticamente
```

3. **Verifique qual IP foi atribuído** via monitor serial ou roteador

4. **Teste MQTT no IP atribuído pelo DHCP**

## Contato e Suporte

Se o problema persistir após seguir todos os passos:
1. Capture e forneça as mensagens do monitor serial
2. Confirme as configurações de rede e MQTT
3. Teste com configuração DHCP antes do IP estático
