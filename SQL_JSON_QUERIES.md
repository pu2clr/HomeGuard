# Consultas SQL para Análise de Dados JSON no HomeGuard

## 🗃️ Estrutura da Tabela
```sql
-- Estrutura da tabela activity
CREATE TABLE activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT (datetime('now', 'utc')),
    topic TEXT,
    message TEXT
);
```

## 📊 Consultas SQL para Dados de Temperatura

### 1. Extrair dados de temperatura do ESP01_DHT22_BRANCO
```sql
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.temperature') as temperature,
    json_extract(message, '$.unit') as unit,
    json_extract(message, '$.rssi') as rssi,
    json_extract(message, '$.uptime') as uptime
FROM activity 
WHERE topic = 'home/temperature/ESP01_DHT22_BRANCO/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL
ORDER BY created_at DESC
LIMIT 50;
```

### 2. Estatísticas de temperatura das últimas 24 horas
```sql
SELECT 
    json_extract(message, '$.device_id') as device,
    json_extract(message, '$.location') as location,
    COUNT(*) as total_readings,
    ROUND(AVG(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as avg_temp,
    ROUND(MIN(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as min_temp,
    ROUND(MAX(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as max_temp,
    ROUND(AVG(CAST(json_extract(message, '$.rssi') AS INTEGER)), 0) as avg_rssi
FROM activity 
WHERE topic LIKE 'home/temperature/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
GROUP BY json_extract(message, '$.device_id')
ORDER BY avg_temp DESC;
```

### 3. Temperaturas por hora (média horária)
```sql
SELECT 
    strftime('%Y-%m-%d %H:00', created_at) as hour,
    json_extract(message, '$.device_id') as device,
    COUNT(*) as readings,
    ROUND(AVG(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as avg_temp,
    ROUND(MIN(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as min_temp,
    ROUND(MAX(CAST(json_extract(message, '$.temperature') AS REAL)), 2) as max_temp
FROM activity 
WHERE topic = 'home/temperature/ESP01_DHT22_BRANCO/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
GROUP BY strftime('%Y-%m-%d %H:00', created_at)
ORDER BY hour DESC;
```

### 4. Encontrar temperaturas extremas
```sql
-- Temperaturas mais altas
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device,
    json_extract(message, '$.location') as location,
    CAST(json_extract(message, '$.temperature') AS REAL) as temperature,
    json_extract(message, '$.unit') as unit
FROM activity 
WHERE topic LIKE 'home/temperature/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL
    AND created_at >= datetime('now', '-7 days')
ORDER BY CAST(json_extract(message, '$.temperature') AS REAL) DESC
LIMIT 10;

-- Temperaturas mais baixas
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device,
    json_extract(message, '$.location') as location,
    CAST(json_extract(message, '$.temperature') AS REAL) as temperature,
    json_extract(message, '$.unit') as unit
FROM activity 
WHERE topic LIKE 'home/temperature/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL
    AND created_at >= datetime('now', '-7 days')
ORDER BY CAST(json_extract(message, '$.temperature') AS REAL) ASC
LIMIT 10;
```

## 🚶 Consultas para Sensores de Movimento

### 5. Atividade de movimento por dispositivo
```sql
SELECT 
    json_extract(message, '$.device_id') as device,
    json_extract(message, '$.location') as location,
    COUNT(*) as total_events,
    SUM(CASE WHEN json_extract(message, '$.motion_detected') = 1 THEN 1 ELSE 0 END) as detections,
    ROUND(
        SUM(CASE WHEN json_extract(message, '$.motion_detected') = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) as detection_rate_percent
FROM activity 
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 1
    AND json_extract(message, '$.device_id') IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
GROUP BY json_extract(message, '$.device_id')
ORDER BY detections DESC;
```

## 📻 Consultas para RDA5807 (Rádio)

### 6. Frequências mais utilizadas
```sql
SELECT 
    CAST(json_extract(message, '$.frequency') AS REAL) as frequency,
    COUNT(*) as usage_count,
    MAX(created_at) as last_used,
    AVG(CAST(json_extract(message, '$.volume') AS INTEGER)) as avg_volume
FROM activity 
WHERE topic LIKE 'home/RDA5807/%'
    AND json_valid(message) = 1
    AND json_extract(message, '$.frequency') IS NOT NULL
    AND created_at >= datetime('now', '-7 days')
GROUP BY CAST(json_extract(message, '$.frequency') AS REAL)
ORDER BY usage_count DESC
LIMIT 20;
```

## 🔍 Consultas Genéricas para Exploração

### 7. Listar todos os tipos de dispositivos
```sql
SELECT 
    DISTINCT json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.location') as location,
    COUNT(*) as message_count,
    MAX(created_at) as last_seen
FROM activity 
WHERE json_valid(message) = 1
    AND json_extract(message, '$.device_id') IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
GROUP BY json_extract(message, '$.device_id')
ORDER BY message_count DESC;
```

