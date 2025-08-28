#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
HomeGuard - Teste de Conexão MySQL
===================================
Script para testar a conexão e configuração do MySQL/MariaDB
"""

import json
import sys
import os
from datetime import datetime

try:
    import mysql.connector
    from mysql.connector import Error
    print("✅ mysql.connector importado com sucesso")
except ImportError as e:
    print("❌ ERRO: mysql.connector não encontrado")
    print("💡 Solução: pip3 install mysql-connector-python")
    sys.exit(1)

def load_config(config_file="config_mysql.json"):
    """Carregar configuração do arquivo JSON"""
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
            print(f"✅ Configuração carregada de {config_file}")
            return config
    except FileNotFoundError:
        print(f"❌ Arquivo {config_file} não encontrado")
        return None
    except json.JSONDecodeError as e:
        print(f"❌ Erro no JSON: {e}")
        return None

def test_connection(db_config):
    """Testar conexão com diferentes métodos"""
    
    print("\n🔍 TESTANDO CONEXÃO MYSQL...")
    print("=" * 50)
    
    # Teste 1: Conexão básica
    print("1️⃣ Testando conexão básica...")
    try:
        conn = mysql.connector.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config['user'],
            password=db_config['password'],
            connection_timeout=10
        )
        
        if conn.is_connected():
            info = conn.get_server_info()
            print(f"✅ Conectado ao servidor MySQL versão {info}")
            
            # Testar query
            cursor = conn.cursor()
            cursor.execute("SELECT VERSION() as version, NOW() as current_time")
            result = cursor.fetchone()
            print(f"   Versão: {result[0]}")
            print(f"   Hora: {result[1]}")
            cursor.close()
            conn.close()
            
        return True
        
    except Error as e:
        print(f"❌ Erro na conexão: {e}")
        
        # Diagnóstico de erro comum
        error_code = e.errno if hasattr(e, 'errno') else None
        
        if error_code == 1045:  # Access denied
            print("\n🔧 ERRO DE AUTENTICAÇÃO DETECTADO:")
            print("   Este é o erro ERROR 1698 ou similar")
            print("   Soluções:")
            print("   - Execute: ./fix_mariadb_auth.sh")
            print("   - Ou verifique a senha do usuário homeguard")
            
        elif error_code == 2003:  # Can't connect
            print("\n🔧 SERVIDOR NÃO ACESSÍVEL:")
            print("   Verifique se MariaDB está rodando:")
            print("   - sudo systemctl status mariadb")
            print("   - sudo systemctl start mariadb")
            
        elif error_code == 1049:  # Unknown database
            print("\n🔧 DATABASE NÃO ENCONTRADA:")
            print("   Database 'homeguard' não existe")
            print("   Execute: ./fix_mariadb_auth.sh para criar")
            
        return False

def test_database(db_config):
    """Testar acesso ao database homeguard"""
    
    print("\n2️⃣ Testando acesso ao database homeguard...")
    try:
        conn = mysql.connector.connect(
            host=db_config['host'],
            port=db_config['port'],
            database=db_config['database'],
            user=db_config['user'],
            password=db_config['password'],
            connection_timeout=10
        )
        
        cursor = conn.cursor()
        
        # Listar tabelas
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        
        if tables:
            print(f"✅ Database '{db_config['database']}' acessível")
            print("   Tabelas encontradas:")
            for table in tables:
                print(f"   - {table[0]}")
        else:
            print(f"⚠️  Database '{db_config['database']}' existe mas está vazio")
            print("   Execute: ./fix_mariadb_auth.sh para criar tabelas")
            
        cursor.close()
        conn.close()
        return True
        
    except Error as e:
        print(f"❌ Erro no database: {e}")
        return False

def test_tables(db_config):
    """Testar estrutura das tabelas"""
    
    print("\n3️⃣ Testando estrutura das tabelas...")
    expected_tables = ['motion_sensors', 'dht11_sensors', 'sensor_alerts']
    
    try:
        conn = mysql.connector.connect(
            host=db_config['host'],
            port=db_config['port'],
            database=db_config['database'],
            user=db_config['user'],
            password=db_config['password']
        )
        
        cursor = conn.cursor()
        
        for table in expected_tables:
            try:
                cursor.execute(f"DESCRIBE {table}")
                columns = cursor.fetchall()
                print(f"✅ Tabela '{table}' OK ({len(columns)} colunas)")
                
                # Contar registros
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                print(f"   Registros: {count}")
                
            except Error:
                print(f"❌ Tabela '{table}' não encontrada")
                
        cursor.close()
        conn.close()
        return True
        
    except Error as e:
        print(f"❌ Erro ao verificar tabelas: {e}")
        return False

def test_insert_sample(db_config):
    """Testar inserção de dados de exemplo"""
    
    print("\n4️⃣ Testando inserção de dados...")
    try:
        conn = mysql.connector.connect(
            host=db_config['host'],
            port=db_config['port'],
            database=db_config['database'],
            user=db_config['user'],
            password=db_config['password'],
            autocommit=True
        )
        
        cursor = conn.cursor()
        
        # Inserir dado de teste
        test_sql = """
        INSERT INTO motion_sensors 
        (device_id, device_name, location, motion_detected, timestamp_received, unix_timestamp) 
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        
        test_data = (
            'test_device_001',
            'Sensor de Teste',
            'Test Location',
            True,
            datetime.now(),
            int(datetime.now().timestamp())
        )
        
        cursor.execute(test_sql, test_data)
        
        # Verificar inserção
        cursor.execute("SELECT * FROM motion_sensors WHERE device_id = 'test_device_001'")
        result = cursor.fetchone()
        
        if result:
            print("✅ Inserção de dados OK")
            
            # Limpar dados de teste
            cursor.execute("DELETE FROM motion_sensors WHERE device_id = 'test_device_001'")
            print("✅ Limpeza de dados de teste OK")
        else:
            print("❌ Falha na inserção")
            
        cursor.close()
        conn.close()
        return True
        
    except Error as e:
        print(f"❌ Erro no teste de inserção: {e}")
        return False

