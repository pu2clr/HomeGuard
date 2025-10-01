# 🚨 DIAGNÓSTICO E CORREÇÃO - INTERRUPT WDT TIMEOUT ESP32-C3

## 📋 **ANÁLISE DO ERRO**

**Erro identificado**: `Guru Meditation Error: Core 0 panic'ed (Interrupt wdt timeout on CPU0)`

### 🎯 **CAUSAS IDENTIFICADAS:**

1. **Loop infinito no WiFi** - `while not wlan.isconnected()` sem timeout
2. **Leituras ADC excessivas** - 20 leituras com delay mínimo (10ms)
3. **Falta de `machine.idle()`** - Não reseta o watchdog timer
4. **Sem tratamento de exceções** - Falhas causam travamento
5. **Bloqueio MQTT** - `client.check_msg()` pode travar

### 🔧 **CORREÇÕES IMPLEMENTADAS:**

#### **main_fixed.py** - Versão corrigida principal

**Melhorias aplicadas:**

1. **Timeout WiFi** - Máximo 30 segundos para conexão
2. **Watchdog Reset** - `machine.idle()` no loop principal
3. **Tratamento de exceções** - Try/catch em todas as operações críticas
4. **Otimização ADC** - Reduzido para 10 amostras com delays maiores
5. **Reconexão automática** - WiFi e MQTT com verificação periódica
6. **Garbage Collection** - Limpeza de memória automática
7. **Heartbeat inteligente** - Status a cada 5 minutos + mudanças
8. **Comando RESTART** - Reinício remoto via MQTT

## 🛠️ **INSTALAÇÃO DA CORREÇÃO**

### **Passo 1: Backup do arquivo atual**
```bash
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/source/Micropython/grid_monitor
cp main.py main_backup.py
```

### **Passo 2: Aplicar correção**
```bash
cp main_fixed.py main.py
```

### **Passo 3: Upload para ESP32-C3**
```bash
# Via ampy (se instalado)
ampy -p /dev/ttyUSB0 put main.py

# Via mpremote (recomendado)
mpremote connect /dev/ttyUSB0 fs cp main.py :
```

### **Passo 4: Reiniciar o device**
```bash
mpremote connect /dev/ttyUSB0 reset
```

## 📊 **MONITORAMENTO E TESTE**

### **1. Monitorar logs via serial:**
```bash
mpremote connect /dev/ttyUSB0
# ou
screen /dev/ttyUSB0 115200
```

### **2. Testar comandos MQTT:**
```bash
# Status do device
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "STATUS"

# Modo manual ON
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "ON"

# Modo manual OFF
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "OFF"

# Modo automático
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "AUTO"

# Reiniciar device remotamente
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "RESTART"
```

### **3. Monitorar status:**
```bash
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/status" -v
```

## ⚙️ **CONFIGURAÇÕES AJUSTÁVEIS**

### **No arquivo main_fixed.py:**

```python
# Timing otimizado
WIFI_TIMEOUT = 30         # Timeout WiFi (segundos)
HEARTBEAT_INTERVAL = 300  # Status a cada 5 minutos
ADC_SAMPLES = 10          # Amostras ADC (era 20)
SAMPLE_DELAY = 20         # Delay entre amostras (ms)
MAIN_LOOP_DELAY = 2       # Delay do loop principal (segundos)

# Threshold da rede elétrica
GRID_THRESHOLD = 2700     # Ajustar conforme sensor
```

## 🔍 **LOGS ESPERADOS**

### **Inicialização bem-sucedida:**
```
Inicializando Grid Monitor ESP32-C3...
Hardware inicializado com sucesso
Conectando ao WiFi...
WiFi conectado: ('192.168.1.xxx', '255.255.255.0', '192.168.1.1', '192.168.1.1')
MQTT conectado e inscrito em home/grid/GRID_MONITOR_C3B/command
Sistema inicializado com sucesso!
Status publicado: {"device_id":"GRID_MONITOR_C3B","grid_status":"online","relay":"off","uptime":xxx,"free_memory":xxxxx,"adc_raw":xxxx}
```

### **Operação normal:**
```
Leitura 1 : 3201 - Grid: ON
Leitura 2 : 3198 - Grid: ON
Leitura 3 : 2650 - Grid: OFF
Status publicado: {"device_id":"GRID_MONITOR_C3B","grid_status":"offline","relay":"on","uptime":xxx,"free_memory":xxxxx,"adc_raw":2650}
```

## 🚫 **PROBLEMAS RESIDUAIS POSSÍVEIS**

### **Se ainda ocorrer WDT timeout:**

1. **Reduzir ADC_SAMPLES para 5**
2. **Aumentar MAIN_LOOP_DELAY para 3 segundos**
3. **Verificar alimentação do ESP32-C3**
4. **Atualizar firmware MicroPython**

### **Verificar alimentação:**
```python
# Adicionar no loop principal para debug
import esp32
hall_sensor = esp32.hall_sensor()
print('Hall sensor:', hall_sensor)  # Indicativo de interferência
```

### **Memory monitoring:**
```python
# Já incluído no código corrigido
if count % 50 == 0:
    gc.collect()
    print('Memória livre:', gc.mem_free())
```

## 📈 **VANTAGENS DA CORREÇÃO**

1. ✅ **Elimina WDT timeout** - Watchdog reset adequado
2. ✅ **Reconexão automática** - WiFi e MQTT resilientes  
3. ✅ **Logs detalhados** - Diagnóstico facilitado
4. ✅ **Controle remoto** - Restart via MQTT
5. ✅ **Monitoramento** - Memória e uptime
6. ✅ **Performance** - Delays otimizados
7. ✅ **Robustez** - Tratamento de exceções completo

## 🎯 **TESTE FINAL**

Após aplicar a correção, o device deve:
- ✅ Conectar WiFi em <30 segundos
- ✅ Conectar MQTT automaticamente  
- ✅ Responder a comandos MQTT
- ✅ Publicar status a cada 5 minutos
- ✅ Detectar falha de energia corretamente
- ✅ **NÃO apresentar mais WDT timeout**

---

**Data:** 1 de outubro de 2025  
**Versão:** v1.1 - Correção WDT timeout  
**Autor:** HomeGuard System