# 🔄 Guia de Migração: Usuário "pi" → "homeguard"

Guia para migrar um sistema HomeGuard existente do usuário "pi" para o usuário "homeguard".

## 🎯 Quando Usar Este Guia

- ✅ Você já tem o HomeGuard funcionando com usuário "pi"
- ✅ Quer padronizar usando usuário "homeguard"
- ✅ Deseja maior segurança e organização
- ✅ Prefere separar aplicações do usuário padrão do sistema

## 📋 Pré-requisitos

- Sistema HomeGuard funcionando
- Acesso sudo/root
- Backup dos dados importantes

## 🚀 Processo de Migração

### **Passo 1: Backup dos Dados**
```bash
# Fazer backup completo
sudo systemctl stop homeguard-mqtt 2>/dev/null || true
cd /home/pi
tar -czf homeguard_backup_$(date +%Y%m%d).tar.gz HomeGuard/

# Verificar backup
ls -lh homeguard_backup_*.tar.gz
```

### **Passo 2: Criar Usuário HomeGuard**
```bash
# Usar script automático
cd /home/pi/HomeGuard
sudo ./scripts/create-homeguard-user.sh
```

### **Passo 3: Migrar Projeto**
```bash
# Copiar projeto para novo usuário
sudo cp -r /home/pi/HomeGuard /home/homeguard/
sudo chown -R homeguard:homeguard /home/homeguard/HomeGuard

# Verificar cópia
sudo -u homeguard ls -la /home/homeguard/HomeGuard
```

### **Passo 4: Reconfigurar Serviço**
```bash
# Parar serviço antigo (se existir)
sudo systemctl stop homeguard-mqtt 2>/dev/null || true
sudo systemctl disable homeguard-mqtt 2>/dev/null || true

# Recriar serviço com novo usuário
cd /home/homeguard/HomeGuard
sudo ./scripts/setup-mqtt-service.sh
```

### **Passo 5: Migrar Banco de Dados**
```bash
# Copiar banco de dados com dados históricos
sudo cp /home/pi/HomeGuard/db/homeguard.db /home/homeguard/HomeGuard/db/
sudo chown homeguard:homeguard /home/homeguard/HomeGuard/db/homeguard.db

# Verificar integridade
sudo -u homeguard sqlite3 /home/homeguard/HomeGuard/db/homeguard.db "SELECT COUNT(*) FROM activity;"
```

### **Passo 6: Migrar Configurações**
```bash
# Copiar arquivos de configuração personalizados
if [ -f /home/pi/HomeGuard/web/config.json ]; then
    sudo cp /home/pi/HomeGuard/web/config.json /home/homeguard/HomeGuard/web/
    sudo chown homeguard:homeguard /home/homeguard/HomeGuard/web/config.json
fi

# Copiar logs importantes (opcional)
if [ -d /home/pi/HomeGuard/logs ]; then
    sudo cp -r /home/pi/HomeGuard/logs/* /home/homeguard/HomeGuard/logs/ 2>/dev/null || true
    sudo chown -R homeguard:homeguard /home/homeguard/HomeGuard/logs/
fi
```

### **Passo 7: Testar Novo Sistema**
```bash
# Verificar status
cd /home/homeguard/HomeGuard
./scripts/manage-mqtt-service.sh status

# Testar funcionalidade
sudo -u homeguard python3 /home/homeguard/HomeGuard/web/mqtt_service.py status
```

### **Passo 8: Remover Sistema Antigo (Opcional)**
```bash
# CUIDADO: Só faça isso após confirmar que novo sistema funciona!

# Parar e remover serviço antigo
sudo systemctl stop homeguard-mqtt 2>/dev/null || true
sudo systemctl disable homeguard-mqtt 2>/dev/null || true
sudo rm -f /etc/systemd/system/homeguard-mqtt.service
sudo systemctl daemon-reload

# Mover projeto antigo (não deletar ainda)
sudo mv /home/pi/HomeGuard /home/pi/HomeGuard_backup_$(date +%Y%m%d)
```

## 🔧 Migração Automática (Script)

Para facilitar, você pode usar este script automático:

