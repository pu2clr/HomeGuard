#!/usr/bin/env python3

"""
============================================
HomeGuard Dashboard - Versão Flask
Interface web leve usando Flask (sem Streamlit)
============================================
"""

from flask import Flask, render_template, jsonify, request, redirect, url_for
import sqlite3
import json
from datetime import datetime, timedelta
import os
import sys
from flask_mqtt_controller import mqtt_controller, init_mqtt
from mqtt_relay_config import RELAYS_CONFIG

app = Flask(__name__)

class FlaskHomeGuardDashboard:
    def __init__(self):
        self.db_path = '../db/homeguard.db'
        self.motion_table = 'motion_sensors'
        self.sensors_table = 'dht11_sensors'  # Nova tabela para sensores DHT11
        self.alerts_table = 'sensor_alerts'   # Nova tabela para alertas
        
        # Configurações de alertas
        self.alert_thresholds = {
            'temperature': {'min': 10, 'max': 35},  # °C
            'humidity': {'min': 30, 'max': 80}      # %
        }
        
        # Inicializar banco de dados
        self._init_database()

    def _init_database(self):
        """Inicializar tabelas do banco de dados"""
        conn = self.get_db_connection()
        if not conn:
            return
            
        try:
            cursor = conn.cursor()
            
            # Verificar se a tabela já existe
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='dht11_sensors'")
            table_exists = cursor.fetchone() is not None
            
            if table_exists:
                # Alterar tabela existente para permitir NULL em temperature e humidity
                try:
                    # Verificar se as colunas já permitem NULL
                    cursor.execute("PRAGMA table_info(dht11_sensors)")
                    columns = cursor.fetchall()
                    
                    # Recriar tabela se necessário
                    cursor.execute("DROP TABLE IF EXISTS dht11_sensors_backup")
                    cursor.execute("""
                        CREATE TABLE dht11_sensors_backup AS 
                        SELECT * FROM dht11_sensors
                    """)
                    
                    cursor.execute("DROP TABLE dht11_sensors")
                    
                except Exception as e:
                    print(f"Aviso: {e}")
            
            # Criar tabela para sensores DHT11 (permitindo NULL em temperature e humidity)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS dht11_sensors (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT NOT NULL,
                    device_name TEXT NOT NULL,
                    location TEXT NOT NULL,
                    sensor_type TEXT NOT NULL,
                    temperature REAL,
                    humidity REAL,
                    rssi INTEGER,
                    uptime INTEGER,
                    timestamp_received TEXT NOT NULL,
                    raw_payload TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Restaurar dados se havia backup
            if table_exists:
                try:
                    cursor.execute("""
                        INSERT INTO dht11_sensors 
                        SELECT * FROM dht11_sensors_backup
                    """)
                    cursor.execute("DROP TABLE dht11_sensors_backup")
                    print("✅ Dados restaurados após atualização da tabela")
                except Exception as e:
                    print(f"Aviso ao restaurar dados: {e}")
            
            # Criar tabela para alertas
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sensor_alerts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT NOT NULL,
                    device_name TEXT NOT NULL,
                    location TEXT NOT NULL,
                    alert_type TEXT NOT NULL,
                    sensor_value REAL NOT NULL,
                    threshold_value REAL NOT NULL,
                    message TEXT NOT NULL,
                    severity TEXT NOT NULL,
                    is_active BOOLEAN DEFAULT 1,
                    timestamp_created TEXT NOT NULL,
                    timestamp_resolved TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Criar índices
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_dht11_device ON dht11_sensors(device_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_dht11_timestamp ON dht11_sensors(timestamp_received)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_alerts_device ON sensor_alerts(device_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_alerts_active ON sensor_alerts(is_active)")
            
            conn.commit()
            print("✅ Banco de dados inicializado com suporte a sensores DHT11")
            
        except Exception as e:
            print(f"❌ Erro ao inicializar banco de dados: {e}")
        finally:
            conn.close()

    def get_db_connection(self):
        """Obter conexão com banco de dados"""
        try:
            return sqlite3.connect(self.db_path)
        except Exception as e:
            print(f"Erro ao conectar ao banco: {e}")
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
            stats['total_motion_devices'] = cursor.fetchone()[0]
            
            # Total de sensores DHT11
            cursor.execute(f"SELECT COUNT(DISTINCT device_id) FROM {self.sensors_table}")
            stats['total_dht11_devices'] = cursor.fetchone()[0]
            
            stats['total_devices'] = stats['total_motion_devices'] + stats['total_dht11_devices']
            
            # Total de eventos hoje
            cursor.execute(f"""
                SELECT COUNT(*) FROM {self.motion_table}
                WHERE date(timestamp_received) = date('now')
            """)
            motion_events = cursor.fetchone()[0]
            
            cursor.execute(f"""
                SELECT COUNT(*) FROM {self.sensors_table}
                WHERE date(timestamp_received) = date('now')
            """)
            sensor_events = cursor.fetchone()[0]
            
            stats['events_today'] = motion_events + sensor_events
            stats['motion_events_today'] = motion_events
            stats['sensor_readings_today'] = sensor_events
            
            # Dispositivos ativos nas últimas 24h
            cursor.execute(f"""
                SELECT COUNT(DISTINCT device_id) FROM {self.motion_table}
                WHERE datetime(timestamp_received) >= datetime('now', '-1 day')
            """)
            motion_active = cursor.fetchone()[0]
            
            cursor.execute(f"""
                SELECT COUNT(DISTINCT device_id) FROM {self.sensors_table}
                WHERE datetime(timestamp_received) >= datetime('now', '-1 day')
            """)
            sensors_active = cursor.fetchone()[0]
            
            stats['active_devices_24h'] = motion_active + sensors_active
            
            # Último evento (de movimento)
            cursor.execute(f"""
                SELECT timestamp_received FROM {self.motion_table}
                ORDER BY unix_timestamp DESC LIMIT 1
            """)
            result = cursor.fetchone()
            stats['last_event'] = result[0] if result else 'Nenhum'
            
            return stats
            
        except Exception as e:
            print(f"Erro ao obter estatísticas: {e}")
            return {}
        finally:
            conn.close()

    def get_device_status(self):
        """Obter status atual de todos os dispositivos de movimento"""
        conn = self.get_db_connection()
        if not conn:
            return []
        
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT 
                    device_id,
                    location,
                    sensor,
                    MAX(timestamp_received) as last_seen,
                    COUNT(*) as total_events,
                    (
                        SELECT event 
                        FROM {self.motion_table} t2 
                        WHERE t2.device_id = t1.device_id 
                        ORDER BY unix_timestamp DESC 
                        LIMIT 1
                    ) as last_event,
                    (
                        SELECT rssi 
                        FROM {self.motion_table} t2 
                        WHERE t2.device_id = t1.device_id 
                        ORDER BY unix_timestamp DESC 
                        LIMIT 1
                    ) as last_rssi
                FROM {self.motion_table} t1
                GROUP BY device_id, location, sensor
                ORDER BY MAX(unix_timestamp) DESC
            """)
            
            devices = []
            for row in cursor.fetchall():
                # Status online/offline (offline se > 10 minutos)
                try:
                    last_seen = datetime.fromisoformat(row[3])
                    now = datetime.now()
                    minutes_offline = (now - last_seen).total_seconds() / 60
                except:
                    minutes_offline = 999
                
                device = {
                    'device_id': row[0],
                    'location': row[1] or 'Não definido',
                    'sensor_type': row[2],
                    'last_seen': row[3],
                    'last_event': row[5],
                    'total_events': row[4],
                    'rssi': row[6] or 0,
                    'status': 'online' if minutes_offline < 10 else 'offline',
                    'minutes_offline': int(minutes_offline)
                }
                devices.append(device)
            
            return devices
            
        except Exception as e:
            print(f"Erro ao obter status dos dispositivos: {e}")
            return []
        finally:
            conn.close()

    def get_recent_events(self, limit=50):
        """Obter eventos recentes de movimento"""
        conn = self.get_db_connection()
        if not conn:
            return []
        
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT timestamp_received, device_id, event, location, rssi
                FROM {self.motion_table}
                ORDER BY unix_timestamp DESC
                LIMIT {limit}
            """)
            
            events = []
            for row in cursor.fetchall():
                events.append({
                    'timestamp': row[0],
                    'device_id': row[1], 
                    'event': row[2],
                    'location': row[3] or 'N/A',
                    'rssi': row[4] or 0
                })
            
            return events
            
        except Exception as e:
            print(f"Erro ao obter eventos: {e}")
            return []
        finally:
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
                        AND date(t2.timestamp_received) = date('now')
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
                last_reading = datetime.fromisoformat(row[6].replace('Z', '+00:00')) if 'Z' in row[6] else datetime.strptime(row[6], '%Y-%m-%d %H:%M:%S')
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
                    'location': row[2],
                    'temperature': round(temperature, 1) if row[3] is not None else '--',
                    'humidity': round(humidity, 1) if row[4] is not None else '--',
                    'rssi': row[5] if row[5] is not None else 0,
                    'last_reading': row[6],
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
            
        except Exception as e:
            print(f"Erro ao obter dados dos sensores DHT11: {e}")
            return []
        finally:
            conn.close()

    def get_sensor_history(self, device_id, hours=24):
        """Obter histórico de um sensor específico"""
        conn = self.get_db_connection()
        if not conn:
            return []
        
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT 
                    temperature,
                    humidity,
                    timestamp_received
                FROM {self.sensors_table}
                WHERE device_id = ?
                AND datetime(timestamp_received) >= datetime('now', '-{hours} hours')
                ORDER BY timestamp_received ASC
            """, (device_id,))
            
            history = []
            for row in cursor.fetchall():
                # Tratar valores NULL adequadamente
                temp = row[0] if row[0] is not None else None
                humid = row[1] if row[1] is not None else None
                
                history.append({
                    'temperature': round(temp, 1) if temp is not None else None,
                    'humidity': round(humid, 1) if humid is not None else None,
                    'timestamp': row[2],
                    'has_temperature': temp is not None,
                    'has_humidity': humid is not None
                })
            
            print(f"📊 Histórico obtido para {device_id}: {len(history)} registros (últimas {hours}h)")
            return history
            
        except Exception as e:
            print(f"Erro ao obter histórico do sensor {device_id}: {e}")
            return []
        finally:
            conn.close()

    def _check_temperature_alert(self, temperature):
        """Verificar alerta de temperatura"""
        thresholds = self.alert_thresholds['temperature']
        if temperature < thresholds['min']:
            return {'type': 'low', 'message': f'Temperatura baixa: {temperature}°C'}
        elif temperature > thresholds['max']:
            return {'type': 'high', 'message': f'Temperatura alta: {temperature}°C'}
        return None

    def _check_humidity_alert(self, humidity):
        """Verificar alerta de umidade"""
        thresholds = self.alert_thresholds['humidity']
        if humidity < thresholds['min']:
            return {'type': 'low', 'message': f'Umidade baixa: {humidity}%'}
        elif humidity > thresholds['max']:
            return {'type': 'high', 'message': f'Umidade alta: {humidity}%'}
        return None

    def save_sensor_alert(self, device_id, device_name, location, alert_type, sensor_value, threshold_value, message, severity='warning'):
        """Salvar alerta no banco de dados"""
        conn = self.get_db_connection()
        if not conn:
            return False
        
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                INSERT INTO {self.alerts_table}
                (device_id, device_name, location, alert_type, sensor_value, threshold_value, message, severity, timestamp_created)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (device_id, device_name, location, alert_type, sensor_value, threshold_value, message, severity, datetime.now().strftime('%Y-%m-%d %H:%M:%S')))
            
            conn.commit()
            return True
            
        except Exception as e:
            print(f"Erro ao salvar alerta: {e}")
            return False
        finally:
            conn.close()

    def get_active_alerts(self):
        """Obter alertas ativos"""
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
                    alert_type,
                    sensor_value,
                    message,
                    severity,
                    timestamp_created
                FROM {self.alerts_table}
                WHERE is_active = 1
                ORDER BY timestamp_created DESC
                LIMIT 20
            """)
            
            alerts = []
            for row in cursor.fetchall():
                alerts.append({
                    'device_id': row[0],
                    'device_name': row[1],
                    'location': row[2],
                    'alert_type': row[3],
                    'sensor_value': row[4],
                    'message': row[5],
                    'severity': row[6],
                    'timestamp': row[7]
                })
            
            return alerts
            
        except Exception as e:
            print(f"Erro ao obter alertas ativos: {e}")
            return []
        finally:
            conn.close()

    def process_sensor_data(self, device_id, device_name, location, temperature, humidity, rssi=None, raw_payload=None):
        """Processar e salvar dados de sensor DHT11"""
        conn = self.get_db_connection()
        if not conn:
            return False
        
        try:
            cursor = conn.cursor()
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            # Inserir dados do sensor
            cursor.execute(f"""
                INSERT INTO {self.sensors_table}
                (device_id, device_name, location, sensor_type, temperature, humidity, rssi, timestamp_received, raw_payload)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (device_id, device_name, location, 'DHT11', temperature, humidity, rssi, timestamp, raw_payload))
            
            # Verificar e salvar alertas
            temp_alert = self._check_temperature_alert(temperature)
            if temp_alert:
                self.save_sensor_alert(device_id, device_name, location, f"temperature_{temp_alert['type']}", 
                                     temperature, self.alert_thresholds['temperature']['min' if temp_alert['type'] == 'low' else 'max'],
                                     temp_alert['message'], 'warning' if temp_alert['type'] == 'low' else 'danger')
            
            humid_alert = self._check_humidity_alert(humidity)
            if humid_alert:
                self.save_sensor_alert(device_id, device_name, location, f"humidity_{humid_alert['type']}", 
                                     humidity, self.alert_thresholds['humidity']['min' if humid_alert['type'] == 'low' else 'max'],
                                     humid_alert['message'], 'warning' if humid_alert['type'] == 'low' else 'danger')
            
            conn.commit()
            return True
            
        except Exception as e:
            print(f"Erro ao processar dados do sensor: {e}")
            return False
        finally:
            conn.close()

    def process_dht11_mqtt_data(self, device_id, device_name, location, temperature=None, humidity=None, rssi=None, raw_payload=None):
        """Processar dados MQTT dos sensores DHT11 (tópicos separados)"""
        conn = self.get_db_connection()
        if not conn:
            return False
        
        try:
            cursor = conn.cursor()
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            # Tentar obter leitura existente recente (últimos 30 segundos) para combinar temperatura e umidade
            cursor.execute(f"""
                SELECT id, temperature, humidity FROM {self.sensors_table}
                WHERE device_id = ? 
                AND datetime(timestamp_received) >= datetime('now', '-30 seconds')
                ORDER BY timestamp_received DESC LIMIT 1
            """, (device_id,))
            
            recent_record = cursor.fetchone()
            
            if recent_record:
                # Atualizar registro existente
                record_id, existing_temp, existing_humid = recent_record
                
                new_temp = temperature if temperature is not None else existing_temp
                new_humid = humidity if humidity is not None else existing_humid
                
                cursor.execute(f"""
                    UPDATE {self.sensors_table} 
                    SET temperature = ?, humidity = ?, rssi = ?, timestamp_received = ?, raw_payload = ?
                    WHERE id = ?
                """, (new_temp, new_humid, rssi, timestamp, raw_payload, record_id))
                
                print(f"🔄 DHT11 atualizado: {device_id} - T:{new_temp}°C H:{new_humid}%")
                
            else:
                # Criar novo registro
                cursor.execute(f"""
                    INSERT INTO {self.sensors_table}
                    (device_id, device_name, location, sensor_type, temperature, humidity, rssi, timestamp_received, raw_payload)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (device_id, device_name, location, 'DHT11', temperature, humidity, rssi, timestamp, raw_payload))
                
                print(f"➕ DHT11 novo: {device_id} - T:{temperature}°C H:{humidity}%")
            
            # Verificar alertas apenas se temos dados completos
            if temperature is not None:
                temp_alert = self._check_temperature_alert(temperature)
                if temp_alert:
                    self.save_sensor_alert(device_id, device_name, location, f"temperature_{temp_alert['type']}", 
                                         temperature, self.alert_thresholds['temperature']['min' if temp_alert['type'] == 'low' else 'max'],
                                         temp_alert['message'], 'warning' if temp_alert['type'] == 'low' else 'danger')
            
            if humidity is not None:
                humid_alert = self._check_humidity_alert(humidity)
                if humid_alert:
                    self.save_sensor_alert(device_id, device_name, location, f"humidity_{humid_alert['type']}", 
                                         humidity, self.alert_thresholds['humidity']['min' if humid_alert['type'] == 'low' else 'max'],
                                         humid_alert['message'], 'warning' if humid_alert['type'] == 'low' else 'danger')
            
            conn.commit()
            return True
            
        except Exception as e:
            print(f"❌ Erro ao processar dados MQTT DHT11: {e}")
            return False
        finally:
            conn.close()

