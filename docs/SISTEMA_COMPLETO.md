# 🏠 HomeGuard Motion Sensor System - SISTEMA COMPLETO

## ✅ **PROBLEMA RESOLVIDO**

Você agora tem um **sistema completo** para compilar e fazer upload de firmware para **5 sensores de movimento** em locais diferentes usando **arduino-cli** com parâmetros configuráveis.

## 🎯 **SENSORES CONFIGURADOS**

| # | Local | IP | MQTT Topic | Descrição |
|---|-------|----|-----------| ----------|
| 1 | **Garagem** | 192.168.18.201 | `motion_garagem` | Detecção na garagem |
| 2 | **Área Serviço** | 192.168.18.202 | `motion_area_servico` | Monitoramento área de serviço |
| 3 | **Varanda** | 192.168.18.203 | `motion_varanda` | Detecção na varanda |
| 4 | **Mezanino** | 192.168.18.204 | `motion_mezanino` | Monitoramento do mezanino |
| 5 | **Ad-Hoc** | 192.168.18.205 | `motion_adhoc` | Localização flexível |

## 🚀 **COMO USAR (3 FORMAS)**

### 1️⃣ **Configuração Inicial (Uma vez só)**
```bash
# Instala arduino-cli e todas as dependências
./scripts/setup-dev-environment.sh
```

### 2️⃣ **Upload Individual (Interativo)**
```bash
# Script pergunta qual sensor e qual porta USB
./scripts/compile-motion-sensors.sh
```
**O script vai:**
- ✅ Mostrar menu dos 5 sensores + opção customizada
- ✅ Detectar portas USB disponíveis
- ✅ Compilar com parâmetros específicos (IP, local, MQTT)
- ✅ Fazer upload direto para ESP-01S
- ✅ Mostrar instruções pós-upload

### 3️⃣ **Compilação em Lote (Todos de uma vez)**
```bash
# Compila os 5 sensores simultaneamente
./scripts/batch-compile-sensors.sh
```
**Resultado:**
- ✅ 5 arquivos `.bin` prontos em `firmware/`
- ✅ Instruções detalhadas em `UPLOAD_INSTRUCTIONS.md`
- ✅ Script de teste automático criado

## 🔧 **SISTEMA TÉCNICO**

### **Template Inteligente**
- ✅ Arquivo único: `motion_detector_template.ino`
- ✅ Configuração via **#define** durante compilação
- ✅ **Sem edição manual** de código necessária

### **Parâmetros de Compilação**
```cpp
// Definidos automaticamente pelo script
#define DEVICE_LOCATION "Garagem"           // Nome do local
#define DEVICE_IP_LAST_OCTET 201           // IP: 192.168.18.201  
#define MQTT_TOPIC_SUFFIX "motion_garagem" // Tópico MQTT
```

### **Build Automático**
```bash
arduino-cli compile \
  --fqbn esp8266:esp8266:generic \
  --build-property compiler.cpp.extra_flags="-DDEVICE_LOCATION=Garagem -DDEVICE_IP_LAST_OCTET=201 -DMQTT_TOPIC_SUFFIX=motion_garagem" \
  motion_detector_template.ino
```

## 📡 **ESTRUTURA MQTT**

Cada sensor publica em sua própria árvore de tópicos:

```
home/motion_garagem/        # Exemplo para garagem
├── cmnd                    # Comandos (STATUS, RESET, SENSITIVITY_*)
├── status                  # Status do dispositivo (JSON)
├── motion                  # Eventos de movimento (JSON)
├── heartbeat              # Keep-alive a cada 60s
└── config                 # Confirmações de configuração
```

## 🧪 **TESTES E VALIDAÇÃO**

### **Teste Individual**
```bash
# Verificar conectividade
ping 192.168.18.201

# Verificar MQTT
mosquitto_pub -h 192.168.18.236 -t "home/motion_garagem/cmnd" -m "STATUS" -u homeguard -P pu2clr123456
```

