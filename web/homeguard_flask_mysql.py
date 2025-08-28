#!/usr/bin/env python3

"""
============================================
HomeGuard Dashboard - Versão Flask + MySQL
Interface web leve usando Flask com MySQL
============================================
"""

from flask import Flask, render_template, jsonify, request, redirect, url_for
import mysql.connector
from mysql.connector import Error
import json
from datetime import datetime, timedelta
import os
import sys
from flask_mqtt_controller import mqtt_controller, init_mqtt
from mqtt_relay_config import RELAYS_CONFIG

app = Flask(__name__)

class MySQLHomeGuardDashboard:
    def __init__(self, config_file="config_mysql.json"):
        """Inicializar o dashboard HomeGuard com MySQL"""
        self.config = self.load_config(config_file)
        self.db_config = self.config['database']
        
        # Configurar Flask
        self.app = Flask(__name__)
        self.app.secret_key = self.config['flask']['secret_key']
        
        # Pool de conexões MySQL
        self.connection_pool = None
        self.init_database_pool()
        
        # Testar conexão na inicialização
        if not self.test_connection():
            print("❌ ERRO: Não foi possível conectar ao MySQL!")
            print("🔧 Execute: ./fix_mariadb_auth.sh para corrigir problemas de autenticação")
            return
        
        print("✅ Conexão MySQL estabelecida com sucesso!")
        
        # Configurar rotas
        self.setup_routes()

    def _load_config(self):
        """Carregar configuração do MySQL"""
        default_config = {
            "mysql": {
                "host": "localhost",
                "port": 3306,
                "database": "homeguard",
                "user": "homeguard",
                "password": "homeguard123",
                "charset": "utf8mb4",
                "autocommit": True
            }
        }
        
        try:
            # Tentar carregar de arquivo local
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                print(f"✅ Configuração carregada de {self.config_file}")
                return config
            
            # Tentar carregar do diretório home
            home_config = os.path.expanduser(f"~/{self.config_file}")
            if os.path.exists(home_config):
                with open(home_config, 'r') as f:
                    config = json.load(f)
                print(f"✅ Configuração carregada de {home_config}")
                return config
                
            print(f"⚠️  Arquivo de configuração não encontrado, usando configuração padrão")
            return default_config
            
        except Exception as e:
            print(f"❌ Erro ao carregar configuração: {e}")
            print("🔧 Usando configuração padrão")
            return default_config

    def _init_database(self):
        """Inicializar tabelas do banco de dados MySQL"""
        conn = self.get_db_connection()
        if not conn:
            print("❌ Não foi possível conectar ao MySQL para inicialização")
            return
            
        try:
            cursor = conn.cursor()
            
            # Criar tabela para sensores DHT11
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS dht11_sensors (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    device_id VARCHAR(255) NOT NULL,
                    device_name VARCHAR(255) NOT NULL,
                    location VARCHAR(255) NOT NULL,
                    sensor_type VARCHAR(50) NOT NULL,
                    temperature DECIMAL(5,2),
                    humidity DECIMAL(5,2),
                    rssi INT,
                    uptime INT,
                    timestamp_received DATETIME NOT NULL,
                    raw_payload TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Criar tabela para sensores de movimento
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS motion_sensors (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    device_id VARCHAR(255) NOT NULL,
                    device_name VARCHAR(255) NOT NULL,
                    location VARCHAR(255) NOT NULL,
                    motion_detected BOOLEAN NOT NULL,
                    rssi INT,
                    uptime INT,
                    battery_level DECIMAL(5,2),
                    timestamp_received DATETIME NOT NULL,
                    unix_timestamp BIGINT,
                    raw_payload TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Criar tabela para alertas
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sensor_alerts (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    device_id VARCHAR(255) NOT NULL,
                    device_name VARCHAR(255) NOT NULL,
                    location VARCHAR(255) NOT NULL,
                    alert_type VARCHAR(100) NOT NULL,
                    sensor_value DECIMAL(8,2) NOT NULL,
                    threshold_value DECIMAL(8,2) NOT NULL,
                    message TEXT NOT NULL,
                    severity VARCHAR(20) NOT NULL,
                    is_active BOOLEAN DEFAULT TRUE,
                    timestamp_created DATETIME NOT NULL,
                    timestamp_resolved DATETIME NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Criar índices para performance
            indices = [
                "CREATE INDEX IF NOT EXISTS idx_dht11_device ON dht11_sensors(device_id)",
                "CREATE INDEX IF NOT EXISTS idx_dht11_timestamp ON dht11_sensors(timestamp_received)",
                "CREATE INDEX IF NOT EXISTS idx_motion_device ON motion_sensors(device_id)", 
                "CREATE INDEX IF NOT EXISTS idx_motion_timestamp ON motion_sensors(timestamp_received)",
                "CREATE INDEX IF NOT EXISTS idx_alerts_device ON sensor_alerts(device_id)",
                "CREATE INDEX IF NOT EXISTS idx_alerts_active ON sensor_alerts(is_active)"
            ]
            
            for index_sql in indices:
                try:
                    cursor.execute(index_sql)
                except Error as e:
                    # Índice já existe, ignorar
                    if "Duplicate key name" not in str(e):
                        print(f"⚠️  Aviso ao criar índice: {e}")
            
            conn.commit()
            print("✅ Banco de dados MySQL inicializado com sucesso")
            
        except Error as e:
            print(f"❌ Erro ao inicializar banco de dados MySQL: {e}")
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def test_connection(self):
        """Testar conexão com MySQL de forma robusta"""
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
            print("   1. Execute: ./fix_mariadb_auth.sh")
            print("   2. Verifique se MariaDB está rodando: sudo systemctl status mariadb")
            print("   3. Verifique as credenciais em config_mysql.json")
            print("   4. Teste conexão manual: mysql -u homeguard -p")
            
        return False

    def get_db_connection(self):
        """Obter conexão do pool com tratamento de erro"""
        try:
            if self.connection_pool:
                conn = self.connection_pool.get_connection()
                if conn.is_connected():
                    return conn
        except Exception as e:
            print(f"❌ Erro no pool de conexões: {str(e)}")
            # Tentar conexão direta se pool falhar
            try:
                conn = mysql.connector.connect(
                    host=self.db_config['host'],
                    port=self.db_config['port'],
                    database=self.db_config['database'],
                    user=self.db_config['user'],
                    password=self.db_config['password'],
                    charset=self.db_config.get('charset', 'utf8mb4'),
                    connection_timeout=self.db_config.get('connection_timeout', 10),
                    autocommit=self.db_config.get('autocommit', True)
                )
                return conn
            except Exception as direct_error:
                print(f"❌ Erro na conexão direta: {str(direct_error)}")
                
        return None

    def get_device_statistics(self):
        """Obter estatísticas dos dispositivos"""
        conn = self.get_db_connection()
        if not conn:
            return {}
        
        try:
            stats = {}
            cursor = conn.cursor()
            
            # Total de dispositivos únicos
            cursor.execute(f"SELECT COUNT(DISTINCT device_id) FROM {self.motion_table}")
            result = cursor.fetchone()
            stats['total_motion_devices'] = result[0] if result else 0
            
            # Total de sensores DHT11
            cursor.execute(f"SELECT COUNT(DISTINCT device_id) FROM {self.sensors_table}")
            result = cursor.fetchone()
            stats['total_dht11_devices'] = result[0] if result else 0
            
            stats['total_devices'] = stats['total_motion_devices'] + stats['total_dht11_devices']
            
            # Total de eventos hoje
            cursor.execute(f"""
                SELECT COUNT(*) FROM {self.motion_table}
                WHERE DATE(timestamp_received) = CURDATE()
            """)
            result = cursor.fetchone()
            motion_events = result[0] if result else 0
            
            cursor.execute(f"""
                SELECT COUNT(*) FROM {self.sensors_table}
                WHERE DATE(timestamp_received) = CURDATE()
            """)
            result = cursor.fetchone()
            sensor_events = result[0] if result else 0
            
            stats['events_today'] = motion_events + sensor_events
            stats['motion_events_today'] = motion_events
            stats['sensor_readings_today'] = sensor_events
            
            # Dispositivos ativos nas últimas 24h
            cursor.execute(f"""
                SELECT COUNT(DISTINCT device_id) FROM {self.motion_table}
                WHERE timestamp_received >= DATE_SUB(NOW(), INTERVAL 1 DAY)
            """)
            result = cursor.fetchone()
            motion_active = result[0] if result else 0
            
            cursor.execute(f"""
                SELECT COUNT(DISTINCT device_id) FROM {self.sensors_table}
                WHERE timestamp_received >= DATE_SUB(NOW(), INTERVAL 1 DAY)
            """)
            result = cursor.fetchone()
            sensors_active = result[0] if result else 0
            
            stats['active_devices_24h'] = motion_active + sensors_active
            
            # Último evento (de movimento)
            cursor.execute(f"""
                SELECT timestamp_received FROM {self.motion_table}
                ORDER BY unix_timestamp DESC LIMIT 1
            """)
            result = cursor.fetchone()
            stats['last_event'] = result[0].strftime('%Y-%m-%d %H:%M:%S') if result and result[0] else 'Nenhum'
            
            return stats
            
        except Error as e:
            print(f"❌ Erro ao obter estatísticas: {e}")
            return {}
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def get_device_status(self):
        """Obter status atual dos dispositivos"""
        motion_devices = self.get_motion_devices_status()
        dht11_devices = self.get_dht11_sensors_data()
        
        # Combinar e ordernar por localização
        all_devices = motion_devices + dht11_devices
        all_devices.sort(key=lambda x: (x['location'], x['device_name']))
        
        return all_devices

    def get_motion_devices_status(self):
        """Obter status dos dispositivos de movimento"""
        conn = self.get_db_connection()
        if not conn:
            return []
        
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT 
                    device_id,
                    device_name,
                    location,
                    motion_detected,
                    rssi,
                    battery_level,
                    timestamp_received,
                    (
                        SELECT COUNT(*) 
                        FROM {self.motion_table} t2 
                        WHERE t2.device_id = t1.device_id
                        AND DATE(t2.timestamp_received) = CURDATE()
                    ) as events_today
                FROM {self.motion_table} t1
                WHERE t1.timestamp_received = (
                    SELECT MAX(timestamp_received) 
                    FROM {self.motion_table} t3 
                    WHERE t3.device_id = t1.device_id
                )
                ORDER BY t1.location, t1.device_name
            """)
            
            devices = []
            for row in cursor.fetchall():
                # Calcular status baseado na última comunicação
                last_seen = row[6]  # timestamp_received
                now = datetime.now()
                
                if isinstance(last_seen, str):
                    last_seen = datetime.strptime(last_seen, '%Y-%m-%d %H:%M:%S')
                
                minutes_ago = (now - last_seen).total_seconds() / 60
                
                # Determinar status
                if minutes_ago <= 5:
                    status = 'online'
                    status_color = 'success'
                elif minutes_ago <= 30:
                    status = 'warning'
                    status_color = 'warning'
                else:
                    status = 'offline'
                    status_color = 'danger'
                
                devices.append({
                    'device_id': row[0],
                    'device_name': row[1], 
                    'location': row[2],
                    'device_type': 'Motion Sensor',
                    'motion_detected': row[3],
                    'rssi': row[4] if row[4] else 0,
                    'battery_level': f"{row[5]:.1f}%" if row[5] else 'N/A',
                    'last_seen': row[6].strftime('%Y-%m-%d %H:%M:%S') if isinstance(row[6], datetime) else row[6],
                    'events_today': row[7],
                    'status': status,
                    'status_color': status_color,
                    'minutes_ago': int(minutes_ago)
                })
            
            return devices
            
        except Error as e:
            print(f"❌ Erro ao obter status dos dispositivos de movimento: {e}")
            return []
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def get_recent_events(self, limit=50):
        """Obter eventos recentes"""
        conn = self.get_db_connection()
        if not conn:
            return []
        
        try:
            cursor = conn.cursor()
            # Unir eventos de movimento e sensores
            cursor.execute(f"""
                (SELECT 
                    device_id,
                    device_name,
                    location,
                    'Motion' as event_type,
                    CASE WHEN motion_detected THEN 'Movimento detectado' ELSE 'Sem movimento' END as event_description,
                    timestamp_received,
                    unix_timestamp,
                    CASE WHEN motion_detected THEN 'danger' ELSE 'info' END as event_class
                FROM {self.motion_table}
                WHERE timestamp_received >= DATE_SUB(NOW(), INTERVAL 7 DAY))
                
                UNION ALL
                
                (SELECT 
                    device_id,
                    device_name,
                    location,
                    'Sensor' as event_type,
                    CONCAT('T:', COALESCE(temperature, 0), '°C H:', COALESCE(humidity, 0), '%') as event_description,
                    timestamp_received,
                    UNIX_TIMESTAMP(timestamp_received) * 1000 as unix_timestamp,
                    'success' as event_class
                FROM {self.sensors_table}
                WHERE timestamp_received >= DATE_SUB(NOW(), INTERVAL 7 DAY))
                
                ORDER BY unix_timestamp DESC
                LIMIT %s
            """, (limit,))
            
            events = []
            for row in cursor.fetchall():
                timestamp = row[5]
                if isinstance(timestamp, str):
                    timestamp = datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S')
                
                events.append({
                    'device_id': row[0],
                    'device_name': row[1],
                    'location': row[2],
                    'event_type': row[3],
                    'event_description': row[4],
                    'timestamp': timestamp.strftime('%d/%m/%Y %H:%M:%S'),
                    'unix_timestamp': row[6],
                    'event_class': row[7]
                })
            
            return events
            
        except Error as e:
            print(f"❌ Erro ao obter eventos: {e}")
            return []
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def get_dht11_sensors_data(self):
        """Obter dados dos sensores DHT11"""
        conn = self.get_db_connection()
        if not conn:
            return []
        
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT 
                    device_id,
                    device_name,
                    location,
                    temperature,
                    humidity,
                    rssi,
                    timestamp_received,
                    (
                        SELECT COUNT(*) 
                        FROM {self.sensors_table} t2 
                        WHERE t2.device_id = t1.device_id
                        AND DATE(t2.timestamp_received) = CURDATE()
                    ) as readings_today
                FROM {self.sensors_table} t1
                WHERE t1.timestamp_received = (
                    SELECT MAX(timestamp_received) 
                    FROM {self.sensors_table} t3 
                    WHERE t3.device_id = t1.device_id
                )
                ORDER BY t1.location, t1.device_name
            """)
            
            sensors = []
            for row in cursor.fetchall():
                # Verificar status baseado na última leitura
                last_reading = row[6]  # timestamp_received
                if isinstance(last_reading, str):
                    last_reading = datetime.strptime(last_reading, '%Y-%m-%d %H:%M:%S')
                
                now = datetime.now()
                minutes_ago = (now - last_reading).total_seconds() / 60
                
                # Determinar status
                if minutes_ago <= 5:
                    status = 'online'
                    status_color = 'success'
                elif minutes_ago <= 30:
                    status = 'warning'
                    status_color = 'warning'
                else:
                    status = 'offline'
                    status_color = 'danger'
                
                # Verificar valores null e tratar alertas
                temperature = row[3] if row[3] is not None else 0
                humidity = row[4] if row[4] is not None else 0
                
                temp_alert = self._check_temperature_alert(temperature) if row[3] is not None else None
                humid_alert = self._check_humidity_alert(humidity) if row[4] is not None else None
                
                sensors.append({
                    'device_id': row[0],
                    'device_name': row[1],
                    'device_type': 'DHT11 Sensor',
                    'location': row[2],
                    'temperature': round(float(temperature), 1) if row[3] is not None else '--',
                    'humidity': round(float(humidity), 1) if row[4] is not None else '--',
                    'rssi': row[5] if row[5] is not None else 0,
                    'last_reading': last_reading.strftime('%Y-%m-%d %H:%M:%S'),
                    'readings_today': row[7],
                    'status': status,
                    'status_color': status_color,
                    'minutes_ago': int(minutes_ago),
                    'temp_alert': temp_alert,
                    'humid_alert': humid_alert,
                    'has_temperature': row[3] is not None,
                    'has_humidity': row[4] is not None
                })
            
            return sensors
            
        except Error as e:
            print(f"❌ Erro ao obter dados dos sensores DHT11: {e}")
            return []
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def _check_temperature_alert(self, temperature):
        """Verificar alertas de temperatura"""
        thresholds = self.alert_thresholds['temperature']
        if temperature < thresholds['min']:
            return {'type': 'low', 'message': f'Temperatura baixa: {temperature}°C'}
        elif temperature > thresholds['max']:
            return {'type': 'high', 'message': f'Temperatura alta: {temperature}°C'}
        return None

    def _check_humidity_alert(self, humidity):
        """Verificar alertas de umidade"""
        thresholds = self.alert_thresholds['humidity']
        if humidity < thresholds['min']:
            return {'type': 'low', 'message': f'Umidade baixa: {humidity}%'}
        elif humidity > thresholds['max']:
            return {'type': 'high', 'message': f'Umidade alta: {humidity}%'}
        return None

# Instanciar dashboard
dashboard = MySQLHomeGuardDashboard()

# Rotas Flask (idênticas ao original)
@app.route('/api/resolve-alert', methods=['POST'])
def api_resolve_alert():
    """API para resolver alertas"""
    try:
        data = request.get_json()
        device_id = data.get('device_id')
        alert_type = data.get('alert_type')
        
        # Atualizar alertas como resolvidos
        conn = dashboard.get_db_connection()
        if not conn:
            return jsonify({'success': False, 'error': 'Erro de conexão com banco'}), 500
        
        cursor = conn.cursor()
        cursor.execute(f"""
            UPDATE {dashboard.alerts_table}
            SET is_active = 0, timestamp_resolved = %s
            WHERE device_id = %s AND alert_type = %s AND is_active = 1
        """, (datetime.now().strftime('%Y-%m-%d %H:%M:%S'), device_id, alert_type))
        
        conn.commit()
        
        return jsonify({'success': True})
        
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 400
    finally:
        if conn.is_connected():
            cursor.close()
            conn.close()

@app.route('/')
def index():
    """Página principal"""
    stats = dashboard.get_device_statistics()
    devices = dashboard.get_device_status()
    current_time = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    return render_template('index.html', stats=stats, devices=devices, current_time=current_time)

@app.route('/events')
def events():
    """Página de eventos"""
    limit = int(request.args.get('limit', 50))
    events = dashboard.get_recent_events(limit)
    current_time = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    return render_template('events.html', events=events, limit=limit, current_time=current_time)

@app.route('/relays')
def relays():
    """Página de controle de relés"""
    # Obter configuração dos relés com status atual do MQTT
    relays_config = mqtt_controller.get_relays_config_with_status()
    current_time = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    return render_template('relays.html', relays=relays_config, current_time=current_time)

@app.route('/api/stats')
def api_stats():
    """API para estatísticas"""
    return jsonify(dashboard.get_device_statistics())

@app.route('/api/devices')
def api_devices():
    """API para status dos dispositivos"""
    return jsonify(dashboard.get_device_status())

@app.route('/api/events')
def api_events():
    """API para eventos"""
    limit = int(request.args.get('limit', 50))
    return jsonify(dashboard.get_recent_events(limit))

@app.route('/api/relay/<relay_id>/<action>')
def api_relay_control(relay_id, action):
    """API para controle de relés"""
    # Usar controlador MQTT real
    result = mqtt_controller.send_command(relay_id, action)
    
    if result['success']:
        return jsonify(result)
    else:
        return jsonify(result), 400

@app.route('/api/relays')
def api_relays_status():
    """API para status dos relés"""
    return jsonify(mqtt_controller.get_relays_config_with_status())

if __name__ == '__main__':
    # Criar diretório de templates se não existir
    os.makedirs('templates', exist_ok=True)
    
    print("🚀 HomeGuard Dashboard Flask + MySQL")
    print("====================================")
    
    # Verificar conexão MySQL
    test_conn = dashboard.get_db_connection()
    if test_conn:
        print("✅ MySQL conectado com sucesso")
        test_conn.close()
    else:
        print("❌ Falha na conexão com MySQL - verifique configuração")
        sys.exit(1)
    
    # Inicializar MQTT
    print("🔌 Conectando ao MQTT...")
    if init_mqtt():
        print("✅ MQTT conectado com sucesso")
    else:
        print("⚠️  Continuando sem MQTT (modo somente leitura)")
    
    print("Servidor iniciando em http://0.0.0.0:5000")
    print("Pressione Ctrl+C para parar")
    
    # Executar servidor
    try:
        app.run(host='0.0.0.0', port=5000, debug=True)
    finally:
        # Desconectar MQTT ao encerrar
        print("🔌 Desconectando MQTT...")
        mqtt_controller.disconnect()
