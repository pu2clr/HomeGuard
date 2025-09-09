# Sistema de Monitoramento DHT11 - HomeGuard

## 📊 Dashboard Web Completo para Sensores DHT11

Este sistema expande o HomeGuard com suporte completo a sensores DHT11, oferecendo:

- **📊 Dashboard web interativo** para visualização de dados
- **📈 Histórico e gráficos** das medições de temperatura e umidade  
- **🚨 Sistema de alertas** para valores críticos
- **🔄 Suporte a múltiplos sensores** com identificação automática

## 🚀 Funcionalidades Implementadas

### 1. Dashboard Web Principal (`/sensors`)
- Visualização em tempo real de todos os sensores DHT11
- Cards interativos com temperatura, umidade, RSSI e status
- Detecção automática de alertas (temperatura/umidade fora dos limites)
- Indicadores visuais de status (online/warning/offline)
- Auto-refresh a cada 30 segundos

### 2. Páginas de Histórico (`/sensor/<device_id>`)
- Gráficos detalhados de temperatura e umidade
- Períodos configuráveis (1h, 6h, 24h, 3d, 7d)
- Estatísticas resumidas (médias, mín/máx, frequência)
- Tabela com dados brutos e deltas
- Exportação para CSV

### 3. Sistema de Alertas (`/alerts`)
- Alertas automáticos para temperaturas < 10°C ou > 35°C
- Alertas automáticos para umidade < 30% ou > 80%
- Classificação por severidade (Warning/Danger)
- Filtragem por tipo, severidade e dispositivo
- Notificações visuais e sonoras

### 4. APIs REST Completas
- `/api/sensors` - Dados de todos os sensores
- `/api/sensor/<id>/history` - Histórico de um sensor específico
- `/api/alerts` - Alertas ativos
- `/api/process_sensor_data` - Receber dados via MQTT
- `/api/resolve_alert` - Resolver alertas

### 5. Bridge MQTT-Flask
- Recepção automática de dados MQTT
- Processamento e validação de dados JSON
- Inserção automática no banco SQLite
- Geração automática de alertas
- Estatísticas e logs detalhados

## 🔧 Configuração e Uso

### 1. Estrutura do Banco de Dados

O sistema cria automaticamente duas novas tabelas:

