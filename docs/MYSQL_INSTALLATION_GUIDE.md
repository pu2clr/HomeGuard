# Guia de Instalação MySQL no Raspberry Pi 4 - HomeGuard

## 📋 Pré-requisitos
- Raspberry Pi 4 com Raspberry Pi OS
- Acesso SSH ou terminal local
- Usuário com privilégios sudo
- Conexão à internet

## 🚀 Instalação Passo a Passo

### 1. Atualizar o Sistema
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Instalar MariaDB Server (Compatível com MySQL)
```bash
# MariaDB é a alternativa recomendada no Raspberry Pi OS
sudo apt install mariadb-server -y

# Alternativamente, se quiser MySQL oficial:
# sudo apt install default-mysql-server -y
```

**Nota**: MariaDB é um fork do MySQL, totalmente compatível e recomendado para Raspberry Pi.

### 3. Iniciar e Habilitar MariaDB/MySQL
```bash
# Para MariaDB
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Verificar status
sudo systemctl status mariadb
```

### 4. Configuração Inicial de Segurança
Execute o script de configuração segura:
```bash
# Para MariaDB
sudo mysql_secure_installation

# Ou para MySQL/MariaDB genérico
sudo mariadb-secure-installation
```

**Respostas recomendadas:**
- **Enter current password for root**: Pressione Enter (sem senha inicial)
- **Switch to unix_socket authentication**: `n` (não)
- **Change the root password**: `y` (sim) - Digite uma senha forte
- **Remove anonymous users**: `y` (sim)
- **Disallow root login remotely**: `n` (não) - Permitir login remoto
- **Remove test database**: `y` (sim)
- **Reload privilege tables**: `y` (sim)

### 5. Configurar Acesso Remoto

#### 5.1 Editar arquivo de configuração:
```bash
# Para MariaDB/MySQL
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf

# Ou tente o caminho tradicional MySQL
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Encontre e altere a linha:
```ini
# De:
bind-address = 127.0.0.1

# Para:
bind-address = 0.0.0.0
```

#### 5.2 Criar usuário para acesso remoto:
```bash
# Conectar como root (MariaDB/MySQL)
sudo mysql -u root -p

# Ou se não pedir senha:
sudo mysql
```

No prompt do MariaDB/MySQL:
```sql
-- Criar usuário homeguard com acesso remoto
CREATE USER 'homeguard'@'%' IDENTIFIED BY 'SUA_SENHA_AQUI';

-- Conceder privilégios
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';

-- Permitir root remoto (opcional)
UPDATE mysql.user SET host='%' WHERE user='root';

-- Para MariaDB, garantir plugin correto
ALTER USER 'root'@'localhost' IDENTIFIED BY 'sua_senha_root';

-- Aplicar mudanças
FLUSH PRIVILEGES;

-- Sair
EXIT;
```

### 6. Reiniciar MariaDB/MySQL
```bash
# Para MariaDB
sudo systemctl restart mariadb

# Ou para MySQL
sudo systemctl restart mysql
```

### 7. Configurar Firewall (se UFW estiver ativo)
```bash
sudo ufw allow 3306/tcp
```

### 8. Criar Database HomeGuard
```bash
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS homeguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

### 9. Instalar Dependências Python

#### 🍓 Para Raspberry Pi OS Bookworm+ (RECOMENDADO)
```bash
# Script específico para Raspberry Pi OS (resolve PEP 668)
./install_mysql_raspberry.sh
```

#### 🐍 Método Manual Tradicional
```bash
# Método automatizado (genérico)
./install_python_mysql_deps.sh

# Ou instalação manual:
# Atualizar pip primeiro
pip3 install --upgrade pip

# Instalar driver MySQL para Python
pip3 install mysql-connector-python PyMySQL

# Ou se preferir usando apt (alternativa)
sudo apt install python3-pymysql -y

# Verificar instalação
python3 -c "import mysql.connector; print('mysql.connector OK')"
```

#### ⚠️ Problemas Comuns e Soluções

**Erro: "externally-managed-environment" (PEP 668)**
```bash
# Raspberry Pi OS Bookworm+ bloqueia pip3 por segurança
# SOLUÇÕES (em ordem de preferência):

# 1. Usar apt (MAIS SEGURO)
sudo apt install python3-pymysql -y

# 2. Virtual environment (RECOMENDADO)
python3 -m venv homeguard-env
source homeguard-env/bin/activate
pip install mysql-connector-python PyMySQL
# Use: homeguard-env/bin/python script.py

# 3. Instalação local do usuário
pip3 install --user mysql-connector-python

# 4. Override (CUIDADO - pode quebrar sistema)
pip3 install --break-system-packages mysql-connector-python
```

