#!/usr/bin/env python3
"""
HomeGuard Activity Monitor - SQLite Version
Monitora sensores de movimento e relés via MQTT e registra dados em SQLite
Inclui monitoramento de atividade de relés ESP01
"""
import os
import sqlite3
import json
import time
import argparse
from datetime import datetime, timedelta, timezone
import signal
import sys

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("❌ paho-mqtt não está instalado. Execute: pip install paho-mqtt")
    sys.exit(1)

# Configuração do banco de dados
DB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'db')
DB_PATH = os.path.join(DB_DIR, 'homeguard.db')
MOTION_TABLE = 'motion_sensors'
RELAY_TABLE = 'relay_activity'

# Configuração MQTT padrão
BROKER = '192.168.18.236'
PORT = 1883
USERNAME = 'homeguard'
PASSWORD = 'pu2clr123456'

# Tópicos MQTT para monitoramento
MOTION_TOPICS = [
    'home/motion_garagem/motion',
    'home/motion_area_servico/motion',
    'home/motion_varanda/motion',
    'home/motion_mezanino/motion',
    'home/motion_adhoc/motion'
]

RELAY_TOPICS = [
    'home/relay/ESP01_RELAY_001/status',
    'home/relay/ESP01_RELAY_001/command',
    'home/relay/ESP01_RELAY_002/status', 
    'home/relay/ESP01_RELAY_002/command',
    'home/relay/ESP01_RELAY_003/status',
    'home/relay/ESP01_RELAY_003/command'
]

ALL_TOPICS = MOTION_TOPICS + RELAY_TOPICS

# Fuso horário Brasil/Brasília (UTC-3)
BR_TZ = timezone(timedelta(hours=-3))

