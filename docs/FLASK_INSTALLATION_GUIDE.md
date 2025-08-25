# 🏠 HomeGuard Flask Dashboard - Guia Completo de Instalação

## 📋 Visão Geral

O **HomeGuard Dashboard** é uma interface web completa desenvolvida em **Flask** para monitoramento e controle do sistema HomeGuard. Este guia apresenta instruções detalhadas para instalação em múltiplas plataformas.

### 🎯 **Recursos do Sistema:**
- ✅ **Monitoramento em tempo real** de sensores ESP8266
- ✅ **Controle MQTT** de relés remotos  
- ✅ **Interface web responsiva** e moderna
- ✅ **Banco de dados SQLite** para persistência
- ✅ **APIs REST** para integração externa
- ✅ **Multi-plataforma** (Raspberry Pi, Ubuntu, macOS, Windows)

---

## 🖥️ Compatibilidade de Plataformas

| Plataforma | Status | Notas |
|------------|--------|-------|
| **🍓 Raspberry Pi OS** | ✅ **Recomendado** | Ideal para produção |
| **🐧 Ubuntu/Debian** | ✅ **Total** | Excelente performance |
| **🍎 macOS** | ✅ **Total** | Desenvolvimento e teste |
| **🪟 Windows 10/11** | ✅ **Total** | WSL2 recomendado |

---

## 📦 Estrutura do Projeto

```
HomeGuard/
├── web/                          # Dashboard Flask
│   ├── homeguard_flask.py        # Aplicação principal
│   ├── flask_mqtt_controller.py  # Controlador MQTT
│   ├── mqtt_relay_config.py      # Configuração MQTT/Relés
│   ├── templates/                # Templates HTML
│   │   ├── base.html
│   │   ├── index.html
│   │   ├── events.html
│   │   └── relays.html
│   ├── install_flask.sh          # Instalador principal
│   ├── install_mqtt.sh           # Instalador MQTT
│   └── restart_flask.sh          # Reinicializador
├── db/                           # Banco de dados SQLite
│   └── homeguard.db
└── source/                       # Código Arduino ESP8266
```

---

## 🚀 Instalação por Plataforma

### 🍓 **RASPBERRY PI OS**

#### **Pré-requisitos:**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv git sqlite3
```

#### **Instalação:**
```bash
# 1. Clonar repositório (se necessário)
git clone https://github.com/pu2clr/HomeGuard.git
cd HomeGuard/web

# 2. Tornar scripts executáveis
chmod +x install_flask.sh install_mqtt.sh restart_flask.sh check_flask.sh

# 3. Instalar Flask
./install_flask.sh

# 4. Instalar MQTT (opcional)
./install_mqtt.sh

# 5. Configurar MQTT
nano mqtt_relay_config.py
# Alterar: 'broker_host': 'SEU_IP_BROKER_AQUI'

# 6. Iniciar dashboard
./restart_flask.sh
```

#### **Executar na inicialização (systemd):**
```bash
sudo tee /etc/systemd/system/homeguard.service << 'EOF'
[Unit]
Description=HomeGuard Flask Dashboard
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/HomeGuard/web
ExecStart=/usr/bin/python3 homeguard_flask.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable homeguard
sudo systemctl start homeguard
```

---

### 🐧 **UBUNTU/DEBIAN**

#### **Instalação padrão:**
```bash
# 1. Atualizar sistema
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential

# 2. Preparar ambiente
cd HomeGuard/web
python3 -m venv venv
source venv/bin/activate

# 3. Instalar dependências
pip install --upgrade pip
pip install flask sqlite3 paho-mqtt

# 4. Configurar
cp mqtt_relay_config.py.example mqtt_relay_config.py  # se existir
nano mqtt_relay_config.py

# 5. Executar
python3 homeguard_flask.py
```

#### **Instalação com Docker:**
```bash
# Criar Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app
COPY web/ .
RUN pip install flask paho-mqtt

EXPOSE 5000
CMD ["python", "homeguard_flask.py"]
EOF

