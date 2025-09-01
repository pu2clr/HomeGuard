# 🔒 Guia Completo de Segurança MQTT - HomeGuard

## 🎯 **Níveis de Segurança Implementáveis**

### ✅ **Nível 1: Autenticação Básica** (JÁ IMPLEMENTADO)
- Usuário/senha: `homeguard`/`pu2clr123456`
- ACL restringindo tópico `home/#`
- Desabilitação de conexões anônimas

### 🔐 **Nível 2: Conexão TLS/SSL Criptografada** (RECOMENDADO)
- Certificados SSL para criptografia
- Proteção contra interceptação de dados
- Validação de identidade do servidor

### 🛡️ **Nível 3: Certificados Cliente** (MÁXIMA SEGURANÇA)
- Autenticação mútua com certificados
- Cada dispositivo com certificado único
- Impossível falsificar identidade

### 🌐 **Nível 4: Segurança de Rede**
- Firewall restringindo acesso
- VPN para acesso externo
- Segregação de rede IoT

---

## 🔐 **NÍVEL 2: Implementando TLS/SSL**

### **Passo 1: Gerar Certificados SSL**

#### Criar Autoridade Certificadora (CA)
```bash
# Criar diretório para certificados
sudo mkdir -p /etc/mosquitto/certs
cd /etc/mosquitto/certs

# Gerar chave privada da CA
sudo openssl genrsa -out ca.key 4096

# Gerar certificado da CA
sudo openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/C=BR/ST=SP/L=SaoPaulo/O=HomeGuard/OU=Security/CN=HomeGuard-CA"
```

#### Criar Certificado do Servidor
```bash
# Gerar chave privada do servidor
sudo openssl genrsa -out server.key 4096

# Gerar requisição de certificado do servidor
sudo openssl req -new -key server.key -out server.csr -subj "/C=BR/ST=SP/L=SaoPaulo/O=HomeGuard/OU=MQTT/CN=192.168.18.198"

# Assinar certificado do servidor com a CA
sudo openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650

# Limpar arquivo temporário
sudo rm server.csr
```

### **Passo 2: Configurar Mosquitto com TLS**

Atualizar `/etc/mosquitto/conf.d/homeguard.conf`:
```conf
# ========================================
# MQTT Broker Security Configuration
# HomeGuard Project
# ========================================

# Desabilitar conexões anônimas
allow_anonymous false

# Arquivo de senhas
password_file /etc/mosquitto/homeguard.pw

# Controle de acesso por tópicos
acl_file /etc/mosquitto/homeguard.acl

# ========================================
# TLS/SSL Configuration
# ========================================

# Porta padrão sem criptografia (apenas rede local)
port 1883
bind_address 127.0.0.1

# Porta TLS/SSL (acesso seguro)
listener 8883
bind_address 0.0.0.0

# Certificados SSL
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key

# Versões TLS permitidas (apenas versões seguras)
tls_version tlsv1.2

# Verificar certificado do cliente (opcional - máxima segurança)
# require_certificate true

# ========================================
# Logging e Monitoramento
# ========================================

# Logs detalhados para auditoria
log_dest file /var/log/mosquitto/mosquitto.log
log_type all

# Logs de conexão para monitoramento
connection_messages true
log_timestamp true

# ========================================
# Configurações de Performance e Segurança
# ========================================

# Timeout de conexões inativas
keepalive_interval 60

# Máximo de conexões simultâneas
max_connections 100

# Tamanho máximo de mensagem (1MB)
message_size_limit 1048576

# Persistência de dados
persistence true
persistence_location /var/lib/mosquitto/
```

### **Passo 3: Ajustar Permissões**
```bash
# Definir proprietário e permissões corretas
sudo chown mosquitto:mosquitto /etc/mosquitto/certs/*
sudo chmod 600 /etc/mosquitto/certs/*.key
sudo chmod 644 /etc/mosquitto/certs/*.crt

# Criar diretório de logs
sudo mkdir -p /var/log/mosquitto
sudo chown mosquitto:mosquitto /var/log/mosquitto
```

### **Passo 4: Reiniciar Mosquitto**
```bash
# Testar configuração
sudo mosquitto -c /etc/mosquitto/conf.d/homeguard.conf -v

# Se OK, reiniciar serviço
sudo systemctl restart mosquitto
sudo systemctl status mosquitto
```

---

## 📱 **Atualizando Dispositivos ESP para TLS**