### **Teste Todos os Sensores**
```bash
# Script automático
./scripts/test-all-motion-sensors.sh
```

### **Monitoramento Contínuo**
```bash
# Ver todos os eventos de movimento
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion_+/motion" -v
```

## 🔄 **PROCESSO DE UPLOAD**

### **Preparação ESP-01S**
1. ⚡ Conectar GPIO0 ao GND (modo programação)
2. 🔌 Conectar ao adaptador USB-serial
3. 🔄 Religar o dispositivo

### **Comando Único**
```bash
./scripts/compile-motion-sensors.sh
```
**Interface interativa:**
```
🏠 HomeGuard Motion Sensor Configuration

Available sensors:
  1. Garagem         (IP: 192.168.18.201, Topic: motion_garagem)
  2. Area_Servico    (IP: 192.168.18.202, Topic: motion_area_servico) 
  3. Varanda         (IP: 192.168.18.203, Topic: motion_varanda)
  4. Mezanino        (IP: 192.168.18.204, Topic: motion_mezanino)
  5. Ad_Hoc          (IP: 192.168.18.205, Topic: motion_adhoc)
  6. Custom configuration

Select sensor (1-6): █
```

### **Seleção de Porta**
```
Available USB ports:
  1. /dev/tty.usbserial-0001
  2. /dev/tty.SLAB_USBtoUART

Enter USB port: █
```

## 📁 **ARQUIVOS CRIADOS**

```
HomeGuard/
├── scripts/
│   ├── setup-dev-environment.sh      # ✅ Setup inicial
│   ├── compile-motion-sensors.sh     # ✅ Upload interativo  
│   ├── batch-compile-sensors.sh      # ✅ Compilação em lote
│   └── test-all-motion-sensors.sh    # ✅ Teste automático
├── source/esp01/mqtt/motion_detector/
│   └── motion_detector_template.ino  # ✅ Template configurável
├── firmware/                         # ✅ Arquivos .bin compilados
├── docs/
│   └── MOTION_SENSOR_COMPILER.md     # ✅ Documentação completa
└── UPLOAD_INSTRUCTIONS.md           # ✅ Instruções detalhadas
```

## 🎉 **EXEMPLO DE USO COMPLETO**

```bash
# 1. Setup inicial (uma vez)
./scripts/setup-dev-environment.sh

# 2. Upload do sensor da garagem
./scripts/compile-motion-sensors.sh
# Escolher: 1 (Garagem)
# Porta: /dev/tty.usbserial-0001
# ✅ Compilação e upload automáticos

# 3. Testar o sensor
ping 192.168.18.201
mosquitto_pub -h 192.168.18.236 -t "home/motion_garagem/cmnd" -m "STATUS" -u homeguard -P pu2clr123456

# 4. Monitorar eventos
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/motion_garagem/motion" -v
```

## 🔥 **CARACTERÍSTICAS AVANÇADAS**

### **✅ Detecção Automática de Portas USB**
### **✅ Compilação com Parâmetros Únicos**  
### **✅ Upload Direto via arduino-cli**
### **✅ Validação Pós-Upload**
### **✅ Testes Automatizados**
### **✅ Documentação Auto-Gerada**
### **✅ Suporte Multi-Plataforma (macOS/Linux)**
### **✅ Configuração Customizada**

## 🏆 **RESULTADO FINAL**

Você tem agora um **sistema industrial** para:
- ⚡ **Compilar** firmwares únicos para cada local
- 🎯 **Configurar** IPs e tópicos MQTT automaticamente  
- 📤 **Fazer upload** via linha de comando
- 🧪 **Testar** conectividade e funcionamento
- 📊 **Monitorar** todos os sensores simultaneamente
- 🔧 **Manter** facilmente o sistema

**Sistema 100% funcional e pronto para produção!** 🚀
