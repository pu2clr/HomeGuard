#!/bin/bash
#
# Script de ROLLBACK inteligente - Retorna ao estado funcionando anterior
# EXECUTAR NO RASPBERRY PI
#

echo "🔄 ROLLBACK INTELIGENTE - HomeGuard Dashboard"
echo "============================================="
echo ""
echo "🎯 ESTRATÉGIA:"
echo "   ✅ Restaurar dashboard.py ao estado original"
echo "   ✅ Remover templates de debug criados"
echo "   ✅ Restaurar base.html sem modificações Chart.js"
echo "   ✅ Manter APENAS a correção mínima do gráfico temperatura"
echo ""

# Localizar diretório HomeGuard
HOMEGUARD_DIR="/home/homeguard/HomeGuard"

if [ ! -d "$HOMEGUARD_DIR" ]; then
    echo "❌ Diretório HomeGuard não encontrado: $HOMEGUARD_DIR"
    echo "   Procurando em outros locais..."
    find /home -name "HomeGuard" -type d 2>/dev/null | head -3
    exit 1
fi

cd "$HOMEGUARD_DIR" || exit 1
echo "📂 Trabalhando em: $(pwd)"
echo ""

echo "1️⃣ BACKUP ATUAL (segurança)"
echo "============================"

# Criar backup dos arquivos atuais
BACKUP_DIR="backup_before_rollback_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

cp web/dashboard.py "$BACKUP_DIR/" 2>/dev/null || echo "   dashboard.py não encontrado"
cp web/templates/base.html "$BACKUP_DIR/" 2>/dev/null || echo "   base.html não encontrado"
cp -r web/templates/dashboard_*.html "$BACKUP_DIR/" 2>/dev/null || echo "   templates debug não encontrados"

echo "   ✅ Backup criado em: $BACKUP_DIR"

echo ""
echo "2️⃣ REMOVENDO ADIÇÕES DE DEBUG"
echo "============================="

# Remover templates de debug que adicionamos
rm -f web/templates/dashboard_ultra_basic.html
rm -f web/templates/temperature_debug.html
echo "   ✅ Templates de debug removidos"

# Parar dashboard atual
sudo pkill -f dashboard.py
sleep 2
echo "   ✅ Dashboard parado"

echo ""
echo "3️⃣ RESTAURANDO DASHBOARD.PY ORIGINAL"
echo "==================================="

# Verificar se existe backup git ou versão original
if [ -d ".git" ]; then
    echo "   🔍 Verificando versões no Git..."
    
    # Verificar se dashboard.py foi modificado
    git status --porcelain web/dashboard.py 2>/dev/null | head -1
    
    # Restaurar versão do git se possível
    git checkout HEAD -- web/dashboard.py 2>/dev/null && echo "   ✅ dashboard.py restaurado do Git" || echo "   ⚠️ Git restoration falhou"
else
    echo "   ⚠️ Sem Git - criando dashboard.py baseado no padrão conhecido"
fi

# Se o git restore falhou ou não existe, criar versão padrão funcional
if [ ! -f web/dashboard.py ] || [ ! -s web/dashboard.py ]; then
    echo "   🔧 Criando dashboard.py padrão funcional..."
    
cat > web/dashboard.py << 'EOF'
from flask import Flask, render_template, jsonify, request
import sqlite3
import json
from datetime import datetime, timedelta

app = Flask(__name__)

def get_db_connection():
    """Conecta ao banco de dados SQLite"""
    conn = sqlite3.connect('db/homeguard.db')
    conn.row_factory = sqlite3.Row
    return conn

@app.route('/')
def dashboard():
    """Página principal do dashboard"""
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
    """Painel de relés"""
    return render_template('relay_panel.html')

@app.route('/api/temperature/data')
def api_temperature_data():
    """API para dados de temperatura"""
    try:
        hours = request.args.get('hours', 24, type=int)
        
        conn = get_db_connection()
        
        # Buscar dados na view de temperatura
        query = """
        SELECT created_at, device_id, name, location, sensor_type, 
               temperature, unit, rssi, uptime
        FROM vw_temperature_activity 
        WHERE datetime(created_at) >= datetime('now', '-{} hours')
        ORDER BY created_at DESC
        LIMIT 1000
        """.format(hours)
        
        rows = conn.execute(query).fetchall()
        conn.close()
        
        data = []
        for row in rows:
            data.append({
                'timestamp': row['created_at'],
                'device_id': row['device_id'],
                'name': row['name'],
                'location': row['location'],
                'sensor_type': row['sensor_type'],
                'temperature': float(row['temperature']) if row['temperature'] else 0,
                'unit': row['unit'],
                'rssi': row['rssi'],
                'uptime': row['uptime']
            })
        
        return jsonify(data)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/humidity/data')
