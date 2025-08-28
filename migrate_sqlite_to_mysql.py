#!/usr/bin/env python3

"""
============================================
HomeGuard - SQLite to MySQL Data Migration
Script para migrar dados do SQLite para MySQL
============================================
"""

import sqlite3
import mysql.connector
from mysql.connector import Error
import json
import os
import sys
from datetime import datetime

class HomeGuardDataMigration:
    def __init__(self):
        self.sqlite_db_path = '../db/homeguard.db'
        self.mysql_config_file = 'homeguard_mysql_config.json'
        self.mysql_config = self._load_mysql_config()
        
        # Tabelas para migrar
        self.tables_to_migrate = [
            'motion_sensors',
            'dht11_sensors', 
            'sensor_alerts'
        ]
        
        print("🔄 HomeGuard Data Migration: SQLite → MySQL")
        print("=" * 50)

    def _load_mysql_config(self):
        """Carregar configuração do MySQL"""
        config_paths = [
            self.mysql_config_file,
            f"~/{self.mysql_config_file}",
            f"../web/{self.mysql_config_file}"
        ]
        
        for config_path in config_paths:
            expanded_path = os.path.expanduser(config_path)
            if os.path.exists(expanded_path):
                try:
                    with open(expanded_path, 'r') as f:
                        config = json.load(f)
                    print(f"✅ Configuração MySQL carregada de: {expanded_path}")
                    return config['mysql']
                except Exception as e:
                    print(f"❌ Erro ao carregar configuração: {e}")
                    continue
        
        # Configuração padrão se não encontrar arquivo
        print("⚠️  Usando configuração MySQL padrão")
        return {
            "host": "localhost",
            "port": 3306,
            "database": "homeguard", 
            "user": "homeguard",
            "password": input("Digite a senha do MySQL para o usuário 'homeguard': "),
            "charset": "utf8mb4"
        }

    def connect_sqlite(self):
        """Conectar ao SQLite"""
        try:
            if not os.path.exists(self.sqlite_db_path):
                print(f"❌ Arquivo SQLite não encontrado: {self.sqlite_db_path}")
                return None
                
            conn = sqlite3.connect(self.sqlite_db_path)
            print(f"✅ Conectado ao SQLite: {self.sqlite_db_path}")
            return conn
            
        except Exception as e:
            print(f"❌ Erro ao conectar ao SQLite: {e}")
            return None

    def connect_mysql(self):
        """Conectar ao MySQL"""
        try:
            connection = mysql.connector.connect(
                host=self.mysql_config['host'],
                port=self.mysql_config['port'],
                database=self.mysql_config['database'],
                user=self.mysql_config['user'],
                password=self.mysql_config['password'],
                charset=self.mysql_config['charset'],
                autocommit=True
            )
            
            print(f"✅ Conectado ao MySQL: {self.mysql_config['host']}:{self.mysql_config['port']}")
            return connection
            
        except Error as e:
            print(f"❌ Erro ao conectar ao MySQL: {e}")
            return None

    def check_sqlite_tables(self, sqlite_conn):
        """Verificar quais tabelas existem no SQLite"""
        try:
            cursor = sqlite_conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
            tables = [row[0] for row in cursor.fetchall()]
            
            existing_tables = []
            for table in self.tables_to_migrate:
                if table in tables:
                    cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    count = cursor.fetchone()[0]
                    existing_tables.append((table, count))
                    print(f"📊 {table}: {count} registros")
                else:
                    print(f"⚠️  Tabela {table} não encontrada no SQLite")
            
            return existing_tables
            
        except Exception as e:
            print(f"❌ Erro ao verificar tabelas SQLite: {e}")
            return []

    def migrate_motion_sensors(self, sqlite_conn, mysql_conn):
        """Migrar tabela motion_sensors"""
        table_name = 'motion_sensors'
        print(f"\n🔄 Migrando {table_name}...")
        
        try:
            sqlite_cursor = sqlite_conn.cursor()
            mysql_cursor = mysql_conn.cursor()
            
            # Buscar dados do SQLite
            sqlite_cursor.execute(f"SELECT * FROM {table_name}")
            rows = sqlite_cursor.fetchall()
            
            # Obter nomes das colunas
            sqlite_cursor.execute(f"PRAGMA table_info({table_name})")
            columns_info = sqlite_cursor.fetchall()
            columns = [col[1] for col in columns_info]
            
            print(f"   Colunas encontradas: {columns}")
            
            if not rows:
                print(f"   ⚠️  Nenhum dado encontrado em {table_name}")
                return True
            
            # Preparar query de inserção MySQL
            placeholders = ', '.join(['%s'] * len(columns))
            mysql_insert_query = f"""
                INSERT INTO {table_name} 
                ({', '.join(columns)}) 
                VALUES ({placeholders})
                ON DUPLICATE KEY UPDATE
                device_name = VALUES(device_name),
                location = VALUES(location),
                motion_detected = VALUES(motion_detected),
                rssi = VALUES(rssi),
                uptime = VALUES(uptime),
                battery_level = VALUES(battery_level),
                timestamp_received = VALUES(timestamp_received),
                unix_timestamp = VALUES(unix_timestamp),
                raw_payload = VALUES(raw_payload)
            """
            
            # Inserir dados no MySQL
            successful_inserts = 0
            for row in rows:
                try:
                    mysql_cursor.execute(mysql_insert_query, row)
                    successful_inserts += 1
                except Error as e:
                    print(f"   ⚠️  Erro ao inserir registro {row[0]}: {e}")
            
            print(f"   ✅ {successful_inserts}/{len(rows)} registros migrados")
            return True
            
        except Exception as e:
            print(f"   ❌ Erro na migração de {table_name}: {e}")
            return False

    def migrate_dht11_sensors(self, sqlite_conn, mysql_conn):
        """Migrar tabela dht11_sensors"""
        table_name = 'dht11_sensors'
        print(f"\n🔄 Migrando {table_name}...")
        
        try:
            sqlite_cursor = sqlite_conn.cursor()
            mysql_cursor = mysql_conn.cursor()
            
            # Buscar dados do SQLite
            sqlite_cursor.execute(f"SELECT * FROM {table_name}")
            rows = sqlite_cursor.fetchall()
            
            # Obter nomes das colunas
            sqlite_cursor.execute(f"PRAGMA table_info({table_name})")
            columns_info = sqlite_cursor.fetchall()
            columns = [col[1] for col in columns_info]
            
            print(f"   Colunas encontradas: {columns}")
            
            if not rows:
                print(f"   ⚠️  Nenhum dado encontrado em {table_name}")
                return True
            
            # Preparar query de inserção MySQL
            placeholders = ', '.join(['%s'] * len(columns))
            mysql_insert_query = f"""
                INSERT INTO {table_name} 
                ({', '.join(columns)}) 
                VALUES ({placeholders})
                ON DUPLICATE KEY UPDATE
                device_name = VALUES(device_name),
                location = VALUES(location),
                sensor_type = VALUES(sensor_type),
                temperature = VALUES(temperature),
                humidity = VALUES(humidity),
                rssi = VALUES(rssi),
                uptime = VALUES(uptime),
                timestamp_received = VALUES(timestamp_received),
                raw_payload = VALUES(raw_payload)
            """
            
            # Inserir dados no MySQL
            successful_inserts = 0
            for row in rows:
                try:
                    mysql_cursor.execute(mysql_insert_query, row)
                    successful_inserts += 1
                except Error as e:
                    print(f"   ⚠️  Erro ao inserir registro {row[0]}: {e}")
            
            print(f"   ✅ {successful_inserts}/{len(rows)} registros migrados")
            return True
            
        except Exception as e:
            print(f"   ❌ Erro na migração de {table_name}: {e}")
            return False

    def migrate_sensor_alerts(self, sqlite_conn, mysql_conn):
        """Migrar tabela sensor_alerts"""
        table_name = 'sensor_alerts'
        print(f"\n🔄 Migrando {table_name}...")
        
        try:
            sqlite_cursor = sqlite_conn.cursor()
            mysql_cursor = mysql_conn.cursor()
            
            # Verificar se tabela existe
            sqlite_cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table_name,))
            if not sqlite_cursor.fetchone():
                print(f"   ⚠️  Tabela {table_name} não existe no SQLite")
                return True
            
            # Buscar dados do SQLite
            sqlite_cursor.execute(f"SELECT * FROM {table_name}")
            rows = sqlite_cursor.fetchall()
            
            # Obter nomes das colunas
            sqlite_cursor.execute(f"PRAGMA table_info({table_name})")
            columns_info = sqlite_cursor.fetchall()
            columns = [col[1] for col in columns_info]
            
            print(f"   Colunas encontradas: {columns}")
            
            if not rows:
                print(f"   ⚠️  Nenhum dado encontrado em {table_name}")
                return True
            
            # Preparar query de inserção MySQL
            placeholders = ', '.join(['%s'] * len(columns))
            mysql_insert_query = f"""
                INSERT INTO {table_name} 
                ({', '.join(columns)}) 
                VALUES ({placeholders})
                ON DUPLICATE KEY UPDATE
                device_name = VALUES(device_name),
                location = VALUES(location),
                alert_type = VALUES(alert_type),
                sensor_value = VALUES(sensor_value),
                threshold_value = VALUES(threshold_value),
                message = VALUES(message),
                severity = VALUES(severity),
                is_active = VALUES(is_active),
                timestamp_created = VALUES(timestamp_created),
                timestamp_resolved = VALUES(timestamp_resolved)
            """
            
            # Inserir dados no MySQL
            successful_inserts = 0
            for row in rows:
                try:
                    mysql_cursor.execute(mysql_insert_query, row)
                    successful_inserts += 1
                except Error as e:
                    print(f"   ⚠️  Erro ao inserir registro {row[0]}: {e}")
            
            print(f"   ✅ {successful_inserts}/{len(rows)} registros migrados")
            return True
            
        except Exception as e:
            print(f"   ❌ Erro na migração de {table_name}: {e}")
            return False

    def verify_migration(self, mysql_conn):
        """Verificar se a migração foi bem-sucedida"""
        print(f"\n🔍 Verificando migração...")
        
        try:
            cursor = mysql_conn.cursor()
            
            for table in self.tables_to_migrate:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                print(f"   📊 {table}: {count} registros no MySQL")
                
                # Verificar alguns registros recentes
                cursor.execute(f"""
                    SELECT device_id, timestamp_received 
                    FROM {table} 
                    ORDER BY id DESC 
                    LIMIT 3
                """)
                
                recent = cursor.fetchall()
                if recent:
                    print(f"      Registros recentes:")
                    for row in recent:
                        print(f"        - {row[0]}: {row[1]}")
                else:
                    print(f"      Nenhum registro encontrado")
            
            return True
            
        except Error as e:
            print(f"   ❌ Erro na verificação: {e}")
            return False

    def create_backup(self, mysql_conn):
        """Criar backup após migração"""
        print(f"\n💾 Criando backup pós-migração...")
        
        try:
            backup_dir = os.path.expanduser("~/backup/mysql")
            os.makedirs(backup_dir, exist_ok=True)
            
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_file = f"{backup_dir}/homeguard_migration_{timestamp}.sql"
            
            # Usar mysqldump para backup
            import subprocess
            
            cmd = [
                'mysqldump',
                f"-h{self.mysql_config['host']}",
                f"-u{self.mysql_config['user']}",
                f"-p{self.mysql_config['password']}",
                self.mysql_config['database']
            ]
            
            with open(backup_file, 'w') as f:
                result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True)
            
            if result.returncode == 0:
                print(f"   ✅ Backup criado: {backup_file}")
                return True
            else:
                print(f"   ⚠️  Erro no backup: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"   ❌ Erro ao criar backup: {e}")
            return False

    def run_migration(self):
        """Executar migração completa"""
        print(f"\n🚀 Iniciando migração de dados...")
        
        # Conectar aos bancos
        sqlite_conn = self.connect_sqlite()
        if not sqlite_conn:
            return False
            
        mysql_conn = self.connect_mysql()
        if not mysql_conn:
            return False
        
        try:
            # Verificar tabelas SQLite
            tables_info = self.check_sqlite_tables(sqlite_conn)
            if not tables_info:
                print("❌ Nenhuma tabela encontrada para migrar")
                return False
            
            print(f"\n📋 Tabelas para migrar: {len(tables_info)}")
            
            # Confirmar migração
            response = input("\n🔄 Deseja continuar com a migração? (y/n): ")
            if response.lower() != 'y':
                print("❌ Migração cancelada pelo usuário")
                return False
            
            # Executar migrações
            migrations = [
                ('motion_sensors', self.migrate_motion_sensors),
                ('dht11_sensors', self.migrate_dht11_sensors),
                ('sensor_alerts', self.migrate_sensor_alerts)
            ]
            
            successful_migrations = 0
            for table_name, migration_func in migrations:
                if any(table_name == info[0] for info in tables_info):
                    if migration_func(sqlite_conn, mysql_conn):
                        successful_migrations += 1
                    else:
                        print(f"❌ Falha na migração de {table_name}")
                else:
                    print(f"⏭️  Pulando {table_name} (não encontrada no SQLite)")
            
            # Verificar resultado
            if successful_migrations > 0:
                self.verify_migration(mysql_conn)
                self.create_backup(mysql_conn)
                
                print(f"\n🎉 MIGRAÇÃO CONCLUÍDA!")
                print(f"   ✅ {successful_migrations} tabelas migradas com sucesso")
                print(f"   💾 Backup criado automaticamente")
                print(f"   🔧 Use homeguard_flask_mysql.py para conectar ao MySQL")
                return True
            else:
                print(f"\n❌ MIGRAÇÃO FALHOU")
                print(f"   Nenhuma tabela foi migrada com sucesso")
                return False
                
        finally:
            # Fechar conexões
            if sqlite_conn:
                sqlite_conn.close()
                print("🔌 Conexão SQLite fechada")
                
            if mysql_conn and mysql_conn.is_connected():
                mysql_conn.close() 
                print("🔌 Conexão MySQL fechada")

def main():
    """Função principal"""
    migration = HomeGuardDataMigration()
    
    try:
        success = migration.run_migration()
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print(f"\n❌ Migração interrompida pelo usuário")
        sys.exit(1)
        
    except Exception as e:
        print(f"\n❌ Erro fatal na migração: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
