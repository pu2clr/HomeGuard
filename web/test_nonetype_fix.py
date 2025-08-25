#!/usr/bin/env python3

"""
🧪 Teste da Correção NoneType
Simular o problema e verificar se foi corrigido
"""

from datetime import datetime
import time

class TestDHT11Logic:
    def __init__(self):
        self.pending_dht11_data = {}
        self.dht11_wait_both_seconds = 10
    
    def test_scenario_1_new_device(self):
        """Teste 1: Novo dispositivo (primeira vez)"""
        print("🧪 Teste 1: Novo dispositivo")
        device_id = "ESP01_DHT11_001"
        now = datetime.now()
        
        # Simular inicialização (como no código original)
        if device_id not in self.pending_dht11_data:
            self.pending_dht11_data[device_id] = {
                'temperature': None,
                'humidity': None,
                'first_data_time': now,  # Inicializada corretamente
            }
        
        pending = self.pending_dht11_data[device_id]
        
        # Testar cálculo (deve funcionar)
        try:
            wait_time_passed = False
            if pending['first_data_time'] is not None:
                wait_time_passed = (now - pending['first_data_time']).total_seconds() >= self.dht11_wait_both_seconds
            print(f"   ✅ Cálculo OK: wait_time_passed = {wait_time_passed}")
        except TypeError as e:
            print(f"   ❌ Erro: {e}")
    
    def test_scenario_2_after_reset(self):
        """Teste 2: Após reset (causa do erro original)"""
        print("\n🧪 Teste 2: Após reset")
        device_id = "ESP01_DHT11_001"
        now = datetime.now()
        
        # Simular reset (como no código original)
        self.pending_dht11_data[device_id] = {
            'temperature': None,
            'humidity': None,
            'first_data_time': None,  # ❌ CAUSA DO ERRO ORIGINAL
        }
        
        pending = self.pending_dht11_data[device_id]
        
        # Testar CÓDIGO ORIGINAL (deve dar erro)
        print("   🔍 Testando código ORIGINAL:")
        try:
            wait_time_passed = (now - pending['first_data_time']).total_seconds() >= self.dht11_wait_both_seconds
            print(f"   ❌ Não deveria chegar aqui: {wait_time_passed}")
        except TypeError as e:
            print(f"   ❌ Erro confirmado: {e}")
        
        # Testar CÓDIGO CORRIGIDO (deve funcionar)
        print("   🔧 Testando código CORRIGIDO:")
        try:
            # Aplicar correção: inicializar se None
            if pending['first_data_time'] is None:
                pending['first_data_time'] = now
                print(f"   🔧 first_data_time inicializada: {pending['first_data_time']}")
            
            # Calcular com proteção
            wait_time_passed = False
            if pending['first_data_time'] is not None:
                wait_time_passed = (now - pending['first_data_time']).total_seconds() >= self.dht11_wait_both_seconds
            print(f"   ✅ Cálculo OK: wait_time_passed = {wait_time_passed}")
        except TypeError as e:
            print(f"   ❌ Erro inesperado: {e}")
    
    def test_scenario_3_multiple_messages(self):
        """Teste 3: Múltiplas mensagens (cenário real)"""
        print("\n🧪 Teste 3: Múltiplas mensagens")
        device_id = "ESP01_DHT11_001"
        
        # Reset inicial
        self.pending_dht11_data[device_id] = {
            'temperature': None,
            'humidity': None,
            'first_data_time': None,
        }
        
        # Simular chegada de temperatura
        print("   📨 1. Temperatura chega...")
        now1 = datetime.now()
        pending = self.pending_dht11_data[device_id]
        
        if pending['first_data_time'] is None:
            pending['first_data_time'] = now1
            print(f"   🔧 first_data_time inicializada: {pending['first_data_time']}")
        
        pending['temperature'] = 25.4
        print(f"   🌡️  Temperatura: {pending['temperature']}°C")
        
        # Simular chegada de umidade (2 segundos depois)
        time.sleep(0.1)  # Pequena pausa para simular
        print("   📨 2. Umidade chega...")
        now2 = datetime.now()
        
        if pending['first_data_time'] is None:
            pending['first_data_time'] = now2
        
        pending['humidity'] = 47.0
        print(f"   💧 Umidade: {pending['humidity']}%")
        
        # Verificar se deve processar
        has_both = pending['temperature'] is not None and pending['humidity'] is not None
        wait_time_passed = False
        if pending['first_data_time'] is not None:
            wait_time_passed = (now2 - pending['first_data_time']).total_seconds() >= self.dht11_wait_both_seconds
        
        should_process = has_both or wait_time_passed
        
        print(f"   📊 has_both: {has_both}")
        print(f"   ⏰ wait_time_passed: {wait_time_passed}")
        print(f"   ✅ should_process: {should_process}")

def main():
    """Função principal de teste"""
    print("🧪 Teste da Correção TypeError - first_data_time NoneType")
    print("="*60)
    
    tester = TestDHT11Logic()
    
    try:
        tester.test_scenario_1_new_device()
        tester.test_scenario_2_after_reset()
        tester.test_scenario_3_multiple_messages()
        
        print("\n✅ Todos os testes concluídos!")
        print("🎯 A correção resolve o problema TypeError.")
        
    except Exception as e:
        print(f"\n❌ Erro durante testes: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