# Instância global do dashboard
dashboard = FlaskHomeGuardDashboard()

@app.route('/sensors')
@app.route('/sensor')  # Adicionar rota alternativa sem barra final
def sensors():
    """Página de sensores DHT11"""
    sensors = dashboard.get_dht11_sensors_data()
    alerts = dashboard.get_active_alerts()
    current_time = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    return render_template('sensors.html', sensors=sensors, alerts=alerts, current_time=current_time)

@app.route('/sensor/')
def sensor_redirect():
    """Redirecionar /sensor/ para /sensors"""
    return redirect(url_for('sensors'))

@app.route('/sensor/<device_id>')
def sensor_detail(device_id):
    """Página de detalhes de um sensor específico"""
    hours = int(request.args.get('hours', 24))
    history = dashboard.get_sensor_history(device_id, hours)
    current_time = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    return render_template('sensor_detail.html', device_id=device_id, history=history, hours=hours, current_time=current_time)

@app.route('/alerts')
def alerts_page():
    """Página de alertas"""
    alerts = dashboard.get_active_alerts()
    current_time = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    return render_template('alerts.html', alerts=alerts, current_time=current_time)

@app.route('/api/sensors')
def api_sensors():
    """API para dados dos sensores DHT11"""
    print(f"🔌 API /api/sensors chamada - {datetime.now().strftime('%H:%M:%S')}")
    sensors_data = dashboard.get_dht11_sensors_data()
    print(f"   📊 Retornando {len(sensors_data)} sensores")
    for sensor in sensors_data:
        print(f"   📱 {sensor.get('device_id')}: T={sensor.get('temperature')}, H={sensor.get('humidity')}, Status={sensor.get('status')}")
    return jsonify(sensors_data)