### **Template Arduino com TLS**
```cpp
// Adicionar biblioteca SSL
#include <WiFiClientSecure.h>

// Certificado CA (colocar o conteúdo de ca.crt)
const char* ca_cert = R"EOF(
-----BEGIN CERTIFICATE-----
[CONTEÚDO DO CERTIFICADO ca.crt]
-----END CERTIFICATE-----
)EOF";

// Cliente seguro
WiFiClientSecure secureClient;
PubSubClient client(secureClient);

void setup_mqtt() {
    // Configurar certificado
    secureClient.setCACert(ca_cert);
    
    // Conectar na porta segura
    client.setServer(MQTT_BROKER, 8883);
    client.setCallback(mqtt_callback);
}
```

### **Script Python com TLS**
```python
import ssl
import paho.mqtt.client as mqtt

# Configurar contexto SSL
context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
context.load_verify_locations("/path/to/ca.crt")

# Cliente MQTT com SSL
client = mqtt.Client()
client.tls_set_context(context)
client.username_pw_set("homeguard", "pu2clr123456")
client.connect("192.168.18.198", 8883, 60)
```

---

## 🛡️ **NÍVEL 3: Certificados Cliente (Máxima Segurança)**

### **Gerar Certificados para Cada Dispositivo**
```bash
# Para cada dispositivo (exemplo: garagem)
DEVICE_NAME="garagem"

# Gerar chave privada do cliente
sudo openssl genrsa -out ${DEVICE_NAME}_client.key 4096

# Gerar requisição de certificado
sudo openssl req -new -key ${DEVICE_NAME}_client.key -out ${DEVICE_NAME}_client.csr -subj "/C=BR/ST=SP/L=SaoPaulo/O=HomeGuard/OU=Sensors/CN=motion-${DEVICE_NAME}"

# Assinar com CA
sudo openssl x509 -req -in ${DEVICE_NAME}_client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ${DEVICE_NAME}_client.crt -days 3650

# Limpar temporário
sudo rm ${DEVICE_NAME}_client.csr
```

### **Configurar Mosquitto para Certificados Cliente**
```conf
# Adicionar ao homeguard.conf
require_certificate true
use_identity_as_username true
```

---

## 🌐 **NÍVEL 4: Segurança de Rede**

### **Firewall (UFW)**
```bash
# Permitir apenas portas necessárias
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 1883/tcp    # MQTT local
sudo ufw allow 8883/tcp    # MQTT TLS
sudo ufw --force enable
```

### **Fail2Ban para MQTT**
Criar `/etc/fail2ban/filter.d/mosquitto.conf`:
```ini
[Definition]
failregex = ^.* Client .* disconnected due to protocol error\.$
            ^.* Bad username or password for .* from .*$
            ^.* Connection denied from .*$
ignoreregex =
```

Configurar `/etc/fail2ban/jail.local`:
```ini
[mosquitto]
enabled = true
port = 1883,8883
filter = mosquitto
logpath = /var/log/mosquitto/mosquitto.log
maxretry = 3
bantime = 3600
```

---

## 🔍 **Monitoramento e Auditoria**

### **Script de Monitoramento de Segurança**
```bash
#!/bin/bash
# Monitorar tentativas de acesso não autorizado

tail -f /var/log/mosquitto/mosquitto.log | while read line; do
    if [[ $line == *"Bad username"* ]] || [[ $line == *"Connection denied"* ]]; then
        echo "$(date): ALERTA SEGURANÇA - $line" | tee -a /var/log/homeguard-security.log
        # Opcional: enviar notificação
    fi
done
```

---

## ✅ **Checklist de Segurança**

### **Básico (Implementado)**
- [x] Autenticação usuário/senha
- [x] ACL restringindo tópicos
- [x] Desabilitação de conexões anônimas

### **Intermediário (Recomendado)**
- [ ] Certificados TLS/SSL
- [ ] Criptografia de dados em trânsito
- [ ] Logs de auditoria
- [ ] Firewall configurado

### **Avançado (Máxima Segurança)**
- [ ] Certificados cliente individuais
- [ ] Fail2Ban configurado
- [ ] Monitoramento automatizado
- [ ] Segregação de rede IoT

### **Rede (Opcional)**
- [ ] VPN para acesso externo
- [ ] VLAN dedicada para IoT
- [ ] Rate limiting
- [ ] Backup de certificados

---

## 🚀 **Próximos Passos Recomendados**

1. **Implementar TLS/SSL** (Nível 2) - Criptografia básica
2. **Configurar logs de auditoria** - Monitoramento
3. **Configurar firewall** - Proteção de rede
4. **Testar com dispositivos** - Validação

**Qual nível deseja implementar primeiro?** Recomendo começar com TLS/SSL (Nível 2) para criptografar toda comunicação.