**Erro: "mysql.connector não encontrado"**
```bash
# Solução 1: PyMySQL como alternativa (funciona igual)
sudo apt install python3-pymysql -y

# Solução 2: Instalar com usuário
pip3 install --user mysql-connector-python

# Solução 3: Instalar dependências de compilação
sudo apt install python3-dev default-libmysqlclient-dev build-essential
pip3 install mysql-connector-python

# Solução 4: Script automatizado
./install_mysql_raspberry.sh
```

**Erro: "Permission denied" no pip**
```bash
# Usar instalação local
pip3 install --user mysql-connector-python

# Ou atualizar pip
python3 -m pip install --upgrade pip --user
```

**Erro: Package 'python3-mysql.connector' has no installation candidate**
```bash
# Usar PyMySQL (alternativa compatível)
sudo apt install python3-pymysql -y

# PyMySQL funciona como substituto do mysql.connector
```

## 🔧 Verificação da Instalação

### Verificar Status do MariaDB/MySQL
```bash
# Para MariaDB
sudo systemctl status mariadb

# Para MySQL  
sudo systemctl status mysql

# Verificar qual está instalado
systemctl list-units --type=service | grep -E "(mysql|mariadb)"
```

### Testar Conexão Local
```bash
mysql -u root -p -e "SHOW DATABASES;"
```

### Testar Conexão Remota (de outro dispositivo)
```bash
mysql -h IP_DO_RASPBERRY -u homeguard -p -e "SHOW DATABASES;"
```

### Verificar Porta MySQL
```bash
sudo netstat -tlnp | grep :3306
```

## 📝 Informações Importantes

### Localização dos Arquivos de Configuração
- **Configuração principal**: `/etc/mysql/mysql.conf.d/mysqld.cnf`
- **Logs de erro**: `/var/log/mysql/error.log`
- **Dados**: `/var/lib/mysql/`

### Comandos Úteis
```bash
# Verificar versão
mysql --version

# Logs do MySQL
sudo journalctl -u mysql

# Reiniciar serviço
sudo systemctl restart mysql

# Parar serviço
sudo systemctl stop mysql

# Status detalhado
sudo systemctl status mysql -l
```

### Configurações de Performance (Opcional)
Para Raspberry Pi 4, edite `/etc/mysql/mysql.conf.d/mysqld.cnf`:
```ini
# Otimizações para Raspberry Pi 4
[mysqld]
innodb_buffer_pool_size = 256M
max_connections = 50
innodb_log_file_size = 32M
```

## 🔒 Segurança Adicional

### Configurar SSL (Opcional)
```bash
# Verificar se SSL está habilitado
mysql -u root -p -e "SHOW VARIABLES LIKE 'have_ssl';"
```

### Configurar Backup Automático
```bash
# Adicionar ao crontab
crontab -e

# Backup diário às 2h da manhã
0 2 * * * mysqldump -u root -p[SENHA] homeguard > /home/pi/backup/homeguard_$(date +\%Y\%m\%d).sql
```

## 🆘 Troubleshooting

### Problema: Conexão Remota Falha
1. Verificar firewall: `sudo ufw status`
2. Verificar bind-address no mysqld.cnf
3. Verificar usuários: `SELECT User, Host FROM mysql.user;`

### Problema: Erro de Autenticação
```sql
-- No MySQL como root
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'sua_senha';
FLUSH PRIVILEGES;
```

### Problema: Performance Baixa
1. Ajustar innodb_buffer_pool_size
2. Verificar logs: `sudo tail -f /var/log/mysql/error.log`
3. Monitorar queries: `SHOW PROCESSLIST;`

## 📊 Monitoramento

### Verificar Performance
```sql
-- Conexões ativas
SHOW STATUS LIKE 'Threads_connected';

-- Uptime
SHOW STATUS LIKE 'Uptime';

-- Queries por segundo
SHOW STATUS LIKE 'Questions';
```

### Scripts de Monitoramento
Criar em `/home/pi/scripts/mysql_monitor.sh`:
```bash
#!/bin/bash
echo "=== MySQL Status ==="
sudo systemctl status mysql --no-pager -l
echo -e "\n=== Connections ==="
mysql -u root -p[SENHA] -e "SHOW STATUS LIKE 'Threads_connected';"
echo -e "\n=== Database Size ==="
mysql -u root -p[SENHA] -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = 'homeguard' GROUP BY table_schema;"
```

---

**💡 Dica**: Execute o script automatizado `install_mysql_homeguard.sh` para instalação automática!

**🔗 Próximos Passos**: Após a instalação, use o `homeguard_flask_mysql.py` para conectar ao MySQL.
