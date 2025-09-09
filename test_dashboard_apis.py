#!/usr/bin/env python3
"""
Teste das APIs específicas do Dashboard
"""

import sqlite3
import json
import os
from datetime import datetime

# Configuração
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, 'db', 'homeguard.db')

def test_api_simulation():
    """Simular as chamadas das APIs do dashboard"""
    
    def execute_query(query, params=None):
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        if params:
            cursor.execute(query, params)
        else:
            cursor.execute(query)
        
        results = cursor.fetchall()
        conn.close()
        return results

    print("🔍 Testando APIs específicas do Dashboard...")
    print("-" * 60)

    # 1. API Temperature Data
    print("1️⃣ Testando /api/temperature/data")
    try:
        query = """
            SELECT * FROM vw_temperature_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            ORDER BY created_at DESC 
            LIMIT 5
        """
        results = execute_query(query)
        
        data = []
        for row in results:
            data.append({
                'created_at': row['created_at'],
                'device_id': row['device_id'],
                'name': row['name'],
                'location': row['location'],
                'sensor_type': row['sensor_type'],
                'temperature': row['temperature'],
                'unit': row['unit'],
                'rssi': row['rssi'],
                'uptime': row['uptime']
            })
        
        print(f"   ✅ OK - {len(data)} registros")
        if data:
            print(f"   📊 Último: {data[0]['temperature']}°C em {data[0]['location']}")
    
    except Exception as e:
        print(f"   ❌ ERRO: {e}")

    # 2. API Humidity Data
    print("\n2️⃣ Testando /api/humidity/data")
    try:
        query = """
            SELECT * FROM vw_humidity_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            ORDER BY created_at DESC 
            LIMIT 5
        """
        results = execute_query(query)
        
        data = []
        for row in results:
            data.append({
                'created_at': row['created_at'],
                'device_id': row['device_id'],
                'name': row['name'],
                'location': row['location'],
                'sensor_type': row['sensor_type'],
                'humidity': row['humidity'],  # Campo corrigido
                'unit': row['unit'],
                'rssi': row['rssi'],
                'uptime': row['uptime']
            })
        
        print(f"   ✅ OK - {len(data)} registros")
        if data:
            print(f"   📊 Último: {data[0]['humidity']}% em {data[0]['location']}")
    
    except Exception as e:
        print(f"   ❌ ERRO: {e}")

    # 3. API Motion Data
    print("\n3️⃣ Testando /api/motion/data")
    try:
        query = """
            SELECT * FROM vw_motion_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            ORDER BY created_at DESC 
            LIMIT 5
        """
        results = execute_query(query)
        
        data = []
        for row in results:
            data.append({
                'created_at': row['created_at'],
                'device_id': row['device_id'],
                'name': row['name'],
                'location': row['location']
            })
        
        print(f"   ✅ OK - {len(data)} registros")
        if data:
            print(f"   📊 Último: {data[0]['created_at']} em {data[0]['location']}")
    
    except Exception as e:
        print(f"   ❌ ERRO: {e}")

    # 4. API Relay Data
    print("\n4️⃣ Testando /api/relay/data")
    try:
        query = """
            SELECT * FROM vw_relay_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            ORDER BY created_at DESC 
            LIMIT 5
        """
        results = execute_query(query)
        
        data = []
        for row in results:
            data.append({
                'created_at': row['created_at'],
                'topic': row['topic'],
                'message': row['message']
            })
        
        print(f"   ✅ OK - {len(data)} registros")
        if data:
            print(f"   📊 Último: {data[0]['message']} em {data[0]['created_at']}")
    
    except Exception as e:
        print(f"   ❌ ERRO: {e}")

    # 5. API Temperature Stats
    print("\n5️⃣ Testando /api/temperature/stats")
    try:
        query = """
            SELECT 
                device_id,
                location,
                sensor_type,
                COUNT(*) as total_readings,
                ROUND(AVG(CAST(temperature AS REAL)), 2) as avg_temp,
                ROUND(MIN(CAST(temperature AS REAL)), 2) as min_temp,
                ROUND(MAX(CAST(temperature AS REAL)), 2) as max_temp,
                ROUND(AVG(CAST(rssi AS INTEGER)), 0) as avg_rssi,
                MAX(created_at) as last_reading
            FROM vw_temperature_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            GROUP BY device_id
            ORDER BY last_reading DESC
        """
        results = execute_query(query)
        
        stats = []
        for row in results:
            stats.append({
                'device_id': row['device_id'],
                'location': row['location'],
                'sensor_type': row['sensor_type'],
                'total_readings': row['total_readings'],
                'avg_temp': row['avg_temp'],
                'min_temp': row['min_temp'],
                'max_temp': row['max_temp'],
                'avg_rssi': row['avg_rssi'],
                'last_reading': row['last_reading']
            })
        
        print(f"   ✅ OK - {len(stats)} dispositivos")
        if stats:
            print(f"   📊 Dispositivo: {stats[0]['device_id']} - Média: {stats[0]['avg_temp']}°C")
    
    except Exception as e:
        print(f"   ❌ ERRO: {e}")

    # 6. API Humidity Stats
    print("\n6️⃣ Testando /api/humidity/stats")
    try:
        query = """
            SELECT 
                device_id,
                location,
                sensor_type,
                COUNT(*) as total_readings,
                ROUND(AVG(CAST(humidity AS REAL)), 2) as avg_humidity,
                ROUND(MIN(CAST(humidity AS REAL)), 2) as min_humidity,
                ROUND(MAX(CAST(humidity AS REAL)), 2) as max_humidity,
                ROUND(AVG(CAST(rssi AS INTEGER)), 0) as avg_rssi,
                MAX(created_at) as last_reading
            FROM vw_humidity_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            GROUP BY device_id
            ORDER BY last_reading DESC
        """
        results = execute_query(query)
        
        stats = []
        for row in results:
            stats.append({
                'device_id': row['device_id'],
                'location': row['location'],
                'sensor_type': row['sensor_type'],
                'total_readings': row['total_readings'],
                'avg_humidity': row['avg_humidity'],
                'min_humidity': row['min_humidity'],
                'max_humidity': row['max_humidity'],
                'avg_rssi': row['avg_rssi'],
                'last_reading': row['last_reading']
            })
        
        print(f"   ✅ OK - {len(stats)} dispositivos")
        if stats:
            print(f"   📊 Dispositivo: {stats[0]['device_id']} - Média: {stats[0]['avg_humidity']}%")
    
    except Exception as e:
        print(f"   ❌ ERRO: {e}")

    print("\n" + "=" * 60)
    print("✅ Teste das APIs concluído!")
    print("\n🚀 Para testar no Raspberry Pi:")
    print("   1. Copie o dashboard.py atualizado")
    print("   2. Recrie a view vw_humidity_activity")
    print("   3. Execute: python3 dashboard.py")
    print("   4. Acesse: http://IP_DO_PI:5000")

if __name__ == '__main__':
    test_api_simulation()
