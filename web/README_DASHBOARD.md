# HomeGuard Dashboard System

Sistema completo de painéis Flask para monitoramento IoT usando as views do banco de dados HomeGuard.

## 🔧 Características

### Dashboard Principal
- **Resumo geral** do sistema com estatísticas de todos os sensores
- **Contadores** de dispositivos ativos por tipo
- **Status em tempo real** de cada categoria de sensor
- **Auto-atualização** configurável (30 segundos)

### Painel de Temperatura
- **Gráficos interativos** com Chart.js mostrando temperatura ao longo do tempo
- **Estatísticas por dispositivo** (média, mín/máx, RSSI, status)
- **Filtros** por período (1h, 6h, 24h, 1 semana) e dispositivo específico
- **Histórico detalhado** com informações do sensor

### Painel de Umidade
- **Monitoramento de umidade** com análise de conforto
- **Análise de conforto automática** baseada nos níveis de umidade
- **Recomendações** para melhoria do ambiente
- **Análise por período do dia** (madrugada, manhã, tarde, noite)
- **Classificação de conforto** (Muito Seco, Seco, Ideal, Úmido, Muito Úmido)

### Painel de Movimento
- **Detecção de padrões** de movimento
- **Análise temporal** (por hora e dia da semana)
- **Estatísticas de frequência** (hora/dia de maior atividade)
- **Histórico de detecções** com tempo decorrido

### Painel de Relés
- **Controle manual** de relés via interface web
- **Histórico de comandos** (ON, OFF, AUTO)
- **Análise de uso** por relé e período
- **Comando customizado** para tópicos específicos
- **Status atual** de cada relé

## 🗄️ Views do Banco de Dados Utilizadas

O sistema utiliza as seguintes views criadas anteriormente:

```sql
-- Temperatura
CREATE VIEW vw_temperature_activity AS
SELECT 
    a.id, a.created_at, a.topic, a.message,
    JSON_EXTRACT(a.message, '$.device_id') as device_id,
    JSON_EXTRACT(a.message, '$.name') as name,
    JSON_EXTRACT(a.message, '$.location') as location,
    JSON_EXTRACT(a.message, '$.sensor_type') as sensor_type,
    JSON_EXTRACT(a.message, '$.temperature') as temperature,
    JSON_EXTRACT(a.message, '$.unit') as unit,
    JSON_EXTRACT(a.message, '$.rssi') as rssi,
    JSON_EXTRACT(a.message, '$.uptime') as uptime
FROM activity a 
WHERE a.topic LIKE '%temperature%'
AND JSON_VALID(a.message)
ORDER BY a.created_at DESC;

-- Umidade (similar structure for humidity, motion, relay)
```

## 🚀 Como Executar

### 1. Instalar Dependências
```bash
# Navegar para o diretório web
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/web

# Instalar Flask (se ainda não tiver)
pip install flask
```

### 2. Executar o Dashboard
```bash
# Executar o dashboard
python dashboard.py
```

### 3. Acessar a Interface
- **Dashboard Principal**: http://localhost:5000/
- **Painel de Temperatura**: http://localhost:5000/temperature
- **Painel de Umidade**: http://localhost:5000/humidity
- **Painel de Movimento**: http://localhost:5000/motion
- **Painel de Relés**: http://localhost:5000/relay

## 📊 APIs Disponíveis

### APIs de Dados
- `GET /api/temperature/data?hours=24&limit=50` - Dados de temperatura
- `GET /api/humidity/data?hours=24&limit=50` - Dados de umidade
- `GET /api/motion/data?hours=24&limit=50` - Dados de movimento
- `GET /api/relay/data?hours=24&limit=50` - Dados de relés

### APIs de Estatísticas
- `GET /api/temperature/stats?hours=24` - Estatísticas de temperatura por dispositivo
- `GET /api/humidity/stats?hours=24` - Estatísticas de umidade por dispositivo
- `GET /api/motion/stats?hours=24` - Estatísticas de movimento por dispositivo
- `GET /api/dashboard/summary?hours=24` - Resumo geral do dashboard

