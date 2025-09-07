# HomeGuard MQTT Activity Logger

Este sistema captura todas as mensagens MQTT do sistema HomeGuard e as armazena em um banco de dados SQLite para análise e uso na aplicação web Flask.

## 📂 Arquivos Criados

### 1. `init_database.py`
Script para inicializar o banco de dados SQLite com a tabela de atividades.

```bash
python3 init_database.py
```

### 2. `mqtt_activity_logger.py`
Classe principal que implementa o listener MQTT (equivalente ao `mosquitto_sub`).

### 3. `mqtt_service.py`
Serviço daemon para executar o logger MQTT em background.

### 4. `db_query.py`
Utilitários para consultar e analisar os dados capturados.

## 🚀 Como Usar

### Para Raspberry Pi (Ambiente Externally-Managed)

**Opção 1: Instalação Simples (Recomendada)**
```bash
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/web
./install_simple.sh
```

**Opção 2: Instalação Completa (com Virtual Environment)**
```bash
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/web
./install_raspberry.sh
```

### Para Outros Sistemas

#### Inicializar o Banco de Dados
```bash
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/web
python3 init_database.py
```

### Iniciar o Serviço MQTT
```bash
# Iniciar o serviço
python3 mqtt_service.py start

# Verificar status
python3 mqtt_service.py status

# Parar o serviço
python3 mqtt_service.py stop

# Reiniciar o serviço
python3 mqtt_service.py restart
```

### Consultar Dados Capturados

#### Estatísticas Gerais
```bash
python3 db_query.py --stats
```

#### Atividades Recentes
```bash
# Últimas 20 atividades
python3 db_query.py

# Últimas 50 atividades
python3 db_query.py --recent 50
```

#### Atividade de Dispositivo Específico
```bash
# Ver atividade do RDA5807
python3 db_query.py --device RDA5807

# Ver atividade de sensor de movimento
python3 db_query.py --device motion

# Ver atividade de sensor DHT
python3 db_query.py --device sensor
```

#### Exportar Dados
```bash
# Exportar últimas 24 horas
python3 db_query.py --export data_24h.json

# Exportar últimas 48 horas
python3 db_query.py --export data_48h.json --hours 48
```

## 📊 Estrutura do Banco de Dados

### Tabela `activity`
- `id`: Chave primária auto-incremental
- `created_at`: Timestamp da mensagem (YYYY-MM-DD HH:MM:SS)
- `topic`: Tópico MQTT da mensagem
- `message`: Conteúdo da mensagem (JSON ou texto)

## 🔧 Configurações MQTT

O sistema está configurado para conectar ao broker MQTT:
- **Host**: 192.168.1.102
- **Porta**: 1883
- **Usuário**: homeguard
- **Senha**: pu2clr123456
- **Tópicos**: home/# (todos os tópicos home)

## 📱 Tópicos Capturados

O sistema captura mensagens dos seguintes dispositivos:

### Sensores de Movimento
- `home/motion/{device_id}/status`
- `home/motion/{device_id}/detection`

### Sensores DHT (Temperatura/Umidade)
- `home/temperature/{device_id}/status`
- `home/humidity/{device_id}/status`
- `home/sensor/{device_id}/status`

### Controle RDA5807 (Rádio FM)
- `home/RDA5807/frequency`
- `home/RDA5807/volume`
- `home/RDA5807/status`

### Relés e Atuadores
- `home/relay/{device_id}/status`
- `home/relay/{device_id}/command`

## 📈 Análise de Dados

O sistema permite análise completa das atividades:

1. **Estatísticas de Uso**: Quantas mensagens por dispositivo
2. **Padrões Temporais**: Atividade por período
3. **Status dos Dispositivos**: Último estado conhecido
4. **Histórico Completo**: Rastreamento de todas as mudanças

## 🔄 Integração com Flask

A estrutura de dados está preparada para integração com a nova aplicação Flask:

- **Dados Centralizados**: Todas as mensagens em uma única tabela
- **Formato JSON**: Mensagens estruturadas dos dispositivos
- **Timestamps Precisos**: Rastreamento temporal completo
- **APIs Prontas**: Funções de consulta preparadas

## 🔒 Recursos de Segurança

- **Threading Locks**: Proteção contra escrita simultânea no banco
- **Error Handling**: Tratamento robusto de erros de conexão
- **Graceful Shutdown**: Encerramento limpo do serviço
- **PID Management**: Controle de instâncias do serviço

## 🌟 Próximos Passos

Este sistema fornece a base para:

1. **Dashboard Web**: Interface Flask para visualizar dados
2. **APIs REST**: Endpoints para aplicações mobile
3. **Alertas**: Sistema de notificações baseado em eventos
4. **Análise Histórica**: Relatórios e gráficos de tendências
5. **Automação**: Regras baseadas em padrões de atividade

## 📋 Logs e Debugging

- **Service Logs**: `/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/logs/mqtt_service.log`
- **PID File**: `/tmp/homeguard_mqtt_logger.pid`
- **Database**: `/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard/db/homeguard.db`

## ✅ Teste de Funcionamento

Para verificar se tudo está funcionando:

1. Inicialize o banco: `python3 init_database.py`
2. Inicie o serviço: `python3 mqtt_service.py start`
3. Aguarde alguns minutos para capturar mensagens
4. Verifique os dados: `python3 db_query.py --stats`

O sistema equivale exatamente ao comando:
```bash
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t 'home/#' -v
```

Mas com a vantagem de armazenar permanentemente todas as mensagens no banco de dados!