```sql
-- Tabela para dados dos sensores DHT11
CREATE TABLE dht11_sensors (
    id INTEGER PRIMARY KEY,
    device_id TEXT NOT NULL,
    device_name TEXT NOT NULL,
    location TEXT NOT NULL,
    sensor_type TEXT NOT NULL,
    temperature REAL NOT NULL,
    humidity REAL NOT NULL,
    rssi INTEGER,
    uptime INTEGER,
    timestamp_received TEXT NOT NULL,
    raw_payload TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para alertas
CREATE TABLE sensor_alerts (
    id INTEGER PRIMARY KEY,
    device_id TEXT NOT NULL,
    device_name TEXT NOT NULL,
    location TEXT NOT NULL,
    alert_type TEXT NOT NULL,
    sensor_value REAL NOT NULL,
    threshold_value REAL NOT NULL,
    message TEXT NOT NULL,
    severity TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    timestamp_created TEXT NOT NULL,
    timestamp_resolved TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 2. Configuração dos Limites de Alerta

Os limites são configuráveis no arquivo `homeguard_flask.py`:

```python
self.alert_thresholds = {
    'temperature': {'min': 10, 'max': 35},  # °C
    'humidity': {'min': 30, 'max': 80}      # %
}
```

### 3. Formato MQTT Único

O sensor DHT11 deve enviar dados no tópico `home/sensor/{DEVICE_ID}/data` com payload JSON:

```json
{
    "device_id": "ESP01_DHT11_001",
    "device_name": "DHT11 Sala",
    "location": "Sala de Estar",
    "sensor_type": "DHT11",
    "temperature": 24.5,
    "temperature_unit": "C",
    "humidity": 62.3,
    "humidity_unit": "%",
    "rssi": -67,
    "uptime": 12345,
    "timestamp": "12345"
}
```

**Importante:** Apenas este formato é suportado. Formatos antigos com tópicos separados (`home/temperature/` e `home/humidity/`) foram descontinuados.

### 4. Executar o Sistema

1. **Iniciar o servidor Flask:**
```bash
cd web/
python homeguard_flask.py
```

2. **Iniciar o bridge MQTT (em outro terminal):**
```bash
cd web/
python mqtt_dht11_bridge.py
```

3. **Acessar o dashboard:**
- Dashboard principal: http://localhost:5000
- Sensores DHT11: http://localhost:5000/sensors
- Alertas: http://localhost:5000/alerts

## 📱 Interface do Usuário

### Dashboard de Sensores
- **Cards interativos** com dados em tempo real
- **Códigos de cores** para status e alertas
- **Badges animados** para alertas críticos
- **Links diretos** para histórico detalhado

### Páginas de Histórico  
- **Gráficos Chart.js** responsivos
- **Seletor de período** intuitivo
- **Estatísticas calculadas** automaticamente
- **Exportação CSV** com um clique

### Sistema de Alertas
- **Alertas categorizados** por severidade
- **Filtros avançados** por tipo/dispositivo
- **Resolução manual** de alertas
- **Sons de notificação** para alertas críticos

## 🔧 Configurações Avançadas

### Personalizar Limites de Alerta

Edite o arquivo `homeguard_flask.py` e modifique:

```python
self.alert_thresholds = {
    'temperature': {'min': 15, 'max': 30},  # Limites personalizados
    'humidity': {'min': 40, 'max': 70}      # Limites personalizados
}
```

### Configurar MQTT

Edite o arquivo `mqtt_dht11_bridge.py`:

```python
MQTT_BROKER = "seu-broker.local"  # IP do broker MQTT
MQTT_PORT = 1883                  # Porta MQTT
FLASK_API_URL = "http://localhost:5000/api/process_sensor_data"
```

### Adicionar Novos Sensores

1. Configure o ESP01 com o código DHT11 existente
2. Certifique-se que o `device_id` seja único
3. O sensor aparecerá automaticamente no dashboard

## 📊 Monitoramento

### Logs do Bridge MQTT

O bridge fornece logs detalhados:

```
2024-01-10 15:30:45 - INFO - ✅ Conectado ao broker MQTT
2024-01-10 15:30:45 - INFO - 📡 Inscrito no tópico: home/sensor/+/data
2024-01-10 15:31:02 - INFO - ✅ Processado sensor ESP01_DHT11_001: Temp=24.5°C, Umid=62.3%
```

### Estatísticas do Sistema

O bridge mostra estatísticas a cada 5 minutos:
- Tempo ativo
- Mensagens MQTT recebidas
- Mensagens processadas  
- API calls (sucesso/falha)

## 🎯 Recursos Principais

### ✅ Implementado
- [x] Dashboard web completo
- [x] Histórico e gráficos detalhados
- [x] Sistema de alertas automáticos
- [x] Suporte a múltiplos sensores
- [x] APIs REST completas
- [x] Bridge MQTT-Flask
- [x] Interface responsiva
- [x] Exportação de dados
- [x] Notificações visuais/sonoras

### 🚀 Próximas Melhorias
- [ ] Notificações email/SMS
- [ ] Dashboard em tempo real (WebSocket)
- [ ] Relatórios PDF automáticos
- [ ] Integração com outros sensores
- [ ] App móvel

## 📝 Uso Prático

1. **Monitoramento residencial:** Temperatura/umidade de ambientes
2. **Estufas/Jardins:** Controle de condições de plantas
3. **Laboratórios:** Monitoramento de condições controladas
4. **Armazéns:** Controle de umidade para preservação
5. **Servidores:** Monitoramento térmico de equipamentos

## 🤝 Integração

Este sistema se integra perfeitamente com:
- Sistema de relés HomeGuard existente
- Sensores de movimento PIR
- Outros dispositivos ESP01/ESP32
- Sistemas de automação residencial
- Plataformas IoT externas via API

---

**🎉 O sistema DHT11 está pronto para uso!** 

Basta inicializar os sensores, executar o Flask e o bridge MQTT, e começar a monitorar temperatura e umidade com interface web completa e alertas inteligentes.
