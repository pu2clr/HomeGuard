#!/usr/bin/env python3
"""
HomeGuard SQLite Database Utility
Ferramenta para consultar e gerenciar o banco de dados de sensores de movimento
"""
import os
import sqlite3
import argparse
from datetime import datetime, timedelta, timezone

DB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'db')
DB_PATH = os.path.join(DB_DIR, 'homeguard.db')
TABLE_NAME = 'motion_sensors'

BR_TZ = timezone(timedelta(hours=-3))

def check_db_exists():
    """Verifica se o banco de dados existe"""
    if not os.path.exists(DB_PATH):
        print(f"❌ Banco de dados não encontrado: {DB_PATH}")
        print("Execute primeiro: python motion_monitor_sqlite.py")
        return False
    return True

def show_table_schema():
    """Mostra a estrutura da tabela"""
    if not check_db_exists():
        return
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(f"PRAGMA table_info({TABLE_NAME})")
        columns = cursor.fetchall()
        
        print("📋 ESTRUTURA DA TABELA motion_sensors")
        print("=" * 50)
        for col in columns:
            col_id, name, data_type, not_null, default, pk = col
            nullable = "NOT NULL" if not_null else "NULL"
            primary = " (PRIMARY KEY)" if pk else ""
            print(f"{name:<20} {data_type:<15} {nullable}{primary}")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ Erro ao consultar estrutura: {e}")

def show_statistics():
    """Mostra estatísticas detalhadas do banco"""
    if not check_db_exists():
        return
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Total de registros
        cursor.execute(f"SELECT COUNT(*) FROM {TABLE_NAME}")
        total = cursor.fetchone()[0]
        
        # Registros por sensor
        cursor.execute(f"""
            SELECT sensor, COUNT(*) as total,
                   SUM(CASE WHEN event = 'MOTION_DETECTED' THEN 1 ELSE 0 END) as detections,
                   SUM(CASE WHEN event = 'MOTION_CLEARED' THEN 1 ELSE 0 END) as clears
            FROM {TABLE_NAME} 
            GROUP BY sensor 
            ORDER BY total DESC
        """)
        sensor_stats = cursor.fetchall()
        
        # Atividade por dia (últimos 7 dias)
        cursor.execute(f"""
            SELECT DATE(timestamp_received) as day, COUNT(*) as events,
                   SUM(CASE WHEN event = 'MOTION_DETECTED' THEN 1 ELSE 0 END) as motions
            FROM {TABLE_NAME} 
            WHERE timestamp_received >= date('now', '-7 days')
            GROUP BY DATE(timestamp_received)
            ORDER BY day DESC
        """)
        daily_stats = cursor.fetchall()
        
        # Dispositivos únicos
        cursor.execute(f"""
            SELECT device_id, location, COUNT(*) as events,
                   MIN(timestamp_received) as first_seen,
                   MAX(timestamp_received) as last_seen
            FROM {TABLE_NAME} 
            WHERE device_id IS NOT NULL
            GROUP BY device_id
            ORDER BY last_seen DESC
        """)
        device_stats = cursor.fetchall()
        
        conn.close()
        
        # Exibir resultados
        print("📊 ESTATÍSTICAS DETALHADAS")
        print("=" * 60)
        print(f"Total de registros: {total:,}")
        
        print(f"\n📍 Estatísticas por sensor:")
        print(f"{'Sensor':<15} {'Total':<8} {'Detecções':<10} {'Liberações':<10}")
        print("-" * 45)
        for sensor, total, detections, clears in sensor_stats:
            print(f"{sensor:<15} {total:<8} {detections:<10} {clears:<10}")
        
        print(f"\n📅 Atividade nos últimos 7 dias:")
        print(f"{'Data':<12} {'Eventos':<8} {'Movimentos':<12}")
        print("-" * 32)
        for day, events, motions in daily_stats:
            print(f"{day:<12} {events:<8} {motions:<12}")
        
        print(f"\n🔧 Dispositivos ativos:")
        print(f"{'Device ID':<20} {'Local':<15} {'Eventos':<8} {'Primeiro':<12} {'Último':<12}")
        print("-" * 70)
        for device_id, location, events, first, last in device_stats:
            device_short = device_id[:18] + ".." if len(device_id) > 20 else device_id
            location_short = location[:13] + ".." if len(location) > 15 else location
            first_short = first[:10] if first else "N/A"
            last_short = last[:10] if last else "N/A"
            print(f"{device_short:<20} {location_short:<15} {events:<8} {first_short:<12} {last_short:<12}")
        
    except Exception as e:
        print(f"❌ Erro ao consultar estatísticas: {e}")

