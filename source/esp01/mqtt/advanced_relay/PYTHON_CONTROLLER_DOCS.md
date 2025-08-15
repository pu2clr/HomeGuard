# Advanced Relay Controller - Python Documentation

## 📖 Visão Geral

O `advanced_relay_controller.py` é um script Python completo para controlar e monitorar o ESP-01S advanced relay. Oferece uma interface CLI rica, monitoramento em tempo real e controle programático completo.

## 🚀 Instalação Rápida

```bash
# Instalar dependências
pip install -r requirements.txt

# Executar modo interativo
python advanced_relay_controller.py
```

## 📋 Funcionalidades Principais

### 🎛️ Controle de Relé
- **ON/OFF/TOGGLE**: Controle básico do relé
- **Status**: Solicitação de status detalhado
- **Restart**: Reinicialização remota do dispositivo

### ⚙️ Configuração Remota
- **Location**: Define a localização do dispositivo
- **Heartbeat**: Controla intervalo e habilitação do heartbeat
- **LED**: Controla LED de status opcional

### 📊 Monitoramento
- **Real-time**: Eventos em tempo real
- **History**: Histórico dos últimos eventos
- **Device Info**: Informações detalhadas do dispositivo
- **Heartbeat**: Monitoramento de heartbeat periódico

## 🎯 Modos de Uso

### 1. Modo Interativo (CLI)
```bash
python advanced_relay_controller.py
```

**Comandos disponíveis:**
```
relay> on              # Liga o relé
relay> off             # Desliga o relé
relay> toggle          # Alterna estado do relé
relay> status          # Solicita status do dispositivo
relay> info            # Mostra informações detalhadas
relay> history 5       # Mostra últimos 5 eventos
relay> location Kitchen # Define localização como "Kitchen"
relay> heartbeat on    # Habilita heartbeat
relay> heartbeat 30    # Define heartbeat para 30 segundos
relay> led on          # Habilita LED de status
relay> restart         # Reinicia o dispositivo
relay> monitor off     # Desabilita monitoramento de heartbeat
relay> help            # Mostra ajuda
relay> quit            # Sair
```

### 2. Comando Único
```bash
# Controle básico
python advanced_relay_controller.py --command on
python advanced_relay_controller.py --command off
python advanced_relay_controller.py --command toggle
python advanced_relay_controller.py --command status

# Configuração
python advanced_relay_controller.py --location "Living Room"
```

### 3. Modo Monitor
```bash
# Apenas monitoramento (sem controle)
python advanced_relay_controller.py --monitor-only
```

### 4. Configuração Personalizada
```bash
# Broker personalizado
python advanced_relay_controller.py --broker 192.168.1.100 --username myuser --password mypass

# Dispositivo personalizado
python advanced_relay_controller.py --device relay2
```

## 🔧 Parâmetros de Linha de Comando

| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| `--broker` | 192.168.18.236 | IP do broker MQTT |
| `--port` | 1883 | Porta do broker MQTT |
| `--username` | homeguard | Usuário MQTT |
| `--password` | pu2clr123456 | Senha MQTT |
| `--device` | relay1 | Prefixo do dispositivo para tópicos |
| `--monitor-only` | - | Modo apenas monitoramento |
| `--command` | - | Comando único para executar |
| `--location` | - | Define localização do dispositivo |

## 📊 Exemplo de Saída

### Status do Dispositivo
```
📊 [2025-08-10 14:30:15] DEVICE STATUS
   🆔 Device ID: relay_a1b2c3
   📍 Location: Kitchen
   🌐 IP Address: 192.168.18.192
   📱 MAC Address: AA:BB:CC:DD:EE:FF
   🔌 Relay State: ON
   🕐 Last Change: 5s ago
   ⏱️  Uptime: 3600s
   💓 Heartbeat: true (60s)
   📶 Signal: -45dBm
```

### Eventos do Relé
```
🟢 [2025-08-10 14:30:20] RELAY RELAY_ON at Kitchen
   🔌 State: ON (REMOTE_COMMAND)
   📶 Signal: -45dBm
```

### Heartbeat
```
💓 [2025-08-10 14:31:15] HEARTBEAT - relay_a1b2c3 at Kitchen
   ✅ Status: ONLINE, Relay: ON, Uptime: 3660s, Signal: -45dBm
```

## 🐍 Uso Programático

### Exemplo Básico
```python
from advanced_relay_controller import AdvancedRelayController

# Criar controlador
controller = AdvancedRelayController()

# Conectar
if controller.connect():
    # Controlar relé
    controller.relay_on()
    time.sleep(2)
    controller.relay_off()
    
    # Configurar dispositivo
    controller.set_location("Kitchen")
    controller.set_heartbeat_interval(30)
    
    # Solicitar status
    controller.request_status()
    
    # Desconectar
    controller.disconnect()
```

### Monitoramento com Callback
```python
def on_relay_event(event_data):
    print(f"Relay changed to {event_data['state']}")

controller = AdvancedRelayController()
# Implementar callback personalizado modificando _handle_relay_event
```

## 🎮 Exemplos Interativos

Execute `python examples.py` para acessar exemplos práticos:

1. **Basic Control**: Demonstra controle básico do relé
2. **Configuration**: Mostra configuração de parâmetros
3. **Monitoring**: Exemplo de monitoramento em tempo real
4. **Event History**: Demonstra rastreamento de eventos

## 🔍 Troubleshooting

### Erro de Conexão MQTT
```bash
❌ Failed to connect to MQTT broker: 5
```
**Solução**: Verifique IP do broker, usuário e senha

### Módulo paho-mqtt não encontrado
```bash
ModuleNotFoundError: No module named 'paho'
```
**Solução**: `pip install paho-mqtt`

### Dispositivo não responde
```bash
❌ No device information available
```
**Solução**: 
1. Verifique se o ESP-01S está ligado
2. Confirme se o firmware advanced_relay.ino está carregado
3. Verifique configuração de rede WiFi

### Permissões de execução
```bash
-bash: ./advanced_relay_controller.py: Permission denied
```
**Solução**: `chmod +x advanced_relay_controller.py`

## 🔧 Personalização

### Modificar Tópicos MQTT
```python
# No construtor da classe
self.topics = {
    'cmd': f"home/{device_prefix}/cmnd",
    'status': f"home/{device_prefix}/status",
    # ... personalizar conforme necessário
}
```

### Adicionar Comandos Personalizados
```python
# No método callback()
elif command == 'meu_comando':
    self.send_command("MEU_COMANDO_PERSONALIZADO")
```

### Configurar Logging
```python
import logging
logging.basicConfig(level=logging.INFO)
```

## 📈 Performance

- **Latência típica**: < 100ms para comandos locais
- **Throughput**: Suporta múltiplos comandos por segundo
- **Memória**: ~10MB uso típico
- **CPU**: Muito baixo uso (threading eficiente)

## 🔒 Segurança

- Autenticação MQTT com usuário/senha
- Validação de comandos
- Tratamento seguro de exceções
- Sem armazenamento de credenciais em logs
