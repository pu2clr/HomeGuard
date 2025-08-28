# HomeGuard - Guia Rápido MySQL

## ❌ Erro: mysql.connector não encontrado

### 🚀 Solução Rápida (1 comando)

```bash
./install_python_mysql_deps.sh
```

### 🔧 Solução Manual

```bash
# Instalar driver MySQL
pip3 install mysql-connector-python

# Verificar
python3 -c "import mysql.connector; print('OK')"
```

### 🆘 Se der erro no pip3

```bash
# Instalar com usuário local
pip3 install --user mysql-connector-python

# Ou usar apt
sudo apt install python3-mysql.connector -y
```

## 📋 Scripts Disponíveis

| Script | Função | Uso |
|--------|---------|-----|
| `check_python_deps.py` | Verifica dependências | `./check_python_deps.py` |
| `install_python_mysql_deps.sh` | Instala dependências | `./install_python_mysql_deps.sh` |
| `basic_mariadb_fix.sh` | Configura MariaDB | `./basic_mariadb_fix.sh` |
| `test_mysql_connection.py` | Testa conexão | `./test_mysql_connection.py` |

## 🎯 Ordem de Execução

```bash
# 1. Verificar dependências Python
./check_python_deps.py

# 2. Se faltar, instalar
./install_python_mysql_deps.sh

# 3. Configurar MariaDB
./basic_mariadb_fix.sh

# 4. Testar conexão
./test_mysql_connection.py

# 5. Executar dashboard
cd web/
python3 homeguard_flask_mysql.py
```

## ✅ Teste Rápido

```bash
python3 -c "
try:
    import mysql.connector
    print('✅ mysql.connector OK')
except ImportError:
    print('❌ mysql.connector não encontrado')
    print('💡 Execute: ./install_python_mysql_deps.sh')
"
```
