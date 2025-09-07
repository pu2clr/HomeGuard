# 🍓 HomeGuard MQTT Logger - Comandos Rápidos para Raspberry Pi

## ⚡ Setup Rápido (Copy & Paste)

```bash
# 1. Ir para o diretório
cd ~/HomeGuard/web

# 2. Instalar dependências
./install_simple.sh

# 3. Testar sistema
python3 quick_test.py

# 4. Iniciar serviço MQTT
python3 mqtt_service.py start
```

## 📋 Comandos Úteis

### Controle do Serviço
```bash
python3 mqtt_service.py start     # Iniciar
python3 mqtt_service.py status    # Status
python3 mqtt_service.py stop      # Parar
python3 mqtt_service.py restart   # Reiniciar
```

### Consultar Dados
```bash
python3 db_query.py --stats       # Estatísticas gerais
python3 db_query.py --recent 20   # Últimas 20 mensagens
python3 db_query.py --device RDA5807  # Atividade do rádio
python3 db_query.py --device motion   # Sensores de movimento
```

### Diagnóstico
```bash
python3 quick_test.py             # Teste rápido do sistema
python3 test_system.py            # Teste completo
python3 init_database.py          # Reinicializar banco
```

### Exportar Dados
```bash
python3 db_query.py --export backup_24h.json --hours 24
python3 db_query.py --export backup_week.json --hours 168
```

## 🔍 Solução de Problemas

### Import Error
```bash
# Se der erro de import, teste:
python3 -c "from mqtt_activity_logger import MQTTActivityLogger; print('OK')"

# Se falhar, verifique dependências:
python3 -c "import paho.mqtt.client; print('paho-mqtt OK')"
```

### Permission Error
```bash
# Se der erro de permissão:
sudo chown -R homeguard:homeguard ~/HomeGuard
chmod +x ~/HomeGuard/web/*.py
chmod +x ~/HomeGuard/web/*.sh
```

### Database Error
```bash
# Se der erro no banco:
rm ~/HomeGuard/db/homeguard.db
python3 init_database.py
```

## 📊 Monitoramento

### Ver logs em tempo real
```bash
tail -f mqtt_logger.log
tail -f ../logs/mqtt_service.log
```

### Verificar conexão MQTT
```bash
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t 'home/#' -v -C 5
```

### Ver crescimento do banco
```bash
watch -n 5 'python3 db_query.py --stats'
```

## 🎯 Resultado Esperado

Após alguns minutos rodando, você deve ver:

```
📊 HomeGuard Database Statistics
==================================================
📝 Total Records: 150
📅 Date Range: 2025-09-06 10:30:00 to 2025-09-06 10:45:00

🔥 Top 10 Topics:
   home/motion/MOTION_01/status        45 messages
   home/RDA5807/status                 20 messages
   home/sensor/DHT_01/status          15 messages

🏠 Device Activity:
   MOTION_01           45 messages
   RDA5807             20 messages
   DHT_01              15 messages
```

## 🌟 Pronto!

O sistema estará capturando **todas** as mensagens MQTT e armazenando no banco SQLite local, equivalente ao comando:

```bash
mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t 'home/#' -v
```

Mas com **persistência permanente** dos dados! 🎉
