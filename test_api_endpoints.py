#!/usr/bin/env python3
"""
Teste específico das APIs de dados do Dashboard
Para simular exatamente o que o JavaScript está fazendo
"""

import requests
import json
import time

def test_api_endpoints():
    """Testar endpoints como o navegador faria"""
    
    # URL base - ajustar conforme necessário
    BASE_URL = "http://localhost:5000"
    
    print("🧪 Teste das APIs como o navegador faz...")
    print("=" * 60)
    
    # Endpoints para testar
    endpoints = [
        "/api/temperature/data?hours=24&limit=50",
        "/api/humidity/data?hours=24&limit=50", 
        "/api/motion/data?hours=24&limit=50",
        "/api/relay/data?hours=24&limit=50",
        "/api/temperature/stats?hours=24",
        "/api/humidity/stats?hours=24"
    ]
    
    for endpoint in endpoints:
        url = BASE_URL + endpoint
        print(f"\n🔍 Testando: {endpoint}")
        
        try:
            response = requests.get(url, timeout=10)
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    print(f"   ✅ JSON válido - {len(data)} registros")
                    
                    # Mostrar primeiro registro para debug
                    if data and len(data) > 0:
                        first_item = data[0]
                        print(f"   📊 Primeiro registro: {list(first_item.keys())}")
                        
                        # Verificar campos específicos
                        if 'temperature' in endpoint:
                            if 'temperature' in first_item:
                                print(f"      Temperature: {first_item['temperature']}")
                            else:
                                print(f"      ❌ Campo 'temperature' não encontrado!")
                                
                        elif 'humidity' in endpoint:
                            if 'humidity' in first_item:
                                print(f"      Humidity: {first_item['humidity']}")
                            else:
                                print(f"      ❌ Campo 'humidity' não encontrado!")
                    
                except json.JSONDecodeError as e:
                    print(f"   ❌ Erro JSON: {e}")
                    print(f"   Response: {response.text[:200]}...")
            else:
                print(f"   ❌ Erro HTTP: {response.text}")
                
        except requests.exceptions.ConnectionError:
            print(f"   ❌ Conexão falhou - servidor não está rodando?")
        except requests.exceptions.Timeout:
            print(f"   ❌ Timeout")
        except Exception as e:
            print(f"   ❌ Erro: {e}")
    
    print("\n" + "=" * 60)
    print("🚀 Para testar:")
    print("   1. Inicie o dashboard: cd web && python3 dashboard.py")
    print("   2. Execute este script em outra janela")
    print("   3. Compare com o que o navegador está recebendo")

if __name__ == '__main__':
    test_api_endpoints()
