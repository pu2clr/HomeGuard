#!/usr/bin/env python3

"""
🔍 Diagnóstico de Sensores Duplicados
Verificar por que um sensor aparece repetido no painel
"""

import sqlite3
from datetime import datetime

def diagnose_duplicate_sensors():
    """Diagnosticar sensores duplicados"""
    print("🔍 Diagnóstico de Sensores Duplicados DHT11")
    print("="*50)
    
    # Conectar ao banco
    try:
        conn = sqlite3.connect('../db/homeguard.db')
        cursor = conn.cursor()
        
        print("✅ Conectado ao banco de dados")
        
        # 1. Verificar todos os device_ids únicos
        print("\n📊 1. Device IDs únicos na tabela:")
        cursor.execute("""
            SELECT DISTINCT device_id, device_name, location, 
                   COUNT(*) as total_registros,
                   MIN(timestamp_received) as primeiro_registro,
                   MAX(timestamp_received) as ultimo_registro
            FROM dht11_sensors 
            GROUP BY device_id
            ORDER BY device_id
        """)
        
        devices = cursor.fetchall()
        for device in devices:
            device_id, name, location, count, first, last = device
            print(f"   📱 {device_id}")
            print(f"      Nome: {name}")
            print(f"      Local: {location}")
            print(f"      Registros: {count}")
            print(f"      Período: {first} → {last}")
            print()
        
        # 2. Verificar registros recentes (últimas 2 horas)
        print("📈 2. Registros recentes (últimas 2 horas):")
        cursor.execute("""
            SELECT device_id, device_name, location, temperature, humidity, 
                   timestamp_received, 
                   COUNT(*) OVER (PARTITION BY device_id) as total_por_device
            FROM dht11_sensors 
            WHERE datetime(timestamp_received) >= datetime('now', '-2 hours')
            ORDER BY timestamp_received DESC 
            LIMIT 20
        """)
        
        recent = cursor.fetchall()
        for record in recent:
            device_id, name, location, temp, humid, timestamp, total = record
            print(f"   ⏰ {timestamp} | {device_id} ({total} total) | {temp}°C {humid}% | {name} @ {location}")
        
        # 3. Verificar possíveis inconsistências
        print("\n⚠️  3. Verificando inconsistências:")
        
        # 3a. Device_ids com nomes diferentes
        cursor.execute("""
            SELECT device_id, COUNT(DISTINCT device_name) as nomes_diferentes,
                   GROUP_CONCAT(DISTINCT device_name) as nomes
            FROM dht11_sensors 
            GROUP BY device_id
            HAVING COUNT(DISTINCT device_name) > 1
        """)
        
        inconsistent_names = cursor.fetchall()
        if inconsistent_names:
            print("   ❌ Device IDs com nomes inconsistentes:")
            for record in inconsistent_names:
                device_id, count, names = record
                print(f"      {device_id}: {count} nomes diferentes -> {names}")
        else:
            print("   ✅ Todos os device IDs têm nomes consistentes")
        
        # 3b. Device_ids com localizações diferentes
        cursor.execute("""
            SELECT device_id, COUNT(DISTINCT location) as locais_diferentes,
                   GROUP_CONCAT(DISTINCT location) as locais
            FROM dht11_sensors 
            GROUP BY device_id
            HAVING COUNT(DISTINCT location) > 1
        """)
        
        inconsistent_locations = cursor.fetchall()
        if inconsistent_locations:
            print("   ❌ Device IDs com localizações inconsistentes:")
            for record in inconsistent_locations:
                device_id, count, locations = record
                print(f"      {device_id}: {count} locais diferentes -> {locations}")
        else:
            print("   ✅ Todos os device IDs têm localizações consistentes")
        
        # 4. Simular o que o painel vê
        print("\n🖥️  4. Simulando dados do painel:")
        cursor.execute("""
            WITH latest_per_device AS (
                SELECT device_id,
                       device_name,
                       location,
                       temperature,
                       humidity,
                       rssi,
                       timestamp_received,
                       ROW_NUMBER() OVER (PARTITION BY device_id ORDER BY timestamp_received DESC) as rn
                FROM dht11_sensors
                WHERE datetime(timestamp_received) >= datetime('now', '-24 hours')
            )
            SELECT device_id, device_name, location, temperature, humidity, 
                   rssi, timestamp_received,
                   ROUND((julianday('now') - julianday(timestamp_received)) * 24 * 60) as minutes_ago
            FROM latest_per_device 
            WHERE rn = 1
            ORDER BY device_id
        """)
        
        panel_data = cursor.fetchall()
        print("   Cards que devem aparecer no painel:")
        for record in panel_data:
            device_id, name, location, temp, humid, rssi, timestamp, minutes_ago = record
            status = "online" if minutes_ago < 5 else "warning" if minutes_ago < 30 else "offline"
            print(f"   📋 {device_id} | {name} @ {location}")
            print(f"      🌡️  {temp}°C, 💧 {humid}%, 📶 {rssi}dBm")
            print(f"      ⏰ {timestamp} ({minutes_ago}min atrás) - {status}")
            print()
        
        # 5. Verificar se há registros com mesmo timestamp
        print("🔄 5. Verificando registros simultâneos (possível duplicação):")
        cursor.execute("""
            SELECT timestamp_received, COUNT(*) as quantidade,
                   GROUP_CONCAT(device_id) as devices
            FROM dht11_sensors
            WHERE datetime(timestamp_received) >= datetime('now', '-1 hour')
            GROUP BY timestamp_received
            HAVING COUNT(*) > 1
            ORDER BY timestamp_received DESC
            LIMIT 10
        """)
        
        simultaneous = cursor.fetchall()
        if simultaneous:
            print("   ⚠️  Registros simultâneos encontrados:")
            for record in simultaneous:
                timestamp, count, devices = record
                print(f"      {timestamp}: {count} registros -> {devices}")
        else:
            print("   ✅ Nenhum registro simultâneo encontrado")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ Erro durante diagnóstico: {e}")
        import traceback
        traceback.print_exc()

def suggest_fixes():
    """Sugerir correções baseadas nos problemas encontrados"""
    print("\n🔧 Possíveis Soluções para Duplicação:")
    print("="*40)
    
    print("1. 📝 **Device ID duplicado no Arduino:**")
    print("   - Verificar se ambos ESP01 têm device_id únicos")
    print("   - ESP01_DHT11_001 vs ESP01_DHT11_002")
    print()
    
    print("2. 🔄 **Cache do navegador:**")
    print("   - Limpar cache: Ctrl+Shift+Del")
    print("   - Atualizar página: Ctrl+F5")
    print()
    
    print("3. 🎯 **JavaScript duplicando cards:**")
    print("   - Verificar se auto-refresh está criando cards duplicados")
    print("   - Abrir Console (F12) para ver erros JavaScript")
    print()
    
    print("4. 🗄️  **Limpeza do banco (se necessário):**")
    print("   - Remover registros de teste antigos")
    print("   - Normalizar device_names inconsistentes")
    print()

if __name__ == "__main__":
    diagnose_duplicate_sensors()
    suggest_fixes()
