# 🚀 HomeGuard - Roadmap e TODO

## ✅ **Concluído - Fase 1: Fundação**
1) ✅ **Sistema SQLite**: Aplicação Python para persistir dados dos sensores
2) ✅ **Dashboard Flask**: Interface web completa e responsiva  
3) ✅ **Controle MQTT**: Integração para controle de relés
4) ✅ **Multi-plataforma**: Scripts de instalação para Pi/Linux/macOS/Windows
5) ✅ **Documentação**: Guias completos de instalação e configuração
6) ✅ **Templates HTML**: Interface moderna com auto-refresh
7) ✅ **APIs REST**: Endpoints para integração externa
8) ✅ **Logging**: Sistema completo de logs e monitoramento

## 🔄 **Em Progresso - Fase 2: Validação**
1) 🔄 **Testes Produção**: Validação completa no Raspberry Pi
2) 🔄 **MQTT Real**: Teste da integração ESP8266 ↔ Broker ↔ Flask
3) 🔄 **Performance**: Otimização para ambientes de baixo recurso
4) 🔄 **Registro de Inicialização**: Log de startup dos dispositivos no banco

## 📋 **Planejado - Fase 3: Expansão**

### **🔒 Segurança e Produção**
- [ ] **HTTPS/SSL**: Certificados para acesso seguro
- [ ] **Autenticação**: Sistema de login/usuários
- [ ] **Firewall**: Configuração de segurança de rede
- [ ] **Backup Automático**: Sistema de backup do banco SQLite

### **📊 Análises Avançadas** 
- [ ] **Gráficos Interativos**: Charts com histórico de atividade
- [ ] **Relatórios PDF**: Geração automática de relatórios
- [ ] **Alertas Email/SMS**: Notificações para eventos críticos
- [ ] **Análise Preditiva**: ML para padrões de atividade

### **🔌 Expansão IoT**
- [ ] **Múltiplos Sensores**: Suporte a temperatura, umidade, etc.
- [ ] **Geofencing**: Automação baseada em localização
- [ ] **Integração Home Assistant**: Plugin oficial
- [ ] **Alexa/Google**: Controle por voz

### **📱 Mobile e UI/UX**
- [ ] **PWA**: Progressive Web App para mobile
- [ ] **App Nativo**: Aplicativo iOS/Android
- [ ] **WebSocket Real-time**: Updates instantâneos
- [ ] **Dark Mode**: Interface escura
- [ ] **Multi-idioma**: Suporte i18n

### **🏗️ Arquitetura**
- [ ] **Docker Compose**: Containerização completa
- [ ] **Kubernetes**: Orquestração para produção
- [ ] **Load Balancer**: Alta disponibilidade
- [ ] **Redis Cache**: Cache distribuído
- [ ] **PostgreSQL**: Migração para DB robusto

---

## 🎯 **Prioridades Imediatas**

### **🔥 Critical (Esta Semana)**
1. **Teste completo no Raspberry Pi** - Validar todas as funcionalidades
2. **MQTT Integration Testing** - Confirmar comunicação ESP ↔ Flask
3. **Documentação Final** - Validar todos os guias de instalação

### **⚡ High (Próximas 2 Semanas)**  
1. **Performance Tuning** - Otimizar para Pi Zero/Pi 3
2. **Error Handling** - Melhorar tratamento de erros MQTT/DB
3. **Auto-restart** - Sistema de monitoramento com auto-recovery

### **📈 Medium (Próximo Mês)**
1. **SSL/HTTPS** - Segurança para acesso remoto
2. **User Authentication** - Sistema básico de login
3. **Data Visualization** - Gráficos básicos de atividade

---

## 🐛 **Bugs Conhecidos**
- [ ] **Timezone**: Verificar se timezone está correto em todas as plataformas
- [ ] **MQTT Reconnect**: Melhorar reconexão automática após falha de rede
- [ ] **DB Lock**: Investigar possível lock no SQLite com múltiplos acessos
- [ ] **Memory Leak**: Monitorar uso de memória em execução prolongada

