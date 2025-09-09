#!/usr/bin/env python3
"""
HomeGuard Camera Web Interface
Interface web para visualização e controle das câmeras Intelbras
"""

from flask import Flask, render_template, jsonify, request, Response, send_file
import json
import os
import sqlite3
from datetime import datetime, timedelta
import cv2
import threading
import time
import base64
from typing import Dict, List, Optional
import logging

# Configuração de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CameraWebInterface:
    """Interface web para sistema de câmeras"""
    
    def __init__(self, config_file: str = "camera_config.json"):
        self.app = Flask(__name__)
        self.config_file = config_file
        self.camera_config = {}
        self.db_path = "../db/homeguard.db"
        
        # Cache de streams
        self.stream_cache = {}
        self.stream_threads = {}
        
        self.load_config()
        self.setup_routes()
    
    def load_config(self):
        """Carrega configuração das câmeras"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    self.camera_config = json.load(f)
        except Exception as e:
            logger.error(f"Erro ao carregar configuração: {e}")
            self.camera_config = {"cameras": []}
    
    def setup_routes(self):
        """Configura rotas da aplicação web"""
        
        @self.app.route('/')
        def dashboard():
            """Dashboard principal"""
            cameras = self.camera_config.get('cameras', [])
            return render_template('camera_dashboard.html', cameras=cameras)
        
        @self.app.route('/camera/<camera_id>')
        def camera_view(camera_id):
            """Visualização individual da câmera"""
            camera = self.get_camera_by_id(camera_id)
            if not camera:
                return "Câmera não encontrada", 404
            
            return render_template('camera_view.html', camera=camera)
        
        @self.app.route('/api/cameras')
        def api_cameras():
            """Lista todas as câmeras"""
            cameras = self.camera_config.get('cameras', [])
            return jsonify(cameras)
        
        @self.app.route('/api/camera/<camera_id>/info')
        def api_camera_info(camera_id):
            """Informações de uma câmera específica"""
            camera = self.get_camera_by_id(camera_id)
            if not camera:
                return jsonify({"error": "Câmera não encontrada"}), 404
            
            return jsonify(camera)
        
        @self.app.route('/api/camera/<camera_id>/snapshot')
        def api_camera_snapshot(camera_id):
            """Captura snapshot de uma câmera"""
            try:
                camera = self.get_camera_by_id(camera_id)
                if not camera:
                    return jsonify({"error": "Câmera não encontrada"}), 404
                
                # Capturar snapshot
                snapshot_path = self.capture_snapshot(camera)
                
                if snapshot_path and os.path.exists(snapshot_path):
                    return send_file(snapshot_path, mimetype='image/jpeg')
                else:
                    return jsonify({"error": "Falha ao capturar snapshot"}), 500
                    
            except Exception as e:
                logger.error(f"Erro ao capturar snapshot: {e}")
                return jsonify({"error": str(e)}), 500
        
        @self.app.route('/api/camera/<camera_id>/stream')
        def api_camera_stream(camera_id):
            """Stream de vídeo MJPEG"""
            camera = self.get_camera_by_id(camera_id)
            if not camera:
                return "Câmera não encontrada", 404
            
            return Response(
                self.generate_stream(camera),
                mimetype='multipart/x-mixed-replace; boundary=frame'
            )
        
        @self.app.route('/api/camera/<camera_id>/ptz', methods=['POST'])
        def api_camera_ptz(camera_id):
            """Controle PTZ"""
            try:
                camera = self.get_camera_by_id(camera_id)
                if not camera or not camera.get('ptz_capable'):
                    return jsonify({"error": "PTZ não suportado"}), 400
                
                data = request.get_json()
                action = data.get('action')
                speed = data.get('speed', 5)
                
                # Implementar controle PTZ aqui
                success = self.ptz_control(camera, action, speed)
                
                return jsonify({"success": success})
                
            except Exception as e:
                logger.error(f"Erro no controle PTZ: {e}")
                return jsonify({"error": str(e)}), 500
        
        @self.app.route('/api/camera/<camera_id>/events')
        def api_camera_events(camera_id):
            """Eventos recentes de uma câmera"""
            try:
                hours = request.args.get('hours', 24, type=int)
                limit = request.args.get('limit', 50, type=int)
                
                events = self.get_camera_events(camera_id, hours, limit)
                return jsonify(events)
                
            except Exception as e:
                logger.error(f"Erro ao buscar eventos: {e}")
                return jsonify({"error": str(e)}), 500
        
        @self.app.route('/api/snapshots/<path:filename>')
        def api_snapshot_file(filename):
            """Serve arquivos de snapshot"""
            snapshots_dir = self.camera_config.get('storage', {}).get('snapshots_dir', 'snapshots')
            file_path = os.path.join(snapshots_dir, filename)
            
            if os.path.exists(file_path):
                return send_file(file_path, mimetype='image/jpeg')
            else:
                return "Arquivo não encontrado", 404
        
        @self.app.route('/api/system/status')
        def api_system_status():
            """Status do sistema"""
            try:
                status = {
                    "timestamp": datetime.now().isoformat(),
                    "cameras_configured": len(self.camera_config.get('cameras', [])),
                    "cameras_online": 0,
                    "total_events_today": 0,
                    "disk_usage": self.get_disk_usage()
                }
                
                # Contar câmeras online (simplificado)
                for camera in self.camera_config.get('cameras', []):
                    if camera.get('enabled'):
                        status["cameras_online"] += 1
                
                # Contar eventos de hoje
                today_events = self.get_events_count_today()
                status["total_events_today"] = today_events
                
                return jsonify(status)
                
            except Exception as e:
                logger.error(f"Erro ao obter status: {e}")
                return jsonify({"error": str(e)}), 500
    
    def get_camera_by_id(self, camera_id: str) -> Optional[Dict]:
        """Obtém câmera por ID"""
        for camera in self.camera_config.get('cameras', []):
            if camera.get('id') == camera_id:
                return camera
        return None
    
    def capture_snapshot(self, camera: Dict) -> Optional[str]:
        """Captura snapshot de uma câmera"""
        try:
            # Construir URL RTSP
            auth_str = f"{camera['username']}:{camera['password']}@" if camera.get('password') else ""
            rtsp_url = f"rtsp://{auth_str}{camera['ip']}:{camera.get('rtsp_port', 554)}/{camera.get('sub_stream', 'cam/realmonitor?channel=1&subtype=1')}"
            
            # Capturar frame
            cap = cv2.VideoCapture(rtsp_url)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            
            ret, frame = cap.read()
            cap.release()
            
            if ret:
                # Salvar snapshot
                snapshots_dir = self.camera_config.get('storage', {}).get('snapshots_dir', 'snapshots')
                os.makedirs(snapshots_dir, exist_ok=True)
                
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"{camera['id']}_snapshot_{timestamp}.jpg"
                filepath = os.path.join(snapshots_dir, filename)
                
                cv2.imwrite(filepath, frame)
                return filepath
            
            return None
            
        except Exception as e:
            logger.error(f"Erro ao capturar snapshot da câmera {camera['id']}: {e}")
            return None
    
    def generate_stream(self, camera: Dict):
        """Gera stream MJPEG"""
        try:
            # Construir URL RTSP
            auth_str = f"{camera['username']}:{camera['password']}@" if camera.get('password') else ""
            rtsp_url = f"rtsp://{auth_str}{camera['ip']}:{camera.get('rtsp_port', 554)}/{camera.get('sub_stream', 'cam/realmonitor?channel=1&subtype=1')}"
            
            cap = cv2.VideoCapture(rtsp_url)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                
                # Redimensionar para web
                height, width = frame.shape[:2]
                if width > 640:
                    scale = 640 / width
                    new_width = int(width * scale)
                    new_height = int(height * scale)
                    frame = cv2.resize(frame, (new_width, new_height))
                
                # Adicionar timestamp
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                cv2.putText(frame, timestamp, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                cv2.putText(frame, camera['name'], (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                
                # Converter para JPEG
                ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
                if ret:
                    frame_bytes = buffer.tobytes()
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
                
                time.sleep(0.1)  # 10 FPS
            
            cap.release()
            
        except Exception as e:
            logger.error(f"Erro no stream da câmera {camera['id']}: {e}")
    
    def ptz_control(self, camera: Dict, action: str, speed: int) -> bool:
        """Controle PTZ simplificado"""
        # Implementar API HTTP da Intelbras para PTZ
        try:
            import requests
            from requests.auth import HTTPDigestAuth
            
            auth = HTTPDigestAuth(camera['username'], camera['password'])
            base_url = f"http://{camera['ip']}:{camera.get('http_port', 80)}"
            
            url = f"{base_url}/cgi-bin/ptz.cgi"
            params = {
                'action': 'start',
                'channel': '0',
                'code': action.title(),
                'arg1': str(speed),
                'arg2': str(speed)
            }
            
            response = requests.get(url, params=params, auth=auth, timeout=5)
            return response.status_code == 200
            
        except Exception as e:
            logger.error(f"Erro no controle PTZ: {e}")
            return False
    
    def get_camera_events(self, camera_id: str, hours: int, limit: int) -> List[Dict]:
        """Obtém eventos de uma câmera"""
        try:
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT * FROM camera_events 
                WHERE camera_id = ? 
                AND timestamp >= datetime('now', '-{} hours')
                ORDER BY timestamp DESC 
                LIMIT ?
            '''.format(hours), (camera_id, limit))
            
            events = []
            for row in cursor.fetchall():
                event = dict(row)
                events.append(event)
            
            conn.close()
            return events
            
        except Exception as e:
            logger.error(f"Erro ao buscar eventos: {e}")
            return []
    
    def get_events_count_today(self) -> int:
        """Conta eventos de hoje"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT COUNT(*) FROM camera_events 
                WHERE DATE(timestamp) = DATE('now')
            ''')
            
            count = cursor.fetchone()[0]
            conn.close()
            return count
            
        except Exception as e:
            logger.error(f"Erro ao contar eventos: {e}")
            return 0
    
    def get_disk_usage(self) -> Dict:
        """Obtém uso de disco"""
        try:
            import shutil
            
            snapshots_dir = self.camera_config.get('storage', {}).get('snapshots_dir', 'snapshots')
            recordings_dir = self.camera_config.get('storage', {}).get('recordings_dir', 'recordings')
            
            total, used, free = shutil.disk_usage('.')
            
            return {
                "total_gb": round(total / (1024**3), 2),
                "used_gb": round(used / (1024**3), 2),
                "free_gb": round(free / (1024**3), 2),
                "used_percent": round((used / total) * 100, 1)
            }
            
        except Exception as e:
            logger.error(f"Erro ao obter uso de disco: {e}")
            return {}
    
    def run(self, host: str = '0.0.0.0', port: int = 8080, debug: bool = False):
        """Executa a aplicação web"""
        logger.info(f"Iniciando interface web em http://{host}:{port}")
        self.app.run(host=host, port=port, debug=debug, threaded=True)

# Templates HTML embutidos (básicos)
def create_templates():
    """Cria templates HTML básicos"""
    templates_dir = "templates"
    os.makedirs(templates_dir, exist_ok=True)
    
    # Template base
    base_template = '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}HomeGuard Cameras{% endblock %}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 1rem; text-align: center; }
        .container { max-width: 1200px; margin: 2rem auto; padding: 0 1rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; }
        .card { background: white; border-radius: 8px; padding: 1.5rem; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .btn { background: #3498db; color: white; border: none; padding: 0.5rem 1rem; border-radius: 4px; cursor: pointer; text-decoration: none; display: inline-block; }
        .btn:hover { background: #2980b9; }
        .status-online { color: #27ae60; font-weight: bold; }
        .status-offline { color: #e74c3c; font-weight: bold; }
        .stream-container { position: relative; background: #000; border-radius: 8px; overflow: hidden; }
        .stream-img { width: 100%; height: auto; display: block; }
        .ptz-controls { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 1rem; }
        .ptz-btn { background: #34495e; color: white; border: none; padding: 0.5rem; border-radius: 4px; cursor: pointer; }
        .ptz-btn:hover { background: #2c3e50; }
        @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
    <div class="header">
        <h1>{% block header %}HomeGuard Camera System{% endblock %}</h1>
    </div>
    <div class="container">
        {% block content %}{% endblock %}
    </div>
    <script>
        function captureSnapshot(cameraId) {
            window.open('/api/camera/' + cameraId + '/snapshot', '_blank');
        }
        
        function ptzControl(cameraId, action) {
            fetch('/api/camera/' + cameraId + '/ptz', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: action, speed: 5})
            }).then(response => response.json())
              .then(data => console.log('PTZ:', data));
        }
    </script>
</body>
</html>'''
    
    # Dashboard template
    dashboard_template = '''{% extends "base.html" %}
{% block title %}Dashboard - HomeGuard Cameras{% endblock %}
{% block content %}
<div class="grid">
    {% for camera in cameras %}
    <div class="card">
        <h3>{{ camera.name }}</h3>
        <p><strong>Local:</strong> {{ camera.location }}</p>
        <p><strong>IP:</strong> {{ camera.ip }}</p>
        <p><strong>Status:</strong> 
            {% if camera.enabled %}
            <span class="status-online">Online</span>
            {% else %}
            <span class="status-offline">Offline</span>
            {% endif %}
        </p>
        
        <div class="stream-container" style="margin: 1rem 0;">
            <img src="/api/camera/{{ camera.id }}/stream" class="stream-img" 
                 alt="Stream {{ camera.name }}" onerror="this.style.display='none'">
        </div>
        
        <div style="margin-top: 1rem;">
            <a href="/camera/{{ camera.id }}" class="btn">Ver Detalhes</a>
            <button class="btn" onclick="captureSnapshot('{{ camera.id }}')">Snapshot</button>
        </div>
        
        {% if camera.ptz_capable %}
        <div class="ptz-controls">
            <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'up')">↑</button>
            <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'down')">↓</button>
            <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'left')">←</button>
            <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'right')">→</button>
            <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'stop')">STOP</button>
        </div>
        {% endif %}
    </div>
    {% endfor %}
</div>
{% endblock %}'''
    
    # Camera view template
    camera_view_template = '''{% extends "base.html" %}
{% block title %}{{ camera.name }} - HomeGuard{% endblock %}
{% block header %}{{ camera.name }} - {{ camera.location }}{% endblock %}
{% block content %}
<div style="margin-bottom: 2rem;">
    <a href="/" class="btn">← Voltar ao Dashboard</a>
</div>

<div class="grid">
    <div class="card" style="grid-column: 1 / -1;">
        <h3>Stream ao Vivo</h3>
        <div class="stream-container">
            <img src="/api/camera/{{ camera.id }}/stream" class="stream-img" 
                 alt="Stream {{ camera.name }}">
        </div>
        
        <div style="margin-top: 1rem;">
            <button class="btn" onclick="captureSnapshot('{{ camera.id }}')">Capturar Snapshot</button>
            {% if camera.ptz_capable %}
            <div class="ptz-controls">
                <h4>Controle PTZ:</h4>
                <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'up')">↑ Cima</button>
                <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'down')">↓ Baixo</button>
                <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'left')">← Esquerda</button>
                <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'right')">→ Direita</button>
                <button class="ptz-btn" onclick="ptzControl('{{ camera.id }}', 'stop')">⏹ Parar</button>
            </div>
            {% endif %}
        </div>
    </div>
    
    <div class="card">
        <h3>Informações da Câmera</h3>
        <p><strong>ID:</strong> {{ camera.id }}</p>
        <p><strong>Nome:</strong> {{ camera.name }}</p>
        <p><strong>Local:</strong> {{ camera.location }}</p>
        <p><strong>IP:</strong> {{ camera.ip }}</p>
        <p><strong>PTZ:</strong> {{ "Sim" if camera.ptz_capable else "Não" }}</p>
        <p><strong>Detecção de Movimento:</strong> {{ "Ativada" if camera.motion_detection else "Desativada" }}</p>
    </div>
    
    <div class="card">
        <h3>Eventos Recentes</h3>
        <div id="events-list">
            <p>Carregando eventos...</p>
        </div>
    </div>
</div>

<script>
// Carregar eventos recentes
fetch('/api/camera/{{ camera.id }}/events?hours=24&limit=10')
    .then(response => response.json())
    .then(events => {
        const eventsDiv = document.getElementById('events-list');
        if (events.length === 0) {
            eventsDiv.innerHTML = '<p>Nenhum evento nas últimas 24 horas</p>';
        } else {
            eventsDiv.innerHTML = events.map(event => `
                <div style="border-bottom: 1px solid #eee; padding: 0.5rem 0;">
                    <strong>${event.event_type}</strong> - ${new Date(event.timestamp).toLocaleString('pt-BR')}
                    ${event.confidence ? ` (${Math.round(event.confidence * 100)}%)` : ''}
                </div>
            `).join('');
        }
    })
    .catch(error => {
        console.error('Erro ao carregar eventos:', error);
        document.getElementById('events-list').innerHTML = '<p>Erro ao carregar eventos</p>';
    });
</script>
{% endblock %}'''
    
    # Salvar templates
    with open(f"{templates_dir}/base.html", 'w') as f:
        f.write(base_template)
    
    with open(f"{templates_dir}/camera_dashboard.html", 'w') as f:
        f.write(dashboard_template)
    
    with open(f"{templates_dir}/camera_view.html", 'w') as f:
        f.write(camera_view_template)

def main():
    """Função principal da interface web"""
    # Criar templates se não existirem
    create_templates()
    
    # Iniciar interface web
    web_interface = CameraWebInterface()
    
    # Configuração da porta
    port = web_interface.camera_config.get('web_interface', {}).get('port', 8080)
    
    try:
        web_interface.run(port=port, debug=False)
    except KeyboardInterrupt:
        logger.info("Interface web encerrada pelo usuário")

if __name__ == "__main__":
    main()
