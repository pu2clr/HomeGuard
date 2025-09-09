#!/usr/bin/env python3
"""
HomeGuard Dashboard - Painéis de Monitoramento
Sistema de painéis para visualizar dados dos sensores via views do banco
"""

from flask import Flask, render_template, jsonify, request
import sqlite3
import json
import os
from datetime import datetime, timedelta
from collections import defaultdict

# Configuração
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DB_PATH = os.path.join(PROJECT_ROOT, 'db', 'homeguard.db')

app = Flask(__name__)

class DatabaseManager:
    @staticmethod
    def get_connection():
        return sqlite3.connect(DB_PATH)
    
    @staticmethod
    def execute_query(query, params=None):
        """Execute query and return results"""
        conn = DatabaseManager.get_connection()
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        if params:
            cursor.execute(query, params)
        else:
            cursor.execute(query)
        
        results = cursor.fetchall()
        conn.close()
        return results

# ================ ROTAS PRINCIPAIS ================

@app.route('/')
def dashboard():
    """Dashboard principal com resumo de todos os sensores"""
    return render_template('dashboard.html')

@app.route('/temperature')
def temperature_panel():
    """Painel de temperatura"""
    return render_template('temperature_panel.html')

@app.route('/humidity')
def humidity_panel():
    """Painel de umidade"""
    return render_template('humidity_panel.html')

@app.route('/motion')
def motion_panel():
    """Painel de movimento"""
    return render_template('motion_panel.html')

@app.route('/relay')
def relay_panel():
    """Painel de controle de relés"""
    return render_template('relay_panel.html')

# ================ APIs DE DADOS ================

@app.route('/api/temperature/data')
def api_temperature_data():
    """API para dados de temperatura usando view"""
    limit = request.args.get('limit', 50, type=int)
    hours = request.args.get('hours', 24, type=int)
    
    query = f"""
        SELECT * FROM vw_temperature_activity 
        WHERE created_at >= datetime('now', '-{hours} hours')
        ORDER BY created_at DESC 
        LIMIT {limit}
    """
    
    results = DatabaseManager.execute_query(query)
    
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
    
    return jsonify(data)

@app.route('/api/humidity/data')
def api_humidity_data():
    """API para dados de umidade usando view"""
    limit = request.args.get('limit', 50, type=int)
    hours = request.args.get('hours', 24, type=int)
    
    query = f"""
        SELECT * FROM vw_humidity_activity 
        WHERE created_at >= datetime('now', '-{hours} hours')
        ORDER BY created_at DESC 
        LIMIT {limit}
    """
    
    results = DatabaseManager.execute_query(query)
    
    data = []
    for row in results:
        data.append({
            'created_at': row['created_at'],
            'device_id': row['device_id'],
            'name': row['name'],
            'location': row['location'],
            'sensor_type': row['sensor_type'],
            'humidity': row['humidity'],  # Agora usando o campo correto
            'unit': row['unit'],
            'rssi': row['rssi'],
            'uptime': row['uptime']
        })
    
    return jsonify(data)

@app.route('/api/motion/data')
def api_motion_data():
    """API para dados de movimento usando view"""
    limit = request.args.get('limit', 50, type=int)
    hours = request.args.get('hours', 24, type=int)
    
    query = f"""
        SELECT * FROM vw_motion_activity 
        WHERE created_at >= datetime('now', '-{hours} hours')
        ORDER BY created_at DESC 
        LIMIT {limit}
    """
    
    results = DatabaseManager.execute_query(query)
    
    data = []
    for row in results:
        data.append({
            'created_at': row['created_at'],
            'device_id': row['device_id'],
            'name': row['name'],
            'location': row['location']
        })
    
    return jsonify(data)

