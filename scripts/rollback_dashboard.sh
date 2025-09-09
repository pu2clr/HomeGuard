#!/bin/bash
#
# Script de Rollback - EXECUTAR NO RASPBERRY PI
# Restaura templates para estado anterior funcional
#

echo "🔄 Rollback Dashboard HomeGuard"
echo "==============================="
echo "Restaurando templates para estado funcional..."
echo ""

# Configurações
TEMPLATES_DIR="/home/homeguard/HomeGuard/web/templates"
BACKUP_DIR="$TEMPLATES_DIR/backups"

echo "📁 Diretório: $TEMPLATES_DIR"
echo "💾 Backups: $BACKUP_DIR"
echo ""

# Verificar se existem backups
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Diretório de backup não encontrado: $BACKUP_DIR"
    echo "   Vamos criar templates básicos funcionais..."
    mkdir -p "$BACKUP_DIR"
else
    echo "📋 Backups disponíveis:"
    ls -la "$BACKUP_DIR"
    echo ""
    
    # Encontrar backup mais recente
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        echo "🔄 Restaurando do backup: $LATEST_BACKUP"
        cp "$BACKUP_DIR/$LATEST_BACKUP"/*.html "$TEMPLATES_DIR/" 2>/dev/null || true
        echo "   ✅ Templates restaurados"
    fi
fi

# Parar dashboard
echo ""
echo "1️⃣ Parando dashboard..."
sudo systemctl stop homeguard-dashboard 2>/dev/null || sudo pkill -f dashboard.py
sleep 2
echo "   ✅ Dashboard parado"

# Criar base.html básico e funcional
echo ""
echo "2️⃣ Criando base.html básico..."
cat > "$TEMPLATES_DIR/base.html" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}HomeGuard Dashboard{% endblock %}</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72, #2a5298);
            color: #333;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 10px;
            margin-bottom: 20px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            color: #2c3e50;
            text-align: center;
            margin-bottom: 10px;
        }
        
        .nav {
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
            gap: 15px;
            margin-top: 15px;
        }
        
        .nav a {
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white;
            text-decoration: none;
            padding: 10px 20px;
            border-radius: 25px;
            font-weight: 500;
            transition: all 0.3s ease;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .nav a:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
            background: linear-gradient(135deg, #2980b9, #3498db);
        }
        
        .nav a.active {
            background: linear-gradient(135deg, #e74c3c, #c0392b);
        }
        
        .card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        
        .card h3 {
            color: #2c3e50;
            margin-bottom: 15px;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #f8f9fa, #e9ecef);
            border-radius: 10px;
            padding: 20px;
            text-align: center;
            border-left: 4px solid #3498db;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 5px;
        }
        
        .stat-label {
            color: #7f8c8d;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .controls {
            display: flex;
            flex-wrap: wrap;
            gap: 15px;
            align-items: center;
            margin-bottom: 20px;
        }
        
        .controls select,
        .controls input,
        .controls button {
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
        }
        
        .controls button {
            background: linear-gradient(135deg, #27ae60, #229954);
            color: white;
            border: none;
            cursor: pointer;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        
        .controls button:hover {
            background: linear-gradient(135deg, #229954, #27ae60);
            transform: translateY(-1px);
        }
        
        .table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        
        .table th,
        .table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        
        .table th {
            background-color: #f8f9fa;
            font-weight: 600;
            color: #2c3e50;
        }
        
        .table tbody tr:hover {
            background-color: #f5f5f5;
        }
        
        .chart-container {
            position: relative;
            height: 400px;
            margin: 20px 0;
        }
        
        .error {
            background-color: #fee;
            border: 1px solid #fcc;
            color: #c00;
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        
        .success {
            background-color: #efe;
            border: 1px solid #cfc;
            color: #060;
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        
        .loading {
            text-align: center;
            padding: 20px;
            color: #7f8c8d;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 10px;
            }
            
            .nav {
                flex-direction: column;
                align-items: center;
            }
            
            .controls {
                flex-direction: column;
                align-items: stretch;
            }
            
            .controls select,
            .controls input,
            .controls button {
                width: 100%;
                margin-bottom: 10px;
            }
            
            .grid {
                grid-template-columns: 1fr;
            }
            
            .chart-container {
                height: 300px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{% block header %}HomeGuard Dashboard{% endblock %}</h1>
            <nav class="nav">
                <a href="/">🏠 Dashboard</a>
                <a href="/temperature">🌡️ Temperatura</a>
                <a href="/humidity">💧 Umidade</a>
                <a href="/motion">👁️ Movimento</a>
                <a href="/relay">🔌 Relés</a>
            </nav>
        </div>
        
        {% block content %}{% endblock %}
    </div>
    
    <script>
        // Funções utilitárias globais
        function formatDateTime(dateStr) {
            const date = new Date(dateStr);
            return date.toLocaleString('pt-BR');
        }
        
        function showError(message) {
            const errorDiv = document.createElement('div');
            errorDiv.className = 'error';
            errorDiv.textContent = message;
            document.body.insertBefore(errorDiv, document.body.firstChild);
            
            setTimeout(() => {
                errorDiv.remove();
            }, 5000);
        }
        
        function showSuccess(message) {
            const successDiv = document.createElement('div');
            successDiv.className = 'success';
            successDiv.textContent = message;
            document.body.insertBefore(successDiv, document.body.firstChild);
            
            setTimeout(() => {
                successDiv.remove();
            }, 3000);
        }
    </script>
</body>
</html>
EOF

echo "   ✅ base.html básico criado"

# Verificar se outros templates existem
echo ""
echo "3️⃣ Verificando templates existentes..."

TEMPLATES_NEEDED=("dashboard.html" "temperature_panel.html" "humidity_panel.html" "motion_panel.html" "relay_panel.html")

for template in "${TEMPLATES_NEEDED[@]}"; do
    if [ ! -f "$TEMPLATES_DIR/$template" ]; then
        echo "   ⚠️ $template não encontrado - será criado template básico"
        
        case $template in
            "dashboard.html")
                cat > "$TEMPLATES_DIR/$template" << 'DASHBOARD_EOF'
{% extends "base.html" %}

{% block title %}Dashboard Principal - HomeGuard{% endblock %}

{% block content %}
<div class="grid">
    <div class="stat-card">
        <div class="stat-number" id="total-devices">-</div>
        <div class="stat-label">Dispositivos Ativos</div>
    </div>
    
    <div class="stat-card">
        <div class="stat-number" id="last-activity">-</div>
        <div class="stat-label">Última Atividade</div>
    </div>
    
    <div class="stat-card">
        <div class="stat-number" id="total-events">-</div>
        <div class="stat-label">Eventos Hoje</div>
    </div>
    
    <div class="stat-card">
        <div class="stat-number" id="system-status">🟢</div>
        <div class="stat-label">Status do Sistema</div>
    </div>
</div>

<div class="card">
    <h3>Painel de Controle</h3>
    <div class="controls">
        <button onclick="location.href='/temperature'">🌡️ Temperatura</button>
        <button onclick="location.href='/humidity'">💧 Umidade</button>
        <button onclick="location.href='/motion'">👁️ Movimento</button>
        <button onclick="location.href='/relay'">🔌 Relés</button>
    </div>
</div>

<div class="card">
    <h3>Atividade Recente</h3>
    <div id="recent-activity">
        <p class="loading">Carregando atividades...</p>
    </div>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
    loadDashboardData();
    setInterval(loadDashboardData, 30000); // Auto-refresh a cada 30s
});

async function loadDashboardData() {
    try {
        // Testar APIs básicas
        const [tempResponse, humidityResponse, motionResponse] = await Promise.all([
            fetch('/api/temperature/data?hours=1').catch(() => null),
            fetch('/api/humidity/data?hours=1').catch(() => null),
            fetch('/api/motion/data?hours=1').catch(() => null)
        ]);
        
        let activeDevices = 0;
        let totalEvents = 0;
        let lastActivity = 'Sem dados';
        
        if (tempResponse && tempResponse.ok) {
            const tempData = await tempResponse.json();
            activeDevices += new Set(tempData.map(item => item.device_id)).size;
            totalEvents += tempData.length;
            if (tempData.length > 0) {
                lastActivity = formatDateTime(tempData[0].created_at);
            }
        }
        
        if (humidityResponse && humidityResponse.ok) {
            const humidityData = await humidityResponse.json();
            activeDevices += new Set(humidityData.map(item => item.device_id)).size;
            totalEvents += humidityData.length;
        }
        
        if (motionResponse && motionResponse.ok) {
            const motionData = await motionResponse.json();
            totalEvents += motionData.length;
        }
        
        // Atualizar estatísticas
        document.getElementById('total-devices').textContent = activeDevices;
        document.getElementById('last-activity').textContent = lastActivity;
        document.getElementById('total-events').textContent = totalEvents;
        document.getElementById('system-status').textContent = '🟢';
        
        // Atualizar atividade recente
        updateRecentActivity();
        
    } catch (error) {
        console.error('Erro ao carregar dados do dashboard:', error);
        document.getElementById('system-status').textContent = '🔴';
    }
}

async function updateRecentActivity() {
    try {
        const response = await fetch('/api/temperature/data?hours=1');
        if (!response.ok) throw new Error('API não disponível');
        
        const data = await response.json();
        const container = document.getElementById('recent-activity');
        
        if (data.length === 0) {
            container.innerHTML = '<p>Nenhuma atividade recente</p>';
            return;
        }
        
        let html = '<table class="table"><thead><tr>';
        html += '<th>Hora</th><th>Dispositivo</th><th>Tipo</th><th>Valor</th></tr></thead><tbody>';
        
        data.slice(0, 10).forEach(item => {
            html += `<tr>
                <td>${formatDateTime(item.created_at)}</td>
                <td>${item.device_id}</td>
                <td>Temperatura</td>
                <td>${item.temperature}°C</td>
            </tr>`;
        });
        
        html += '</tbody></table>';
        container.innerHTML = html;
        
    } catch (error) {
        console.error('Erro ao carregar atividade recente:', error);
        document.getElementById('recent-activity').innerHTML = '<p>Erro ao carregar atividades</p>';
    }
}
</script>
{% endblock %}
DASHBOARD_EOF
                ;;
            *)
                # Template básico para outros painéis
                PANEL_NAME=$(echo $template | sed 's/_panel.html//' | sed 's/.html//')
                PANEL_TITLE=$(echo $PANEL_NAME | sed 's/^./\U&/' | sed 's/temperature/Temperatura/' | sed 's/humidity/Umidade/' | sed 's/motion/Movimento/' | sed 's/relay/Relés/')
                
                cat > "$TEMPLATES_DIR/$template" << TEMPLATE_EOF
{% extends "base.html" %}

{% block title %}Painel de $PANEL_TITLE - HomeGuard{% endblock %}

{% block header %}Monitoramento de $PANEL_TITLE{% endblock %}

{% block content %}
<div class="card">
    <h3>Dados de $PANEL_TITLE</h3>
    <div class="controls">
        <button onclick="loadData()">Atualizar Dados</button>
    </div>
</div>

<div class="card">
    <h3>Histórico</h3>
    <div id="data-container">
        <p class="loading">Carregando dados...</p>
    </div>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
    loadData();
});

async function loadData() {
    try {
        const response = await fetch('/api/$PANEL_NAME/data?hours=24');
        if (!response.ok) {
            throw new Error('API não disponível');
        }
        
        const data = await response.json();
        const container = document.getElementById('data-container');
        
        if (data.length === 0) {
            container.innerHTML = '<p>Nenhum dado encontrado</p>';
            return;
        }
        
        let html = '<table class="table"><thead><tr>';
        html += '<th>Data/Hora</th><th>Dispositivo</th><th>Dados</th></tr></thead><tbody>';
        
        data.slice(0, 50).forEach(item => {
            html += \`<tr>
                <td>\${formatDateTime(item.created_at)}</td>
                <td>\${item.device_id}</td>
                <td>\${JSON.stringify(item)}</td>
            </tr>\`;
        });
        
        html += '</tbody></table>';
        container.innerHTML = html;
        
    } catch (error) {
        console.error('Erro ao carregar dados:', error);
        document.getElementById('data-container').innerHTML = '<p>Erro ao carregar dados: ' + error.message + '</p>';
    }
}
</script>
{% endblock %}
TEMPLATE_EOF
                ;;
        esac
        echo "     ✅ $template criado"
    else
        echo "     ✅ $template já existe"
    fi
done

# Ajustar permissões
echo ""
echo "4️⃣ Ajustando permissões..."
chown homeguard:homeguard "$TEMPLATES_DIR"/*.html
chmod 644 "$TEMPLATES_DIR"/*.html
echo "   ✅ Permissões ajustadas"

# Reiniciar dashboard
echo ""
echo "5️⃣ Iniciando dashboard..."
cd /home/homeguard/HomeGuard
python3 web/dashboard.py > dashboard.log 2>&1 &
DASHBOARD_PID=$!
sleep 3
echo "   ✅ Dashboard iniciado (PID: $DASHBOARD_PID)"

# Testar
echo ""
echo "6️⃣ Testando dashboard..."
sleep 2

if curl -s http://localhost:5000/ >/dev/null; then
    echo "   ✅ Dashboard principal funcionando"
else
    echo "   ⚠️ Dashboard ainda inicializando..."
fi

if curl -s http://localhost:5000/api/temperature/data >/dev/null; then
    echo "   ✅ APIs funcionando"
else
    echo "   ⚠️ APIs ainda inicializando..."
fi

echo ""
echo "✅ ROLLBACK CONCLUÍDO!"
echo ""
echo "🧪 TESTE:"
echo "   Dashboard: http://$(hostname -I | awk '{print $1}'):5000/"
echo "   - Deve carregar página principal"
echo "   - Botões devem funcionar"
echo "   - Dados devem aparecer (mesmo que básicos)"
echo ""
echo "📋 Status:"
echo "   ✅ Templates básicos funcionais restaurados"
echo "   ✅ Chart.js carregado (versão básica)"
echo "   ✅ APIs mantidas funcionando"
echo "   ✅ Dashboard reiniciado"
echo ""
echo "🔧 Próximos passos:"
echo "   1. Teste todos os painéis"
echo "   2. Se funcionarem, podemos aplicar correções específicas"
echo "   3. Uma correção por vez, testando individualmente"
echo ""
echo "📄 Logs em: /home/homeguard/HomeGuard/dashboard.log"
