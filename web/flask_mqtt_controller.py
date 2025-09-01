#!/usr/bin/env python3

"""
============================================
Controlador MQTT para Relés - Versão Flask
============================================
"""

import paho.mqtt.client as mqtt
import json
import threading
import time
import requests
from datetime import datetime
from mqtt_relay_config import MQTT_CONFIG, RELAYS_CONFIG, RELAY_COMMANDS, RELAY_TIMEOUT

class MQTTRelayController:
    def __init__(self):
        self.client = None
        self.connected = False
        self.relay_status = {}
        self.lock = threading.Lock()
        
        # Inicializar status dos relés
        for relay in RELAYS_CONFIG:
            self.relay_status[relay['id']] = {
                'status': 'unknown',
                'last_update': None,
                'last_command': None
            }
        
        # Tópicos DHT11 para monitoramento
        self.dht11_topics = [
            "home/temperature/+/data",
            "home/humidity/+/data",
            "home/sensor/+/status",
            "home/sensor/+/info"
        ]
        
        # Tópicos Motion Sensor para monitoramento
        self.motion_topics = [
            "home/motion_sensor/+/motion",
            "home/motion_sensor/+/status",
            "home/motion_sensor/+/heartbeat",
            "home/motion_sensor/+/config"
        ]
        
        # Controle de throttling para DHT11 (evitar spam)
        self.last_dht11_data = {}  # device_id: {'timestamp': datetime, 'data': {}}
        self.dht11_throttle_seconds = 120  # Mínimo 120 segundos (2 minutos) entre processamentos
        self.pending_dht11_data = {}  # device_id: {'temp': value, 'humid': value, 'last_update': datetime}
        self.dht11_wait_both_seconds = 10  # Aguardar 10s para receber temp e humidity

    def on_connect(self, client, userdata, flags, rc):
        """Callback quando conecta ao MQTT"""
        if rc == 0:
            self.connected = True
            print(f"✅ Conectado ao MQTT broker {MQTT_CONFIG['broker_host']}:{MQTT_CONFIG['broker_port']}")
            
            # Subscrever aos tópicos de relés
            for relay in RELAYS_CONFIG:
                topic = relay['mqtt_topic_status']
                client.subscribe(topic)
                print(f"🎧 Subscrito em relé: {topic}")
            
            # Subscrever aos tópicos DHT11
            for topic in self.dht11_topics:
                client.subscribe(topic)
                print(f"🌡️  Subscrito em DHT11: {topic}")
                
            # Subscrever aos tópicos Motion Sensor
            for topic in self.motion_topics:
                client.subscribe(topic)
                print(f"🚶 Subscrito em Motion: {topic}")
                
            print(f"📊 Total de tópicos monitorados: {len(RELAYS_CONFIG) + len(self.dht11_topics) + len(self.motion_topics)}")
        else:
            self.connected = False
            print(f"❌ Falha na conexão MQTT: {rc}")

    def on_disconnect(self, client, userdata, rc):
        """Callback quando desconecta do MQTT"""
        self.connected = False
        print(f"⚠️  Desconectado do MQTT broker")

    def on_message(self, client, userdata, msg):
        """Callback para mensagens recebidas"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            timestamp = datetime.now().strftime('%H:%M:%S')
            
            print(f"\n📨 [{timestamp}] MQTT Flask recebeu:")
            print(f"   📍 Tópico: {topic}")
            print(f"   📦 Payload: {payload}")
            
            # Processar mensagens de relés
            for relay in RELAYS_CONFIG:
                if topic == relay['mqtt_topic_status']:
                    with self.lock:
                        self.relay_status[relay['id']] = {
                            'status': payload.lower(),
                            'last_update': datetime.now().strftime('%d/%m/%Y %H:%M:%S'),
                            'last_command': self.relay_status[relay['id']].get('last_command')
                        }
                    
                    print(f"📩 Status atualizado - {relay['id']}: {payload}")
                    return
            
            # Processar mensagens DHT11
            self._process_dht11_message(topic, payload)
            
            # Processar mensagens Motion Sensor
            self._process_motion_message(topic, payload)
                    
        except Exception as e:
            print(f"❌ Erro ao processar mensagem MQTT: {e}")
            import traceback
            traceback.print_exc()

    def _process_dht11_message(self, topic, payload):
        """Processar mensagens dos sensores DHT11"""
        try:
            # Verificar se é um tópico DHT11
            if topic.startswith("home/temperature/") and topic.endswith("/data"):
                # Extrair device_id do tópico
                device_id = topic.split('/')[2]
                self._send_sensor_data_to_flask(device_id, payload, "temperature")
                
            elif topic.startswith("home/humidity/") and topic.endswith("/data"):
                # Extrair device_id do tópico
                device_id = topic.split('/')[2]
                self._send_sensor_data_to_flask(device_id, payload, "humidity")
                
            elif topic.startswith("home/sensor/") and topic.endswith("/status"):
                device_id = topic.split('/')[2]
                print(f"🌡️  Status sensor {device_id}: {payload}")
                
            elif topic.startswith("home/sensor/") and topic.endswith("/info"):
                device_id = topic.split('/')[2]
                print(f"📊 Info sensor {device_id}: {payload}")
                
        except Exception as e:
            print(f"❌ Erro ao processar mensagem DHT11: {e}")

    def _process_motion_message(self, topic, payload):
        """Processar mensagens dos sensores de movimento"""
        try:
            # Verificar se é um tópico motion_sensor
            if topic.startswith("home/motion_sensor/") and "/motion" in topic:
                # Extrair device_id do tópico: home/motion_sensor/{device_id}/motion
                device_id = topic.split('/')[2]
                self._send_motion_data_to_flask(device_id, payload, "motion")
                
            elif topic.startswith("home/motion_sensor/") and "/status" in topic:
                device_id = topic.split('/')[2]
                print(f"🚶 Status motion {device_id}: {payload}")
                
            elif topic.startswith("home/motion_sensor/") and "/heartbeat" in topic:
                device_id = topic.split('/')[2]
                print(f"💓 Heartbeat motion {device_id}: {payload}")
                
            elif topic.startswith("home/motion_sensor/") and "/config" in topic:
                device_id = topic.split('/')[2]
                print(f"⚙️  Config motion {device_id}: {payload}")
                
        except Exception as e:
            print(f"❌ Erro ao processar mensagem Motion: {e}")

    def _send_motion_data_to_flask(self, device_id, payload, event_type):
        """Enviar dados do sensor de movimento para o Flask via API local"""
        try:
            # Parse do payload JSON
            data = json.loads(payload)
            
            # Preparar dados para inserção no banco
            flask_data = {
                'device_id': device_id,
                'device_name': data.get('device_name', device_id),
                'location': data.get('location', 'Não definido'),
                'motion_detected': data.get('motion', 'DETECTED') == 'DETECTED',
                'timestamp_received': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'raw_payload': payload
            }
            
            print(f"🚶 Processando motion de {device_id}: {data.get('motion', 'N/A')}")
            
            # Enviar via POST para o endpoint do Flask
            response = requests.post(
                'http://localhost:5000/api/motion',
                json=flask_data,
                timeout=5
            )
            
            if response.status_code == 200:
                print(f"✅ Motion data enviado para Flask: {device_id}")
            else:
                print(f"❌ Erro ao enviar motion data: {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            print(f"🔌 Flask não disponível para motion data: {e}")
        except Exception as e:
            print(f"❌ Erro ao enviar motion data para Flask: {e}")

    def _send_sensor_data_to_flask(self, device_id, payload, sensor_type):
        """Enviar dados do sensor para o Flask via API local (combinando temp e humidity)"""
        try:
            # Parse do payload JSON
            data = json.loads(payload)
            
            now = datetime.now()
            
            # Inicializar dados pendentes se não existir
            if device_id not in self.pending_dht11_data:
                self.pending_dht11_data[device_id] = {
                    'temperature': None,
                    'humidity': None,
                    'last_temp_update': None,
                    'last_humid_update': None,
                    'first_data_time': now,
                    'device_name': data.get('device_name', device_id),
                    'location': data.get('location', 'Não definido'),
                    'rssi': data.get('rssi', 0),
                    'raw_payload': payload
                }
            
            # Atualizar dados pendentes
            pending = self.pending_dht11_data[device_id]
            
            # Se é o primeiro dado após reset, inicializar first_data_time
            if pending['first_data_time'] is None:
                pending['first_data_time'] = now
            
            if sensor_type == "temperature":
                pending['temperature'] = data.get('temperature', 0)
                pending['last_temp_update'] = now
                print(f"🌡️  Temperatura recebida - {device_id}: {pending['temperature']}°C")
                
            elif sensor_type == "humidity":
                pending['humidity'] = data.get('humidity', 0)
                pending['last_humid_update'] = now
                print(f"💧 Umidade recebida - {device_id}: {pending['humidity']}%")
            
            # Atualizar outros dados
            pending['device_name'] = data.get('device_name', pending['device_name'])
            pending['location'] = data.get('location', pending['location'])
            pending['rssi'] = data.get('rssi', pending['rssi'])
            pending['raw_payload'] = payload
            
            # Verificar se temos ambos os valores ou se passou o tempo de espera
            has_both = pending['temperature'] is not None and pending['humidity'] is not None
            
            # Calcular tempo de espera apenas se first_data_time não for None
            wait_time_passed = False
            if pending['first_data_time'] is not None:
                wait_time_passed = (now - pending['first_data_time']).total_seconds() >= self.dht11_wait_both_seconds
            
            # Só processar se:
            # 1. Temos ambos os valores, OU
            # 2. Passou o tempo de espera (10s) e temos pelo menos um valor
            should_try_process = has_both or (wait_time_passed and (pending['temperature'] is not None or pending['humidity'] is not None))
            
            if not should_try_process:
                print(f"⏳ Aguardando mais dados - {device_id}: T:{pending['temperature']} H:{pending['humidity']}")
                return
            
            # Verificar throttling principal (2 minutos)
            should_process = False
            if device_id not in self.last_dht11_data:
                should_process = True
            else:
                last_time = self.last_dht11_data[device_id]['timestamp']
                seconds_since_last = (now - last_time).total_seconds()
                
                if seconds_since_last >= self.dht11_throttle_seconds:
                    should_process = True
                else:
                    print(f"🔄 DHT11 throttling - {device_id}: aguardando {int(self.dht11_throttle_seconds - seconds_since_last)}s")
                    return
            
            # Processar dados
            if should_process:
                # Preparar dados para envio ao Flask
                flask_data = {
                    'device_id': device_id,
                    'device_name': pending['device_name'],
                    'location': pending['location'],
                    'sensor_type': 'DHT11',
                    'rssi': pending['rssi'],
                    'uptime': data.get('uptime', 0),
                    'timestamp_received': now.strftime('%Y-%m-%d %H:%M:%S'),
                    'raw_payload': pending['raw_payload'],
                    'temperature': pending['temperature'],
                    'humidity': pending['humidity']
                }
                
                # Enviar para API Flask
                self._store_sensor_data_internally(flask_data)
                
                # Atualizar controle de throttling
                self.last_dht11_data[device_id] = {
                    'timestamp': now,
                    'data': flask_data
                }
                
                # Reset dados pendentes para próxima coleta
                self.pending_dht11_data[device_id] = {
                    'temperature': None,
                    'humidity': None,
                    'last_temp_update': None,
                    'last_humid_update': None,
                    'first_data_time': None,
                    'device_name': pending['device_name'],
                    'location': pending['location'],
                    'rssi': pending['rssi'],
                    'raw_payload': ''
                }
                
                temp_str = f"{flask_data['temperature']}°C" if flask_data['temperature'] is not None else "N/A"
                humid_str = f"{flask_data['humidity']}%" if flask_data['humidity'] is not None else "N/A"
                print(f"✅ Dados DHT11 processados - {device_id}: T:{temp_str}, H:{humid_str}")
            
        except Exception as e:
            print(f"❌ Erro ao processar dados DHT11: {e}")
            import traceback
            traceback.print_exc()

    def _store_sensor_data_internally(self, data):
        """Armazenar dados do sensor internamente (sem HTTP)"""
        try:
            # Importar dashboard aqui para evitar import circular
            from homeguard_flask import dashboard
            
            # Debug: mostrar dados que serão processados
            print(f"🔧 Debug - Processando dados: {data}")
            
            # Processar dados diretamente no dashboard
            success = dashboard.process_dht11_mqtt_data(
                device_id=data['device_id'],
                device_name=data['device_name'], 
                location=data['location'],
                temperature=data.get('temperature'),
                humidity=data.get('humidity'),
                rssi=data['rssi'],
                raw_payload=data['raw_payload']
            )
            
            if success:
                temp_str = f"{data.get('temperature')}°C" if data.get('temperature') is not None else "N/A"
                humid_str = f"{data.get('humidity')}%" if data.get('humidity') is not None else "N/A"
                print(f"✅ Dados DHT11 armazenados - {data['device_id']} (T:{temp_str}, H:{humid_str})")
            else:
                print(f"❌ Falha ao armazenar dados DHT11 - {data['device_id']}")
                
        except Exception as e:
            print(f"❌ Erro crítico ao armazenar dados internamente: {e}")
            print(f"🔍 Dados que causaram erro: {data}")
            import traceback
            traceback.print_exc()

    def connect(self):
        """Conectar ao broker MQTT"""
        try:
            # Compatibilidade com paho-mqtt 2.0+
            try:
                self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, MQTT_CONFIG['client_id'])
            except:
                # Fallback para versões antigas
                self.client = mqtt.Client(MQTT_CONFIG['client_id'])
                
            self.client.on_connect = self.on_connect
            self.client.on_disconnect = self.on_disconnect
            self.client.on_message = self.on_message
            
            # Configurar credenciais se necessário
            if MQTT_CONFIG['username'] and MQTT_CONFIG['password']:
                self.client.username_pw_set(MQTT_CONFIG['username'], MQTT_CONFIG['password'])
            
            # Conectar
            self.client.connect(
                MQTT_CONFIG['broker_host'], 
                MQTT_CONFIG['broker_port'], 
                MQTT_CONFIG['keepalive']
            )
            
            # Iniciar loop em thread separada
            self.client.loop_start()
            
            # Aguardar conexão
            timeout = 10
            while not self.connected and timeout > 0:
                time.sleep(0.5)
                timeout -= 0.5
            
            return self.connected
            
        except Exception as e:
            print(f"❌ Erro ao conectar MQTT: {e}")
            return False

    def disconnect(self):
        """Desconectar do MQTT"""
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()
        self.connected = False

    def send_command(self, relay_id, action):
        """Enviar comando para relé"""
        if not self.connected:
            return {'success': False, 'message': 'MQTT não conectado'}
        
        # Encontrar configuração do relé
        relay_config = None
        for relay in RELAYS_CONFIG:
            if relay['id'] == relay_id:
                relay_config = relay
                break
        
        if not relay_config:
            return {'success': False, 'message': f'Relé {relay_id} não encontrado'}
        
        # Validar ação
        if action not in RELAY_COMMANDS:
            return {'success': False, 'message': f'Ação {action} inválida'}
        
        try:
            # Preparar comando
            command = RELAY_COMMANDS[action]
            topic = relay_config['mqtt_topic_command']
            
            # Enviar comando
            result = self.client.publish(topic, command)
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                # Atualizar registro do último comando
                with self.lock:
                    self.relay_status[relay_id]['last_command'] = {
                        'action': action,
                        'timestamp': datetime.now().strftime('%d/%m/%Y %H:%M:%S')
                    }
                
                print(f"📤 Comando enviado - {relay_id}: {command} -> {topic}")
                
                return {
                    'success': True,
                    'relay_id': relay_id,
                    'action': action,
                    'command': command,
                    'topic': topic,
                    'message': f'Comando {action} enviado para {relay_config["name"]}'
                }
            else:
                return {'success': False, 'message': 'Falha ao publicar comando MQTT'}
                
        except Exception as e:
            print(f"❌ Erro ao enviar comando: {e}")
            return {'success': False, 'message': f'Erro: {str(e)}'}

    def get_relay_status(self, relay_id=None):
        """Obter status dos relés"""
        with self.lock:
            if relay_id:
                return self.relay_status.get(relay_id, {'status': 'unknown'})
            else:
                return dict(self.relay_status)

    def get_relays_config_with_status(self):
        """Obter configuração dos relés com status atual"""
        relays_with_status = []
        
        for relay in RELAYS_CONFIG:
            relay_copy = relay.copy()
            status_info = self.get_relay_status(relay['id'])
            relay_copy.update(status_info)
            relays_with_status.append(relay_copy)
        
        return relays_with_status

# Instância global do controlador
mqtt_controller = MQTTRelayController()

def init_mqtt():
    """Inicializar conexão MQTT"""
    print("🔌 Inicializando controlador MQTT...")
    if mqtt_controller.connect():
        print("✅ Controlador MQTT inicializado com sucesso")
        return True
    else:
        print("❌ Falha ao inicializar controlador MQTT")
        return False
