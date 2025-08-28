# Migração HomeGuard: SQLite para MySQL

## 📋 Visão Geral

Este documento detalha como migrar o HomeGuard Dashboard do SQLite para MySQL, mantendo todas as funcionalidades e estruturas de dados existentes.

## 🔄 Arquivos Criados

### 1. `homeguard_flask_mysql.py`
- **Propósito**: Versão do Flask app adaptada para MySQL
- **Diferenças**: 
  - Usa `mysql.connector` em vez de `sqlite3`
  - Sintaxe SQL adaptada para MySQL
  - Gerenciamento de conexões melhorado
  - Suporte a configuração via JSON

### 2. `install_mysql_homeguard.sh`
- **Propósito**: Script de instalação automática do MySQL
- **Funcionalidades**:
  - Instalação e configuração do MySQL Server
  - Criação de usuário e database
  - Configuração de acesso remoto
  - Criação das tabelas necessárias

### 3. `homeguard_mysql_config.json`
- **Propósito**: Arquivo de configuração de conexão MySQL
- **Criado automaticamente** pelo script de instalação

## 🚀 Passos de Migração

### Passo 1: Instalação do MySQL
1. **Conectar ao Raspberry Pi 4**:
```bash
ssh pi@IP_DO_RASPBERRY
```

2. **Baixar arquivos**:
```bash
git pull  # ou copiar os arquivos manualmente
```

3. **Executar script de instalação**:
```bash
cd /home/pi/HomeGuard
chmod +x install_mysql_homeguard.sh
./install_mysql_homeguard.sh
```

4. **Seguir prompts**:
   - Definir senha do root MySQL
   - Definir senha do usuário homeguard
   - Confirmar configurações

### Passo 2: Migração de Dados (Opcional)

Se você tem dados importantes no SQLite:

1. **Exportar dados do SQLite**:
```bash
cd /home/pi/HomeGuard
python3 migrate_sqlite_to_mysql.py
```

2. **Verificar migração**:
```bash
mysql -u homeguard -p -e "USE homeguard; SELECT COUNT(*) FROM motion_sensors;"
```

### Passo 3: Configurar Nova Aplicação

1. **Instalar dependências Python**:
```bash
pip3 install mysql-connector-python flask
```

2. **Testar conexão**:
```bash
cd /home/pi/HomeGuard/web
python3 -c "
from homeguard_flask_mysql import MySQLHomeGuardDashboard
dashboard = MySQLHomeGuardDashboard()
print('Conexão MySQL:', 'OK' if dashboard.get_db_connection() else 'FALHA')
"
```

### Passo 4: Executar Nova Aplicação

1. **Parar aplicação SQLite** (se estiver rodando):
```bash
pkill -f homeguard_flask.py
```

2. **Iniciar aplicação MySQL**:
```bash
cd /home/pi/HomeGuard/web
python3 homeguard_flask_mysql.py
```

3. **Verificar funcionamento**:
   - Acessar: `http://IP_DO_RASPBERRY:5000`
   - Verificar dashboard, eventos, sensores

## 🔧 Diferenças de Implementação

### Conexão de Banco
```python
# SQLite (antigo)
conn = sqlite3.connect('db_path')

# MySQL (novo)
conn = mysql.connector.connect(
    host='localhost',
    database='homeguard',
    user='homeguard', 
    password='senha'
)
```

### Sintaxe SQL Adaptada
```sql
-- SQLite
SELECT date('now')
WHERE datetime(timestamp) >= datetime('now', '-1 day')

-- MySQL  
SELECT CURDATE()
WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 1 DAY)
```

### Tipos de Dados
| SQLite | MySQL | Observações |
|--------|-------|-------------|
| `INTEGER PRIMARY KEY AUTOINCREMENT` | `INT PRIMARY KEY AUTO_INCREMENT` | Chave primária |
| `TEXT` | `VARCHAR(255)` ou `TEXT` | Textos |
| `REAL` | `DECIMAL(5,2)` | Números decimais |
| `BOOLEAN` | `BOOLEAN` | Valores booleanos |
| `DATETIME DEFAULT CURRENT_TIMESTAMP` | `TIMESTAMP DEFAULT CURRENT_TIMESTAMP` | Timestamps |

## 📊 Estrutura das Tabelas MySQL