# Build e execução
docker build -t homeguard-flask .
docker run -d -p 5000:5000 -v $(pwd)/db:/app/../db homeguard-flask
```

---

### 🍎 **macOS**

#### **Com Homebrew:**
```bash
# 1. Instalar Homebrew (se não tiver)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Instalar Python
brew install python@3.9

# 3. Criar ambiente virtual
cd HomeGuard/web
python3 -m venv venv
source venv/bin/activate

# 4. Instalar dependências
pip install --upgrade pip
pip install flask paho-mqtt

# 5. Executar
python3 homeguard_flask.py
```

#### **Com pyenv (recomendado para desenvolvimento):**
```bash
# 1. Instalar pyenv
brew install pyenv

# 2. Instalar Python específico
pyenv install 3.9.18
pyenv global 3.9.18

# 3. Configurar ambiente
cd HomeGuard/web
python -m venv venv
source venv/bin/activate
pip install flask paho-mqtt

# 4. Executar
python homeguard_flask.py
```

---

### 🪟 **WINDOWS**

#### **Opção 1: WSL2 (Recomendado):**
```powershell
# 1. Instalar WSL2
wsl --install -d Ubuntu-20.04

# 2. No WSL2, seguir instruções do Ubuntu
sudo apt update && sudo apt install python3 python3-pip python3-venv
cd /mnt/c/Users/SEU_USUARIO/HomeGuard/web
chmod +x *.sh
./install_flask.sh
```

#### **Opção 2: Python nativo Windows:**
```powershell
# 1. Instalar Python do Microsoft Store ou python.org
# Verificar: python --version

# 2. Criar ambiente virtual
cd HomeGuard\web
python -m venv venv
venv\Scripts\activate

# 3. Instalar dependências
pip install --upgrade pip
pip install flask paho-mqtt

# 4. Executar
python homeguard_flask.py
```

#### **Opção 3: Docker Desktop:**
```powershell
# No PowerShell
cd HomeGuard
docker build -t homeguard-flask ./web
docker run -d -p 5000:5000 homeguard-flask
```

---

## 🔧 Configuração Detalhada

### **1. Configuração MQTT (`mqtt_relay_config.py`)**

```python
# Configuração do Broker MQTT
MQTT_CONFIG = {
    'broker_host': '192.168.1.100',     # IP do seu broker MQTT
    'broker_port': 1883,                # Porta MQTT padrão
    'username': 'homeguard',            # Usuário (se necessário)
    'password': 'sua_senha',            # Senha (se necessário)  
    'keepalive': 60,
    'client_id': 'homeguard_dashboard'
}

# Configuração dos Relés
RELAYS_CONFIG = [
    {
        "id": "ESP01_RELAY_001",
        "name": "Luz Principal",
        "location": "Sala",
        "mqtt_topic_command": "homeguard/relay/001/cmd",
        "mqtt_topic_status": "homeguard/relay/001/status",
        "status": "unknown"
    }
    # Adicione mais relés conforme necessário
]
```

### **2. Configuração de Banco de Dados**

O sistema usa SQLite por padrão, mas pode ser alterado:

```python
# Em homeguard_flask.py
class FlaskHomeGuardDashboard:
    def __init__(self):
        # SQLite (padrão)
        self.db_path = '../db/homeguard.db'
        
        # Para PostgreSQL
        # self.db_url = 'postgresql://user:pass@localhost/homeguard'
        
        # Para MySQL
        # self.db_url = 'mysql://user:pass@localhost/homeguard'
```

---

## 🌐 Acesso e URLs

### **URLs Principais:**
- **Dashboard:** http://IP_DO_SERVIDOR:5000/
- **Eventos:** http://IP_DO_SERVIDOR:5000/events
- **Relés:** http://IP_DO_SERVIDOR:5000/relays

### **APIs REST:**
- **GET** `/api/stats` - Estatísticas gerais
- **GET** `/api/devices` - Status dos dispositivos  
- **GET** `/api/events?limit=50` - Eventos recentes
- **GET** `/api/relays` - Status dos relés
- **GET** `/api/relay/{id}/{action}` - Controlar relé (on/off/toggle)

---

## 🔍 Monitoramento e Logs

### **Verificar Status:**
```bash
./check_flask.sh                    # Status completo
curl http://localhost:5000/api/stats # Teste API
tail -f flask.log                   # Logs em tempo real
```

### **Logs do Sistema:**
```bash
# Raspberry Pi (systemd)
sudo journalctl -u homeguard -f