@app.route('/api/sensor/<device_id>/history')
def api_sensor_history(device_id):
    """API para histórico de um sensor"""
    hours = int(request.args.get('hours', 24))
    print(f"📈 API /api/sensor/{device_id}/history chamada - {hours}h - {datetime.now().strftime('%H:%M:%S')}")
    history_data = dashboard.get_sensor_history(device_id, hours)
    print(f"   📊 Retornando {len(history_data)} registros históricos")
    return jsonify(history_data)

@app.route('/api/alerts')
def api_alerts():
    """API para alertas ativos"""
    return jsonify(dashboard.get_active_alerts())

@app.route('/api/process_sensor_data', methods=['POST'])
def api_process_sensor_data():
    """API para processar dados de sensores (MQTT callback)"""
    try:
        data = request.get_json()
        result = dashboard.process_sensor_data(
            device_id=data.get('device_id'),
            device_name=data.get('device_name'),
            location=data.get('location'),
            temperature=data.get('temperature'),
            humidity=data.get('humidity'),
            rssi=data.get('rssi'),
            raw_payload=json.dumps(data)
        )
        return jsonify({'success': result})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/resolve_alert', methods=['POST'])
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
            SET is_active = 0, timestamp_resolved = ?
            WHERE device_id = ? AND alert_type = ? AND is_active = 1
        """, (datetime.now().strftime('%Y-%m-%d %H:%M:%S'), device_id, alert_type))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 400

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
    
    print("🚀 HomeGuard Dashboard Flask")
    print("============================")
    
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
