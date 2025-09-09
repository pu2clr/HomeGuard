# HomeGuard - MySQL/MariaDB Authentication Fix Guide

## ❌ Problema Identificado

Você encontrou o erro:
```
ERROR 1698 (28000): Access denied for user 'root'@'localhost'
```

Este é um problema comum no **MariaDB** (que substitui o MySQL no Raspberry Pi OS). O MariaDB usa **socket authentication** por padrão para o usuário root, não password authentication.

## 🔧 Solução Automática

### 1. Execute o Script de Correção
```bash
./fix_mariadb_auth.sh
```

Este script oferece 3 opções:
- **Opção 1**: Manter socket auth (mais seguro) - root conecta via `sudo mysql`
- **Opção 2**: Alterar para password auth (tradicional) - root conecta via `mysql -u root -p`  
- **Opção 3**: Configurar ambos métodos (híbrido)

### 2. Teste a Configuração
```bash
cd web/
python3 test_mysql_connection.py
```

### 3. Execute o Dashboard
```bash
cd web/
python3 homeguard_flask_mysql.py
```

## 🛠️ Solução Manual (se preferir)

### Para Socket Authentication (Recomendado)
```sql
-- Conectar como root via socket
sudo mysql

-- Configurar root para socket auth
UPDATE mysql.user SET plugin='unix_socket' WHERE User='root';
FLUSH PRIVILEGES;

-- Criar usuário homeguard
CREATE USER 'homeguard'@'%' IDENTIFIED BY 'sua_senha_aqui';
GRANT ALL PRIVILEGES ON homeguard.* TO 'homeguard'@'%';
FLUSH PRIVILEGES;
```

### Para Password Authentication (Tradicional)
```sql
-- Conectar como root via socket
sudo mysql

-- Alterar root para usar senha
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'sua_senha_root';
FLUSH PRIVILEGES;
```

## 📋 Diagnóstico de Problemas

### Verificar Status do MariaDB
```bash
sudo systemctl status mariadb
sudo systemctl start mariadb  # se parado
```

### Verificar Usuários e Authentication Methods
```sql
sudo mysql -e "SELECT User, Host, plugin FROM mysql.user;"
```

### Testar Diferentes Conexões
```bash
# Socket authentication
sudo mysql

# Password authentication  
mysql -u root -p

# Usuário homeguard
mysql -u homeguard -p
```

## 🎯 Estrutura de Arquivos

```
HomeGuard/
├── fix_mariadb_auth.sh           # Script de correção automática
├── test_mysql_connection.py      # Script de teste
├── install_mysql_homeguard.sh    # Instalação completa
└── web/
    ├── homeguard_flask_mysql.py  # Dashboard MySQL
    ├── config_mysql.json         # Configuração MySQL
    └── homeguard_flask.py         # Dashboard SQLite (original)
```

## ✅ Verificação Final

Após executar a correção, você deve ver:

```bash
✅ Root configurado para socket/password authentication
✅ Usuário homeguard configurado  
✅ Database homeguard criada
✅ Tabelas HomeGuard criadas
🚀 Dashboard: http://[IP_DO_RPI]:5000
```

## 🚨 Problemas Comuns e Soluções

| Erro | Causa | Solução |
|------|-------|---------|
| `ERROR 1698` | MariaDB socket auth | `./fix_mariadb_auth.sh` |
| `Can't connect to MySQL server` | MariaDB parado | `sudo systemctl start mariadb` |
| `Unknown database 'homeguard'` | Database não existe | Script cria automaticamente |
| `Access denied for user 'homeguard'` | Usuário não existe | Script cria automaticamente |

## 🔐 Configuração de Segurança

O script também configura:
- Acesso remoto para usuário homeguard
- Senha segura (mínimo 8 caracteres)
- Privilégios limitados ao database homeguard
- Conexões SSL (se disponível)

## 🚀 Próximos Passos

1. Execute `./fix_mariadb_auth.sh`
2. Execute `python3 test_mysql_connection.py` 
3. Configure `web/config_mysql.json` com suas credenciais
4. Execute `python3 homeguard_flask_mysql.py`
5. Acesse `http://[IP_DO_RPI]:5000`

---

**💡 Dica**: Mantenha sempre o arquivo original `homeguard_flask.py` como backup!