@app.route('/api/relay/data')
def api_relay_data():
    """API para dados de relés usando view"""
    limit = request.args.get('limit', 50, type=int)
    hours = request.args.get('hours', 24, type=int)
    
    query = f"""
        SELECT * FROM vw_relay_activity 
        WHERE created_at >= datetime('now', '-{hours} hours')
        ORDER BY created_at DESC 
        LIMIT {limit}
    """
    
    results = DatabaseManager.execute_query(query)
    
    data = []
    for row in results:
        data.append({
            'created_at': row['created_at'],
            'topic': row['topic'],
            'message': row['message']
        })
    
    return jsonify(data)

# ================ APIs DE ESTATÍSTICAS ================

@app.route('/api/temperature/stats')
def api_temperature_stats():
    """Estatísticas de temperatura por dispositivo"""
    hours = request.args.get('hours', 24, type=int)
    
    query = f"""
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
        WHERE created_at >= datetime('now', '-{hours} hours')
        GROUP BY device_id
        ORDER BY last_reading DESC
    """
    
    results = DatabaseManager.execute_query(query)
    
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
    
    return jsonify(stats)

@app.route('/api/humidity/stats')
def api_humidity_stats():
    """Estatísticas de umidade por dispositivo"""
    hours = request.args.get('hours', 24, type=int)
    
    query = f"""
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
        WHERE created_at >= datetime('now', '-{hours} hours')
        GROUP BY device_id
        ORDER BY last_reading DESC
    """
    
    results = DatabaseManager.execute_query(query)
    
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
    
    return jsonify(stats)

@app.route('/api/motion/stats')
def api_motion_stats():
    """Estatísticas de movimento por dispositivo"""
    hours = request.args.get('hours', 24, type=int)
    
    query = f"""
        SELECT 
            device_id,
            location,
            COUNT(*) as total_detections,
            MAX(created_at) as last_detection,
            MIN(created_at) as first_detection
        FROM vw_motion_activity 
        WHERE created_at >= datetime('now', '-{hours} hours')
        GROUP BY device_id
        ORDER BY total_detections DESC
    """
    
    results = DatabaseManager.execute_query(query)
    
    stats = []
    for row in results:
        stats.append({
            'device_id': row['device_id'],
            'location': row['location'],
            'total_detections': row['total_detections'],
            'last_detection': row['last_detection'],
            'first_detection': row['first_detection']
        })
    
    return jsonify(stats)

@app.route('/api/dashboard/summary')
def api_dashboard_summary():
    """Resumo geral para o dashboard"""
    hours = request.args.get('hours', 24, type=int)
    
    # Contar dispositivos ativos por tipo
    queries = {
        'temperature': f"SELECT COUNT(DISTINCT device_id) as count FROM vw_temperature_activity WHERE created_at >= datetime('now', '-{hours} hours')",
        'humidity': f"SELECT COUNT(DISTINCT device_id) as count FROM vw_humidity_activity WHERE created_at >= datetime('now', '-{hours} hours')",
        'motion': f"SELECT COUNT(DISTINCT device_id) as count FROM vw_motion_activity WHERE created_at >= datetime('now', '-{hours} hours')",
        'relay': f"SELECT COUNT(DISTINCT topic) as count FROM vw_relay_activity WHERE created_at >= datetime('now', '-{hours} hours')"
    }
    
    summary = {}
    for sensor_type, query in queries.items():
        result = DatabaseManager.execute_query(query)
        summary[f'{sensor_type}_devices'] = result[0]['count'] if result else 0
    
    # Total de eventos nas últimas horas
    total_events_query = f"""
        SELECT COUNT(*) as total FROM activity 
        WHERE created_at >= datetime('now', '-{hours} hours')
    """
    result = DatabaseManager.execute_query(total_events_query)
    summary['total_events'] = result[0]['total'] if result else 0
    
    return jsonify(summary)

if __name__ == '__main__':
    # Criar pasta templates se não existir
    templates_dir = os.path.join(SCRIPT_DIR, 'templates')
    if not os.path.exists(templates_dir):
        os.makedirs(templates_dir)
    
    app.run(host='0.0.0.0', port=5000, debug=True)
