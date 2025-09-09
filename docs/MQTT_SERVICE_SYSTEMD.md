# 🚀 Configuração do Serviço MQTT HomeGuard para Boot Automático

Guia completo para configurar o `mqtt_service.py` como serviço systemd no Raspberry Pi 4, garantindo que inicie automaticamente durante o boot.

## 🎯 Objetivo

Configurar o serviço MQTT do HomeGuard para:
- ✅ **Iniciar automaticamente** no boot do Raspberry Pi
- ✅ **Reiniciar automaticamente** em caso de falha
- ✅ **Gerenciar logs** de forma centralizada
- ✅ **Controle completo** via systemctl

## 📋 Pré-requisitos

### **Sistema**
- Raspberry Pi 4 (ou 3/Zero) com Raspbian/Ubuntu
- Python 3.7+ instalado
- Acesso sudo/root
- Usuário `homeguard` criado no sistema

### **Projeto HomeGuard**
- Projeto HomeGuard clonado em `/home/homeguard/HomeGuard/` (ou outro diretório)
- Arquivo `web/mqtt_service.py` funcionando
- Broker MQTT configurado (Mosquitto recomendado)

### **Dependências Python**
```bash
# Instalar dependências se necessário
cd /home/homeguard/HomeGuard
pip3 install paho-mqtt
```

## 🚀 Instalação Automática (Recomendado)

### **Passo 1: Executar Script de Instalação**
```bash
# No Raspberry Pi, navegue até o projeto
cd /home/homeguard/HomeGuard

# Execute o script de configuração
sudo ./scripts/setup-mqtt-service.sh
```

### **Passo 2: Verificar Instalação**
```bash
# Verificar status do serviço
./scripts/manage-mqtt-service.sh status
```

### **Passo 3: Testar Reinicialização**
```bash
# Reiniciar Pi para testar boot automático
sudo reboot

# Após reinicialização, verificar se serviço iniciou
./scripts/manage-mqtt-service.sh status
```

## ⚙️ Instalação Manual (Avançado)

### **1. Criar Arquivo de Serviço Systemd**

```bash
# Criar arquivo de serviço
sudo nano /etc/systemd/system/homeguard-mqtt.service
```

**Conteúdo do arquivo:**
```ini
[Unit]
Description=HomeGuard MQTT Activity Logger Service
Documentation=https://github.com/pu2clr/HomeGuard
After=network.target mosquitto.service
Wants=network.target
RequiresMountsFor=/home/homeguard/HomeGuard

[Service]
Type=simple
User=homeguard
Group=homeguard
WorkingDirectory=/home/homeguard/HomeGuard
Environment=PATH=/usr/bin:/usr/local/bin
Environment=PYTHONPATH=/home/homeguard/HomeGuard/web:/home/homeguard/HomeGuard
ExecStart=/usr/bin/python3 /home/homeguard/HomeGuard/web/mqtt_service.py start
ExecStop=/usr/bin/python3 /home/homeguard/HomeGuard/web/mqtt_service.py stop
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/home/homeguard/HomeGuard/logs /home/homeguard/HomeGuard/db /tmp
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=homeguard-mqtt

[Install]
WantedBy=multi-user.target
```

### **2. Configurar Permissões**
```bash
# Tornar mqtt_service.py executável
chmod +x /home/homeguard/HomeGuard/web/mqtt_service.py

# Criar diretórios necessários
mkdir -p /home/homeguard/HomeGuard/logs
mkdir -p /home/homeguard/HomeGuard/db

# Definir permissões corretas
chown -R homeguard:homeguard /home/homeguard/HomeGuard/logs
chown -R homeguard:homeguard /home/homeguard/HomeGuard/db
```

### **3. Ativar e Iniciar Serviço**
```bash
# Recarregar configuração systemd
sudo systemctl daemon-reload

# Habilitar serviço para boot automático
sudo systemctl enable homeguard-mqtt

# Iniciar serviço agora
sudo systemctl start homeguard-mqtt

# Verificar status
sudo systemctl status homeguard-mqtt
```

