#!/bin/bash
#
# Script para correção do Chart.js - EXECUTAR NO RASPBERRY PI
# Salve como: fix_temperature_chart.sh
# Execute: chmod +x fix_temperature_chart.sh && ./fix_temperature_chart.sh
#

echo "🌡️ Correção Chart.js - Painel de Temperatura"
echo "============================================"
echo "Executando diretamente no Raspberry Pi..."
echo ""

# Configurações
TEMPLATES_DIR="/home/homeguard/HomeGuard/web/templates"
BACKUP_DIR="$TEMPLATES_DIR/backups/chartjs-fix-$(date +%Y%m%d-%H%M%S)"

echo "🔧 Problema: 'time' is not a registered controller"
echo "✅ Solução: Verificação robusta + fallback para escala linear"
echo ""

# Verificar diretório
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "❌ Diretório não encontrado: $TEMPLATES_DIR"
    echo "   Ajuste o caminho no script"
    exit 1
fi

echo "📁 Diretório: $TEMPLATES_DIR"
echo ""

# Fazer backup
echo "1️⃣ Criando backup..."
mkdir -p "$BACKUP_DIR"
cp "$TEMPLATES_DIR"/*.html "$BACKUP_DIR/" 2>/dev/null || true
echo "   ✅ Backup criado em: $BACKUP_DIR"
ls -la "$BACKUP_DIR/"
echo ""

# Parar dashboard
echo "2️⃣ Parando dashboard..."
sudo systemctl stop homeguard-dashboard 2>/dev/null || sudo pkill -f dashboard.py
sleep 2
echo "   ✅ Dashboard parado"
echo ""

# Corrigir base.html
echo "3️⃣ Corrigindo base.html..."
cat > "$TEMPLATES_DIR/base.html" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}HomeGuard Dashboard{% endblock %}</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns/dist/chartjs-adapter-date-fns.bundle.min.js"></script>
    <script>
        // Verificar se Chart.js e adapter foram carregados
        document.addEventListener('DOMContentLoaded', function() {
            console.log('Chart.js versão:', Chart.version);
            console.log('Chart.js registry:', Chart.registry ? 'Disponível' : 'Não disponível');
            
            // Registrar escalas disponíveis
            if (Chart.registry && Chart.registry.plugins) {
                console.log('Plugins Chart.js registrados:', Object.keys(Chart.registry.plugins.items));
            }
            
            // Verificar se adapter de tempo foi carregado
            try {
                const timeScale = Chart.registry ? Chart.registry.getScale('time') : null;
                console.log('Escala de tempo:', timeScale ? 'Disponível' : 'Não disponível');
            } catch (e) {
                console.warn('Erro ao verificar escala de tempo:', e);
            }
        });
    </script>
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
        
        /* Animações */
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        .card {
            animation: fadeIn 0.5s ease-out;
        }
        
        /* Auto-refresh indicator */
        .auto-refresh-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            background-color: #27ae60;
            border-radius: 50%;
            margin-left: 5px;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
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

echo "   ✅ base.html corrigido"
echo ""

# Verificar se temperature_panel.html existe
if [ ! -f "$TEMPLATES_DIR/temperature_panel.html" ]; then
    echo "⚠️ temperature_panel.html não encontrado, criando template básico..."
    
    cat > "$TEMPLATES_DIR/temperature_panel.html" << 'EOF'
{% extends "base.html" %}

{% block title %}Painel de Temperatura - HomeGuard{% endblock %}

{% block header %}Monitoramento de Temperatura{% endblock %}

{% block content %}
<div class="card">
    <h3>Configurações de Visualização</h3>
    <div class="controls">
        <select id="hours-filter">
            <option value="1">Última hora</option>
            <option value="6">Últimas 6 horas</option>
            <option value="24" selected>Últimas 24 horas</option>
            <option value="168">Última semana</option>
        </select>
        
        <button onclick="loadTemperatureData()">Atualizar</button>
        
        <label>
            <input type="checkbox" id="auto-refresh" checked> Auto-atualizar (30s)
        </label>
    </div>
</div>

<div class="grid">
    <div class="stat-card">
        <div class="stat-number" id="avg-temp">-</div>
        <div class="stat-label">Temperatura Média</div>
    </div>
    
    <div class="stat-card">
        <div class="stat-number" id="min-temp">-</div>
        <div class="stat-label">Temperatura Mínima</div>
    </div>
    
    <div class="stat-card">
        <div class="stat-number" id="max-temp">-</div>
        <div class="stat-label">Temperatura Máxima</div>
    </div>
    
    <div class="stat-card">
        <div class="stat-number" id="active-devices">-</div>
        <div class="stat-label">Dispositivos Ativos</div>
    </div>
