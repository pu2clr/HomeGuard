#!/usr/bin/env python3

"""
============================================
HomeGuard SQLite System Test
Testa o sistema de monitoramento com SQLite
============================================
"""

import os
import sys
import time
import sqlite3
from datetime import datetime, timedelta

def test_database_creation():
    """Testa criação do banco de dados"""
    print("🗄️ Testando criação do banco de dados...")
    
    db_path = './db/homeguard.db'
    if os.path.exists(db_path):
        os.remove(db_path)
        print("   • Banco anterior removido")
    
    # Importar e inicializar o banco
    sys.path.append('.')
    try:
        from motion_monitor_sqlite import init_db
        conn = init_db()
        if conn:
            print("   ✓ Banco criado com sucesso")
            conn.close()
            return True
        else:
            print("   ❌ Falha na criação do banco")
            return False
    except ImportError:
        print("   ❌ Erro ao importar motion_monitor_sqlite.py")
        return False

def test_database_structure():
    """Testa estrutura do banco de dados"""
    print("🏗️ Testando estrutura do banco...")
    
    db_path = './db/homeguard.db'
    if not os.path.exists(db_path):
        print("   ❌ Banco não existe")
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Verificar tabelas
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        
        expected_tables = ['motion_sensors']
        found_tables = [table[0] for table in tables]
        
        for table in expected_tables:
            if table in found_tables:
                print(f"   ✓ Tabela '{table}' existe")
            else:
                print(f"   ❌ Tabela '{table}' não encontrada")
                return False
        
        # Verificar colunas da tabela motion_sensors
        cursor.execute("PRAGMA table_info(motion_sensors)")
        columns = cursor.fetchall()
        
        expected_columns = ['id', 'sensor', 'event', 'device_id', 'location', 
                          'rssi', 'count', 'duration', 'timestamp_device', 
                          'unix_timestamp', 'timestamp_received', 'raw_payload']
        found_columns = [col[1] for col in columns]
        
        for col in expected_columns:
            if col in found_columns:
                print(f"   ✓ Coluna '{col}' existe")
            else:
                print(f"   ❌ Coluna '{col}' não encontrada")
                return False
        
        # Verificar índices
        cursor.execute("SELECT name FROM sqlite_master WHERE type='index'")
        indexes = cursor.fetchall()
        index_names = [idx[0] for idx in indexes]
        
        expected_indexes = ['idx_motion_timestamp', 'idx_motion_sensor', 'idx_motion_event']
        
        for idx in expected_indexes:
            if idx in index_names:
                print(f"   ✓ Índice '{idx}' existe")
            else:
                print(f"   ❌ Índice '{idx}' não encontrado")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"   ❌ Erro ao verificar estrutura: {e}")
        return False

def test_data_insertion():
    """Testa inserção de dados de teste"""
    print("📝 Testando inserção de dados...")
    
    db_path = './db/homeguard.db'
    if not os.path.exists(db_path):
        print("   ❌ Banco não existe")
        return False
    
    try:
        sys.path.append('.')
        from motion_monitor_sqlite import insert_motion_data
        
        # Dados de teste com parâmetros corretos
        test_entries = [
            ('ESP01_001', 'DETECTED', 'ESP01_001', 'SALA', -45, 1, 2.5, 
             datetime.now().strftime('%Y-%m-%d %H:%M:%S'), int(time.time()), 
             'ESP01_001|DETECTED|SALA|-45|1|2.5'),
            ('ESP01_002', 'CLEAR', 'ESP01_002', 'COZINHA', -50, 1, 0.0,
             datetime.now().strftime('%Y-%m-%d %H:%M:%S'), int(time.time()) + 10,
             'ESP01_002|CLEAR|COZINHA|-50|1|0.0')
        ]
        
        for params in test_entries:
            sensor, event, device_id, location, rssi, count, duration, timestamp_device, unix_timestamp, raw_payload = params
            if insert_motion_data(sensor, event, device_id, location, rssi, count, duration, 
                                timestamp_device, unix_timestamp, raw_payload):
                print(f"   ✓ Inserido: {sensor} - {event} - {location}")
            else:
                print(f"   ❌ Falha: {sensor} - {event} - {location}")
                return False
        
        return True
        
    except Exception as e:
        print(f"   ❌ Erro na inserção: {e}")
        return False

def test_data_query():
    """Testa consulta de dados"""
    print("🔍 Testando consulta de dados...")
    
    db_path = './db/homeguard.db'
    if not os.path.exists(db_path):
        print("   ❌ Banco não existe")
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Contar registros
        cursor.execute("SELECT COUNT(*) FROM motion_sensors")
        count = cursor.fetchone()[0]
        print(f"   ✓ Encontrados {count} registros")
        
        # Buscar registros recentes
        cursor.execute("""
            SELECT sensor, event, timestamp_device, location 
            FROM motion_sensors 
            ORDER BY unix_timestamp DESC 
            LIMIT 5
        """)
        
        records = cursor.fetchall()
        print("   ✓ Últimos registros:")
        for record in records:
            print(f"     • {record[0]} - {record[1]} - {record[2]} - {record[3]}")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"   ❌ Erro na consulta: {e}")
        return False

def test_database_utility():
    """Testa utilitário de banco"""
    print("🛠️ Testando utilitário de banco...")
    
    try:
        sys.path.append('.')
        from db_utility import show_statistics
        
        print("   ✓ Estatísticas do banco:")
        show_statistics()
        return True
        
    except Exception as e:
        print(f"   ❌ Erro no utilitário: {e}")
        return False

def main():
    """Função principal do teste"""
    print("🧪 HomeGuard SQLite System Test")
    print("=" * 40)
    print()
    
    tests = [
        ("Criação do Banco", test_database_creation),
        ("Estrutura do Banco", test_database_structure),
        ("Inserção de Dados", test_data_insertion),
        ("Consulta de Dados", test_data_query),
        ("Utilitário de Banco", test_database_utility)
    ]
    
    passed = 0
    failed = 0
    
    for test_name, test_func in tests:
        print(f"🔄 {test_name}...")
        try:
            if test_func():
                print(f"✅ {test_name}: PASSOU")
                passed += 1
            else:
                print(f"❌ {test_name}: FALHOU")
                failed += 1
        except Exception as e:
            print(f"❌ {test_name}: ERRO - {e}")
            failed += 1
        
        print()
    
    print("=" * 40)
    print(f"📊 Resultados: {passed} passaram, {failed} falharam")
    
    if failed == 0:
        print("🎉 Todos os testes passaram! Sistema SQLite está funcionando.")
    else:
        print("⚠️ Alguns testes falharam. Verifique os erros acima.")
    
    return failed == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