## 🔧 Gerenciamento do Serviço

### **Script de Gerenciamento**
Use o script `manage-mqtt-service.sh` para facilitar o gerenciamento:

```bash
# Ver status completo
./scripts/manage-mqtt-service.sh status

# Iniciar serviço
./scripts/manage-mqtt-service.sh start

# Parar serviço
./scripts/manage-mqtt-service.sh stop

# Reiniciar serviço
./scripts/manage-mqtt-service.sh restart

# Ver logs em tempo real
./scripts/manage-mqtt-service.sh logs

# Habilitar boot automático
./scripts/manage-mqtt-service.sh enable

# Desabilitar boot automático
./scripts/manage-mqtt-service.sh disable
```

### **Comandos Systemctl Diretos**
```bash
# Status do serviço
sudo systemctl status homeguard-mqtt

# Iniciar/Parar/Reiniciar
sudo systemctl start homeguard-mqtt
sudo systemctl stop homeguard-mqtt
sudo systemctl restart homeguard-mqtt

# Habilitar/Desabilitar boot automático
sudo systemctl enable homeguard-mqtt
sudo systemctl disable homeguard-mqtt

# Ver logs
sudo journalctl -u homeguard-mqtt -f
sudo journalctl -u homeguard-mqtt -n 50
```

## 📊 Monitoramento

### **Verificar Status do Serviço**
```bash
# Status rápido
systemctl is-active homeguard-mqtt
systemctl is-enabled homeguard-mqtt

# Status detalhado
sudo systemctl status homeguard-mqtt --no-pager
```

### **Logs do Sistema**
```bash
# Logs em tempo real
sudo journalctl -u homeguard-mqtt -f

# Últimas 50 linhas
sudo journalctl -u homeguard-mqtt -n 50

# Logs com timestamp específico
sudo journalctl -u homeguard-mqtt --since "2023-09-09 10:00:00"

# Logs de erro apenas
sudo journalctl -u homeguard-mqtt -p err
```

### **Logs da Aplicação**
```bash
# Log específico da aplicação (se configurado)
tail -f /home/pi/HomeGuard/logs/mqtt_service.log

# Ver estatísticas do banco
sqlite3 /home/pi/HomeGuard/db/homeguard.db "SELECT COUNT(*) as total_messages FROM activity;"
```

## 🐛 Troubleshooting

### **Serviço Não Inicia**

#### **1. Verificar Logs de Erro**
```bash
sudo journalctl -u homeguard-mqtt -n 20 --no-pager
```

#### **2. Problemas Comuns**

**Erro de Permissões:**
```bash
# Corrigir permissões
sudo chown -R homeguard:homeguard /home/homeguard/HomeGuard
chmod +x /home/homeguard/HomeGuard/web/mqtt_service.py
```

**Python não encontrado:**
```bash
# Verificar caminho do Python
which python3
# Atualizar ExecStart no arquivo de serviço se necessário
```

**Dependências não encontradas:**
```bash
# Instalar dependências
cd /home/homeguard/HomeGuard
pip3 install -r requirements.txt
```

**MQTT Broker offline:**
```bash
# Verificar broker Mosquitto
sudo systemctl status mosquitto
sudo systemctl start mosquitto
```

### **Serviço Para Unexpectadamente**

#### **1. Verificar Logs de Crash**
```bash
sudo journalctl -u homeguard-mqtt --since "1 hour ago"
```

#### **2. Verificar Recursos do Sistema**
```bash
# Memória disponível
free -h

# Espaço em disco
df -h

# Processos em execução
top -p $(pgrep -f mqtt_service)
```

#### **3. Verificar Conectividade MQTT**
```bash
# Testar conexão MQTT
mosquitto_pub -h localhost -t "test/topic" -m "test message"
mosquitto_sub -h localhost -t "test/topic" -C 1
```

### **Problemas de Performance**

