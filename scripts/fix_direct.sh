#!/bin/bash
#
# Script de Correção Direta - EXECUTAR NO RASPBERRY PI
# Adiciona rota ultra-basic e corrige dashboard
#

echo "🔧 Correção Direta Dashboard HomeGuard"
echo "======================================"
echo ""

# Parar dashboard
echo "1️⃣ Parando dashboard..."
sudo pkill -f dashboard.py
sleep 2
echo "   ✅ Dashboard parado"

# Verificar se dashboard.py existe
DASHBOARD_FILE="/home/homeguard/HomeGuard/web/dashboard.py"

if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "❌ Arquivo dashboard.py não encontrado: $DASHBOARD_FILE"
    echo "   Verifique o caminho do projeto"
    exit 1
fi

echo ""
echo "2️⃣ Adicionando rota ultra-basic ao dashboard.py..."

# Fazer backup
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup"

# Adicionar rota se não existir
if ! grep -q "ultra-basic" "$DASHBOARD_FILE"; then
    echo "   Adicionando rota..."
    
    # Adicionar rota antes da última linha (if __name__ == '__main__')
    sed -i '/if __name__ == .__main__.:/i\
@app.route("/ultra-basic")\
def dashboard_ultra_basic():\
    return render_template("dashboard_ultra_basic.html")\
' "$DASHBOARD_FILE"
    
    echo "   ✅ Rota adicionada"
else
    echo "   ✅ Rota já existe"
fi

echo ""
echo "3️⃣ Criando template ultra-basic..."

TEMPLATES_DIR="/home/homeguard/HomeGuard/web/templates"
mkdir -p "$TEMPLATES_DIR"

