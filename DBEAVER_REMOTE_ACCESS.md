# DBeaver - Configuração Acesso Remoto MySQL/MariaDB
# HomeGuard System

## 🎯 Problema Comum: DBeaver não consegue conectar ao MySQL/MariaDB do Raspberry Pi

### ✅ Soluções Passo a Passo

## 1. 🔧 No Raspberry Pi - Executar Script de Correção

```bash
# Conectar ao Raspberry Pi
ssh pi@IP_DO_RASPBERRY
cd /home/pi/HomeGuard

# Executar script de correção automática
chmod +x fix_remote_access_dbeaver.sh
./fix_remote_access_dbeaver.sh
```

## 2. 🔧 Configuração Manual (se necessário)

### 2.1 Verificar bind-address
```bash
# Editar configuração
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf

# Alterar de:
bind-address = 127.0.0.1
# Para:
bind-address = 0.0.0.0

# Reiniciar serviço
sudo systemctl restart mariadb
```

### 2.2 Criar usuário para acesso remoto
```bash
sudo mysql -e "
CREATE USER 'homeguard'@'%' IDENTIFIED BY 'homeguard123';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';
CREATE USER 'root'@'%' IDENTIFIED BY 'root123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User IN ('homeguard', 'root');
FLUSH PRIVILEGES;
"
```

### 2.3 Liberar firewall
```bash
sudo ufw allow 3306/tcp
```

## 3. 🖥️ Configuração no DBeaver

### 3.1 Nova Conexão
1. **File** → **New** → **Database Connection**
2. Selecionar **MySQL**
3. Click **Next**

### 3.2 Configurações de Conexão
```
Server Host: [IP_DO_RASPBERRY_PI]
Port: 3306
Database: homeguard
Username: homeguard
Password: homeguard123
```

### 3.3 Configurações Avançadas (se necessário)
- **Driver Properties** → Adicionar:
  - `useSSL`: `false`
  - `allowPublicKeyRetrieval`: `true`
  - `serverTimezone`: `UTC`

### 3.4 Testar Conexão
- Click em **Test Connection**
- Se aparecer erro, ver seção de troubleshooting abaixo

## 4. 🧪 Teste de Conectividade

### Do seu computador (Mac/PC):
```bash
# Testar conectividade
./test_remote_connection.sh IP_DO_RASPBERRY

# Exemplo:
./test_remote_connection.sh 192.168.1.100
```

### Teste direto com mysql client:
```bash
mysql -h IP_DO_RASPBERRY -P 3306 -u homeguard -phomeguard123 -e "SHOW DATABASES;"
```

## 5. ❌ Troubleshooting - Problemas Comuns

### Erro: "Connection refused"
**Causa**: MySQL não está ouvindo na porta 3306 ou bind-address incorreto
```bash
# Verificar se está rodando
sudo systemctl status mariadb

# Verificar porta
netstat -tlnp | grep 3306

# Corrigir bind-address
sudo sed -i 's/bind-address.*=.*127\.0\.0\.1/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb
```

### Erro: "Access denied for user"
**Causa**: Usuário não tem permissão de acesso remoto
```bash
sudo mysql -e "
CREATE USER IF NOT EXISTS 'homeguard'@'%' IDENTIFIED BY 'homeguard123';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='homeguard';
FLUSH PRIVILEGES;
"
```

### Erro: "Public Key Retrieval is not allowed"
**Solução**: No DBeaver, adicionar propriedade:
- **Driver Properties** → `allowPublicKeyRetrieval`: `true`

### Erro: "SSL connection required"
**Solução**: No DBeaver, adicionar propriedade:
- **Driver Properties** → `useSSL`: `false`

### Erro: Timeout ou sem resposta
**Causa**: Firewall bloqueando porta 3306
```bash
# UFW
sudo ufw allow 3306/tcp

# iptables (se não usar UFW)
sudo iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
```

## 6. 📋 Checklist de Verificação

### No Raspberry Pi:
- [ ] MariaDB/MySQL está rodando: `systemctl status mariadb`
- [ ] Porta 3306 aberta: `netstat -tlnp | grep 3306`
- [ ] bind-address = 0.0.0.0 nos arquivos de configuração
- [ ] Usuário criado com acesso remoto (%)
- [ ] Firewall liberado para porta 3306
- [ ] Plugin de autenticação mysql_native_password

### No DBeaver:
- [ ] IP correto do Raspberry Pi
- [ ] Porta 3306
- [ ] Usuário e senha corretos
- [ ] Driver MySQL selecionado
- [ ] Propriedades SSL configuradas se necessário

## 7. 🔍 Comandos de Diagnóstico

### Verificar configuração atual:
```bash
# Status do serviço
sudo systemctl status mariadb

# Verificar usuários
sudo mysql -e "SELECT User, Host FROM mysql.user WHERE User IN ('root', 'homeguard');"

# Verificar bind-address atual
grep -r "bind-address" /etc/mysql/

# Verificar porta
sudo netstat -tlnp | grep 3306

# Logs do MySQL
sudo tail -f /var/log/mysql/error.log
```

## 8. 🎯 Configurações Recomendadas para DBeaver

### Propriedades do Driver MySQL:
```
allowMultiQueries: true
allowPublicKeyRetrieval: true
autoReconnect: true
serverTimezone: UTC
useSSL: false
verifyServerCertificate: false
```

### SQL Mode (se necessário):
```sql
SET sql_mode = '';
```

---

## ✅ Resultado Esperado

Após seguir estes passos, você deve conseguir:
1. ✅ Conectar ao MySQL/MariaDB via DBeaver
2. ✅ Ver o database `homeguard`
3. ✅ Visualizar as tabelas do HomeGuard
4. ✅ Executar queries e navegar pelos dados

---

**💡 Dica**: Se ainda tiver problemas, execute primeiro o script `fix_remote_access_dbeaver.sh` que automatiza todas essas configurações!
