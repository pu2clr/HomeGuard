#!/usr/bin/env python3
"""
Teste das APIs do Dashboard para diagnosticar erros
"""

import sqlite3
import json
import os

# Configuração
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, 'db', 'homeguard.db')

def test_database_connection():
    """Testar conexão com banco"""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.close()
        print("✅ Conexão com banco OK")
        return True
    except Exception as e:
        print(f"❌ Erro na conexão: {e}")
        return False

def test_temperature_query():
    """Testar query de temperatura"""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        query = """
            SELECT * FROM vw_temperature_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            ORDER BY created_at DESC 
            LIMIT 5
        """
        
        cursor.execute(query)
        results = cursor.fetchall()
        conn.close()
        
        print(f"✅ Query temperatura OK - {len(results)} registros")
        if results:
            print(f"   Último registro: {results[0]['created_at']}")
        return True
    except Exception as e:
        print(f"❌ Erro query temperatura: {e}")
        return False

def test_humidity_query():
    """Testar query de umidade"""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        query = """
            SELECT * FROM vw_humidity_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            ORDER BY created_at DESC 
            LIMIT 5
        """
        
        cursor.execute(query)
        results = cursor.fetchall()
        conn.close()
        
        print(f"✅ Query umidade OK - {len(results)} registros")
        if results:
            print(f"   Último registro: {results[0]['created_at']}")
        return True
    except Exception as e:
        print(f"❌ Erro query umidade: {e}")
        return False

def test_motion_query():
    """Testar query de movimento"""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        query = """
            SELECT * FROM vw_motion_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            ORDER BY created_at DESC 
            LIMIT 5
        """
        
        cursor.execute(query)
        results = cursor.fetchall()
        conn.close()
        
        print(f"✅ Query movimento OK - {len(results)} registros")
        if results:
            print(f"   Último registro: {results[0]['created_at']}")
        return True
    except Exception as e:
        print(f"❌ Erro query movimento: {e}")
        return False

def test_relay_query():
    """Testar query de relés"""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        query = """
            SELECT * FROM vw_relay_activity 
            WHERE created_at >= datetime('now', '-24 hours')
            ORDER BY created_at DESC 
            LIMIT 5
        """
        
        cursor.execute(query)
        results = cursor.fetchall()
        conn.close()
        
        print(f"✅ Query relés OK - {len(results)} registros")
        if results:
            print(f"   Último registro: {results[0]['created_at']}")
        return True
    except Exception as e:
        print(f"❌ Erro query relés: {e}")
        return False

def main():
    print("🔍 Testando APIs do Dashboard...")
    print(f"📁 Banco de dados: {DB_PATH}")
    print("-" * 50)
    
    # Verificar se arquivo existe
    if not os.path.exists(DB_PATH):
        print(f"❌ Arquivo do banco não encontrado: {DB_PATH}")
        return
    
    # Executar testes
    tests = [
        test_database_connection,
        test_temperature_query,
        test_humidity_query,
        test_motion_query,
        test_relay_query
    ]
    
    passed = 0
    for test in tests:
        if test():
            passed += 1
    
    print("-" * 50)
    print(f"📊 Resultado: {passed}/{len(tests)} testes passaram")

if __name__ == '__main__':
    main()
