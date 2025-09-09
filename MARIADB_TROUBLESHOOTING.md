# HomeGuard - Troubleshooting MariaDB

## 🐛 Problemas Identificados e Soluções

### ❌ Erro 1: SQL Syntax Error "current_time"
**Problema**: `You have an error in your SQL syntax... near 'current_time'`
**Causa**: MariaDB não aceita `current_time` como alias em algumas versões
**Solução**: ✅ **CORRIGIDO** no `test_mysql_connection.py`

### ❌ Erro 2: Unknown Column "unix_timestamp"
**Problema**: `Unknown column 'unix_timestamp' in 'INSERT INTO'`
**Causa**: Tabela criada sem a coluna `unix_timestamp`
**Solução**: Execute `./fix_mariadb_tables.sh`

### ❌ Erro 3: DeprecationWarning get_server_info
**Problema**: `Call to deprecated function get_server_info`
**Causa**: mysql.connector versão mais nova deprecou o método
**Solução**: ✅ **CORRIGIDO** - usando propriedade `server_info`

## 🚀 Soluções Rápidas

### Para Resolver TODOS os Problemas:
```bash
# 1. Corrigir estrutura das tabelas
./fix_mariadb_tables.sh

# 2. Testar novamente
cd web/
python3 ../test_mysql_connection.py

# 3. Se OK, executar dashboard
python3 homeguard_flask_mysql.py
```

### Se Ainda Houver Problemas:
```bash
# Verificar estrutura das tabelas manualmente
mysql -u homeguard -p homeguard -e "DESCRIBE motion_sensors;"

# Verificar se todas as colunas existem
mysql -u homeguard -p homeguard -e "SHOW COLUMNS FROM motion_sensors;"
```

## 📋 Checklist de Verificação

- [ ] MariaDB rodando: `sudo systemctl status mariadb`
- [ ] Usuário homeguard existe e conecta
- [ ] Database homeguard existe
- [ ] Tabelas têm estrutura completa (usar `./fix_mariadb_tables.sh`)
- [ ] Python pode importar mysql.connector
- [ ] Teste de conexão passa

## 🔧 Scripts de Correção Disponíveis

| Script | Função |
|--------|---------|
| `basic_mariadb_fix.sh` | Configura usuário e database |
| `fix_mariadb_tables.sh` | Corrige estrutura das tabelas |
| `install_mysql_raspberry.sh` | Instala dependências Python |
| `test_mysql_connection.py` | Testa conexão (corrigido) |

## 📊 Status Esperado Após Correção

```
📋 RESUMO DOS TESTES
==================================================
Conexão Básica       ✅ PASSOU
Acesso Database      ✅ PASSOU  
Estrutura Tabelas    ✅ PASSOU
Inserção Dados       ✅ PASSOU
```

## 🎯 Próximos Passos

1. Execute: `./fix_mariadb_tables.sh [senha_homeguard]`
2. Execute: `cd web/ && python3 ../test_mysql_connection.py`
3. Se todos os testes passarem: `python3 homeguard_flask_mysql.py`
4. Acesse: `http://[IP_RASPBERRY]:5000`