# Docker
docker logs -f container_name

# Arquivo local
tail -f web/flask.log
```

---

## 🛡️ Segurança e Produção

### **Configuração de Firewall:**
```bash
# Ubuntu/Raspberry Pi
sudo ufw allow 5000/tcp
sudo ufw enable

# CentOS/RHEL  
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --reload
```

### **Proxy Reverso com Nginx:**
```nginx
server {
    listen 80;
    server_name homeguard.local;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### **SSL/TLS com Let's Encrypt:**
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d homeguard.seudominio.com
```

---

## 🐛 Solução de Problemas

### **Problemas Comuns:**

#### **"ModuleNotFoundError: No module named 'flask'"**
```bash
# Solução
pip install flask
# ou
source venv/bin/activate && pip install flask
```

#### **"Permission denied" ao executar scripts**
```bash
chmod +x *.sh
```

#### **Banco de dados não encontrado**
```bash
mkdir -p ../db
sqlite3 ../db/homeguard.db "CREATE TABLE motion_sensors (id INTEGER PRIMARY KEY);"
```

#### **MQTT não conecta**
```bash
# Testar broker
telnet IP_BROKER 1883

# Verificar configuração
python3 test_mqtt.py
```

#### **Porta 5000 já em uso**
```bash
# Encontrar processo
lsof -i :5000
# ou
netstat -tulpn | grep :5000

# Matar processo
sudo kill -9 PID
```

### **Debug Mode:**
```python
# Em homeguard_flask.py, alterar última linha:
app.run(host='0.0.0.0', port=5000, debug=True)
```

---

## 📊 Performance e Otimização

### **Configurações de Produção:**
```python
# homeguard_flask.py
if __name__ == '__main__':
    # Produção
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
    
    # Com Gunicorn (recomendado)
    # gunicorn -w 4 -b 0.0.0.0:5000 homeguard_flask:app
```

### **Monitoramento de Recursos:**
```bash
# CPU e Memória
htop
ps aux | grep python

# Conexões de rede
netstat -an | grep :5000

# Espaço em disco
df -h
du -sh ../db/
```

---

## 🔄 Backup e Manutenção

### **Backup do Banco de Dados:**
```bash
# Backup SQLite
cp ../db/homeguard.db ../db/homeguard_backup_$(date +%Y%m%d).db

# Backup automático (crontab)
0 2 * * * cp /home/pi/HomeGuard/db/homeguard.db /home/pi/backups/homeguard_$(date +\%Y\%m\%d).db
```

### **Limpeza de Logs:**
```bash
# Limitar tamanho do log
tail -n 1000 flask.log > flask.log.tmp && mv flask.log.tmp flask.log

# Rotação automática
echo "*/home/pi/HomeGuard/web/flask.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}" | sudo tee /etc/logrotate.d/homeguard
```

---

## 📞 Suporte

### **Informações de Versão:**
```bash
python3 --version
pip list | grep flask
cat /etc/os-release        # Linux
sw_vers                    # macOS
```

### **Testes Automatizados:**
```bash
python3 test_mqtt.py       # Teste MQTT
curl http://localhost:5000/api/stats  # Teste API
```

### **Community e Documentação:**
- 📖 **Wiki:** [GitHub Wiki](https://github.com/pu2clr/HomeGuard/wiki)
- 🐛 **Issues:** [GitHub Issues](https://github.com/pu2clr/HomeGuard/issues)
- 💬 **Discussões:** [GitHub Discussions](https://github.com/pu2clr/HomeGuard/discussions)

---

**🎯 O HomeGuard Flask Dashboard está pronto para produção em qualquer plataforma!**