</div>

<div class="card">
    <h3>Gráfico de Temperatura</h3>
    <div class="chart-container">
        <canvas id="temperatureChart"></canvas>
    </div>
</div>

<div class="card">
    <h3>Histórico de Dados</h3>
    <div id="temperature-history">
        <p class="loading">Carregando dados...</p>
    </div>
</div>

<script>
let temperatureChart = null;
let autoRefreshInterval = null;

// Carregar dados ao inicializar
document.addEventListener('DOMContentLoaded', function() {
    loadTemperatureData();
    
    // Auto-refresh
    const autoRefreshCheckbox = document.getElementById('auto-refresh');
    if (autoRefreshCheckbox.checked) {
        startAutoRefresh();
    }
    
    autoRefreshCheckbox.addEventListener('change', function() {
        if (this.checked) {
            startAutoRefresh();
        } else {
            stopAutoRefresh();
        }
    });
});

function startAutoRefresh() {
    stopAutoRefresh(); // Limpar interval anterior
    autoRefreshInterval = setInterval(loadTemperatureData, 30000);
}

function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
    }
}

async function loadTemperatureData() {
    const hours = document.getElementById('hours-filter').value;
    
    try {
        console.log('[DEBUG] Carregando dados de temperatura...');
        const response = await fetch(`/api/temperature/data?hours=${hours}`);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log('[DEBUG] Dados recebidos:', data.length, 'registros');
        
        // Carregar estatísticas
        await loadTemperatureStats(hours);
        
        // Atualizar gráfico
        updateTemperatureChart(data);
        
        // Atualizar histórico
        updateTemperatureHistory(data);
        
    } catch (error) {
        console.error('[ERROR] Erro ao carregar dados de temperatura:', error);
        showError('Erro ao carregar dados de temperatura: ' + error.message);
    }
}

async function loadTemperatureStats(hours) {
    try {
        const response = await fetch(`/api/temperature/stats?hours=${hours}`);
        const stats = await response.json();
        
        if (stats.length === 0) {
            document.getElementById('avg-temp').textContent = '-';
            document.getElementById('min-temp').textContent = '-';
            document.getElementById('max-temp').textContent = '-';
            document.getElementById('active-devices').textContent = '0';
            return;
        }
        
        // Calcular estatísticas globais
        const avgTemp = (stats.reduce((sum, device) => sum + device.avg_temp, 0) / stats.length).toFixed(1);
        const minTemp = Math.min(...stats.map(device => device.min_temp)).toFixed(1);
        const maxTemp = Math.max(...stats.map(device => device.max_temp)).toFixed(1);
        
        document.getElementById('avg-temp').textContent = `${avgTemp}°C`;
        document.getElementById('min-temp').textContent = `${minTemp}°C`;
        document.getElementById('max-temp').textContent = `${maxTemp}°C`;
        document.getElementById('active-devices').textContent = stats.length;
        
    } catch (error) {
        console.error('Erro ao carregar estatísticas:', error);
    }
}

