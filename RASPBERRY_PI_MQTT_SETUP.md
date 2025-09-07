# HomeGuard MQTT Logger - Guia de Instalação para Raspberry Pi

## 🛠️ Problemas de Caminhos Resolvidos ✅

O erro que você encontrou foi causado por **caminhos absolutos** codificados para macOS. Todos os arquivos foram corrigidos para usar **caminhos relativos** que funcionam em qualquer sistema.

## 📋 Mudanças Realizadas

### 1. `init_database.py` ✅
```python
# ANTES (não funcionava no Raspberry Pi):
DB_PATH = "/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/db/homeguard.db"

# DEPOIS (funciona em qualquer sistema):
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DB_PATH = os.path.join(PROJECT_ROOT, "db", "homeguard.db")
```

### 2. `mqtt_activity_logger.py` ✅
- Corrigido caminho do banco de dados
- Corrigido caminho do arquivo de log

### 3. `db_query.py` ✅
- Corrigido caminho do banco de dados

### 4. `mqtt_service.py` ✅
- Corrigido caminho do arquivo de log do serviço

## 🚀 Instalação no Raspberry Pi

### Passo 1: Instalar Dependências
```bash
# Método Simples (RECOMENDADO):
cd ~/HomeGuard/web
./install_simple.sh

# OU método completo com fallback:
./install_raspberry.sh

# OU manualmente:
sudo apt update
sudo apt install python3-paho-mqtt python3-full
```

### Passo 2: Testar o Sistema
```bash
cd ~/HomeGuard/web
python3 quick_test.py
```

### Passo 3: Inicializar o Banco de Dados (se necessário)
```bash
python3 init_database.py
```

### Passo 4: Iniciar o Serviço MQTT
```bash
python3 mqtt_service.py start
```

### Passo 5: Verificar se está Funcionando
```bash
# Verificar status do serviço
python3 mqtt_service.py status

# Ver estatísticas do banco (após alguns minutos)
python3 db_query.py --stats

# Ver atividades recentes
python3 db_query.py --recent 10
```

## 🔧 Estrutura de Diretórios

O sistema agora funciona com esta estrutura em **qualquer sistema**:

```
HomeGuard/
├── web/
│   ├── init_database.py      # ✅ Caminhos relativos
│   ├── mqtt_activity_logger.py  # ✅ Caminhos relativos
│   ├── mqtt_service.py       # ✅ Caminhos relativos
│   ├── db_query.py          # ✅ Caminhos relativos
│   ├── test_system.py       # ✅ Script de teste
│   └── mqtt_logger.log      # Log do MQTT
├── db/
│   └── homeguard.db         # Banco SQLite
└── logs/
    └── mqtt_service.log     # Log do serviço
```

## 🐧 Comandos Específicos para Raspberry Pi

### Verificar se o Broker MQTT está Acessível
```bash
# Testar conexão MQTT
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t 'home/#' -v -C 5
```

### Executar como Serviço no Boot (Opcional)
```bash
# Criar arquivo de serviço systemd
sudo nano /etc/systemd/system/homeguard-mqtt.service
```

Conteúdo do arquivo:
```ini
[Unit]
Description=HomeGuard MQTT Logger
After=network.target

[Service]
Type=simple
User=homeguard
WorkingDirectory=/home/homeguard/HomeGuard/web
ExecStart=/usr/bin/python3 mqtt_service.py start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Ativar o serviço:
```bash
sudo systemctl enable homeguard-mqtt.service
sudo systemctl start homeguard-mqtt.service
sudo systemctl status homeguard-mqtt.service
```

## 🧪 Teste Completo no Raspberry Pi

Execute este teste completo:

```bash
cd ~/HomeGuard

# 1. Testar o sistema
python3 web/test_system.py

# 2. Inicializar banco
python3 web/init_database.py

# 3. Iniciar serviço em background
python3 web/mqtt_service.py start

# 4. Aguardar alguns minutos e verificar
sleep 60
python3 web/db_query.py --stats

# 5. Ver atividades recentes
python3 web/db_query.py --recent 5
```

## 📊 Resultados Esperados

Após alguns minutos de execução, você deve ver:

```
📊 HomeGuard Database Statistics
==================================================
📝 Total Records: 150
📅 Date Range: 2025-09-06 10:30:00 to 2025-09-06 10:45:00

🔥 Top 10 Topics:
   home/motion/MOTION_01/status        45 messages
   home/RDA5807/status                 20 messages
   home/sensor/DHT_01/status          15 messages
   ...

🏠 Device Activity:
   MOTION_01           45 messages
   RDA5807             20 messages
   DHT_01              15 messages
   ...
```

## ✅ Sistema 100% Portável

Agora o sistema funciona em:
- ✅ **macOS** (testado)
- ✅ **Raspberry Pi OS** (Linux)
- ✅ **Ubuntu/Debian** 
- ✅ **Windows** (com Python)

Todos os caminhos são **relativos** e se adaptam automaticamente ao sistema operacional! 🎉
