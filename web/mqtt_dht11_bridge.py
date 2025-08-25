#!/usr/bin/env python3

"""
============================================
MQTT to Flask Bridge - DHT11 Sensors
Recebe dados MQTT dos sensores DHT11 e envia para Flask API
============================================
"""

import paho.mqtt.client as mqtt
import json
import requests
import logging
from datetime import datetime
import threading
import time

# Configurações
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_USERNAME = 'homeguard'  # Definir se necessário
MQTT_PASSWORD = 'pu2clr123456' # Definir se necessário
MQTT_TOPICS = [
    "home/sensor/+/data",      # Único formato suportado: sensor unificado
]

FLASK_API_URL = "http://localhost:5000/api/process_sensor_data"

# Códigos de erro MQTT para diagnóstico
MQTT_ERROR_CODES = {
    0: "Connection successful",
    1: "Connection refused - incorrect protocol version",
    2: "Connection refused - invalid client identifier",
    3: "Connection refused - server unavailable", 
    4: "Connection refused - bad username or password",
    5: "Connection refused - not authorised"
}

# Configurar logging
logging.basicConfig(
    level=logging.DEBUG,  # Mudado para DEBUG para ver mais detalhes
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MQTTToFlaskBridge:
    def __init__(self):
        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
        self.running = False
        
        # Configurar credenciais se necessário
        if MQTT_USERNAME and MQTT_PASSWORD:
            self.client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
        
        # Estatísticas
        self.stats = {
            'messages_received': 0,
            'messages_processed': 0,
            'api_calls_success': 0,
            'api_calls_failed': 0,
            'start_time': datetime.now()
        }

    def on_connect(self, client, userdata, flags, rc):
        """Callback quando conecta ao MQTT"""
        if rc == 0:
            logger.info("✅ Conectado ao broker MQTT")
            # Inscrever-se nos tópicos
            for topic in MQTT_TOPICS:
                client.subscribe(topic)
                logger.info(f"📡 Inscrito no tópico: {topic}")
        else:
            error_msg = MQTT_ERROR_CODES.get(rc, f"Erro desconhecido: {rc}")
            logger.error(f"❌ Falha na conexão MQTT. Código {rc}: {error_msg}")
            
            # Sugestões baseadas no código de erro
            if rc == 3:
                logger.error("💡 Verifique se o broker Mosquitto está rodando: sudo systemctl status mosquitto")
            elif rc == 4:
                logger.error("💡 Verifique as credenciais MQTT_USERNAME e MQTT_PASSWORD")
            elif rc == 5:
                logger.error("💡 Verifique as permissões do usuário no broker MQTT")

    def on_disconnect(self, client, userdata, rc):
        """Callback quando desconecta do MQTT"""
        logger.warning(f"🔌 Desconectado do MQTT. Código: {rc}")

    def on_message(self, client, userdata, msg):
        """Callback quando recebe mensagem MQTT"""
        try:
            self.stats['messages_received'] += 1
            
            # Decodificar mensagem
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            logger.info(f"📥 Mensagem recebida: {topic}")
            logger.debug(f"Payload completo: {payload}")
            
            # Parse do JSON
            try:
                data = json.loads(payload)
                logger.debug(f"JSON parseado com sucesso: {len(data)} campos")
            except json.JSONDecodeError as e:
                logger.error(f"❌ Erro ao decodificar JSON: {e}")
                logger.error(f"Payload problemático: {payload}")
                return
            
            # Processar dados do sensor DHT11
            if self.is_dht11_sensor(topic, data):
                logger.debug(f"✅ Mensagem identificada como sensor DHT11 válido")
                self.process_dht11_data(topic, data)
            else:
                logger.warning(f"⚠️  Tópico não reconhecido ou dados inválidos: {topic}")
                logger.debug(f"Dados recebidos: {data}")
                
        except Exception as e:
            logger.error(f"❌ Erro ao processar mensagem: {e}")
            logger.error(f"Tópico: {topic}")
            logger.error(f"Payload: {payload}")

    def is_dht11_sensor(self, topic, data):
        """Verificar se é um sensor DHT11 válido"""
        logger.debug(f"🔍 Verificando tópico: {topic}")
        
        # Apenas o formato unificado é suportado
        if not topic.startswith("home/sensor/"):
            logger.debug(f"Tópico não suportado: {topic}")
            return False
        
        # Verificar campos obrigatórios
        required_fields = ['temperature', 'humidity']
        has_required = all(field in data for field in required_fields)
        
        if not has_required:
            logger.debug(f"Campos obrigatórios ausentes. Dados recebidos: {list(data.keys())}")
            return False
            
        # Verificar se os valores são numéricos válidos
        try:
            temp = float(data['temperature'])
            humid = float(data['humidity'])
            logger.debug(f"Dados válidos: Temp={temp}°C, Humid={humid}%")
            return True
        except (ValueError, TypeError) as e:
            logger.debug(f"Erro ao converter valores numéricos: {e}")
            return False

    def process_dht11_data(self, topic, data):
        """Processar dados do sensor DHT11"""
        try:
            # Extrair device_id do tópico: home/sensor/ESP01_DHT11_001/data
            topic_parts = topic.split('/')
            device_id = topic_parts[2] if len(topic_parts) >= 3 else "unknown"
            
            logger.debug(f"🔧 Processando device_id: {device_id}")
            logger.debug(f"🔧 Tópico: {topic}")
            
            # Preparar dados para a API Flask
            api_data = {
                'device_id': device_id,
                'device_name': data.get('device_name', device_id),
                'location': data.get('location', 'Não definido'),
                'temperature': float(data['temperature']),
                'humidity': float(data['humidity']),
                'rssi': data.get('rssi'),
                'uptime': data.get('uptime'),
                'timestamp': data.get('timestamp', datetime.now().isoformat()),
                'raw_payload': json.dumps(data)
            }
            
            # Enviar para Flask API
            self.send_to_flask_api(api_data)
            
            self.stats['messages_processed'] += 1
            
            logger.info(f"✅ Processado {device_id}: Temp={api_data['temperature']}°C, Umid={api_data['humidity']}%")
            
        except Exception as e:
            logger.error(f"❌ Erro ao processar dados DHT11: {e}")
            logger.error(f"Tópico: {topic}")
            logger.error(f"Dados: {data}")

    def send_to_flask_api(self, data):
        """Enviar dados para a API Flask"""
        try:
            response = requests.post(
                FLASK_API_URL,
                json=data,
                timeout=10,
                headers={'Content-Type': 'application/json'}
            )
            
            if response.status_code == 200:
                self.stats['api_calls_success'] += 1
                logger.debug("✅ Dados enviados para Flask API")
            else:
                self.stats['api_calls_failed'] += 1
                logger.error(f"❌ Erro na API Flask: {response.status_code} - {response.text}")
                
        except requests.exceptions.Timeout:
            self.stats['api_calls_failed'] += 1
            logger.error("❌ Timeout ao conectar com Flask API")
        except requests.exceptions.ConnectionError:
            self.stats['api_calls_failed'] += 1
            logger.error("❌ Erro de conexão com Flask API")
        except Exception as e:
            self.stats['api_calls_failed'] += 1
            logger.error(f"❌ Erro inesperado ao chamar API: {e}")

    def print_stats(self):
        """Imprimir estatísticas"""
        uptime = datetime.now() - self.stats['start_time']
        logger.info("📊 Estatísticas:")
        logger.info(f"   Tempo ativo: {uptime}")
        logger.info(f"   Mensagens MQTT recebidas: {self.stats['messages_received']}")
        logger.info(f"   Mensagens processadas: {self.stats['messages_processed']}")
        logger.info(f"   API calls sucesso: {self.stats['api_calls_success']}")
        logger.info(f"   API calls falha: {self.stats['api_calls_failed']}")

    def stats_thread(self):
        """Thread para imprimir estatísticas periodicamente"""
        while self.running:
            time.sleep(300)  # A cada 5 minutos
            if self.running:
                self.print_stats()

    def start(self):
        """Iniciar o bridge"""
        self.running = True
        
        # Iniciar thread de estatísticas
        stats_thread = threading.Thread(target=self.stats_thread, daemon=True)
        stats_thread.start()
        
        logger.info("🚀 Iniciando MQTT to Flask Bridge")
        
        try:
            # Conectar ao broker MQTT
            self.client.connect(MQTT_BROKER, MQTT_PORT, 60)
            
            # Loop principal
            self.client.loop_forever()
            
        except KeyboardInterrupt:
            logger.info("🛑 Parando o bridge...")
            self.stop()
        except Exception as e:
            logger.error(f"❌ Erro no loop principal: {e}")
            self.stop()

    def stop(self):
        """Parar o bridge"""
        self.running = False
        self.client.disconnect()
        self.print_stats()
        logger.info("✅ Bridge parado")

def test_flask_api():
    """Testar conectividade com a API Flask"""
    try:
        # Dados de teste
        test_data = {
            'device_id': 'TEST_DHT11',
            'device_name': 'Teste DHT11',
            'location': 'Laboratório',
            'temperature': 23.5,
            'humidity': 65.2,
            'rssi': -67,
            'timestamp': datetime.now().isoformat()
        }
        
        response = requests.post(FLASK_API_URL, json=test_data, timeout=5)
        
        if response.status_code == 200:
            logger.info("✅ API Flask está respondendo corretamente")
            return True
        else:
            logger.error(f"❌ API Flask retornou: {response.status_code}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erro ao testar API Flask: {e}")
        return False

if __name__ == "__main__":
    # Testar API Flask primeiro
    logger.info("🔍 Testando conectividade com Flask API...")
    if not test_flask_api():
        logger.error("❌ Flask API não está disponível. Verifique se o servidor Flask está rodando.")
        exit(1)
    
    # Iniciar bridge
    bridge = MQTTToFlaskBridge()
    bridge.start()
