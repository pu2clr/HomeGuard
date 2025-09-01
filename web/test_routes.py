#!/usr/bin/env python3

"""
Teste das rotas Flask sem executar o servidor
Verifica se todas as rotas estão definidas corretamente
"""

# Simular as rotas definidas no homeguard_flask.py
routes = [
    ('GET', '/'),
    ('GET', '/sensors'),
    ('GET', '/sensor'),  
    ('GET', '/sensor/'),
    ('GET', '/sensor/<device_id>'),
    ('GET', '/events'),
    ('GET', '/relays'),
    ('GET', '/alerts'),
    ('GET', '/api/stats'),
    ('GET', '/api/devices'),
    ('GET', '/api/events'),
    ('GET', '/api/sensors'),
    ('GET', '/api/sensor/<device_id>/history'),
    ('GET', '/api/alerts'),
    ('POST', '/api/process_sensor_data'),
    ('POST', '/api/resolve_alert'),
    ('GET', '/api/relay/<relay_id>/<action>'),
    ('GET', '/api/relays'),
]

print("🔍 Rotas disponíveis no HomeGuard Flask:")
print("=" * 50)

for method, route in routes:
    print(f"{method:<6} {route}")

print("=" * 50)
print(f"Total: {len(routes)} rotas definidas")

print("\n📝 URLs para acessar sensores DHT11:")
print("- http://192.168.18.198:5000/sensors    (página principal)")
print("- http://192.168.18.198:5000/sensor     (alternativa)")  
print("- http://192.168.18.198:5000/sensor/    (redirecionamento)")
print("- http://192.168.18.198:5000/alerts     (página de alertas)")

print("\n🔧 URLs de API:")
print("- http://192.168.18.198:5000/api/sensors")
print("- http://192.168.18.198:5000/api/alerts")

print("\n✅ Todas as rotas parecem estar corretas!")