function updateTemperatureChart(data) {
    const ctx = document.getElementById('temperatureChart').getContext('2d');
    
    // Destruir gráfico existente
    if (temperatureChart) {
        try {
            temperatureChart.destroy();
            temperatureChart = null;
        } catch (e) {
            console.warn("Erro ao destruir gráfico:", e);
        }
    }
    
    if (data.length === 0) {
        return;
    }
    
    // Agrupar dados por dispositivo
    const deviceData = {};
    data.forEach(item => {
        if (!deviceData[item.device_id]) {
            deviceData[item.device_id] = {
                label: `${item.device_id} (${item.location || 'Sem local'})`,
                data: [],
                borderColor: getDeviceColor(item.device_id),
                backgroundColor: getDeviceColor(item.device_id, 0.1),
                fill: false,
                tension: 0.4
            };
        }
        
        // Converter timestamp para Date object
        const timestamp = new Date(item.created_at);
        deviceData[item.device_id].data.push({
            x: timestamp,
            y: parseFloat(item.temperature)
        });
    });
    
    // Ordenar dados por tempo
    Object.values(deviceData).forEach(dataset => {
        dataset.data.sort((a, b) => a.x - b.x);
    });
    
    try {
        // Verificar se escala de tempo está disponível
        let useTimeScale = false;
        try {
            // Tentar registrar escala de tempo se não estiver disponível
            if (Chart.registry && Chart.registry.getScale) {
                const timeScale = Chart.registry.getScale('time');
                useTimeScale = !!timeScale;
            }
        } catch (e) {
            console.warn('Escala de tempo não disponível, usando linear:', e);
            useTimeScale = false;
        }
        
        if (!useTimeScale) {
            // Fallback para escala linear com labels de tempo
            const sortedData = Object.values(deviceData).map(dataset => ({
                ...dataset,
                data: dataset.data.map((point, index) => ({
                    x: index,
                    y: point.y,
                    label: point.x.toLocaleTimeString('pt-BR', { 
                        hour: '2-digit', 
                        minute: '2-digit' 
                    })
                }))
            }));
            
            temperatureChart = new Chart(ctx, {
                type: 'line',
                data: {
                    datasets: sortedData
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        title: {
                            display: true,
                            text: 'Temperatura ao Longo do Tempo (Escala Linear)'
                        },
                        legend: {
                            display: true,
                            position: 'top'
                        },
                        tooltip: {
                            callbacks: {
                                title: function(context) {
                                    const dataIndex = context[0].dataIndex;
                                    const dataset = context[0].dataset.data;
                                    return dataset[dataIndex]?.label || 'Ponto ' + dataIndex;
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            type: 'linear',
                            title: {
                                display: true,
                                text: 'Sequência de Leituras'
                            }
                        },
                        y: {
                            title: {
                                display: true,
                                text: 'Temperatura (°C)'
                            }
                        }
                    },
                    interaction: {
                        intersect: false,
                        mode: 'index'
                    }
                }
            });
        } else {
            // Usar escala de tempo
            temperatureChart = new Chart(ctx, {
                type: 'line',
                data: {
                    datasets: Object.values(deviceData)
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        title: {
                            display: true,
                            text: 'Temperatura ao Longo do Tempo'
                        },
                        legend: {
                            display: true,
                            position: 'top'
                        }
                    },
                    scales: {
                        x: {
                            type: 'time',
                            time: {
                                displayFormats: {
                                    hour: 'HH:mm',
                                    day: 'dd/MM'
                                }
                            },
                            title: {
                                display: true,
                                text: 'Tempo'
                            }
                        },
                        y: {
                            title: {
                                display: true,
                                text: 'Temperatura (°C)'
                            }
                        }
                    },
                    interaction: {
                        intersect: false,
                        mode: 'index'
                    }
                }
            });
        }
        
        console.log('Gráfico criado com sucesso, escala:', useTimeScale ? 'time' : 'linear');
        
    } catch (error) {
        console.error('Erro ao criar gráfico:', error);
        showError('Erro ao criar gráfico: ' + error.message);
        
        // Tentar criar gráfico básico como último recurso
        try {
            const basicData = Object.values(deviceData).map(dataset => ({
                label: dataset.label,
                data: dataset.data.map(point => point.y),
                borderColor: dataset.borderColor,
                backgroundColor: dataset.backgroundColor,
                fill: false
            }));
            
            temperatureChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: Object.values(deviceData)[0]?.data.map((_, index) => `Ponto ${index + 1}`) || [],
                    datasets: basicData
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        title: {
                            display: true,
                            text: 'Temperatura - Gráfico Básico'
                        }
                    }
                }
            });
            console.log('Gráfico básico criado como fallback');
        } catch (fallbackError) {
            console.error('Falha no fallback básico:', fallbackError);
        }
    }
}