### motion_sensors
```sql
CREATE TABLE motion_sensors (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    motion_detected BOOLEAN NOT NULL,
    rssi INT,
    uptime INT,
    battery_level DECIMAL(5,2),
    timestamp_received DATETIME NOT NULL,
    unix_timestamp BIGINT,
    raw_payload TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### dht11_sensors
```sql
CREATE TABLE dht11_sensors (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    sensor_type VARCHAR(50) NOT NULL,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    rssi INT,
    uptime INT,
    timestamp_received DATETIME NOT NULL,
    raw_payload TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### sensor_alerts
```sql
CREATE TABLE sensor_alerts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    alert_type VARCHAR(100) NOT NULL,
    sensor_value DECIMAL(8,2) NOT NULL,
    threshold_value DECIMAL(8,2) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    timestamp_created DATETIME NOT NULL,
    timestamp_resolved DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🔐 Configuração de Segurança

### Arquivo de Configuração
```json
{
    "mysql": {
        "host": "localhost",
        "port": 3306,
        "database": "homeguard",
        "user": "homeguard",
        "password": "sua_senha_aqui",
        "charset": "utf8mb4",
        "autocommit": true
    }
}
```

### Permissões Recomendadas
```bash
# Arquivo de configuração
chmod 600 ~/homeguard_mysql_config.json

# Apenas proprietário pode ler
chown pi:pi ~/homeguard_mysql_config.json
```

## 📈 Vantagens da Migração

### Performance
- ✅ **Melhor concorrência**: MySQL suporta múltiplas conexões simultâneas
- ✅ **Índices otimizados**: Performance superior em consultas complexas  
- ✅ **Cache inteligente**: InnoDB buffer pool para cache automático
- ✅ **Escalabilidade**: Suporte a grandes volumes de dados

### Recursos
- ✅ **Acesso remoto**: Conexão de múltiplas aplicações
- ✅ **Backup avançado**: Ferramentas nativas de backup/restore
- ✅ **Monitoramento**: Métricas detalhadas de performance
- ✅ **Replicação**: Possibilidade de réplicas para alta disponibilidade

### Manutenção
- ✅ **Logs detalhados**: Sistema de logs robusto
- ✅ **Ferramentas de admin**: phpMyAdmin, MySQL Workbench
- ✅ **Otimização automática**: Auto-tuning de queries
- ✅ **Integridade**: Verificação automática de integridade

## 🆘 Troubleshooting

### Problema: Conexão Falha
```bash
# Verificar se MySQL está rodando
sudo systemctl status mysql

# Verificar logs de erro
sudo tail -f /var/log/mysql/error.log

# Testar conexão manual
mysql -u homeguard -p -h localhost
```

### Problema: Performance Baixa
```sql
-- Verificar queries lentas
SHOW PROCESSLIST;

-- Analisar performance de query específica
EXPLAIN SELECT * FROM motion_sensors WHERE device_id = 'ESP123';

-- Verificar índices
SHOW INDEX FROM motion_sensors;
```

### Problema: Migração de Dados
```bash
# Verificar integridade dos dados
mysql -u homeguard -p -e "
USE homeguard; 
SELECT 
    'motion_sensors' as table_name, COUNT(*) as records 
FROM motion_sensors 
UNION 
SELECT 
    'dht11_sensors', COUNT(*) 
FROM dht11_sensors;
"
```

## 🔄 Rollback para SQLite

Se necessário voltar ao SQLite:

1. **Parar aplicação MySQL**:
```bash
pkill -f homeguard_flask_mysql.py
```

2. **Restaurar aplicação SQLite**:
```bash
cd /home/pi/HomeGuard/web
python3 homeguard_flask.py
```

3. **Recuperar dados** (se necessário):
```bash
# Exportar do MySQL para SQLite
python3 migrate_mysql_to_sqlite.py
```

## 📊 Monitoramento Pós-Migração

### Verificações Diárias
```bash
# Status do MySQL
sudo systemctl status mysql

# Espaço em disco usado pela database
mysql -u homeguard -p -e "
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables 
WHERE table_schema = 'homeguard';
"

# Conexões ativas
mysql -u homeguard -p -e "SHOW STATUS LIKE 'Threads_connected';"
```

### Backup Automático
```bash
# Adicionar ao crontab
crontab -e

# Backup diário às 2h
0 2 * * * /home/pi/backup/mysql/backup_homeguard.sh
```

---

**✅ Migração Concluída!** 

Após seguir este guia, seu HomeGuard estará rodando com MySQL, oferecendo melhor performance, escalabilidade e recursos avançados de gerenciamento de dados.
