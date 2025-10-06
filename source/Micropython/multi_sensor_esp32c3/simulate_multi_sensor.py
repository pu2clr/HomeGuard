#!/usr/bin/env python3
"""
Simulador ESP32-C3 Multi-Sensor para desenvolvimento local
Simula hardware: DHT11/DHT22, PIR, Relé, LED, WiFi, MQTT

Como usar:
    python3 simulate_multi_sensor.py

Funcionalidades simuladas:
- ✅ Conexão WiFi 
- ✅ Cliente MQTT (publicação e subscrição)
- ✅ Sensor DHT11/DHT22 (temperatura/umidade)
- ✅ Sensor PIR/IR (movimento)
- ✅ Controle de relé
- ✅ LED de status
- ✅ GPIO do ESP32-C3
- ✅ Comandos MQTT interativos
"""

import sys
import os
import time
import json
import random
import threading
from typing import Optional, Callable, Dict, Any
from datetime import datetime

# Adicionar o diretório do simulador ao path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

print("🚀 INICIANDO SIMULAÇÃO ESP32-C3 MULTI-SENSOR")
print("📦 Instalando módulos MicroPython simulados...")

# ============= MÓDULOS MICROPYTHON SIMULADOS =============

class MockPin:
    """Simula machine.Pin do ESP32-C3"""
    
    IN = 'IN'
    OUT = 'OUT'
    PULL_UP = 'PULL_UP'
    
    _pins = {}  # Registro global de pinos
    
    def __init__(self, pin_num: int, mode: str = None, pull=None):
        self.pin_num = pin_num
        self.mode = mode
        self.pull = pull
        self._value = 0
        MockPin._pins[pin_num] = self
        print(f"📌 GPIO{pin_num} configurado como {mode}")
    
    def value(self, val=None):
        """Define ou lê o valor do pino"""
        if val is not None:
            self._value = val
            if self.pin_num == 5:  # Relé
                status = "LIGADO" if val else "DESLIGADO"
                print(f"🔌 Relé {status} (GPIO{self.pin_num})")
            elif self.pin_num == 8:  # LED
                status = "ACESO" if not val else "APAGADO"  # Lógica invertida
                print(f"💡 LED {status} (GPIO{self.pin_num})")
        return self._value
    
    def on(self):
        """Liga o pino"""
        self.value(1)
    
    def off(self):
        """Desliga o pino"""
        self.value(0)

class MockMachine:
    """Simula módulo machine"""
    
    Pin = MockPin
    
    @staticmethod
    def reset():
        """Simula reset do ESP32-C3"""
        print("🔄 ESP32-C3 reiniciando...")
        time.sleep(2)
        print("✅ ESP32-C3 reiniciado")

class MockDHT11:
    """Simula sensor DHT11"""
    
    def __init__(self, pin):
        self.pin = pin
        self._temp = None
        self._humid = None
        print(f"🌡️ DHT11 inicializado no GPIO{pin.pin_num}")
    
    def measure(self):
        """Simula leitura do DHT11"""
        # Simular valores realistas com pequenas variações
        base_temp = 22.0 + (time.time() % 100) / 50  # 22-24°C oscilando
        base_humid = 55.0 + random.randint(-10, 10)  # 45-65% com variação
        
        # Adicionar pequeno ruído
        self._temp = round(base_temp + random.uniform(-0.5, 0.5), 1)
        self._humid = round(base_humid + random.uniform(-2.0, 2.0), 1)
        
        # Simular falha ocasional (5% das vezes)
        if random.random() < 0.05:
            self._temp = None
            self._humid = None
            print("⚠️ DHT11: Falha na leitura")
        else:
            print(f"🌡️ DHT11: {self._temp}°C, {self._humid}%")
    
    def temperature(self):
        """Retorna temperatura"""
        return self._temp
    
    def humidity(self):
        """Retorna umidade"""
        return self._humid

