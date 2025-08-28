#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
HomeGuard Dashboard Flask - Versão MySQL/MariaDB (PyMySQL)
==========================================================
Dashboard web para monitoramento de sensores IoT usando PyMySQL
Compatível com Raspberry Pi OS Bookworm+ (PEP 668)
"""

import json
import pymysql
from datetime import datetime, timedelta
import threading
import time
from flask import Flask, render_template, jsonify, request, redirect, url_for

class MySQLHomeGuardDashboard:
    """Dashboard HomeGuard usando PyMySQL"""
    
    def __init__(self, config_file="config_mysql.json"):
        """Inicializar o dashboard HomeGuard com MySQL via PyMySQL"""
        self.config = self.load_config(config_file)
        self.db_config = self.config['database']
        
        # Configurar Flask
        self.app = Flask(__name__)
        self.app.secret_key = self.config['flask']['secret_key']
        
        # Pool de conexões simulado (PyMySQL não tem pool nativo)
        self.connection_lock = threading.Lock()
        
        # Testar conexão na inicialização
        if not self.test_connection():
            print("❌ ERRO: Não foi possível conectar ao MySQL!")
            print("🔧 Execute: ./basic_mariadb_fix.sh para corrigir problemas")
            return
        
        print("✅ Conexão MySQL/PyMySQL estabelecida com sucesso!")
        
        # Configurar rotas
        self.setup_routes()

    def load_config(self, config_file):
        """Carregar configuração do arquivo JSON"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
                print(f"✅ Configuração carregada: {config_file}")
                return config
        except FileNotFoundError:
            print(f"❌ Arquivo de configuração não encontrado: {config_file}")
            print("💡 Copie config_mysql.json.example para config_mysql.json")
            exit(1)
        except json.JSONDecodeError as e:
            print(f"❌ Erro no JSON de configuração: {e}")
            exit(1)

    def test_connection(self):
        """Testar conexão com MySQL usando PyMySQL"""
        try:
            conn = self.get_db_connection()
            if conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1 AS test")
                result = cursor.fetchone()
                cursor.close()
                conn.close()
                
                if result and result[0] == 1:
                    print(f"✅ Conexão MySQL OK - Host: {self.db_config['host']}:{self.db_config['port']}")
                    return True
                    
        except Exception as e:
            print(f"❌ Erro na conexão MySQL: {str(e)}")
            print("\\n🔧 SOLUÇÕES POSSÍVEIS:")
            print("   1. Execute: ./basic_mariadb_fix.sh")
            print("   2. Verifique se MariaDB está rodando: sudo systemctl status mariadb")
            print("   3. Verifique as credenciais em config_mysql.json")
            print("   4. Teste conexão manual: mysql -u homeguard -p")
            
        return False

    def get_db_connection(self):
        """Obter conexão PyMySQL"""
        try:
            conn = pymysql.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database=self.db_config['database'],
                user=self.db_config['user'],
                password=self.db_config['password'],
                charset=self.db_config.get('charset', 'utf8mb4'),
                connect_timeout=self.db_config.get('connection_timeout', 10),
                autocommit=self.db_config.get('autocommit', True)
            )
            return conn
        except Exception as e:
            print(f"❌ Erro na conexão PyMySQL: {str(e)}")
            return None

    def execute_query(self, query, params=None, fetch_one=False, fetch_all=False):
        """Executar query de forma thread-safe"""
        with self.connection_lock:
            conn = self.get_db_connection()
            if not conn:
                return None
                
            try:
                cursor = conn.cursor(pymysql.cursors.DictCursor)
                cursor.execute(query, params or ())
                
                if fetch_one:
                    result = cursor.fetchone()
                elif fetch_all:
                    result = cursor.fetchall()
                else:
                    result = cursor.rowcount
                    
                cursor.close()
                conn.close()
                return result
                
            except Exception as e:
                print(f"❌ Erro na query: {str(e)}")
                conn.close()
                return None

    def setup_routes(self):
        """Configurar rotas Flask"""
        
        @self.app.route('/')
        def index():
            """Página principal do dashboard"""
            return render_template('index.html')
        
        @self.app.route('/api/motion_sensors')
        def get_motion_sensors():
            """API: Obter dados dos sensores de movimento"""
            try:
                query = """
                SELECT * FROM motion_sensors 
                ORDER BY timestamp_received DESC 
                LIMIT %s
                """
                limit = request.args.get('limit', 50, type=int)
                sensors = self.execute_query(query, (limit,), fetch_all=True)
                
                return jsonify({
                    'status': 'success',
                    'data': sensors or [],
                    'count': len(sensors) if sensors else 0
                })
                
            except Exception as e:
                return jsonify({
                    'status': 'error',
                    'message': str(e)
                }), 500

        @self.app.route('/api/dht11_sensors')
        def get_dht11_sensors():
            """API: Obter dados dos sensores DHT11"""
            try:
                query = """
                SELECT * FROM dht11_sensors 
                ORDER BY timestamp_received DESC 
                LIMIT %s
                """
                limit = request.args.get('limit', 50, type=int)
                sensors = self.execute_query(query, (limit,), fetch_all=True)
                
                return jsonify({
                    'status': 'success',
                    'data': sensors or [],
                    'count': len(sensors) if sensors else 0
                })
                
            except Exception as e:
                return jsonify({
                    'status': 'error',
                    'message': str(e)
                }), 500

        @self.app.route('/api/alerts')
        def get_alerts():
            """API: Obter alertas ativos"""
            try:
                query = """
                SELECT * FROM sensor_alerts 
                WHERE is_active = 1
                ORDER BY timestamp_created DESC 
                LIMIT %s
                """
                limit = request.args.get('limit', 20, type=int)
                alerts = self.execute_query(query, (limit,), fetch_all=True)
                
                return jsonify({
                    'status': 'success',
                    'data': alerts or [],
                    'count': len(alerts) if alerts else 0
                })
                
            except Exception as e:
                return jsonify({
                    'status': 'error',
                    'message': str(e)
                }), 500

        @self.app.route('/api/stats')
        def get_stats():
            """API: Estatísticas gerais"""
            try:
                stats = {}
                
                # Total de sensores de movimento
                motion_count = self.execute_query(
                    "SELECT COUNT(DISTINCT device_id) as count FROM motion_sensors",
                    fetch_one=True
                )
                stats['motion_sensors'] = motion_count['count'] if motion_count else 0
                
                # Total de sensores DHT11  
                dht_count = self.execute_query(
                    "SELECT COUNT(DISTINCT device_id) as count FROM dht11_sensors",
                    fetch_one=True
                )
                stats['dht11_sensors'] = dht_count['count'] if dht_count else 0
                
                # Alertas ativos
                alert_count = self.execute_query(
                    "SELECT COUNT(*) as count FROM sensor_alerts WHERE is_active = 1",
                    fetch_one=True
                )
                stats['active_alerts'] = alert_count['count'] if alert_count else 0
                
                # Último movimento detectado
                last_motion = self.execute_query(
                    "SELECT MAX(timestamp_received) as last_motion FROM motion_sensors WHERE motion_detected = 1",
                    fetch_one=True
                )
                stats['last_motion'] = last_motion['last_motion'] if last_motion and last_motion['last_motion'] else None
                
                return jsonify({
                    'status': 'success',
                    'data': stats
                })
                
            except Exception as e:
                return jsonify({
                    'status': 'error',
                    'message': str(e)
                }), 500

        @self.app.route('/api/health')
        def health_check():
            """API: Verificação de saúde do sistema"""
            try:
                # Testar conexão com database
                test_result = self.execute_query("SELECT 1 as test", fetch_one=True)
                
                if test_result and test_result['test'] == 1:
                    return jsonify({
                        'status': 'healthy',
                        'database': 'connected',
                        'driver': 'PyMySQL',
                        'timestamp': datetime.now().isoformat()
                    })
                else:
                    return jsonify({
                        'status': 'unhealthy',
                        'database': 'disconnected',
                        'driver': 'PyMySQL'
                    }), 503
                    
            except Exception as e:
                return jsonify({
                    'status': 'error',
                    'database': 'error',
                    'message': str(e)
                }), 500

    def run(self):
        """Executar servidor Flask"""
        try:
            host = self.config['flask']['host']
            port = self.config['flask']['port']
            debug = self.config['flask']['debug']
            
            print(f"🚀 Iniciando HomeGuard Dashboard...")
            print(f"   URL: http://{host}:{port}")
            print(f"   Debug: {debug}")
            print(f"   Database: {self.db_config['database']} (PyMySQL)")
            print("   Pressione Ctrl+C para parar")
            
            self.app.run(
                host=host,
                port=port,
                debug=debug,
                threaded=True
            )
            
        except KeyboardInterrupt:
            print("\n⏹️  Servidor interrompido pelo usuário")
        except Exception as e:
            print(f"❌ Erro ao iniciar servidor: {str(e)}")

def main():
    """Função principal"""
    print("🏠 HomeGuard Dashboard - MySQL/MariaDB (PyMySQL)")
    print("=" * 50)
    
    try:
        dashboard = MySQLHomeGuardDashboard()
        dashboard.run()
    except KeyboardInterrupt:
        print("\n👋 Encerrando HomeGuard Dashboard...")
    except Exception as e:
        print(f"❌ Erro fatal: {str(e)}")

if __name__ == "__main__":
    main()