def init_db():
    """Inicializa o banco de dados e cria as tabelas se não existirem"""
    try:
        os.makedirs(DB_DIR, exist_ok=True)
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Criar tabela de sensores de movimento
        cursor.execute(f"""
            CREATE TABLE IF NOT EXISTS {MOTION_TABLE} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sensor TEXT NOT NULL,
                event TEXT NOT NULL,
                device_id TEXT,
                location TEXT,
                rssi INTEGER,
                count INTEGER,
                duration INTEGER,
                timestamp_device TEXT,
                unix_timestamp INTEGER,
                timestamp_received TEXT NOT NULL,
                raw_payload TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Criar tabela de atividade de relés
        cursor.execute(f"""
            CREATE TABLE IF NOT EXISTS {RELAY_TABLE} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_name TEXT NOT NULL,
                device_id TEXT NOT NULL,
                location TEXT NOT NULL,
                event TEXT NOT NULL,
                current_status TEXT NOT NULL,
                command_source TEXT,
                rssi INTEGER,
                uptime INTEGER,
                timestamp_received TEXT NOT NULL,
                raw_payload TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Criar índices para tabela motion_sensors
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_motion_sensor ON {MOTION_TABLE}(sensor)")
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_motion_event ON {MOTION_TABLE}(event)")
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_motion_timestamp ON {MOTION_TABLE}(timestamp_received)")
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_motion_device ON {MOTION_TABLE}(device_id)")
        
        # Criar índices para tabela relay_activity
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_relay_device ON {RELAY_TABLE}(device_id)")
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_relay_event ON {RELAY_TABLE}(event)")
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_relay_timestamp ON {RELAY_TABLE}(timestamp_received)")
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_relay_status ON {RELAY_TABLE}(current_status)")
        
        conn.commit()
        conn.close()
        print(f"✅ Banco de dados inicializado: {DB_PATH}")
        print(f"📊 Tabelas criadas: {MOTION_TABLE}, {RELAY_TABLE}")
        
    except Exception as e:
        print(f"❌ Erro ao inicializar banco de dados: {e}")
        sys.exit(1)

def insert_motion_data(sensor, event, device_id, location, rssi, count, duration, 
                      timestamp_device, unix_timestamp, raw_payload):
    """Insere dados de movimento no banco de dados"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        timestamp_received = datetime.now(BR_TZ).strftime('%Y-%m-%d %H:%M:%S')
        
        cursor.execute(f"""
            INSERT INTO {MOTION_TABLE} 
            (sensor, event, device_id, location, rssi, count, duration, 
             timestamp_device, unix_timestamp, timestamp_received, raw_payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (sensor, event, device_id, location, rssi, count, duration, 
              timestamp_device, unix_timestamp, timestamp_received, raw_payload))
        
        conn.commit()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ Erro ao inserir dados de movimento no banco: {e}")
        return False

def insert_relay_data(device_name, device_id, location, event, current_status, 
                     command_source, rssi, uptime, raw_payload):
    """Insere dados de atividade de relé no banco de dados"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        timestamp_received = datetime.now(BR_TZ).strftime('%Y-%m-%d %H:%M:%S')
        
        cursor.execute(f"""
            INSERT INTO {RELAY_TABLE} 
            (device_name, device_id, location, event, current_status, command_source,
             rssi, uptime, timestamp_received, raw_payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (device_name, device_id, location, event, current_status, command_source,
              rssi, uptime, timestamp_received, raw_payload))
        
        conn.commit()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ Erro ao inserir dados de relé no banco: {e}")
        return False

def on_connect(client, userdata, flags, rc):
    """Callback executado quando conecta ao broker MQTT"""
    if rc == 0:
        print(f"✅ Conectado ao broker MQTT: {BROKER}:{PORT}")
        print("📡 Subscrevendo aos tópicos:")
        
        for topic in ALL_TOPICS:
            client.subscribe(topic)
            print(f"   - {topic}")
        
        print(f"💾 Dados serão salvos em: {DB_PATH}")
        print("🏠 Monitor de sensores e relés ativo!")
        
    else:
        error_messages = {
            1: "Protocolo incorreto",
            2: "ID do cliente inválido", 
            3: "Servidor indisponível",
            4: "Usuário/senha incorretos",
            5: "Não autorizado"
        }
        error_msg = error_messages.get(rc, f"Erro desconhecido ({rc})")
        print(f"❌ Falha na conexão MQTT: {error_msg}")

def on_disconnect(client, userdata, rc):
    """Callback executado quando desconecta do broker MQTT"""
    if rc != 0:
        print("⚠️ Desconexão inesperada do broker MQTT")
    else:
        print("📡 Desconectado do broker MQTT")

def on_message(client, userdata, msg):
    """Callback executado quando recebe uma mensagem MQTT"""
    try:
        # Decodificar payload
        payload = msg.payload.decode('utf-8')
        topic = msg.topic
        topic_parts = topic.split('/')
        
        timestamp_now = datetime.now(BR_TZ).strftime('%H:%M:%S')
        
        # Verificar se é um tópico de movimento
        if 'motion' in topic and len(topic_parts) >= 2:
            process_motion_message(topic, topic_parts, payload, timestamp_now)
        
        # Verificar se é um tópico de relé
        elif 'relay' in topic and len(topic_parts) >= 4:
            process_relay_message(topic, topic_parts, payload, timestamp_now)
        
        else:
            print(f"⚠️ [{timestamp_now}] Tópico não reconhecido: {topic}")
        
    except Exception as e:
        print(f"❌ Erro ao processar mensagem: {e}")
        print(f"   Tópico: {msg.topic}")
        print(f"   Payload: {msg.payload.decode('utf-8', errors='ignore')}")

def process_motion_message(topic, topic_parts, payload, timestamp_now):
    """Processa mensagens de sensores de movimento"""
    try:
        # Extrair nome do sensor do tópico
        sensor = topic_parts[1].replace('motion_', '')
        
        # Parse JSON
        data = json.loads(payload)
        
        # Extrair dados da mensagem
        event = data.get('event', 'UNKNOWN')
        device_id = data.get('device_id', None)
        location = data.get('location', sensor)
        rssi = data.get('rssi', None)
        count = data.get('count', None)
        duration = data.get('duration', None)
        timestamp_device = data.get('timestamp', None)
        unix_timestamp = data.get('unix_timestamp', None)
        
        # Converter RSSI se for string
        if rssi and isinstance(rssi, str) and rssi.endswith('dBm'):
            try:
                rssi = int(rssi.replace('dBm', ''))
            except ValueError:
                rssi = None
        
        # Converter duration se for string
        if duration and isinstance(duration, str) and duration.endswith('s'):
            try:
                duration = int(duration.replace('s', ''))
            except ValueError:
                duration = None
        
        # Inserir no banco de dados
        success = insert_motion_data(
            sensor=sensor,
            event=event,
            device_id=device_id,
            location=location,
            rssi=rssi,
            count=count,
            duration=duration,
            timestamp_device=timestamp_device,
            unix_timestamp=unix_timestamp,
            raw_payload=payload
        )
        
        if success:
            print(f"[{timestamp_now}] 📊 MOTION {sensor.upper()}: {event} (ID: {device_id})")
            
            if event == "MOTION_DETECTED":
                print(f"               🚶 Movimento detectado em {location}")
            elif event == "MOTION_CLEARED":
                if duration:
                    print(f"               ✅ Movimento finalizado após {duration}s")
                else:
                    print(f"               ✅ Movimento finalizado")
        
    except json.JSONDecodeError:
        print(f"❌ Erro ao decodificar JSON do tópico de movimento {topic}: {payload}")
    except Exception as e:
        print(f"❌ Erro ao processar mensagem de movimento: {e}")

def process_relay_message(topic, topic_parts, payload, timestamp_now):
    """Processa mensagens de relés"""
    try:
        # topic format: home/relay/ESP01_RELAY_XXX/status ou /command
        device_id = topic_parts[2]  # ESP01_RELAY_001, ESP01_RELAY_002, etc
        message_type = topic_parts[3]  # status ou command
        
        # Determinar device name e location baseado no device_id
        device_mapping = {
            'ESP01_RELAY_001': {'name': 'Luz da Sala', 'location': 'Sala'},
            'ESP01_RELAY_002': {'name': 'Luz da Cozinha', 'location': 'Cozinha'},
            'ESP01_RELAY_003': {'name': 'Bomba d\'Água', 'location': 'Externa'}
        }
        
        device_info = device_mapping.get(device_id, {'name': device_id, 'location': 'Unknown'})
        device_name = device_info['name']
        location = device_info['location']
        
        # Processar diferentes tipos de mensagem
        if message_type == 'status':
            # Mensagem de status: payload é simples: "on" ou "off"
            current_status = payload.strip().upper()
            event = f"STATUS_REPORT"
            command_source = "DEVICE"
            rssi = None
            uptime = None
            
        elif message_type == 'command':
            # Mensagem de comando: payload é o comando enviado
            event = f"COMMAND_RECEIVED"
            current_status = payload.strip().upper()
            command_source = "EXTERNAL" 
            rssi = None
            uptime = None
            
        else:
            # Outros tipos de mensagem (como info)
            try:
                # Tentar parsear como JSON para mensagens info
                data = json.loads(payload)
                event = "INFO_REPORT"
                current_status = data.get('relay_state', 'UNKNOWN').upper()
                command_source = "DEVICE"
                rssi = data.get('rssi', None)
                uptime = data.get('uptime', None)
            except json.JSONDecodeError:
                # Se não for JSON, tratar como mensagem simples
                event = f"MESSAGE_{message_type.upper()}"
                current_status = payload.strip().upper()
                command_source = "DEVICE"
                rssi = None
                uptime = None
        
        # Inserir no banco de dados
        success = insert_relay_data(
            device_name=device_name,
            device_id=device_id,
            location=location,
            event=event,
            current_status=current_status,
            command_source=command_source,
            rssi=rssi,
            uptime=uptime,
            raw_payload=payload
        )
        
        if success:
            status_icon = "🟢" if current_status in ['ON', 'on'] else "🔴" if current_status in ['OFF', 'off'] else "⚪"
            
            print(f"[{timestamp_now}] 🔌 RELAY {device_name}: {event}")
            print(f"               {status_icon} Status: {current_status} | Local: {location}")
            
            if event == "COMMAND_RECEIVED":
                print(f"               📤 Comando recebido: {current_status}")
            elif event == "STATUS_REPORT":
                print(f"               📊 Relatório de status: {current_status}")
        
    except Exception as e:
        print(f"❌ Erro ao processar mensagem de relé: {e}")
        print(f"   Tópico: {topic}")
        print(f"   Payload: {payload}")

def signal_handler(signum, frame):
    """Handler para capturar Ctrl+C e encerrar graciosamente"""
    print("\n🛑 Encerrando monitor de atividades...")
    sys.exit(0)

def show_statistics():
    """Mostra estatísticas do banco de dados"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Estatísticas de sensores de movimento
        cursor.execute(f"SELECT COUNT(*) FROM {MOTION_TABLE}")
        motion_records = cursor.fetchone()[0]
        
        # Estatísticas de relés
        cursor.execute(f"SELECT COUNT(*) FROM {RELAY_TABLE}")
        relay_records = cursor.fetchone()[0]
        
        # Registros por sensor de movimento
        cursor.execute(f"""
            SELECT sensor, COUNT(*) 
            FROM {MOTION_TABLE} 
            GROUP BY sensor 
            ORDER BY COUNT(*) DESC
        """)
        motion_sensor_counts = cursor.fetchall()
        
        # Registros por relé
        cursor.execute(f"""
            SELECT device_name, COUNT(*) 
            FROM {RELAY_TABLE} 
            GROUP BY device_name 
            ORDER BY COUNT(*) DESC
        """)
        relay_counts = cursor.fetchall()
        
        # Eventos de movimento por sensor
        cursor.execute(f"""
            SELECT sensor, COUNT(*) 
            FROM {MOTION_TABLE} 
            WHERE event = 'MOTION_DETECTED'
            GROUP BY sensor 
            ORDER BY COUNT(*) DESC
        """)
        motion_detection_counts = cursor.fetchall()
        
        # Status atual dos relés
        cursor.execute(f"""
            SELECT device_name, current_status, MAX(timestamp_received) as last_update
            FROM {RELAY_TABLE} 
            WHERE event IN ('STATUS_REPORT', 'COMMAND_RECEIVED')
            GROUP BY device_name
            ORDER BY last_update DESC
        """)
        relay_status = cursor.fetchall()
        
        # Últimos registros de movimento
        cursor.execute(f"""
            SELECT sensor, event, timestamp_received 
            FROM {MOTION_TABLE} 
            ORDER BY id DESC 
            LIMIT 5
        """)
        recent_motion = cursor.fetchall()
        
        # Últimos registros de relé
        cursor.execute(f"""
            SELECT device_name, event, current_status, timestamp_received 
            FROM {RELAY_TABLE} 
            ORDER BY id DESC 
            LIMIT 5
        """)
        recent_relay = cursor.fetchall()
        
        conn.close()
        
        print("\n" + "=" * 80)
        print("📊 ESTATÍSTICAS DO BANCO DE DADOS HOMEGUARD")
        print("=" * 80)
        print(f"Total de registros de movimento: {motion_records}")
        print(f"Total de registros de relés: {relay_records}")
        print(f"Total geral: {motion_records + relay_records}")
        
        print("\n🚶 SENSORES DE MOVIMENTO:")
        print("-" * 40)
        if motion_sensor_counts:
            print("📍 Registros por sensor:")
            for sensor, count in motion_sensor_counts:
                print(f"   {sensor}: {count} registros")
            
            print("\n🎯 Detecções de movimento:")
            for sensor, count in motion_detection_counts:
                print(f"   {sensor}: {count} detecções")
        else:
            print("   Nenhum registro de movimento encontrado")
        
        print("\n🔌 CONTROLE DE RELÉS:")
        print("-" * 40)
        if relay_counts:
            print("📊 Atividade por relé:")
            for device, count in relay_counts:
                print(f"   {device}: {count} eventos")
            
            print("\n⚡ Status atual dos relés:")
            for device, status, last_update in relay_status:
                status_icon = "🟢" if status in ['ON', 'on'] else "🔴" if status in ['OFF', 'off'] else "⚪"
                print(f"   {status_icon} {device}: {status} (atualizado: {last_update})")
        else:
            print("   Nenhum registro de relé encontrado")
        
        print("\n📝 REGISTROS RECENTES:")
        print("-" * 40)
        print("🚶 Últimos movimentos:")
        if recent_motion:
            for sensor, event, timestamp in recent_motion:
                print(f"   [{timestamp}] {sensor}: {event}")
        else:
            print("   Nenhum registro de movimento")
        
        print("\n🔌 Últimas atividades de relés:")
        if recent_relay:
            for device, event, status, timestamp in recent_relay:
                status_icon = "🟢" if status in ['ON', 'on'] else "🔴" if status in ['OFF', 'off'] else "⚪"
                print(f"   [{timestamp}] {status_icon} {device}: {event} → {status}")
        else:
            print("   Nenhum registro de relé")
        
        print("=" * 80)
        
    except Exception as e:
        print(f"❌ Erro ao mostrar estatísticas: {e}")

def main():
    """Função principal"""
    parser = argparse.ArgumentParser(
        description='HomeGuard Activity Monitor - SQLite Version (Motion + Relay)'
    )
    parser.add_argument('--broker', default=BROKER, 
                       help=f'MQTT broker IP (padrão: {BROKER})')
    parser.add_argument('--port', type=int, default=PORT, 
                       help=f'MQTT broker port (padrão: {PORT})')
    parser.add_argument('--username', default=USERNAME, 
                       help=f'MQTT username (padrão: {USERNAME})')
    parser.add_argument('--password', default=PASSWORD, 
                       help='MQTT password')
    parser.add_argument('--stats', action='store_true', 
                       help='Mostrar estatísticas do banco e sair')
    
    args = parser.parse_args()
    
    # Se solicitado, mostrar estatísticas e sair
    if args.stats:
        init_db()
        show_statistics()
        return
    
    # Configurar handler para Ctrl+C
    signal.signal(signal.SIGINT, signal_handler)
    
    # Inicializar banco de dados
    init_db()
    
    # Configurar cliente MQTT
    client = mqtt.Client()
    client.username_pw_set(args.username, args.password)
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect
    
    try:
        # Conectar ao broker
        print(f"🔗 Conectando ao broker MQTT {args.broker}:{args.port}...")
        client.connect(args.broker, args.port, 60)
        
        # Iniciar loop principal
        client.loop_forever()
        
    except Exception as e:
        print(f"❌ Erro na conexão MQTT: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()