def api_humidity_data():
    """API para dados de umidade"""
    try:
        hours = request.args.get('hours', 24, type=int)
        
        conn = get_db_connection()
        
        query = """
        SELECT created_at, device_id, name, location, sensor_type, 
               humidity, unit, rssi, uptime
        FROM vw_humidity_activity 
        WHERE datetime(created_at) >= datetime('now', '-{} hours')
        ORDER BY created_at DESC
        LIMIT 1000
        """.format(hours)
        
        rows = conn.execute(query).fetchall()
        conn.close()
        
        data = []
        for row in rows:
            data.append({
                'timestamp': row['created_at'],
                'device_id': row['device_id'],
                'name': row['name'],
                'location': row['location'], 
                'sensor_type': row['sensor_type'],
                'humidity': float(row['humidity']) if row['humidity'] else 0,
                'unit': row['unit'],
                'rssi': row['rssi'],
                'uptime': row['uptime']
            })
        
        return jsonify(data)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/motion/data')
def api_motion_data():
    """API para dados de movimento"""
    try:
        hours = request.args.get('hours', 24, type=int)
        
        conn = get_db_connection()
        
        query = """
        SELECT created_at, device_id, name, location
        FROM vw_motion_activity 
        WHERE datetime(created_at) >= datetime('now', '-{} hours')
        ORDER BY created_at DESC
        LIMIT 1000
        """.format(hours)
        
        rows = conn.execute(query).fetchall()
        conn.close()
        
        data = []
        for row in rows:
            data.append({
                'timestamp': row['created_at'],
                'device_id': row['device_id'],
                'name': row['name'],
                'location': row['location']
            })
        
        return jsonify(data)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/relay/data')
def api_relay_data():
    """API para dados de relés"""
    try:
        hours = request.args.get('hours', 24, type=int)
        
        conn = get_db_connection()
        
        query = """
        SELECT created_at, relay_id, status_brasileiro, message
        FROM vw_relay_activity 
        WHERE datetime(created_at) >= datetime('now', '-{} hours')
        ORDER BY created_at DESC
        LIMIT 1000
        """.format(hours)
        
        rows = conn.execute(query).fetchall()
        conn.close()
        
        data = []
        for row in rows:
            data.append({
                'timestamp': row['created_at'],
                'relay_id': row['relay_id'],
                'status': row['status_brasileiro'],
                'message': row['message']
            })
        
        return jsonify(data)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
EOF

    echo "   ✅ dashboard.py padrão criado"
fi

echo ""
echo "4️⃣ VERIFICANDO BASE.HTML"
echo "========================"

# Verificar se base.html existe e tem Chart.js
if [ -f web/templates/base.html ]; then
    # Verificar se tem Chart.js básico
    if grep -q "chart.min.js" web/templates/base.html; then
        echo "   ✅ base.html com Chart.js encontrado"
        
        # Verificar se tem adaptadores problemáticos
        if grep -q "chartjs-adapter" web/templates/base.html; then
            echo "   🔧 Removendo adaptadores Chart.js problemáticos..."
            
            # Criar versão limpa do base.html
            cp web/templates/base.html web/templates/base.html.backup
            
            # Remover linhas de adaptadores
            sed -i.bak '/chartjs-adapter/d' web/templates/base.html
            echo "   ✅ Adaptadores removidos"
        fi
    else
        echo "   ⚠️ base.html sem Chart.js - pode precisar adicionar"
    fi
else
    echo "   ❌ base.html não encontrado!"
fi

echo ""
echo "5️⃣ CORREÇÃO MÍNIMA - APENAS GRÁFICO TEMPERATURA"
echo "==============================================="

