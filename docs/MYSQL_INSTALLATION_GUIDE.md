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

### 2. Instalar MySQL Server
```bash
sudo apt install mysql-server -y
```

### 3. Iniciar e Habilitar MySQL
```bash
sudo systemctl start mysql
sudo systemctl enable mysql
```

### 4. Configuração Inicial de Segurança
Execute o script de configuração segura:
```bash
sudo mysql_secure_installation
```

**Respostas recomendadas:**
- **VALIDATE PASSWORD COMPONENT**: `y` (sim)
- **Password validation policy**: `2` (STRONG)
- **New root password**: Digite uma senha forte
- **Re-enter new password**: Confirme a senha
- **Remove anonymous users**: `y` (sim)
- **Disallow root login remotely**: `n` (não) - Permitir login remoto
- **Remove test database**: `y` (sim)
- **Reload privilege tables**: `y` (sim)

### 5. Configurar Acesso Remoto

#### 5.1 Editar arquivo de configuração:
```bash
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
sudo mysql -u root -p
```

No prompt do MySQL:
```sql
-- Criar usuário homeguard com acesso remoto
CREATE USER 'homeguard'@'%' IDENTIFIED BY 'SUA_SENHA_AQUI';

-- Conceder privilégios
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';

-- Permitir root remoto (opcional)
UPDATE mysql.user SET host='%' WHERE user='root';

-- Aplicar mudanças
FLUSH PRIVILEGES;

-- Sair
EXIT;
```

### 6. Reiniciar MySQL
```bash
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
```bash
# Instalar driver MySQL para Python
pip3 install mysql-connector-python PyMySQL

# Ou se preferir usando apt
sudo apt install python3-mysql.connector python3-pymysql -y
```

## 🔧 Verificação da Instalação

### Verificar Status do MySQL
```bash
sudo systemctl status mysql
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