#### **1. Otimizar Configuração**
```bash
# Editar arquivo de serviço para melhor performance
sudo nano /etc/systemd/system/homeguard-mqtt.service

# Adicionar na seção [Service]:
# Nice=10                    # Menor prioridade CPU
# IOSchedulingClass=2        # Melhor I/O scheduling
# IOSchedulingPriority=4
```

#### **2. Monitorar Recursos**
```bash
# Monitor contínuo de recursos
watch 'ps aux | grep mqtt_service; echo ""; free -h; echo ""; df -h /'
```

## 🔒 Segurança

### **Configurações de Segurança Implementadas**
- ✅ **NoNewPrivileges**: Impede escalação de privilégios
- ✅ **PrivateTmp**: Diretório /tmp isolado
- ✅ **ProtectSystem**: Sistema de arquivos protegido
- ✅ **ReadWritePaths**: Acesso limitado apenas aos diretórios necessários

### **Hardening Adicional**
```bash
# Limitar acesso de rede (opcional)
sudo ufw allow from 192.168.1.0/24 to any port 1883

# Logs de acesso
sudo auditctl -w /home/pi/HomeGuard -p rwxa -k homeguard_access
```

## 📈 Otimização

### **Performance do Raspberry Pi**
```bash
# Aumentar swap se necessário
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile  # CONF_SWAPSIZE=1024
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Otimizar boot
sudo systemctl disable bluetooth
sudo systemctl disable hciuart
```

### **Configuração de Logs**
```bash
# Limitar tamanho dos logs do systemd
sudo nano /etc/systemd/journald.conf

# Adicionar:
# SystemMaxUse=100M
# SystemMaxFileSize=10M
# SystemMaxFiles=10

sudo systemctl restart systemd-journald
```

## 📅 Manutenção

### **Backup da Configuração**
```bash
# Backup do arquivo de serviço
sudo cp /etc/systemd/system/homeguard-mqtt.service ~/homeguard-mqtt.service.backup

# Backup do banco de dados
cp /home/homeguard/HomeGuard/db/homeguard.db ~/homeguard_backup_$(date +%Y%m%d).db
```

### **Rotação de Logs**
```bash
# Criar configuração logrotate
sudo nano /etc/logrotate.d/homeguard

# Conteúdo:
/home/homeguard/HomeGuard/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 homeguard homeguard
    postrotate
        systemctl reload homeguard-mqtt || true
    endscript
}
```

## ✅ Checklist de Instalação

- [ ] ✅ **Raspberry Pi configurado** com Raspbian/Ubuntu
- [ ] ✅ **Python 3.7+** instalado e funcionando
- [ ] ✅ **Usuário homeguard** criado no sistema
- [ ] ✅ **Projeto HomeGuard** clonado em `/home/homeguard/HomeGuard/`
- [ ] ✅ **Dependências Python** instaladas
- [ ] ✅ **Broker MQTT** (Mosquitto) rodando
- [ ] ✅ **Script de instalação** executado: `sudo ./scripts/setup-mqtt-service.sh`
- [ ] ✅ **Serviço ativo**: `systemctl is-active homeguard-mqtt`
- [ ] ✅ **Boot automático habilitado**: `systemctl is-enabled homeguard-mqtt`
- [ ] ✅ **Teste de reinicialização** realizado
- [ ] ✅ **Logs funcionando** corretamente
- [ ] ✅ **Monitoramento** configurado

---

## 🎉 Resultado Final

Após seguir este guia, você terá:

1. **Serviço SystemD** configurado e funcionando
2. **Inicialização automática** no boot do Raspberry Pi
3. **Reinicialização automática** em caso de falhas
4. **Logs centralizados** via journald
5. **Scripts de gerenciamento** para facilitar a manutenção
6. **Segurança** implementada conforme best practices
7. **Monitoramento** e troubleshooting facilitados

O serviço `mqtt_service.py` agora funcionará como um **daemon profissional** no seu Raspberry Pi! 🚀🏠