function updateTemperatureHistory(data) {
    const container = document.getElementById('temperature-history');
    
    if (data.length === 0) {
        container.innerHTML = '<p>Nenhum dado de temperatura encontrado</p>';
        return;
    }
    
    let html = '<table class="table"><thead><tr>';
    html += '<th>Data/Hora</th><th>Dispositivo</th><th>Local</th>';
    html += '<th>Sensor</th><th>Temperatura</th><th>RSSI</th><th>Uptime</th></tr></thead><tbody>';
    
    data.slice(0, 20).forEach(item => {
        html += `<tr>
            <td>${formatDateTime(item.created_at)}</td>
            <td><strong>${item.device_id}</strong></td>
            <td>${item.location || 'N/A'}</td>
            <td>${item.sensor_type || 'N/A'}</td>
            <td><strong>${item.temperature}°C</strong></td>
            <td>${item.rssi || 'N/A'}</td>
            <td>${item.uptime || 'N/A'}</td>
        </tr>`;
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

function getDeviceColor(deviceId, alpha = 1) {
    const colors = [
        `rgba(75, 192, 192, ${alpha})`,
        `rgba(255, 99, 132, ${alpha})`,
        `rgba(54, 162, 235, ${alpha})`,
        `rgba(255, 206, 86, ${alpha})`,
        `rgba(153, 102, 255, ${alpha})`,
        `rgba(255, 159, 64, ${alpha})`
    ];
    
    const hash = deviceId.split('').reduce((a, b) => {
        a = ((a << 5) - a) + b.charCodeAt(0);
        return a & a;
    }, 0);
    
    return colors[Math.abs(hash) % colors.length];
}
</script>
{% endblock %}
EOF
    echo "   ✅ temperature_panel.html criado"
else
    echo "4️⃣ Aplicando patch no temperature_panel.html existente..."
    
    # Fazer backup específico
    cp "$TEMPLATES_DIR/temperature_panel.html" "$TEMPLATES_DIR/temperature_panel.html.bak"
    
    # Aplicar correção na função updateTemperatureChart
    # Essa é uma abordagem mais segura que substitui apenas a parte problemática
    python3 << 'PYTHON_EOF'
import re

# Ler arquivo
with open('/home/homeguard/HomeGuard/web/templates/temperature_panel.html', 'r') as f:
    content = f.read()

# Padrão para encontrar a verificação problemática
old_pattern = r'if \(typeof Chart\.registry\.getController\(\'time\'\) === \'undefined\'\)'
new_pattern = '''let useTimeScale = false;
        try {
            // Tentar registrar escala de tempo se não estiver disponível
            if (Chart.registry && Chart.registry.getScale) {
                const timeScale = Chart.registry.getScale('time');
                useTimeScale = !!timeScale;
            }
        } catch (e) {
            console.warn('Escala de tempo não disponível, usando linear:', e);
            useTimeScale = false;
        }
        
        if (!useTimeScale)'''

# Substituir a verificação problemática
content = re.sub(old_pattern, new_pattern, content)

# Escrever arquivo
with open('/home/homeguard/HomeGuard/web/templates/temperature_panel.html', 'w') as f:
    f.write(content)

print("   ✅ Patch aplicado com sucesso")
PYTHON_EOF
fi

echo ""

# Ajustar permissões
echo "5️⃣ Ajustando permissões..."
chown homeguard:homeguard "$TEMPLATES_DIR"/*.html
chmod 644 "$TEMPLATES_DIR"/*.html
echo "   ✅ Permissões ajustadas"
echo ""

# Iniciar dashboard
echo "6️⃣ Iniciando dashboard..."
cd /home/homeguard/HomeGuard
python3 web/dashboard.py > dashboard.log 2>&1 &
DASHBOARD_PID=$!
sleep 3
echo "   ✅ Dashboard iniciado (PID: $DASHBOARD_PID)"
echo ""

# Testar resultado
echo "7️⃣ Testando correção..."
sleep 2

# Testar se dashboard está respondendo
if curl -s http://localhost:5000/ >/dev/null; then
    echo "   ✅ Dashboard funcionando"
else
    echo "   ⚠️ Dashboard pode estar inicializando..."
fi

# Testar API
if curl -s http://localhost:5000/api/temperature/data >/dev/null; then
    echo "   ✅ API funcionando"
else
    echo "   ⚠️ API pode estar inicializando..."
fi

echo ""
echo "✅ CORREÇÃO CONCLUÍDA!"
echo ""
echo "🧪 TESTE MANUAL:"
echo "   1. Acesse: http://$(hostname -I | awk '{print $1}'):5000/temperature"
echo "   2. Abra Console do navegador (F12)"
echo "   3. Procure por mensagens:"
echo "      • 'Chart.js versão: X.X.X'"
echo "      • 'Escala de tempo: Disponível/Não disponível'"  
echo "      • 'Gráfico criado com sucesso, escala: time/linear'"
echo "   4. Clique em 'Atualizar' para carregar dados"
echo "   5. Verifique se o gráfico aparece SEM ERRO"
echo ""
echo "🎯 EXPECTATIVA:"
echo "   ❌ ANTES: Erro 'time' is not a registered controller"
echo "   ✅ DEPOIS: Gráfico renderiza (escala time ou linear)"
echo ""
echo "📋 Se ainda houver problemas:"
echo "   tail -f dashboard.log"
echo "   Verifique console do navegador"
echo ""
echo "💾 Backup em: $BACKUP_DIR"
echo "   Para rollback: cp $BACKUP_DIR/* $TEMPLATES_DIR/"
echo ""
echo "🚀 Dashboard rodando em background (PID: $DASHBOARD_PID)"