### 8. Buscar qualquer campo JSON específico
```sql
-- Exemplo: buscar todos os valores de RSSI
SELECT 
    created_at,
    topic,
    json_extract(message, '$.device_id') as device,
    CAST(json_extract(message, '$.rssi') AS INTEGER) as rssi
FROM activity 
WHERE json_valid(message) = 1
    AND json_extract(message, '$.rssi') IS NOT NULL
    AND created_at >= datetime('now', '-6 hours')
ORDER BY rssi ASC
LIMIT 50;
```

### 9. Análise de uptime dos dispositivos
```sql
SELECT 
    json_extract(message, '$.device_id') as device,
    json_extract(message, '$.location') as location,
    MAX(CAST(json_extract(message, '$.uptime') AS INTEGER)) as max_uptime_seconds,
    ROUND(MAX(CAST(json_extract(message, '$.uptime') AS INTEGER)) / 3600.0, 2) as max_uptime_hours,
    COUNT(*) as total_reports,
    MAX(created_at) as last_report
FROM activity 
WHERE json_valid(message) = 1
    AND json_extract(message, '$.uptime') IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
GROUP BY json_extract(message, '$.device_id')
ORDER BY max_uptime_seconds DESC;
```

### 10. Criar view para facilitar consultas
```sql
-- Criar uma view para dados de temperatura
CREATE VIEW temperature_data AS
SELECT 
    id,
    created_at,
    topic,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    CAST(json_extract(message, '$.temperature') AS REAL) as temperature,
    json_extract(message, '$.unit') as unit,
    CAST(json_extract(message, '$.rssi') AS INTEGER) as rssi,
    CAST(json_extract(message, '$.uptime') AS INTEGER) as uptime
FROM activity 
WHERE topic LIKE 'home/temperature/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL;

-- Agora pode usar a view para consultas mais simples:
SELECT * FROM temperature_data 
WHERE device_id = 'ESP01_DHT22_BRANCO' 
ORDER BY created_at DESC 
LIMIT 10;
```

## 🚀 Como Executar as Consultas

### No terminal:
```bash
# Conectar ao banco SQLite
sqlite3 ~/HomeGuard/db/homeguard.db

# Executar consulta
.mode column
.headers on
SELECT created_at, json_extract(message, '$.temperature') as temp 
FROM activity 
WHERE topic = 'home/temperature/ESP01_DHT22_BRANCO/data' 
LIMIT 5;
```

### Em Python:
```python
import sqlite3
import json

conn = sqlite3.connect('~/HomeGuard/db/homeguard.db')
cursor = conn.cursor()

query = """
SELECT 
    created_at,
    json_extract(message, '$.temperature') as temperature
FROM activity 
WHERE topic = 'home/temperature/ESP01_DHT22_BRANCO/data'
    AND json_valid(message) = 1
ORDER BY created_at DESC 
LIMIT 10
"""

results = cursor.execute(query).fetchall()
for row in results:
    print(f"Time: {row[0]}, Temp: {row[1]}°C")
```

## 💡 Dicas Importantes

1. **Sempre use `json_valid(message) = 1`** para garantir JSON válido
2. **Use `CAST(...AS REAL/INTEGER)`** para converter tipos de dados
3. **`json_extract(message, '$.campo')`** para extrair campos específicos
4. **Índices podem melhorar performance** em tabelas grandes:
   ```sql
   CREATE INDEX idx_activity_json_temp ON activity(json_extract(message, '$.temperature')) 
   WHERE json_valid(message) = 1;
   ```

## 🔧 Correção de Dados Malformados

### Identificar JSON inválido
```sql
-- Ver quantos registros têm JSON inválido
SELECT 
    topic,
    COUNT(*) as invalid_count
FROM activity 
WHERE json_valid(message) = 0
GROUP BY topic
ORDER BY invalid_count DESC;
```

### Ver mensagens malformadas
```sql
-- Examinar mensagens problemáticas
SELECT id, topic, message 
FROM activity 
WHERE json_valid(message) = 0 
LIMIT 5;
```

### Corrigir padrão comum dos sensores de movimento
```sql
-- Corrigir quotes duplos consecutivos (backup primeiro!)
UPDATE activity 
SET message = REPLACE(message, '""sensor_type"', '","sensor_type"')
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0;
```

**⚠️ Sempre faça backup antes de correções em massa!**  
**Consulte o arquivo `FIX_MALFORMED_JSON.md` para procedimentos detalhados.**

Essas consultas SQL permitem análises ad-hoc diretas no banco sem precisar de scripts Python! 🎯
