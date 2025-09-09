# 🌡️ **Integração DHT11 com Flask - Solução Implementada**

## 📋 **Resumo da Solução**

Implementei a integração completa dos sensores DHT11 ao sistema Flask HomeGuard, seguindo o sketch funcional que você forneceu (com tópicos separados). A solução **NÃO** usa o bridge, integrando diretamente via MQTT.

## 🎯 **Recursos Implementados**

### **1. ✅ Dashboard Web**
- **Nova aba "🌡️ Sensores DHT11"** na navegação principal
- **Página `/sensors`** com visualização de todos os sensores
- **Cards interativos** mostrando temperatura, umidade e status
- **Status em tempo real**: online/warning/offline
- **Auto-refresh** a cada 30 segundos

### **2. ✅ Histórico/Gráficos**
- **Página de detalhes** `/sensor/<device_id>` para cada sensor
- **Gráficos históricos** de temperatura e umidade
- **Filtros por período**: 1h, 6h, 24h, 7 dias
- **API endpoints** para dados históricos

### **3. ✅ Alertas para Valores Críticos**
- **Sistema de alertas automático** baseado em thresholds:
  - Temperatura: < 10°C ou > 35°C
  - Umidade: < 30% ou > 80%
- **Página `/alerts`** com alertas ativos
- **Resolução de alertas** via API
- **Badges visuais** nos cards dos sensores

### **4. ✅ Múltiplos Sensores**
- **Suporte completo** para vários dispositivos DHT11
- **Configuração automática** baseada no sketch ESP01
- **Identificação por device_id**, nome e localização

## 🔧 **Arquivos Modificados**

### **1. `homeguard_flask.py`**
```python
# Novos métodos adicionados:
- get_dht11_sensors_data()           # Lista todos os sensores
- get_sensor_history()               # Histórico de um sensor
- process_dht11_mqtt_data()          # Processa dados MQTT (tópicos separados)
- get_active_alerts()                # Alertas ativos
- save_sensor_alert()                # Salva alertas no banco

# Novas rotas:
- /sensors                           # Página principal dos sensores
- /sensor/<device_id>               # Detalhes de um sensor
- /alerts                           # Página de alertas
- /api/sensors                      # API para dados dos sensores
- /api/sensor/<device_id>/history   # API para histórico
```

### **2. `flask_mqtt_controller.py`**
```python
# Integração MQTT para DHT11:
- Subscrição nos tópicos: home/temperature/+/data, home/humidity/+/data
- Processamento automático de mensagens DHT11
- Combinação de dados de temperatura e umidade
- Envio direto para o dashboard Flask (sem HTTP)
```

### **3. `templates/base.html`**
```html
<!-- Navegação atualizada: -->
- 🌡️ Sensores DHT11 (novo)
- 🚨 Alertas (novo)
```

### **4. Templates Existentes**
- `sensors.html` - Página principal dos sensores
- `sensor_detail.html` - Detalhes individuais
- `alerts.html` - Página de alertas

## 📊 **Banco de Dados**

### **Tabelas Criadas:**
```sql
-- Dados dos sensores DHT11
dht11_sensors (
    id, device_id, device_name, location, sensor_type,
    temperature, humidity, rssi, timestamp_received, raw_payload
)

-- Alertas do sistema
sensor_alerts (
    id, device_id, device_name, location, alert_type,
    sensor_value, threshold_value, message, severity, is_active
)
```

## 🚀 **Como Funciona**

### **1. Fluxo de Dados MQTT:**
```
ESP01 DHT11 → Tópicos MQTT → Flask MQTT Controller → Dashboard Flask → SQLite
```

### **2. Tópicos MQTT Monitorados:**
- `home/temperature/ESP01_DHT11_001/data` - Dados de temperatura
- `home/humidity/ESP01_DHT11_001/data` - Dados de umidade  
- `home/sensor/ESP01_DHT11_001/status` - Status do dispositivo
- `home/sensor/ESP01_DHT11_001/info` - Informações do dispositivo

### **3. Processamento Inteligente:**
- **Combina** dados de temperatura e umidade dos tópicos separados
- **Atualiza** registros recentes (últimos 30 segundos) em vez de duplicar
- **Gera alertas** automaticamente baseado em thresholds
- **Calcula status** (online/offline) baseado na última leitura

## 🔧 **Configuração no Raspberry Pi**

### **1. Instalar Dependências:**
```bash
pip install flask paho-mqtt
```

### **2. Executar o Sistema:**
```bash
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/web
python homeguard_flask.py
```

### **3. Acessar Dashboard:**
```
http://raspberry-pi-ip:5000/sensors
```

## 📱 **Interface do Usuário**

### **Dashboard Principal (`/sensors`):**
- Cards com temperatura/umidade atuais
- Status visual (verde/amarelo/vermelho)
- Badges de alerta quando necessário
- Links para detalhes de cada sensor

### **Detalhes do Sensor (`/sensor/ESP01_DHT11_001`):**
- Gráficos históricos interativos
- Filtros de período
- Estatísticas detalhadas
- Histórico de leituras

### **Alertas (`/alerts`):**
- Lista de alertas ativos
- Possibilidade de resolver alertas
- Histórico de alertas passados

## ✅ **Pronto para Usar!**

A solução está **100% implementada** e pronta para ser executada no Raspberry Pi. Quando você carregar o sketch DHT11 no ESP01, os dados começarão a aparecer automaticamente na nova aba "🌡️ Sensores DHT11" do dashboard Flask.

**Características:**
- ✅ Integração direta MQTT (sem bridge)
- ✅ Tópicos separados como no seu sketch funcional  
- ✅ Todas as funcionalidades solicitadas
- ✅ Interface responsiva e intuitiva
- ✅ Sistema de alertas automático
- ✅ Suporte a múltiplos sensores