def main():
    """Função principal"""
    
    print("🔍 HomeGuard MySQL Connection Test")
    print("=" * 50)
    
    # Verificar se estamos no diretório correto
    if not os.path.exists('config_mysql.json'):
        print("❌ Arquivo config_mysql.json não encontrado")
        print("💡 Execute este script no diretório web/")
        sys.exit(1)
    
    # Carregar configuração
    config = load_config()
    if not config:
        sys.exit(1)
        
    db_config = config['database']
    print(f"📊 Configuração MySQL:")
    print(f"   Host: {db_config['host']}:{db_config['port']}")
    print(f"   Database: {db_config['database']}")
    print(f"   User: {db_config['user']}")
    
    # Executar testes
    tests = [
        ("Conexão Básica", lambda: test_connection(db_config)),
        ("Acesso Database", lambda: test_database(db_config)),
        ("Estrutura Tabelas", lambda: test_tables(db_config)),
        ("Inserção Dados", lambda: test_insert_sample(db_config))
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ Erro inesperado em {test_name}: {e}")
            results.append((test_name, False))
    
    # Resumo final
    print("\n" + "=" * 50)
    print("📋 RESUMO DOS TESTES")
    print("=" * 50)
    
    all_passed = True
    for test_name, result in results:
        status = "✅ PASSOU" if result else "❌ FALHOU"
        print(f"{test_name:20} {status}")
        if not result:
            all_passed = False
    
    print("\n" + "=" * 50)
    if all_passed:
        print("🎉 TODOS OS TESTES PASSARAM!")
        print("✅ MySQL está configurado corretamente")
        print("🚀 Você pode executar: python3 homeguard_flask_mysql.py")
    else:
        print("❌ ALGUNS TESTES FALHARAM")
        print("🔧 Execute: ./fix_mariadb_auth.sh para corrigir problemas")
        
    print("=" * 50)

if __name__ == "__main__":
    main()