class MockDHT22:
    """Simula sensor DHT22 (maior precisão)"""
    
    def __init__(self, pin):
        self.pin = pin
        self._temp = None
        self._humid = None
        print(f"🌡️ DHT22 inicializado no GPIO{pin.pin_num}")
    
    def measure(self):
        """Simula leitura do DHT22"""
        # DHT22 tem maior precisão
        base_temp = 23.5 + (time.time() % 200) / 100  # 23.5-25.5°C
        base_humid = 60.0 + random.randint(-15, 15)   # 45-75%
        
        self._temp = round(base_temp + random.uniform(-0.2, 0.2), 2)
        self._humid = round(base_humid + random.uniform(-1.0, 1.0), 2)
        
        # Falha menos comum (2%)
        if random.random() < 0.02:
            self._temp = None
            self._humid = None
            print("⚠️ DHT22: Falha na leitura")
        else:
            print(f"🌡️ DHT22: {self._temp}°C, {self._humid}%")
    
    def temperature(self):
        return self._temp
    
    def humidity(self):
        return self._humid

class MockDHT:
    """Simula módulo dht"""
    DHT11 = MockDHT11
    DHT22 = MockDHT22

class MockWLAN:
    """Simula network.WLAN do ESP32-C3"""
    
    STA_IF = 'STA_IF'
    
    def __init__(self, interface):
        self.interface = interface
        self._active = False
        self._connected = False
        self._ip = "192.168.1.155"
        
    def active(self, state=None):
        """Ativa/desativa interface WiFi"""
        if state is not None:
            self._active = state
            print(f"📡 WiFi {'ativado' if state else 'desativado'}")
        return self._active
    
    def connect(self, ssid, password):
        """Simula conexão WiFi"""
        print(f"📡 Conectando ao WiFi: {ssid}")
        time.sleep(2)  # Simular tempo de conexão
        self._connected = True
        print(f"✅ WiFi conectado! IP: {self._ip}")
    
    def isconnected(self):
        """Verifica se WiFi está conectado"""
        return self._connected
    
    def ifconfig(self):
        """Retorna configuração de rede"""
        return [self._ip, '255.255.255.0', '192.168.1.1', '8.8.8.8']

class MockNetwork:
    """Simula módulo network"""
    
    STA_IF = MockWLAN.STA_IF
    WLAN = MockWLAN

class MockMQTTClient:
    """Simula umqtt.simple.MQTTClient"""
    
    def __init__(self, client_id: str, server: str, port: int = 1883, 
                 user: Optional[str] = None, password: Optional[str] = None):
        self.client_id = client_id
        self.server = server
        self.port = port
        self.user = user
        self.password = password
        self._callback = None
        self._connected = False
        self._subscriptions = []
        print(f"📡 MQTT Client criado: {client_id}@{server}:{port}")
        
        # Simular comandos MQTT em thread separada
        self._command_thread = threading.Thread(target=self._command_simulator, daemon=True)
        self._command_thread.start()
    
    def set_callback(self, callback: Callable):
        """Define callback para mensagens MQTT"""
        self._callback = callback
        print("📋 MQTT callback configurado")
    
    def connect(self):
        """Simula conexão MQTT"""
        print(f"🔗 Conectando MQTT: {self.server}:{self.port}")
        time.sleep(1)  # Simular tempo de conexão
        self._connected = True
        print("✅ MQTT conectado")
    
    def subscribe(self, topic: bytes):
        """Simula inscrição em tópico"""
        topic_str = topic.decode() if isinstance(topic, bytes) else topic
        self._subscriptions.append(topic_str)
        print(f"📥 Inscrito no tópico: {topic_str}")
    
    def publish(self, topic: bytes, message: str, retain: bool = False):
        """Simula publicação MQTT"""
        topic_str = topic.decode() if isinstance(topic, bytes) else topic
        retain_str = " [RETAIN]" if retain else ""
        print(f"📤 MQTT: {topic_str} = {message}{retain_str}")
    
    def check_msg(self):
        """Simula verificação de mensagens"""
        # Implementação vazia - mensagens são injetadas por _command_simulator
        pass
    
    def _command_simulator(self):
        """Simula recebimento de comandos MQTT em background"""
        time.sleep(5)  # Aguardar inicialização
        
        commands = [
            ('home/multisensor/MULTI_SENSOR_C3A/command', 'STATUS'),
            ('home/multisensor/MULTI_SENSOR_C3A/relay/command', 'ON'),
            ('home/multisensor/MULTI_SENSOR_C3A/relay/command', 'OFF'),
            ('home/multisensor/MULTI_SENSOR_C3A/command', 'READ'),
            ('home/multisensor/MULTI_SENSOR_C3A/command', 'INFO'),
        ]
        
        while self._connected:
            time.sleep(random.randint(10, 30))  # Comando a cada 10-30 segundos
            
            if self._callback and self._subscriptions:
                topic, cmd = random.choice(commands)
                if any(sub in topic for sub in self._subscriptions):
                    print(f"📨 Simulando comando MQTT: {topic} -> {cmd}")
                    self._callback(topic.encode(), cmd.encode())