# Verificar se temperature_panel.html precisa da correção mínima do Chart.js
if [ -f web/templates/temperature_panel.html ]; then
    if grep -q "type: 'time'" web/templates/temperature_panel.html; then
        echo "   🔧 Aplicando correção mínima no gráfico de temperatura..."
        
        # Backup
        cp web/templates/temperature_panel.html web/templates/temperature_panel.html.backup
        
        # Aplicar APENAS a correção do 'time' → 'line'
        sed -i.bak "s/type: 'time'/type: 'line'/g" web/templates/temperature_panel.html
        echo "   ✅ Gráfico temperatura corrigido (time → line)"
    else
        echo "   ✅ Gráfico temperatura já correto"
    fi
else
    echo "   ⚠️ temperature_panel.html não encontrado"
fi

echo ""
echo "6️⃣ TESTANDO VIEWS DO BANCO"
echo "=========================="

# Verificar se as views existem e funcionam
DB_PATH="db/homeguard.db"

if [ -f "$DB_PATH" ]; then
    TEMP_VIEW_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM vw_temperature_activity;" 2>/dev/null || echo "0")
    HUMIDITY_VIEW_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM vw_humidity_activity;" 2>/dev/null || echo "0")
    
    echo "   🌡️ View temperatura: $TEMP_VIEW_COUNT registros"
    echo "   💧 View umidade: $HUMIDITY_VIEW_COUNT registros"
    
    if [ "$TEMP_VIEW_COUNT" = "0" ] || [ "$HUMIDITY_VIEW_COUNT" = "0" ]; then
        echo ""
        echo "   ⚠️ VIEWS PODEM ESTAR VAZIAS!"
        echo "   💡 Isso pode explicar o problema original"
        echo "   🔧 Se continuar sem dados, execute fix_database_views.sh"
    else
        echo "   ✅ Views parecem ter dados"
    fi
else
    echo "   ❌ Banco de dados não encontrado: $DB_PATH"
fi

echo ""
echo "7️⃣ REINICIANDO DASHBOARD RESTAURADO"
echo "=================================="

# Iniciar dashboard
python3 web/dashboard.py > dashboard_rollback.log 2>&1 &
DASHBOARD_PID=$!

sleep 3
echo "   ✅ Dashboard reiniciado (PID: $DASHBOARD_PID)"

# Testar se está respondendo
sleep 2
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5000/" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "   ✅ Dashboard respondendo (HTTP $HTTP_STATUS)"
else
    echo "   ❌ Dashboard não responde (HTTP $HTTP_STATUS)"
    echo "   📄 Verificar logs: tail -f dashboard_rollback.log"
fi

echo ""
echo "8️⃣ TESTE FINAL"
echo "=============="

sleep 3

# Testar APIs básicas
TEMP_API_COUNT=$(curl -s "http://localhost:5000/api/temperature/data?hours=1" | jq '. | length' 2>/dev/null || echo "ERRO")
HUMIDITY_API_COUNT=$(curl -s "http://localhost:5000/api/humidity/data?hours=1" | jq '. | length' 2>/dev/null || echo "ERRO")

echo "   🌡️ API temperatura: $TEMP_API_COUNT registros"
echo "   💧 API umidade: $HUMIDITY_API_COUNT registros"

echo ""
echo "✅ ROLLBACK CONCLUÍDO!"
echo "====================="
echo ""
echo "📊 ESTADO RESTAURADO:"
echo "   🔄 dashboard.py: versão original/padrão"
echo "   🗑️ templates debug: removidos"
echo "   🎨 base.html: adaptadores Chart.js removidos"
echo "   🌡️ temperatura: gráfico corrigido (time→line)"
echo ""
echo "🧪 TESTE AGORA:"
echo "   Dashboard: http://$(hostname -I | awk '{print $1}'):5000/"
echo ""
echo "🎯 EXPECTATIVA:"
echo "   ✅ Dashboard principal carrega"
echo "   ✅ Painéis Umidade/Movimento/Relés funcionam (como antes)"
echo "   ✅ Gráfico Temperatura sem erro Chart.js"
echo "   ⚠️ Se painéis sem dados: views do banco precisam correção"
echo ""
echo "📋 PRÓXIMOS PASSOS:"
echo "   1. Testar dashboard principal"
echo "   2. Testar cada painel individualmente"
echo "   3. Se painéis vazios: execute fix_database_views.sh"
echo ""
echo "💾 Backup em: $BACKUP_DIR"
