#!/usr/bin/env python3
"""
HomeGuard Camera Integration System
Sistema de integração com câmeras Intelbras via RTSP
"""

import cv2
import json
import time
import threading
import logging
import numpy as np
import sqlite3
import os
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
import paho.mqtt.client as mqtt
from urllib.parse import urlparse
import subprocess
import requests
from requests.auth import HTTPDigestAuth
import xml.etree.ElementTree as ET

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class CameraConfig:
    """Configuração de uma câmera Intelbras"""
    id: str
    name: str
    location: str
    ip: str
    rtsp_port: int = 554
    http_port: int = 80
    username: str = "admin"
    password: str = ""
    main_stream: str = "cam/realmonitor?channel=1&subtype=0"  # Stream principal
    sub_stream: str = "cam/realmonitor?channel=1&subtype=1"   # Stream secundário
    ptz_capable: bool = False
    recording_enabled: bool = True
    motion_detection: bool = True
    enabled: bool = True

@dataclass
class MotionEvent:
    """Evento de movimento detectado"""
    camera_id: str
    timestamp: datetime
    confidence: float
    bbox: Optional[Tuple[int, int, int, int]] = None
    snapshot_path: Optional[str] = None

class IntelbrasAPI:
    """Interface para API HTTP das câmeras Intelbras"""
    
    def __init__(self, camera: CameraConfig):
        self.camera = camera
        self.base_url = f"http://{camera.ip}:{camera.http_port}"
        self.auth = HTTPDigestAuth(camera.username, camera.password)
        self.session = requests.Session()
        self.session.auth = self.auth
    
    def get_device_info(self) -> Dict:
        """Obtém informações do dispositivo"""
        try:
            url = f"{self.base_url}/cgi-bin/magicBox.cgi?action=getDeviceType"
            response = self.session.get(url, timeout=10)
            response.raise_for_status()
            
            # Parse da resposta Intelbras (formato key=value)
            info = {}
            for line in response.text.split('\n'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    info[key.strip()] = value.strip()
            
            return info
        except Exception as e:
            logger.error(f"Erro ao obter info da câmera {self.camera.id}: {e}")
            return {}
    
    def get_ptz_status(self) -> Dict:
        """Obtém status PTZ (se suportado)"""
        if not self.camera.ptz_capable:
            return {}
        
        try:
            url = f"{self.base_url}/cgi-bin/ptz.cgi?action=getCurrentProtocolCaps&channel=0"
            response = self.session.get(url, timeout=5)
            response.raise_for_status()
            
            status = {}
            for line in response.text.split('\n'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    status[key.strip()] = value.strip()
            
            return status
        except Exception as e:
            logger.warning(f"Erro ao obter status PTZ da câmera {self.camera.id}: {e}")
            return {}
    
    def ptz_control(self, action: str, speed: int = 5) -> bool:
        """
        Controle PTZ
        Ações: up, down, left, right, zoomin, zoomout, stop
        """
        if not self.camera.ptz_capable:
            return False
        
        try:
            url = f"{self.base_url}/cgi-bin/ptz.cgi"
            params = {
                'action': 'start',
                'channel': '0',
                'code': action.title(),
                'arg1': str(speed),
                'arg2': str(speed)
            }
            
            response = self.session.get(url, params=params, timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Erro no controle PTZ da câmera {self.camera.id}: {e}")
            return False
    
    def capture_snapshot(self, save_path: str) -> bool:
        """Captura snapshot da câmera"""
        try:
            url = f"{self.base_url}/cgi-bin/snapshot.cgi?channel=0"
            response = self.session.get(url, timeout=15)
            response.raise_for_status()
            
            with open(save_path, 'wb') as f:
                f.write(response.content)
            
            return True
        except Exception as e:
            logger.error(f"Erro ao capturar snapshot da câmera {self.camera.id}: {e}")
            return False

class CameraStreamProcessor:
    """Processador de stream de vídeo com detecção de movimento"""
    
    def __init__(self, camera: CameraConfig, use_sub_stream: bool = True):
        self.camera = camera
        self.use_sub_stream = use_sub_stream
        self.cap = None
        self.running = False
        self.motion_detector = None
        self.last_frame = None
        self.motion_threshold = 1000  # Área mínima para considerar movimento
        self.motion_callback = None
        
        # Configurar URL RTSP
        stream_path = camera.sub_stream if use_sub_stream else camera.main_stream
        auth_str = f"{camera.username}:{camera.password}@" if camera.password else ""
        self.rtsp_url = f"rtsp://{auth_str}{camera.ip}:{camera.rtsp_port}/{stream_path}"
    
    def set_motion_callback(self, callback):
        """Define callback para eventos de movimento"""
        self.motion_callback = callback
    
    def start_stream(self) -> bool:
        """Inicia o stream de vídeo"""
        try:
            logger.info(f"Conectando à câmera {self.camera.id} via RTSP...")
            
            # Configurar OpenCV para RTSP
            self.cap = cv2.VideoCapture(self.rtsp_url)
            self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Reduzir latência
            self.cap.set(cv2.CAP_PROP_FPS, 10)  # Limitar FPS
            
            if not self.cap.isOpened():
                logger.error(f"Não foi possível conectar à câmera {self.camera.id}")
                return False
            
            # Inicializar detector de movimento
            self.motion_detector = cv2.createBackgroundSubtractorMOG2(
                detectShadows=True,
                varThreshold=50
            )
            
            self.running = True
            logger.info(f"Stream da câmera {self.camera.id} iniciado com sucesso")
            return True
            
        except Exception as e:
            logger.error(f"Erro ao iniciar stream da câmera {self.camera.id}: {e}")
            return False
    
    def stop_stream(self):
        """Para o stream de vídeo"""
        self.running = False
        if self.cap:
            self.cap.release()
    
    def process_frame(self) -> Optional[MotionEvent]:
        """Processa um frame e detecta movimento"""
        if not self.cap or not self.running:
            return None
        
        ret, frame = self.cap.read()
        if not ret:
            logger.warning(f"Falha ao ler frame da câmera {self.camera.id}")
            return None
        
        # Redimensionar frame para processamento mais rápido
        height, width = frame.shape[:2]
        if width > 640:
            scale = 640 / width
            new_width = int(width * scale)
            new_height = int(height * scale)
            frame = cv2.resize(frame, (new_width, new_height))
        
        # Detectar movimento
        if self.camera.motion_detection and self.motion_detector:
            fg_mask = self.motion_detector.apply(frame)
            
            # Remover ruído
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
            fg_mask = cv2.morphologyEx(fg_mask, cv2.MORPH_OPEN, kernel)
            
            # Encontrar contornos
            contours, _ = cv2.findContours(fg_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # Verificar se há movimento significativo
            for contour in contours:
                area = cv2.contourArea(contour)
                if area > self.motion_threshold:
                    x, y, w, h = cv2.boundingRect(contour)
                    
                    # Calcular confiança baseada na área
                    confidence = min(area / (width * height * 0.1), 1.0)
                    
                    motion_event = MotionEvent(
                        camera_id=self.camera.id,
                        timestamp=datetime.now(),
                        confidence=confidence,
                        bbox=(x, y, w, h)
                    )
                    
                    return motion_event
        
        self.last_frame = frame
        return None
    
    def get_latest_frame(self) -> Optional[np.ndarray]:
        """Retorna o último frame capturado"""
        return self.last_frame

class CameraManager:
    """Gerenciador central das câmeras"""
    
    def __init__(self, config_file: str = "camera_config.json"):
        self.config_file = config_file
        self.cameras: Dict[str, CameraConfig] = {}
        self.processors: Dict[str, CameraStreamProcessor] = {}
        self.apis: Dict[str, IntelbrasAPI] = {}
        self.running = False
        
        # Configuração MQTT
        self.mqtt_client = None
        self.mqtt_config = {
            "host": "192.168.18.198",
            "port": 1883,
            "username": "homeguard",
            "password": "pu2clr123456",
            "base_topic": "homeguard/cameras"
        }
        
        # Configuração do banco de dados
        self.db_path = "../db/homeguard.db"
        
        # Diretórios
        self.snapshots_dir = "snapshots"
        self.recordings_dir = "recordings"
        os.makedirs(self.snapshots_dir, exist_ok=True)
        os.makedirs(self.recordings_dir, exist_ok=True)
        
        self.load_config()
        self.setup_database()
    
    def load_config(self):
        """Carrega configuração das câmeras"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    config_data = json.load(f)
                
                self.mqtt_config.update(config_data.get('mqtt', {}))
                
                for cam_data in config_data.get('cameras', []):
                    camera = CameraConfig(**cam_data)
                    self.cameras[camera.id] = camera
                    logger.info(f"Câmera carregada: {camera.id} ({camera.name})")
            else:
                self.create_default_config()
        except Exception as e:
            logger.error(f"Erro ao carregar configuração: {e}")
            self.create_default_config()
    
    def create_default_config(self):
        """Cria configuração padrão"""
        default_config = {
            "mqtt": self.mqtt_config,
            "cameras": [
                {
                    "id": "CAM_001",
                    "name": "Câmera Entrada",
                    "location": "Entrada Principal",
                    "ip": "192.168.1.100",
                    "username": "admin",
                    "password": "admin123",
                    "ptz_capable": False,
                    "enabled": True
                },
                {
                    "id": "CAM_002",
                    "name": "Câmera Quintal",
                    "location": "Quintal/Fundos",
                    "ip": "192.168.1.101",
                    "username": "admin",
                    "password": "admin123",
                    "ptz_capable": True,
                    "enabled": True
                }
            ]
        }
        
        with open(self.config_file, 'w') as f:
            json.dump(default_config, f, indent=2)
        
        logger.info(f"Configuração padrão criada: {self.config_file}")
    
    def setup_database(self):
        """Configura tabelas do banco de dados"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Tabela de eventos de câmera
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS camera_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    camera_id TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    confidence REAL,
                    bbox_x INTEGER,
                    bbox_y INTEGER,
                    bbox_w INTEGER,
                    bbox_h INTEGER,
                    snapshot_path TEXT,
                    processed BOOLEAN DEFAULT FALSE
                )
            ''')
            
            # Tabela de status das câmeras
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS camera_status (
                    camera_id TEXT PRIMARY KEY,
                    name TEXT,
                    location TEXT,
                    ip TEXT,
                    status TEXT,
                    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
                    fps REAL,
                    resolution TEXT,
                    uptime_seconds INTEGER
                )
            ''')
            
            conn.commit()
            conn.close()
            logger.info("Banco de dados configurado")
            
        except Exception as e:
            logger.error(f"Erro ao configurar banco de dados: {e}")
    
    def setup_mqtt(self):
        """Configura conexão MQTT"""
        try:
            self.mqtt_client = mqtt.Client()
            self.mqtt_client.username_pw_set(
                self.mqtt_config["username"],
                self.mqtt_config["password"]
            )
            
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_message = self.on_mqtt_message
            
            self.mqtt_client.connect(
                self.mqtt_config["host"],
                self.mqtt_config["port"],
                60
            )
            
            self.mqtt_client.loop_start()
            logger.info("MQTT conectado")
            
        except Exception as e:
            logger.error(f"Erro ao conectar MQTT: {e}")
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback de conexão MQTT"""
        if rc == 0:
            logger.info("MQTT conectado com sucesso")
            # Subscrever comandos
            client.subscribe(f"{self.mqtt_config['base_topic']}/+/cmd")
            client.subscribe("homeguard/motion/+/event")  # Integração com sensores
        else:
            logger.error(f"Falha na conexão MQTT: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """Callback de mensagem MQTT"""
        try:
            topic = msg.topic
            payload = json.loads(msg.payload.decode())
            
            if "/cmd" in topic:
                # Comando para câmera
                camera_id = topic.split('/')[-2]
                self.handle_camera_command(camera_id, payload)
            elif "motion" in topic and "event" in topic:
                # Evento de sensor de movimento
                self.handle_motion_sensor_event(payload)
                
        except Exception as e:
            logger.error(f"Erro ao processar mensagem MQTT: {e}")
    
    def handle_camera_command(self, camera_id: str, command: Dict):
        """Processa comando para câmera"""
        if camera_id not in self.cameras:
            return
        
        cmd_type = command.get('command')
        
        if cmd_type == 'snapshot':
            self.capture_snapshot(camera_id)
        elif cmd_type == 'ptz':
            action = command.get('action')
            speed = command.get('speed', 5)
            self.ptz_control(camera_id, action, speed)
        elif cmd_type == 'recording':
            if command.get('enabled'):
                self.start_recording(camera_id)
            else:
                self.stop_recording(camera_id)
    
    def handle_motion_sensor_event(self, event_data: Dict):
        """Processa evento de sensor de movimento para ativar câmeras"""
        try:
            device_id = event_data.get('device_id')
            location = event_data.get('location', '')
            motion = event_data.get('motion', 0)
            
            if motion == 1:  # Movimento detectado
                # Encontrar câmeras próximas baseado na localização
                for camera_id, camera in self.cameras.items():
                    if camera.enabled and location.lower() in camera.location.lower():
                        logger.info(f"Movimento detectado em {location}, ativando câmera {camera_id}")
                        
                        # Capturar snapshot
                        threading.Thread(
                            target=self.capture_snapshot,
                            args=(camera_id,),
                            daemon=True
                        ).start()
                        
                        # PTZ para posição padrão se suportado
                        if camera.ptz_capable:
                            threading.Thread(
                                target=self.ptz_control,
                                args=(camera_id, 'stop'),
                                daemon=True
                            ).start()
                        
        except Exception as e:
            logger.error(f"Erro ao processar evento de movimento: {e}")
    
    def capture_snapshot(self, camera_id: str) -> Optional[str]:
        """Captura snapshot de uma câmera"""
        if camera_id not in self.cameras:
            return None
        
        camera = self.cameras[camera_id]
        api = self.apis.get(camera_id)
        
        if not api:
            api = IntelbrasAPI(camera)
            self.apis[camera_id] = api
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{camera_id}_{timestamp}.jpg"
        filepath = os.path.join(self.snapshots_dir, filename)
        
        if api.capture_snapshot(filepath):
            logger.info(f"Snapshot capturado: {filepath}")
            
            # Salvar no banco
            self.save_camera_event(camera_id, "snapshot", filepath=filepath)
            
            # Publicar via MQTT
            self.publish_camera_event(camera_id, "snapshot", {"filepath": filepath})
            
            return filepath
        
        return None
    
    def ptz_control(self, camera_id: str, action: str, speed: int = 5):
        """Controla PTZ de uma câmera"""
        if camera_id not in self.cameras:
            return
        
        camera = self.cameras[camera_id]
        if not camera.ptz_capable:
            return
        
        api = self.apis.get(camera_id)
        if not api:
            api = IntelbrasAPI(camera)
            self.apis[camera_id] = api
        
        if api.ptz_control(action, speed):
            logger.info(f"PTZ {action} executado na câmera {camera_id}")
            self.publish_camera_event(camera_id, "ptz", {
                "action": action,
                "speed": speed
            })
    
    def start_monitoring(self):
        """Inicia monitoramento de todas as câmeras"""
        if self.running:
            return
        
        logger.info("Iniciando monitoramento de câmeras...")
        self.running = True
        
        # Configurar MQTT
        self.setup_mqtt()
        
        # Iniciar processadores para cada câmera
        for camera_id, camera in self.cameras.items():
            if camera.enabled:
                processor = CameraStreamProcessor(camera)
                processor.set_motion_callback(self.on_motion_detected)
                self.processors[camera_id] = processor
                
                # Iniciar em thread separada
                thread = threading.Thread(
                    target=self.monitor_camera,
                    args=(camera_id, processor),
                    daemon=True
                )
                thread.start()
        
        # Thread de status
        status_thread = threading.Thread(target=self.status_monitor, daemon=True)
        status_thread.start()
        
        logger.info("Monitoramento iniciado")
    
    def monitor_camera(self, camera_id: str, processor: CameraStreamProcessor):
        """Monitora uma câmera específica"""
        camera = self.cameras[camera_id]
        logger.info(f"Iniciando monitoramento da câmera {camera_id}")
        
        retry_count = 0
        max_retries = 5
        
        while self.running:
            try:
                if not processor.start_stream():
                    retry_count += 1
                    if retry_count >= max_retries:
                        logger.error(f"Máximo de tentativas excedido para câmera {camera_id}")
                        break
                    
                    logger.warning(f"Tentativa {retry_count} de reconexão da câmera {camera_id}")
                    time.sleep(5 * retry_count)
                    continue
                
                retry_count = 0  # Reset contador
                
                while self.running and processor.running:
                    motion_event = processor.process_frame()
                    
                    if motion_event:
                        self.on_motion_detected(motion_event)
                    
                    time.sleep(0.1)  # 10 FPS
                
            except Exception as e:
                logger.error(f"Erro no monitoramento da câmera {camera_id}: {e}")
                time.sleep(5)
            finally:
                processor.stop_stream()
        
        logger.info(f"Monitoramento da câmera {camera_id} finalizado")
    
    def on_motion_detected(self, motion_event: MotionEvent):
        """Callback para movimento detectado"""
        logger.info(f"Movimento detectado na câmera {motion_event.camera_id} "
                   f"(confiança: {motion_event.confidence:.2f})")
        
        # Capturar snapshot se movimento significativo
        if motion_event.confidence > 0.3:
            snapshot_path = self.capture_motion_snapshot(motion_event)
            motion_event.snapshot_path = snapshot_path
        
        # Salvar evento no banco
        self.save_camera_event(
            motion_event.camera_id,
            "motion",
            confidence=motion_event.confidence,
            bbox=motion_event.bbox,
            filepath=motion_event.snapshot_path
        )
        
        # Publicar via MQTT
        self.publish_camera_event(motion_event.camera_id, "motion", {
            "confidence": motion_event.confidence,
            "bbox": motion_event.bbox,
            "snapshot_path": motion_event.snapshot_path
        })
    
    def capture_motion_snapshot(self, motion_event: MotionEvent) -> Optional[str]:
        """Captura snapshot de evento de movimento"""
        processor = self.processors.get(motion_event.camera_id)
        if not processor:
            return None
        
        frame = processor.get_latest_frame()
        if frame is None:
            return None
        
        # Desenhar bbox se disponível
        if motion_event.bbox:
            x, y, w, h = motion_event.bbox
            cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
            cv2.putText(frame, f"Motion: {motion_event.confidence:.2f}",
                       (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
        
        # Salvar snapshot
        timestamp = motion_event.timestamp.strftime("%Y%m%d_%H%M%S_%f")[:-3]
        filename = f"{motion_event.camera_id}_motion_{timestamp}.jpg"
        filepath = os.path.join(self.snapshots_dir, filename)
        
        if cv2.imwrite(filepath, frame):
            return filepath
        
        return None
    
    def save_camera_event(self, camera_id: str, event_type: str, 
                         confidence: float = None, bbox: Tuple = None, 
                         filepath: str = None):
        """Salva evento no banco de dados"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            bbox_x = bbox_y = bbox_w = bbox_h = None
            if bbox:
                bbox_x, bbox_y, bbox_w, bbox_h = bbox
            
            cursor.execute('''
                INSERT INTO camera_events 
                (camera_id, event_type, confidence, bbox_x, bbox_y, bbox_w, bbox_h, snapshot_path)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (camera_id, event_type, confidence, bbox_x, bbox_y, bbox_w, bbox_h, filepath))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Erro ao salvar evento no banco: {e}")
    
    def publish_camera_event(self, camera_id: str, event_type: str, data: Dict):
        """Publica evento via MQTT"""
        if not self.mqtt_client:
            return
        
        try:
            topic = f"{self.mqtt_config['base_topic']}/{camera_id}/{event_type}"
            payload = {
                "camera_id": camera_id,
                "event_type": event_type,
                "timestamp": datetime.now().isoformat(),
                **data
            }
            
            self.mqtt_client.publish(topic, json.dumps(payload))
            
        except Exception as e:
            logger.error(f"Erro ao publicar evento MQTT: {e}")
    
    def status_monitor(self):
        """Monitor de status das câmeras"""
        while self.running:
            try:
                for camera_id, camera in self.cameras.items():
                    if not camera.enabled:
                        continue
                    
                    # Verificar status da câmera
                    api = self.apis.get(camera_id)
                    if not api:
                        api = IntelbrasAPI(camera)
                        self.apis[camera_id] = api
                    
                    device_info = api.get_device_info()
                    processor = self.processors.get(camera_id)
                    
                    status = {
                        "camera_id": camera_id,
                        "name": camera.name,
                        "location": camera.location,
                        "ip": camera.ip,
                        "status": "online" if device_info else "offline",
                        "device_info": device_info
                    }
                    
                    # Publicar status
                    topic = f"{self.mqtt_config['base_topic']}/{camera_id}/status"
                    self.mqtt_client.publish(topic, json.dumps(status))
                
                time.sleep(60)  # Status a cada minuto
                
            except Exception as e:
                logger.error(f"Erro no monitor de status: {e}")
                time.sleep(60)
    
    def stop_monitoring(self):
        """Para o monitoramento"""
        logger.info("Parando monitoramento de câmeras...")
        self.running = False
        
        # Parar processadores
        for processor in self.processors.values():
            processor.stop_stream()
        
        # Parar MQTT
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
        
        logger.info("Monitoramento parado")

def main():
    """Função principal"""
    import signal
    import sys
    
    camera_manager = CameraManager()
    
    def signal_handler(sig, frame):
        logger.info("Recebido sinal de parada...")
        camera_manager.stop_monitoring()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        camera_manager.start_monitoring()
        
        # Loop principal
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        logger.info("Interrompido pelo usuário")
    finally:
        camera_manager.stop_monitoring()

if __name__ == "__main__":
    main()