def show_recent_events(limit=20):
    """Mostra os eventos mais recentes"""
    if not check_db_exists():
        return
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(f"""
            SELECT timestamp_received, sensor, event, device_id, location, rssi
            FROM {TABLE_NAME} 
            ORDER BY id DESC 
            LIMIT ?
        """, (limit,))
        
        events = cursor.fetchall()
        conn.close()
        
        print(f"📝 ÚLTIMOS {limit} EVENTOS")
        print("=" * 80)
        print(f"{'Timestamp':<19} {'Sensor':<12} {'Evento':<15} {'Local':<15} {'RSSI':<6}")
        print("-" * 80)
        
        for timestamp, sensor, event, device_id, location, rssi in events:
            rssi_str = f"{rssi}dBm" if rssi else "N/A"
            location_str = location[:13] + ".." if location and len(location) > 15 else (location or "N/A")
            print(f"{timestamp:<19} {sensor:<12} {event:<15} {location_str:<15} {rssi_str:<6}")
        
    except Exception as e:
        print(f"❌ Erro ao consultar eventos recentes: {e}")

def query_by_sensor(sensor_name, limit=50):
    """Consulta eventos de um sensor específico"""
    if not check_db_exists():
        return
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(f"""
            SELECT timestamp_received, event, device_id, location, rssi, duration
            FROM {TABLE_NAME} 
            WHERE sensor = ?
            ORDER BY id DESC 
            LIMIT ?
        """, (sensor_name, limit))
        
        events = cursor.fetchall()
        conn.close()
        
        print(f"📍 EVENTOS DO SENSOR: {sensor_name.upper()}")
        print("=" * 70)
        print(f"{'Timestamp':<19} {'Evento':<15} {'Local':<15} {'RSSI':<6} {'Duração':<8}")
        print("-" * 70)
        
        for timestamp, event, device_id, location, rssi, duration in events:
            rssi_str = f"{rssi}dBm" if rssi else "N/A"
            duration_str = f"{duration}s" if duration else "N/A"
            location_str = location[:13] + ".." if location and len(location) > 15 else (location or "N/A")
            print(f"{timestamp:<19} {event:<15} {location_str:<15} {rssi_str:<6} {duration_str:<8}")
        
        if not events:
            print(f"Nenhum evento encontrado para o sensor '{sensor_name}'")
        
    except Exception as e:
        print(f"❌ Erro ao consultar sensor: {e}")

def cleanup_old_records(days=30):
    """Remove registros antigos do banco"""
    if not check_db_exists():
        return
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Contar registros que serão removidos
        cursor.execute(f"""
            SELECT COUNT(*) FROM {TABLE_NAME} 
            WHERE timestamp_received < date('now', '-{days} days')
        """)
        count_to_delete = cursor.fetchone()[0]
        
        if count_to_delete == 0:
            print(f"✅ Nenhum registro anterior a {days} dias encontrado")
            conn.close()
            return
        
        # Confirmar remoção
        response = input(f"⚠️ Remover {count_to_delete} registros anteriores a {days} dias? (s/N): ")
        if response.lower() != 's':
            print("❌ Operação cancelada")
            conn.close()
            return
        
        # Remover registros
        cursor.execute(f"""
            DELETE FROM {TABLE_NAME} 
            WHERE timestamp_received < date('now', '-{days} days')
        """)
        
        deleted_count = cursor.rowcount
        conn.commit()
        
        # Otimizar banco após remoção
        cursor.execute("VACUUM")
        conn.close()
        
        print(f"✅ {deleted_count} registros removidos com sucesso")
        print("✅ Banco de dados otimizado")
        
    except Exception as e:
        print(f"❌ Erro ao limpar registros: {e}")

def main():
    parser = argparse.ArgumentParser(description='HomeGuard SQLite Database Utility')
    parser.add_argument('--stats', action='store_true', help='Mostrar estatísticas detalhadas')
    parser.add_argument('--schema', action='store_true', help='Mostrar estrutura da tabela')
    parser.add_argument('--recent', type=int, default=20, help='Mostrar eventos recentes (padrão: 20)')
    parser.add_argument('--sensor', type=str, help='Consultar eventos de sensor específico')
    parser.add_argument('--cleanup', type=int, help='Remover registros anteriores a N dias')
    
    args = parser.parse_args()
    
    # Executar ação solicitada
    if args.schema:
        show_table_schema()
    elif args.stats:
        show_statistics()
    elif args.sensor:
        query_by_sensor(args.sensor)
    elif args.cleanup:
        cleanup_old_records(args.cleanup)
    else:
        show_recent_events(args.recent)

if __name__ == '__main__':
    main()