class MockUMQTT:
    """Simula módulo umqtt.simple"""
    
    class simple:
        MQTTClient = MockMQTTClient

# Simulador de PIR com movimento aleatório
class PIRSimulator:
    """Simula sensor PIR com movimento aleatório"""
    
    def __init__(self):
        self.motion_state = False
        self.last_change = time.time()
        self.motion_duration = 0
        
    def simulate_motion(self):
        """Simula padrões de movimento realistas"""
        current_time = time.time()
        
        if not self.motion_state:
            # Sem movimento - chance de detectar movimento
            if random.random() < 0.02:  # 2% chance por verificação
                self.motion_state = True
                self.last_change = current_time
                self.motion_duration = random.randint(5, 45)  # 5-45 segundos
                print("🚶 PIR: MOVIMENTO DETECTADO!")
        else:
            # Com movimento - verificar se deve parar
            if current_time - self.last_change > self.motion_duration:
                self.motion_state = False
                self.last_change = current_time
                print("🛑 PIR: Movimento finalizado")
        
        return self.motion_state

# Instância global do simulador PIR
pir_simulator = PIRSimulator()

# ============= INSTALAÇÃO DOS MÓDULOS =============

# Instalar módulos simulados
sys.modules['machine'] = MockMachine()
sys.modules['network'] = MockNetwork()
sys.modules['dht'] = MockDHT()
sys.modules['umqtt'] = MockUMQTT()
sys.modules['umqtt.simple'] = MockUMQTT.simple()

# Função para simular time.ticks_ms() do MicroPython
def ticks_ms():
    """Simula time.ticks_ms() do MicroPython"""
    return int(time.time() * 1000)

def ticks_diff(new, old):
    """Simula time.ticks_diff() do MicroPython"""
    return new - old

def sleep_ms(ms):
    """Simula time.sleep_ms() do MicroPython"""
    time.sleep(ms / 1000.0)

# Adicionar funções ao módulo time
time.ticks_ms = ticks_ms
time.ticks_diff = ticks_diff
time.sleep_ms = sleep_ms

# Mock para o sensor PIR (simular leituras)
original_pin_value = MockPin.value

def enhanced_pin_value(self, val=None):
    """Versão aprimorada que simula PIR no GPIO1"""
    if val is None and self.pin_num == 1:  # PIR no GPIO1
        return pir_simulator.simulate_motion()
    return original_pin_value(self, val)

MockPin.value = enhanced_pin_value

print("✅ Módulos MicroPython instalados com sucesso!")
print("🎯 Configuração:")
print("   - WiFi: Homeguard")
print("   - MQTT: 192.168.1.102:1883")
print("   - DHT: GPIO0")
print("   - PIR: GPIO1") 
print("   - Relé: GPIO5")
print("   - LED: GPIO8")
print()

# ============= EXECUTAR SCRIPT PRINCIPAL =============

if __name__ == '__main__':
    try:
        print("📁 Carregando main.py...")
        
        # Importar e executar o script principal
        with open('main.py', 'r', encoding='utf-8') as f:
            script_content = f.read()
        
        # Executar o script
        exec(script_content)
        
    except FileNotFoundError:
        print("❌ Arquivo main.py não encontrado!")
        print("   Certifique-se de que main.py está no mesmo diretório.")
    except KeyboardInterrupt:
        print("\n🛑 Simulação interrompida pelo usuário")
    except Exception as e:
        print(f"❌ Erro na simulação: {e}")
        import traceback
        traceback.print_exc()