### Parâmetros Disponíveis
- **hours**: Período em horas (1, 6, 24, 168)
- **limit**: Limite de registros retornados (10-1000)

## 🎨 Características da Interface

### Design Responsivo
- **Layout adaptável** para desktop, tablet e mobile
- **Cores consistentes** com tema azul/roxo
- **Cards informativos** com gradientes

### Funcionalidades Interativas
- **Auto-refresh** configurável (pode ser ligado/desligado)
- **Filtros dinâmicos** por período e dispositivo
- **Gráficos interativos** com Chart.js
- **Status em tempo real** (online/offline)

### Navegação
- **Menu de navegação** sempre visível
- **Indicador de página ativa** no menu
- **Breadcrumb** visual para orientação

## 🔧 Configuração

### Banco de Dados
```python
# Configuração do banco no dashboard.py
DB_PATH = os.path.join(PROJECT_ROOT, 'db', 'homeguard.db')
```

### Porta do Servidor
```python
# Executar na porta 5000 (padrão Flask)
app.run(host='0.0.0.0', port=5000, debug=True)
```

## 📈 Análises Disponíveis

### Temperatura
- Temperatura média, mínima e máxima por período
- Comparação entre dispositivos
- Histórico detalhado com uptime e RSSI

### Umidade
- **Análise de conforto** automática
- **Recomendações** baseadas nos níveis
- **Análise temporal** por período do dia
- Classificação: Muito Seco (<30%), Seco (30-40%), Ideal (40-60%), Úmido (60-70%), Muito Úmido (>70%)

### Movimento
- **Padrões de detecção** por hora e dia da semana
- **Hora de maior atividade** identificada automaticamente
- **Dia da semana** com mais detecções
- Análise de frequência temporal

### Relés
- **Controle manual** via interface web
- **Histórico de comandos** com análise de uso
- **Estado atual** de cada relé
- Análise de uso por período do dia

## 🎯 Próximos Passos

1. **Integração MQTT Real**: Implementar envio real de comandos MQTT
2. **Autenticação**: Adicionar sistema de login
3. **Alertas**: Sistema de notificações para eventos importantes
4. **Configurações**: Interface para configurar thresholds e alertas
5. **Exportação**: Funcionalidade para exportar dados (CSV, PDF)
6. **Backup**: Sistema automático de backup das configurações

## 🔍 Troubleshooting

### Erro de Flask não encontrado
```bash
pip install flask
```

### Erro de banco de dados
- Verificar se o arquivo `homeguard.db` existe em `../db/`
- Verificar se as views foram criadas corretamente

### Gráficos não aparecem
- Verificar conexão com internet (Chart.js é carregado via CDN)
- Verificar console do navegador para erros JavaScript

### Auto-refresh não funciona
- Verificar se JavaScript está habilitado
- Verificar console do navegador para erros

## 📁 Estrutura de Arquivos

```
web/
├── dashboard.py              # Aplicação Flask principal
├── templates/               # Templates HTML
│   ├── base.html           # Template base com CSS/JS comum
│   ├── dashboard.html      # Dashboard principal
│   ├── temperature_panel.html  # Painel de temperatura
│   ├── humidity_panel.html     # Painel de umidade
│   ├── motion_panel.html       # Painel de movimento
│   └── relay_panel.html        # Painel de relés
└── README_DASHBOARD.md      # Esta documentação
```

## 📞 Suporte

Para dúvidas ou problemas:
1. Verificar logs do Flask no terminal
2. Verificar console do navegador (F12) para erros JavaScript
3. Verificar se o banco de dados possui dados nas views
4. Testar APIs individualmente via browser ou curl

---

**Sistema criado para monitoramento completo da rede de sensores HomeGuard com interface web moderna e responsiva.**
