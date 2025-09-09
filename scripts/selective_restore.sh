#!/bin/bash
#
# Script para restauração seletiva de arquivos após backup mal feito
# EXECUTAR NO RASPBERRY PI
#

echo "🔧 RESTAURAÇÃO SELETIVA: Resgatando arquivos críticos"
echo "===================================================="
echo ""

HOMEGUARD_DIR="/home/homeguard/HomeGuard"
cd "$HOMEGUARD_DIR" || exit 1

echo "🎯 OPÇÕES DE RESTAURAÇÃO:"
echo "========================"
echo ""
echo "1️⃣ Restaurar via Git (se disponível)"
echo "2️⃣ Restaurar arquivos específicos de backup"
echo "3️⃣ Recriar arquivos com configuração correta"
echo "4️⃣ Verificar e corrigir apenas configurações"
echo ""

# Função para restaurar via Git
restore_via_git() {
    echo "🔄 TENTANDO RESTAURAÇÃO VIA GIT"
    echo "==============================="
    
    if [ -d ".git" ]; then
        echo "   ✅ Repositório Git encontrado"
        
        # Mostrar status
        echo "   📊 Status atual:"
        git status --porcelain | head -10
        
        echo ""
        echo "   🔧 Arquivos que podem ser restaurados:"
        
        # Verificar arquivos modificados/deletados
        MODIFIED_FILES=$(git status --porcelain | grep -E "^ M|^ D" | awk '{print $2}')
        
        for file in $MODIFIED_FILES; do
            if [[ "$file" == web/* ]] || [[ "$file" == *.py ]]; then
                echo "      - $file"
            fi
        done
        
        echo ""
        read -p "   ❓ Restaurar arquivos via Git? (y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            # Restaurar arquivos específicos
            git checkout HEAD -- web/mqtt_activity_logger.py 2>/dev/null && echo "   ✅ mqtt_activity_logger.py restaurado"
            git checkout HEAD -- web/dashboard.py 2>/dev/null && echo "   ✅ dashboard.py restaurado"
            
            echo "   ✅ Restauração Git concluída"
            return 0
        fi
    else
        echo "   ❌ Sem repositório Git disponível"
        return 1
    fi
}

# Função para recriar mqtt_activity_logger com configuração correta
recreate_mqtt_logger() {
    echo "🔧 RECRIANDO MQTT ACTIVITY LOGGER"
    echo "================================="
    
    # Backup do arquivo atual se existir
    if [ -f "web/mqtt_activity_logger.py" ]; then
        cp web/mqtt_activity_logger.py web/mqtt_activity_logger.py.broken.$(date +%Y%m%d_%H%M%S)
        echo "   📦 Backup do arquivo problemático criado"
    fi
    
    # Criar versão correta
    cat > web/mqtt_activity_logger.py << 'EOF'
#!/usr/bin/env python3
"""
HomeGuard MQTT Activity Logger
Captures all MQTT messages from home/* topics and logs to SQLite database
"""

import paho.mqtt.client as mqtt
import sqlite3
import json
import logging
import signal
import sys
import os
from datetime import datetime
from threading import Lock
import time

# Configuration
MQTT_CONFIG = {
    'host': '192.168.1.102',  # IP CORRETO!
    'port': 1883,
    'username': 'homeguard',
    'password': 'pu2clr123456',
    'topic': 'home/#',
    'keepalive': 60
}

# Database configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DB_CONFIG = {
    'path': os.path.join(PROJECT_ROOT, 'db', 'homeguard.db'),
    'timeout': 20.0
}

# Global variables
db_lock = Lock()
message_count = 0
start_time = time.time()

# Setup logging
LOG_FILE = os.path.join(SCRIPT_DIR, 'mqtt_logger.log')
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def log_to_database(topic, message):
    """Insert MQTT message into database"""
    global message_count
    
    try:
        with db_lock:
            conn = sqlite3.connect(DB_CONFIG['path'], timeout=DB_CONFIG['timeout'])
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO activity (topic, message) 
                VALUES (?, ?)
            ''', (topic, message))
            
            conn.commit()
            message_count += 1
            
            if (message_count % 10 == 0 or 
                'status' in topic or 
                'command' in topic or
                message_count <= 5):
                logger.info(f"📝 Logged message #{message_count}: {topic}")
            
            conn.close()
            return True
            
    except sqlite3.Error as e:
        logger.error(f"❌ Database error: {e}")
        return False
    except Exception as e:
        logger.error(f"❌ Unexpected error: {e}")
        return False

def on_connect(client, userdata, flags, rc):
    """Callback for MQTT connection"""
    if rc == 0:
        logger.info("✅ Connected to MQTT broker successfully")
        client.subscribe(MQTT_CONFIG['topic'])
        logger.info(f"📡 Subscribed to topic: {MQTT_CONFIG['topic']}")
        log_to_database('system/mqtt', 'MQTT client connected successfully')
    else:
        logger.error(f"❌ Failed to connect to MQTT broker. Return code: {rc}")

def on_disconnect(client, userdata, rc):
    """Callback for MQTT disconnection"""
    if rc != 0:
        logger.warning("🔌 Unexpected MQTT disconnection. Will auto-reconnect.")
        log_to_database('system/mqtt', f'MQTT client disconnected unexpectedly: {rc}')
    else:
        logger.info("🔌 MQTT client disconnected gracefully")

def on_message(client, userdata, msg):
    """Callback for MQTT message"""
    try:
        topic = msg.topic
        message = msg.payload.decode('utf-8')
        
        # Log to database
        success = log_to_database(topic, message)
        
        # Console output
        print(f"{topic} {message}")
        
        if not success:
            logger.warning(f"⚠️ Failed to log message: {topic}")
            
    except Exception as e:
        logger.error(f"❌ Error processing message: {e}")

def signal_handler(signum, frame):
    """Handle interrupt signals"""
    logger.info(f"\n🛑 Received signal {signum}. Shutting down...")
    
    uptime = time.time() - start_time
    log_to_database('system/mqtt', f'MQTT logger shutdown - Messages: {message_count}, Uptime: {uptime:.1f}s')
    
    logger.info(f"📊 Final statistics:")
    logger.info(f"   - Total messages: {message_count}")
    logger.info(f"   - Uptime: {uptime:.1f} seconds")
    
    sys.exit(0)

def main():
    """Main function"""
    global start_time
    start_time = time.time()
    
    logger.info("🚀 Starting HomeGuard MQTT Activity Logger")
    logger.info(f"🏠 MQTT Broker: {MQTT_CONFIG['host']}:{MQTT_CONFIG['port']}")
    logger.info(f"📡 Topic filter: {MQTT_CONFIG['topic']}")
    logger.info(f"💾 Database: {DB_CONFIG['path']}")
    
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Create MQTT client
    client = mqtt.Client()
    client.username_pw_set(MQTT_CONFIG['username'], MQTT_CONFIG['password'])
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    
    try:
        # Connect and start loop
        client.connect(MQTT_CONFIG['host'], MQTT_CONFIG['port'], MQTT_CONFIG['keepalive'])
        client.loop_forever()
        
    except Exception as e:
        logger.error(f"❌ MQTT client error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    echo "   ✅ mqtt_activity_logger.py recriado com IP correto"
}

# Função principal
main_menu() {
    echo "❓ Escolha uma opção:"
    echo "   1 - Tentar restauração via Git"
    echo "   2 - Recriar mqtt_activity_logger.py"
    echo "   3 - Apenas corrigir IP no arquivo existente"
    echo "   4 - Análise completa primeiro"
    echo ""
    read -p "Opção (1-4): " option
    
    case $option in
        1)
            restore_via_git || echo "❌ Restauração Git falhou"
            ;;
        2)
            recreate_mqtt_logger
            ;;
        3)
            if [ -f "web/mqtt_activity_logger.py" ]; then
                cp web/mqtt_activity_logger.py web/mqtt_activity_logger.py.backup.$(date +%Y%m%d_%H%M%S)
                sed -i "s/'host': '192\.168\.18\.198'/'host': '192.168.1.102'/g" web/mqtt_activity_logger.py
                sed -i "s/'host': '192\.168\.1\.198'/'host': '192.168.1.102'/g" web/mqtt_activity_logger.py
                echo "   ✅ IP corrigido no arquivo existente"
            else
                echo "   ❌ Arquivo não encontrado"
            fi
            ;;
        4)
            echo "   🔍 Execute primeiro: ./scripts/analyze_backup_issues.sh"
            exit 0
            ;;
        *)
            echo "   ❌ Opção inválida"
            exit 1
            ;;
    esac
}

# Executar menu principal
main_menu

echo ""
echo "🔄 REINICIANDO SERVIÇOS"
echo "======================="

# Parar processos atuais
sudo pkill -f mqtt_activity_logger.py
sudo pkill -f dashboard.py
sleep 2

# Iniciar mqtt_activity_logger
echo "   🚀 Iniciando MQTT Logger..."
python3 web/mqtt_activity_logger.py > mqtt_logger_restored.log 2>&1 &
MQTT_PID=$!

sleep 3

# Iniciar dashboard
echo "   🌐 Iniciando Dashboard..."
python3 web/dashboard.py > dashboard_restored.log 2>&1 &
DASHBOARD_PID=$!

sleep 2

echo "   ✅ Serviços iniciados:"
echo "      - MQTT Logger: PID $MQTT_PID"
echo "      - Dashboard: PID $DASHBOARD_PID"

echo ""
echo "🧪 TESTE RÁPIDO"
echo "==============="

sleep 3

# Teste de captura
mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/test/restore" -m "teste_restauracao" 2>/dev/null

sleep 2

# Verificar se foi capturado
if [ -f "db/homeguard.db" ]; then
    RECENT_COUNT=$(sqlite3 "db/homeguard.db" "SELECT COUNT(*) FROM activity WHERE datetime(created_at) >= datetime('now', '-1 minute');" 2>/dev/null || echo "0")
    echo "   📊 Mensagens capturadas no último minuto: $RECENT_COUNT"
    
    if [ "$RECENT_COUNT" -gt 0 ]; then
        echo "   🎉 SUCESSO! Sistema de captura funcionando!"
    else
        echo "   ⚠️ Ainda sem captura - verificar logs"
    fi
fi

echo ""
echo "✅ RESTAURAÇÃO SELETIVA CONCLUÍDA!"
echo "=================================="
echo ""
echo "📊 PRÓXIMOS PASSOS:"
echo "   1. Testar dashboard: http://$(hostname -I | awk '{print $1}'):5000/"
echo "   2. Verificar painel de relés"
echo "   3. Monitorar logs por alguns minutos"
echo ""
echo "💾 LOGS CRIADOS:"
echo "   📄 mqtt_logger_restored.log"
echo "   📄 dashboard_restored.log"