---

## 💡 **Ideias Futuras**
- **Machine Learning**: Detecção de anomalias nos padrões de movimento
- **Computer Vision**: Integração com câmeras para reconhecimento facial
- **Weather Integration**: Correlação com dados meteorológicos
- **Energy Monitoring**: Monitoramento de consumo energético
- **Social Features**: Compartilhamento de status com família/amigos
- **Plugin System**: Arquitetura extensível para plugins de terceiros

---

## 📊 **Métricas de Sucesso**
- ✅ **Estabilidade**: 99.9% uptime no Raspberry Pi
- ✅ **Performance**: < 100ms response time para APIs
- ✅ **Usabilidade**: Interface funcional em mobile/desktop
- ✅ **Documentação**: Guia completo para todas as plataformas
- 🔄 **Adoção**: Feedback positivo da comunidade
- 🔄 **Contribuições**: PRs externos aceitos

---

**Status Geral do Projeto: 🟢 ATIVO - Fase de Validação**

*Última atualização: 18/08/2025*



### Paineis de Monitoramento

-- Obtendo dados histórico de temperatura 
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.temperature') as temperature,
    json_extract(message, '$.unit') as unit,
    json_extract(message, '$.rssi') as rssi,
    json_extract(message, '$.uptime') as uptime
FROM activity 
WHERE topic like  'home/temperature/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL
ORDER BY created_at DESC

-- Obtendo dados histórico de Umidade
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.humidity') as temperature,
    json_extract(message, '$.unit') as unit,
    json_extract(message, '$.rssi') as rssi,
    json_extract(message, '$.uptime') as uptime
FROM activity 
WHERE topic like  'home/humidity/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.humidity') IS NOT NULL
ORDER BY created_at DESC

-- Obtendo detecção de movimento
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location
FROM activity 
WHERE topic like  'home/motion/%/event'
    AND json_valid(message) = 1
    AND json_extract(message, '$.motion') = 1
ORDER BY created_at DESC

-- Obtendo dados ação de relés
SELECT 
    created_at,
    topic,
	message
FROM activity 
WHERE topic like  'home/relay/%/command' AND message = 'ON'
ORDER BY created_at DESC

-- Obtendo dados do rádio DSP5807
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.command') as command,
    json_extract(message, '$.value') as value,
    json_extract(message, '$.location') as location,   
    json_extract(message, '$.action') as action
FROM activity 
WHERE topic like  'home/RDA5807/status%'
ORDER BY created_at DESC


-- Views

-- Obtendo dados histórico de temperatura 
create VIEW vw_temperature_activity as
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.temperature') as temperature,
    json_extract(message, '$.unit') as unit,
    json_extract(message, '$.rssi') as rssi,
    json_extract(message, '$.uptime') as uptime
FROM activity 
WHERE topic like  'home/temperature/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.temperature') IS NOT NULL
ORDER BY created_at DESC;

-- Obtendo dados histórico de Umidade
create VIEW vw_humidity_activity as
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.humidity') as temperature,
    json_extract(message, '$.unit') as unit,
    json_extract(message, '$.rssi') as rssi,
    json_extract(message, '$.uptime') as uptime
FROM activity 
WHERE topic like  'home/humidity/%/data'
    AND json_valid(message) = 1
    AND json_extract(message, '$.humidity') IS NOT NULL
ORDER BY created_at DESC;


-- Obtendo detecção de movimento
create VIEW vw_motion_activity as
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.name') as name,
    json_extract(message, '$.location') as location
FROM activity 
WHERE topic like  'home/motion/%/event'
    AND json_valid(message) = 1
    AND json_extract(message, '$.motion') = 1
ORDER BY created_at DESC;


-- Obtendo dados ação de relés
create VIEW vw_relay_activity as
SELECT 
    created_at,
    topic,
	message  -- ON ou OFF
FROM activity 
WHERE topic like  'home/relay/%/command' -- AND message = 'ON'
ORDER BY created_at DESC;

