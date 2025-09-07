# Scripts do HomeGuard

Esta pasta contém scripts utilitários para configurar e gerenciar o sistema HomeGuard com SQLite.

## 📁 Estrutura

```
scripts/
├── README.md                     # Esta documentação
├── install_sqlite.sh            # Instalação do SQLite no Raspberry Pi
├── motion_monitor_sqlite.py      # Monitor MQTT com banco SQLite
├── db_utility.py                # Utilitário de gerenciamento do banco
└── test_sqlite_system.py        # Teste do sistema SQLite
```

## 🚀 Instalação Inicial

### 1. Instalar SQLite no Raspberry Pi

```bash
# Tornar executável e executar
chmod +x scripts/install_sqlite.sh
./scripts/install_sqlite.sh
```

Este script instala:
- SQLite3 e bibliotecas de desenvolvimento
- Python 3 e pip
- Biblioteca paho-mqtt
- Verifica todas as instalações

### 2. Testar o Sistema

```bash
# Testar sistema SQLite
python3 scripts/test_sqlite_system.py
```

Este teste verifica:
- ✅ Criação do banco de dados
- ✅ Estrutura das tabelas e índices
- ✅ Inserção de dados de teste
- ✅ Consultas de dados
- ✅ Funcionamento do utilitário

## 📊 Scripts de Monitoramento

### motion_monitor_sqlite.py

Monitor principal que recebe dados MQTT e armazena no SQLite.

**Uso:**
```bash
python3 scripts/motion_monitor_sqlite.py
```

**Configuração:**
```python
# MQTT Broker
BROKER_HOST = "192.168.1.102"
BROKER_PORT = 1883
USERNAME = "homeguard"
PASSWORD = "homeguard"

# Banco de dados
DB_PATH = './db/homeguard.db'
```

**Funcionalidades:**
- ✅ Conexão MQTT com reconexão automática
- ✅ Armazenamento em SQLite com índices
- ✅ Tratamento de fuso horário (Brasil/Brasília)
- ✅ Log detalhado de eventos
- ✅ Estatísticas em tempo real

### db_utility.py

Utilitário para gerenciar e consultar o banco de dados.

**Comandos disponíveis:**
```bash
# Ver estatísticas gerais
python3 scripts/db_utility.py --stats

# Ver últimos 50 eventos
python3 scripts/db_utility.py --recent 50

# Ver eventos por sensor
python3 scripts/db_utility.py --sensor ESP01_001

# Ver eventos por status
python3 scripts/db_utility.py --status DETECTED

# Ver eventos de hoje
python3 scripts/db_utility.py --today

# Limpar registros antigos (mais de 30 dias)
python3 scripts/db_utility.py --cleanup 30

# Ver esquema do banco
python3 scripts/db_utility.py --schema
```

## 🗄️ Estrutura do Banco de Dados

### Tabela: motion_events

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | INTEGER PRIMARY KEY | ID único do evento |
| `sensor_id` | TEXT NOT NULL | ID do sensor (ex: ESP01_001) |
| `sensor_type` | TEXT NOT NULL | Tipo do sensor (ex: PIR) |
| `timestamp` | TEXT NOT NULL | Data/hora em formato legível |
| `unix_timestamp` | INTEGER NOT NULL | Timestamp Unix |
| `status` | TEXT NOT NULL | Status do evento (DETECTED/CLEAR) |
| `location` | TEXT | Localização do sensor |
| `raw_message` | TEXT | Mensagem MQTT original |

### Índices Criados

```sql
-- Para consultas por timestamp
CREATE INDEX idx_motion_timestamp ON motion_events(unix_timestamp);

-- Para consultas por sensor
CREATE INDEX idx_motion_sensor_id ON motion_events(sensor_id);

-- Para consultas por status
CREATE INDEX idx_motion_status ON motion_events(status);
```

## 📡 Formato das Mensagens MQTT

**Tópico:** `homeguard/motion`

**Formato:** `SENSOR_ID|SENSOR_TYPE|STATUS|LOCATION`

**Exemplos:**
```
ESP01_001|PIR|DETECTED|SALA
ESP01_002|PIR|CLEAR|COZINHA
ESP01_003|PIR|DETECTED|QUARTO
```

## 🕐 Configuração de Fuso Horário

O sistema está configurado para o fuso horário do Brasil (UTC-3):

**No Arduino:**
```cpp
// Configurar fuso horário para Brasil (UTC-3)
configTime(-3 * 3600, 0, "pool.ntp.org", "time.nist.gov");
```

**No Python:**
```python
# Fuso horário Brasil/Brasília
import zoneinfo
TIMEZONE = zoneinfo.ZoneInfo('America/Sao_Paulo')
```

## 🔧 Monitoramento e Manutenção

### Verificar Status do Sistema

```bash
# Verificar se o banco existe
ls -la db/homeguard.db

# Ver estatísticas
python3 scripts/db_utility.py --stats

# Testar sistema completo
python3 scripts/test_sqlite_system.py
```

### Logs de Execução

O `motion_monitor_sqlite.py` gera logs detalhados:

```
2024-01-15 10:30:45 - INFO - Conectado ao broker MQTT
2024-01-15 10:30:46 - INFO - Banco de dados inicializado
2024-01-15 10:31:00 - INFO - Movimento detectado: ESP01_001 em SALA
2024-01-15 10:31:15 - INFO - Status: 1 sensores ativos, 1 eventos hoje
```

### Manutenção do Banco

```bash
# Limpar registros antigos (mais de 30 dias)
python3 scripts/db_utility.py --cleanup 30

# Backup do banco
cp db/homeguard.db db/backup_$(date +%Y%m%d_%H%M%S).db

# Verificar integridade
sqlite3 db/homeguard.db "PRAGMA integrity_check;"
```

## 🚨 Solução de Problemas

### Erro de Conexão MQTT

1. Verificar se o broker está rodando
2. Confirmar IP, porta, usuário e senha
3. Testar conectividade de rede

### Erro no Banco SQLite

1. Verificar permissões da pasta `db/`
2. Executar teste: `python3 scripts/test_sqlite_system.py`
3. Verificar integridade: `sqlite3 db/homeguard.db "PRAGMA integrity_check;"`

### Problemas de Fuso Horário

1. Verificar configuração NTP no Arduino
2. Confirmar timezone no Python
3. Testar com: `python3 -c "from datetime import datetime; import zoneinfo; print(datetime.now(zoneinfo.ZoneInfo('America/Sao_Paulo')))"`

## 📈 Estatísticas e Relatórios

O sistema oferece várias opções de relatório:

```bash
# Estatísticas gerais
python3 scripts/db_utility.py --stats

# Eventos por dia
sqlite3 db/homeguard.db "SELECT date(timestamp) as dia, COUNT(*) as eventos FROM motion_events GROUP BY date(timestamp) ORDER BY dia DESC LIMIT 7;"

# Sensores mais ativos
sqlite3 db/homeguard.db "SELECT sensor_id, location, COUNT(*) as eventos FROM motion_events GROUP BY sensor_id, location ORDER BY eventos DESC;"
```

## 🔄 Integração com Arduino

Para usar com os sketches Arduino, configure:

1. **WiFi e MQTT** no sketch
2. **Fuso horário** com NTP
3. **Formato de mensagem** correto
4. **ID único** para cada sensor

Exemplo no Arduino:
```cpp
// Enviar dados para MQTT
String message = String(SENSOR_ID) + "|PIR|DETECTED|SALA";
client.publish("homeguard/motion", message.c_str());
```
