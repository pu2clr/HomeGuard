"""
Mock Hardware - Simulador dos módulos ESP32 para teste local
=============================================================

Este arquivo simula os módulos machine, network e umqtt para 
permitir execução local do código MicroPython do ESP32.

Uso:
    python3 simulate_esp32.py
    ou
    micropython simulate_esp32.py
"""

import time
import random
import json
import sys
from typing import Optional, Callable, Any

# =============================================================================
# MOCK DO MÓDULO MACHINE
# =============================================================================

class MockPin:
    """Simula machine.Pin do ESP32"""
    
    OUT = 1
    IN = 0
    
    def __init__(self, pin: int, mode: Optional[int] = None):
        self.pin = pin
        self.mode = mode
        self._value = 0
        print(f"🔌 GPIO{pin} configurado como {'OUTPUT' if mode == self.OUT else 'INPUT'}")
    
    def value(self, val: Optional[int] = None) -> int:
        if val is not None:
            self._value = val
            print(f"📡 GPIO{self.pin} = {val} ({'HIGH' if val else 'LOW'})")
        return self._value

class MockADC:
    """Simula machine.ADC do ESP32"""
    
    ATTN_11DB = 3
    
    def __init__(self, pin):
        self.pin = pin
        self._voltage_base = 2700  # Simulação próxima ao seu threshold
        print(f"📊 ADC configurado no GPIO{pin.pin}")
    
    def read(self) -> int:
        """Simula leitura do sensor ZMPT101B com variação realística"""
        # Simular variação como sensor real
        variation = random.randint(-200, 200)
        noise = random.randint(-50, 50)
        reading = self._voltage_base + variation + noise
        
        # Simular mudança de estado da rede ocasionalmente
        if random.random() < 0.05:  # 5% chance de mudança
            self._voltage_base = 2400 if self._voltage_base > 2600 else 2800
            
        return max(0, min(4095, reading))  # Limitar range ADC
    
    def atten(self, attenuation):
        """Simula configuração de atenuação"""
        print(f"⚙️  ADC atenuação configurada: {attenuation}")

class MockMachine:
    """Simula módulo machine completo"""
    
    Pin = MockPin
    ADC = MockADC
    ATTN_11DB = 3
    
    @staticmethod
    def idle():
        """Simula machine.idle() - yield para watchdog"""
        time.sleep(0.001)  # Pequeno delay para simular yield
    
    @staticmethod
    def reset():
        """Simula reset do microcontrolador"""
        print("🔄 RESET simulado - reiniciando sistema...")
        time.sleep(1)
        # Em vez de exit(), reinicia a simulação
        import os
        os.execv(sys.executable, ['python'] + sys.argv)
    
    @staticmethod
    def freq(freq: Optional[int] = None) -> int:
        """Simula frequência da CPU"""
        if freq is not None:
            print(f"⚡ CPU freq configurada: {freq} Hz")
        return 240000000  # 240MHz padrão ESP32

# =============================================================================
# MOCK DO MÓDULO NETWORK
# =============================================================================

class MockWLAN:
    """Simula network.WLAN do ESP32"""
    
    STA_IF = 0
    AP_IF = 1
    
    def __init__(self, interface):
        self.interface = interface
        self._active = False
        self._connected = False
        self._config = {}
        print(f"📶 WLAN interface {interface} criada")
    
    def active(self, state: Optional[bool] = None) -> bool:
        if state is not None:
            self._active = state
            print(f"📶 WLAN {'ativada' if state else 'desativada'}")
        return self._active
    
    def connect(self, ssid: str, password: str):
        """Simula conexão WiFi"""
        print(f"🔗 Conectando ao WiFi: {ssid}")
        time.sleep(2)  # Simular tempo de conexão
        self._connected = True
        print(f"✅ WiFi conectado: {ssid}")
    
    def isconnected(self) -> bool:
        return self._connected
    
    def ifconfig(self) -> tuple:
        """Simula configuração de rede"""
        if self._connected:
            return ('192.168.1.150', '255.255.255.0', '192.168.1.1', '192.168.1.1')
        return ('0.0.0.0', '0.0.0.0', '0.0.0.0', '0.0.0.0')

class MockNetwork:
    """Simula módulo network completo"""
    
    WLAN = MockWLAN
    STA_IF = 0
    AP_IF = 1

