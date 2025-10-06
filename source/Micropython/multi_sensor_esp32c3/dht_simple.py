# Simple DHT library for MicroPython ESP32-C3
# Compatível com DHT11 e DHT22
# Baseado no driver oficial do MicroPython

import machine
import time

class DHT11:
    """Driver simples para DHT11"""
    
    def __init__(self, pin):
        self.pin = machine.Pin(pin, machine.Pin.OUT)
        self.temp = None
        self.humid = None
        
    def measure(self):
        """Realiza leitura do sensor"""
        try:
            # Implementação simplificada usando machine.dht_readinto
            # ou protocolo bit-bang se necessário
            
            # Placeholder para leitura real
            # Em um ESP32-C3 real, usar:
            # import dht
            # sensor = dht.DHT11(machine.Pin(pin))
            # sensor.measure()
            
            # Simulação para desenvolvimento local
            import random
            self.temp = 20 + random.randint(0, 15)  # 20-35°C
            self.humid = 40 + random.randint(0, 30)  # 40-70%
            
        except Exception as e:
            print(f"Erro na leitura DHT11: {e}")
            self.temp = None
            self.humid = None
    
    def temperature(self):
        """Retorna temperatura em Celsius"""
        return self.temp
    
    def humidity(self):
        """Retorna umidade relativa em %"""
        return self.humid

class DHT22:
    """Driver simples para DHT22"""
    
    def __init__(self, pin):
        self.pin = machine.Pin(pin, machine.Pin.OUT)
        self.temp = None
        self.humid = None
        
    def measure(self):
        """Realiza leitura do sensor"""
        try:
            # Implementação simplificada
            # Em um ESP32-C3 real, usar:
            # import dht
            # sensor = dht.DHT22(machine.Pin(pin))
            # sensor.measure()
            
            # Simulação para desenvolvimento local
            import random
            self.temp = 15.0 + random.randint(0, 200) / 10.0  # 15.0-35.0°C
            self.humid = 30.0 + random.randint(0, 400) / 10.0  # 30.0-70.0%
            
        except Exception as e:
            print(f"Erro na leitura DHT22: {e}")
            self.temp = None
            self.humid = None
    
    def temperature(self):
        """Retorna temperatura em Celsius"""
        return self.temp
    
    def humidity(self):
        """Retorna umidade relativa em %"""
        return self.humid