cat > "$TEMPLATES_DIR/dashboard_ultra_basic.html" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Dashboard Ultra Básico - HomeGuard</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 20px; 
            background: #f0f0f0; 
        }
        .card { 
            background: white; 
            padding: 20px; 
            margin: 10px 0; 
            border-radius: 5px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
        }
        .button { 
            background: #007bff; 
            color: white; 
            padding: 10px 20px; 
            border: none; 
            border-radius: 3px; 
            cursor: pointer; 
            margin: 5px; 
        }
        .button:hover { 
            background: #0056b3; 
        }
        .data { 
            font-family: monospace; 
            background: #f8f9fa; 
            padding: 10px; 
            border-radius: 3px; 
            margin: 10px 0; 
            white-space: pre-wrap;
        }
        .error { 
            background: #f8d7da; 
            color: #721c24; 
            padding: 10px; 
            border-radius: 3px; 
            margin: 10px 0; 
        }
        .success { 
            background: #d4edda; 
            color: #155724; 
            padding: 10px; 
            border-radius: 3px; 
            margin: 10px 0; 
        }
        .status {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 15px;
            color: white;
            font-weight: bold;
            margin: 5px;
        }
        .status.ok { background: #28a745; }
        .status.error { background: #dc3545; }
        .status.warning { background: #ffc107; color: #000; }
    </style>
</head>
<body>
    <h1>🏠 HomeGuard Dashboard - Modo Ultra Básico</h1>
    <p><strong>Versão de Diagnóstico:</strong> Esta página testa diretamente as APIs sem dependências complexas.</p>
    
    <div class="card">
        <h3>🌐 Navegação</h3>
        <button class="button" onclick="location.href='/'">📊 Dashboard Principal</button>
        <button class="button" onclick="location.href='/temperature'">🌡️ Temperatura</button>
        <button class="button" onclick="location.href='/humidity'">💧 Umidade</button>
        <button class="button" onclick="location.href='/motion'">👁️ Movimento</button>
        <button class="button" onclick="location.href='/relay'">🔌 Relés</button>
    </div>
    
    <div class="card">
        <h3>🧪 Status das APIs</h3>
        <div id="api-status">
            <p>Clique em "Testar Todas as APIs" para verificar o funcionamento</p>
        </div>
        <button class="button" onclick="testAllAPIs()">🔄 Testar Todas as APIs</button>
        <button class="button" onclick="clearResults()">🗑️ Limpar Resultados</button>
    </div>
    
    <div class="card">
        <h3>📊 Dados em Tempo Real</h3>
        <div id="live-data">
            <p>Carregando dados automaticamente...</p>
        </div>
        <button class="button" onclick="loadLiveData()">🔄 Recarregar Dados</button>
    </div>
    
    <div class="card">
        <h3>🔍 Debug JavaScript</h3>
        <div id="debug-info">
            <p>Informações de debug aparecerão aqui...</p>
        </div>
    </div>

    <script>
        // Função para mostrar resultado
        function showResult(containerId, message, type = 'info') {
            const container = document.getElementById(containerId);
            const div = document.createElement('div');
            div.className = type === 'error' ? 'error' : (type === 'success' ? 'success' : 'data');
            div.textContent = new Date().toLocaleTimeString() + ': ' + message;
            container.appendChild(div);
            
            // Manter apenas os últimos 10 resultados
            while (container.children.length > 10) {
                container.removeChild(container.firstChild);
            }
        }
        
        function clearResults() {
            document.getElementById('api-status').innerHTML = '<p>Resultados limpos</p>';
        }
        
        // Teste individual de API
        async function testAPI(endpoint, name) {
            try {
                showResult('api-status', `🔄 Testando ${name}...`);
                
                const response = await fetch(`/api/${endpoint}?hours=1`);
                
                if (response.ok) {
                    const data = await response.json();
                    showResult('api-status', `✅ ${name}: OK (${data.length} registros)`, 'success');
                    
                    if (data.length > 0) {
                        const sample = JSON.stringify(data[0], null, 2);
                        showResult('api-status', `📄 Amostra ${name}:\n${sample.substring(0, 200)}...`);
                    }
                    
                    return { success: true, count: data.length, data: data };
                } else {
                    showResult('api-status', `❌ ${name}: ERRO HTTP ${response.status}`, 'error');
                    return { success: false, error: `HTTP ${response.status}` };
                }
            } catch (error) {
                showResult('api-status', `❌ ${name}: ERRO ${error.message}`, 'error');
                return { success: false, error: error.message };
            }
        }
        
        // Testar todas as APIs
        async function testAllAPIs() {
            showResult('api-status', '🚀 Iniciando teste completo das APIs...');
            
            const apis = [
                { endpoint: 'temperature/data', name: 'Temperatura' },
                { endpoint: 'humidity/data', name: 'Umidade' },
                { endpoint: 'motion/data', name: 'Movimento' },
                { endpoint: 'relay/data', name: 'Relés' },
                { endpoint: 'temperature/stats', name: 'Estatísticas' }
            ];
            
            let successCount = 0;
            
            for (const api of apis) {
                const result = await testAPI(api.endpoint, api.name);
                if (result.success) successCount++;
                
                // Pequena pausa entre testes
                await new Promise(resolve => setTimeout(resolve, 500));
            }
            
            showResult('api-status', `📋 Teste concluído: ${successCount}/${apis.length} APIs funcionando`, 
                      successCount === apis.length ? 'success' : 'error');
        }
        
        // Carregar dados em tempo real
        async function loadLiveData() {
            const container = document.getElementById('live-data');
            container.innerHTML = '🔄 Carregando dados em tempo real...';
            
            try {
                const [tempResponse, humidityResponse] = await Promise.all([
                    fetch('/api/temperature/data?hours=1'),
                    fetch('/api/humidity/data?hours=1')
                ]);
                
                let html = '<h4>📊 Dados Atuais:</h4>';
                
                if (tempResponse.ok) {
                    const tempData = await tempResponse.json();
                    html += `<div class="data"><strong>🌡️ Temperatura:</strong> ${tempData.length} registros`;
                    
                    if (tempData.length > 0) {
                        const latest = tempData[0];
                        html += `\n📍 Mais recente: ${latest.device_id} = ${latest.temperature}°C`;
                        html += `\n🕒 Horário: ${latest.created_at}`;
                        html += `\n📍 Local: ${latest.location || 'N/A'}`;
                    }
                    html += '</div>';
                }
                
                if (humidityResponse.ok) {
                    const humidityData = await humidityResponse.json();
                    html += `<div class="data"><strong>💧 Umidade:</strong> ${humidityData.length} registros`;
                    
                    if (humidityData.length > 0) {
                        const latest = humidityData[0];
                        html += `\n📍 Mais recente: ${latest.device_id} = ${latest.humidity}%`;
                        html += `\n🕒 Horário: ${latest.created_at}`;
                    }
                    html += '</div>';
                }
                
                // Adicionar status visual
                const tempOk = tempResponse.ok;
                const humidityOk = humidityResponse.ok;
                
                html += '<div><strong>🔍 Status:</strong>';
                html += `<span class="status ${tempOk ? 'ok' : 'error'}">Temp ${tempOk ? 'OK' : 'ERRO'}</span>`;
                html += `<span class="status ${humidityOk ? 'ok' : 'error'}">Umid ${humidityOk ? 'OK' : 'ERRO'}</span>`;
                html += '</div>';
                
                container.innerHTML = html;
                
            } catch (error) {
                container.innerHTML = `<div class="error">❌ Erro ao carregar dados: ${error.message}</div>`;
            }
        }
        
        // Debug JavaScript
        function updateDebugInfo() {
            const debugContainer = document.getElementById('debug-info');
            
            let info = `🔍 Informações de Debug:\n`;
            info += `📅 Horário: ${new Date().toLocaleString()}\n`;
            info += `🌐 URL: ${window.location.href}\n`;
            info += `📱 User Agent: ${navigator.userAgent.substring(0, 100)}...\n`;
            info += `🔧 Fetch API: ${typeof fetch !== 'undefined' ? 'Disponível' : 'Não disponível'}\n`;
            info += `📊 JSON: ${typeof JSON !== 'undefined' ? 'Disponível' : 'Não disponível'}\n`;
            
            debugContainer.innerHTML = `<div class="data">${info}</div>`;
        }
        
        // Inicialização automática
        document.addEventListener('DOMContentLoaded', function() {
            updateDebugInfo();
            loadLiveData();
            
            // Auto-refresh a cada 60 segundos
            setInterval(loadLiveData, 60000);
            setInterval(updateDebugInfo, 30000);
        });
    </script>
</body>
</html>
EOF

echo "   ✅ Template ultra-basic criado"

echo ""
echo "4️⃣ Verificando estrutura do projeto..."

# Listar estrutura
echo "   📁 Estrutura web/:"
ls -la "/home/homeguard/HomeGuard/web/" || echo "   ⚠️ Diretório web não encontrado"

echo "   📁 Templates:"
ls -la "$TEMPLATES_DIR/" || echo "   ⚠️ Diretório templates não encontrado"

echo ""
echo "5️⃣ Iniciando dashboard..."

cd /home/homeguard/HomeGuard

# Verificar se existe requirements.txt e instalar dependências se necessário
if [ -f "requirements.txt" ]; then
    echo "   📦 Instalando dependências..."
    pip3 install -r requirements.txt > /dev/null 2>&1
fi

# Iniciar dashboard com logs detalhados
echo "   🚀 Iniciando dashboard..."
python3 web/dashboard.py > dashboard_ultra_debug.log 2>&1 &
DASHBOARD_PID=$!

sleep 5

# Verificar se está rodando
if ps -p $DASHBOARD_PID > /dev/null; then
    echo "   ✅ Dashboard iniciado (PID: $DASHBOARD_PID)"
else
    echo "   ❌ Falha ao iniciar dashboard"
    echo "   📄 Últimas linhas do log:"
    tail -20 dashboard_ultra_debug.log 2>/dev/null || echo "   Log não encontrado"
fi

echo ""
echo "6️⃣ Testando conectividade..."

sleep 2

# Testar página principal
if curl -s http://localhost:5000/ > /dev/null; then
    echo "   ✅ Dashboard principal: OK"
else
    echo "   ❌ Dashboard principal: ERRO"
fi

# Testar ultra-basic
if curl -s http://localhost:5000/ultra-basic > /dev/null; then
    echo "   ✅ Ultra-basic: OK"
else
    echo "   ❌ Ultra-basic: ERRO"
fi

# Testar API
if curl -s http://localhost:5000/api/temperature/data > /dev/null; then
    echo "   ✅ API: OK"
else
    echo "   ❌ API: ERRO"
fi

echo ""
echo "✅ CORREÇÃO CONCLUÍDA!"
echo "====================="
echo ""
echo "🧪 TESTES:"
echo "   Dashboard: http://$(hostname -I | awk '{print $1}'):5000/"
echo "   Ultra-básico: http://$(hostname -I | awk '{print $1}'):5000/ultra-basic"
echo ""
echo "📋 Se ultra-basic não funcionar:"
echo "   1. Verifique logs: tail -f dashboard_ultra_debug.log"
echo "   2. Verifique se Flask está rodando: ps aux | grep dashboard"
echo "   3. Verifique porta: netstat -tlnp | grep 5000"
echo ""
echo "🎯 O ultra-basic DEVE funcionar agora!"
echo "   Se funcionar: problema era nos templates complexos"
echo "   Se não funcionar: problema é no Flask/backend"