# =============================================================================
# MOCK DO MÓDULO UMQTT
# =============================================================================

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
    
    def publish(self, topic: bytes, message: str):
        """Simula publicação MQTT"""
        topic_str = topic.decode() if isinstance(topic, bytes) else topic
        print(f"📤 MQTT Publish: {topic_str}")
        print(f"    Mensagem: {message}")
        
        # Simular resposta de comando ocasionalmente
        if "command" in topic_str and random.random() < 0.1:
            self._simulate_command_response()
    
    def check_msg(self):
        """Simula verificação de mensagens"""
        # Simular recebimento de comando ocasionalmente
        if self._callback and random.random() < 0.02:  # 2% chance
            commands = [b'STATUS', b'AUTO', b'ON', b'OFF']
            cmd = random.choice(commands)
            topic = self._subscriptions[0] if self._subscriptions else "test/command"
            print(f"📨 MQTT comando recebido simulado: {cmd.decode()}")
            self._callback(topic.encode(), cmd)
    
    def _simulate_command_response(self):
        """Simula resposta a comandos MQTT"""
        time.sleep(0.1)

class MockUMQTT:
    """Simula módulo umqtt.simple"""
    
    class simple:
        MQTTClient = MockMQTTClient

# =============================================================================
# MOCK DO MÓDULO GC
# =============================================================================

class MockGC:
    """Simula módulo gc (garbage collector)"""
    
    @staticmethod
    def collect():
        """Simula garbage collection"""
        print("🗑️  Garbage collection executado")
    
    @staticmethod
    def mem_free() -> int:
        """Simula memória livre"""
        return random.randint(50000, 80000)  # Simular variação de memória

# =============================================================================
# MOCK DO MÓDULO TIME (ESTENDIDO)
# =============================================================================

class MockTime:
    """Estende módulo time com funções MicroPython"""
    
    @staticmethod
    def sleep_ms(ms: int):
        """Simula time.sleep_ms do MicroPython"""
        time.sleep(ms / 1000.0)
    
    @staticmethod
    def ticks_ms() -> int:
        """Simula time.ticks_ms do MicroPython"""
        return int(time.time() * 1000)
    
    @staticmethod
    def ticks_diff(end: int, start: int) -> int:
        """Simula time.ticks_diff do MicroPython"""
        return end - start
    
    # Proxies para funções padrão do time
    sleep = time.sleep
    time = time.time

# =============================================================================
# INSTALAÇÃO DOS MOCKS
# =============================================================================

def install_mocks():
    """Instala todos os módulos mock no sys.modules"""
    
    # Instalar mocks
    sys.modules['machine'] = MockMachine()
    sys.modules['network'] = MockNetwork()
    sys.modules['umqtt'] = MockUMQTT()
    sys.modules['umqtt.simple'] = MockUMQTT.simple()
    sys.modules['gc'] = MockGC()
    
    # Estender módulo time
    import time as original_time
    mock_time = MockTime()
    # Adicionar funções MicroPython ao módulo time existente
    original_time.sleep_ms = mock_time.sleep_ms
    original_time.ticks_ms = mock_time.ticks_ms
    original_time.ticks_diff = mock_time.ticks_diff
    
    print("✅ Módulos ESP32 simulados instalados:")
    print("   - machine (Pin, ADC, idle, reset)")
    print("   - network (WLAN, WiFi)")
    print("   - umqtt.simple (MQTTClient)")
    print("   - gc (garbage collector)")
    print("   - time (sleep_ms, ticks_ms)")
    print("")

# =============================================================================
# SIMULAÇÃO PRINCIPAL
# =============================================================================

def run_simulation():
    """Executa simulação do grid monitor"""
    
    print("🚀 INICIANDO SIMULAÇÃO ESP32-C3 GRID MONITOR")
    print("=" * 50)
    print("")
    
    # Instalar módulos mock
    install_mocks()
    
    # Importar e executar o código principal
    try:
        print("📂 Carregando main.py...")
        
        # Executar o código principal
        with open('main.py', 'r') as f:
            code = f.read()
        
        print("▶️  Executando código principal...")
        print("-" * 50)
        
        exec(code, {'__name__': '__main__'})
        
    except FileNotFoundError:
        print("❌ Arquivo main.py não encontrado!")
        print("   Certifique-se de estar na pasta correta:")
        print("   cd source/Micropython/grid_monitor_esp32c3")
        
    except KeyboardInterrupt:
        print("\n⏹️  Simulação interrompida pelo usuário")
        
    except Exception as e:
        print(f"❌ Erro na simulação: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    run_simulation()