```bash
#!/bin/bash
# Script de migração automática

echo "=== MIGRAÇÃO AUTOMÁTICA PI → HOMEGUARD ==="

# Verificar se sistema antigo existe
if [ ! -d "/home/pi/HomeGuard" ]; then
    echo "❌ Sistema antigo não encontrado em /home/pi/HomeGuard"
    exit 1
fi

# Backup
echo "📦 Criando backup..."
cd /home/pi
sudo tar -czf homeguard_migration_backup_$(date +%Y%m%d_%H%M%S).tar.gz HomeGuard/

# Parar serviço antigo
echo "⏹️ Parando serviço antigo..."
sudo systemctl stop homeguard-mqtt 2>/dev/null || true

# Criar usuário
echo "👤 Criando usuário homeguard..."
cd /home/pi/HomeGuard
sudo ./scripts/create-homeguard-user.sh

# Migrar projeto
echo "📁 Migrando projeto..."
sudo cp -r /home/pi/HomeGuard /home/homeguard/
sudo chown -R homeguard:homeguard /home/homeguard/HomeGuard

# Reconfigurar serviço
echo "⚙️ Reconfigurando serviço..."
cd /home/homeguard/HomeGuard
sudo ./scripts/setup-mqtt-service.sh

# Verificar
echo "✅ Verificando migração..."
./scripts/manage-mqtt-service.sh status

echo "🎉 Migração concluída!"
echo "📋 Backup salvo em: /home/pi/homeguard_migration_backup_*"
```

## 🐛 Troubleshooting

### **Serviço Não Inicia**
```bash
# Verificar logs
sudo journalctl -u homeguard-mqtt -n 20

# Verificar permissões
ls -la /home/homeguard/HomeGuard/web/mqtt_service.py
sudo chown homeguard:homeguard /home/homeguard/HomeGuard/web/mqtt_service.py
chmod +x /home/homeguard/HomeGuard/web/mqtt_service.py
```

### **Banco de Dados com Problemas**
```bash
# Verificar integridade
sudo -u homeguard sqlite3 /home/homeguard/HomeGuard/db/homeguard.db ".schema"

# Recriar se necessário
sudo -u homeguard python3 /home/homeguard/HomeGuard/web/db_query.py
```

### **Permissões Incorretas**
```bash
# Corrigir todas as permissões
sudo chown -R homeguard:homeguard /home/homeguard/HomeGuard
sudo chmod -R 755 /home/homeguard/HomeGuard
sudo chmod +x /home/homeguard/HomeGuard/web/mqtt_service.py
sudo chmod +x /home/homeguard/HomeGuard/scripts/*.sh
```

## ✅ Verificação Final

### **Checklist Pós-Migração**
- [ ] ✅ Usuário "homeguard" criado e configurado
- [ ] ✅ Projeto copiado para /home/homeguard/HomeGuard
- [ ] ✅ Banco de dados migrado com dados históricos
- [ ] ✅ Serviço systemd recriado com novo usuário
- [ ] ✅ Serviço iniciando automaticamente
- [ ] ✅ Logs funcionando corretamente
- [ ] ✅ Interface web acessível
- [ ] ✅ MQTT recebendo mensagens
- [ ] ✅ Backup do sistema antigo criado

### **Comandos de Verificação**
```bash
# Status geral
./scripts/manage-mqtt-service.sh status

# Verificar usuário do processo
ps aux | grep mqtt_service

# Verificar logs recentes
sudo journalctl -u homeguard-mqtt -n 10

# Testar banco de dados
sudo -u homeguard sqlite3 /home/homeguard/HomeGuard/db/homeguard.db "SELECT COUNT(*) FROM activity;"
```

## 📈 Benefícios da Migração

### **Segurança**
- ✅ Separação de responsabilidades
- ✅ Usuário dedicado para aplicação
- ✅ Menor superfície de ataque
- ✅ Isolamento de processos

### **Organização**
- ✅ Sistema mais organizado
- ✅ Facilita manutenção
- ✅ Backup/restore simplificado
- ✅ Configurações centralizadas

### **Manutenibilidade**
- ✅ Easier troubleshooting
- ✅ Logs mais claros
- ✅ Permissões bem definidas
- ✅ Atualizações mais seguras

---

## 🎉 Conclusão

Após a migração, você terá um sistema HomeGuard mais seguro e organizado, usando o usuário dedicado "homeguard" em vez do usuário padrão "pi". Isso segue melhores práticas de segurança e facilita a manutenção do sistema.

**A migração preserva todos os dados históricos e configurações!** 🚀
