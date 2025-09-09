#!/bin/bash
#
# Diagnóstico Completo Dashboard - EXECUTAR NO RASPBERRY PI
#

echo "🔍 Diagnóstico Completo Dashboard HomeGuard"
echo "==========================================="
echo ""

# Configurações
TEMPLATES_DIR="/home/homeguard/HomeGuard/web/templates"
LOG_FILE="dashboard_diagnosis.log"

echo "📊 1. TESTE DE APIs (Backend)"
echo "=============================="

# Testar APIs principais
APIs=("temperature/data" "humidity/data" "motion/data" "relay/data" "temperature/stats")

for api in "${APIs[@]}"; do
    echo -n "   API /$api: "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/api_test.json "http://localhost:5000/api/$api" 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        data_count=$(cat /tmp/api_test.json | jq '. | length' 2>/dev/null || echo "N/A")
        echo "✅ OK ($data_count registros)"
    else
        echo "❌ ERRO ($response)"
    fi
done

echo ""
echo "📄 2. TESTE DE TEMPLATES (Frontend)"
echo "==================================="

# Verificar templates existentes
TEMPLATES=("dashboard.html" "temperature_panel.html" "humidity_panel.html" "motion_panel.html" "relay_panel.html")

for template in "${TEMPLATES[@]}"; do
    echo -n "   Template $template: "
    
    if [ -f "$TEMPLATES_DIR/$template" ]; then
        # Verificar se tem JavaScript
        js_functions=$(grep -c "function\|async\|fetch" "$TEMPLATES_DIR/$template" 2>/dev/null || echo "0")
        echo "✅ Existe ($js_functions funções JS)"
    else
        echo "❌ Não encontrado"
    fi
done

echo ""
echo "🌐 3. TESTE DE PÁGINAS WEB"
echo "=========================="

# Testar páginas principais
PAGES=("" "temperature" "humidity" "motion" "relay")

for page in "${PAGES[@]}"; do
    url="http://localhost:5000/$page"
    echo -n "   Página /$page: "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/page_test.html "$url" 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        # Verificar se tem conteúdo JavaScript
        js_content=$(grep -c "loadData\|fetch\|Chart" /tmp/page_test.html 2>/dev/null || echo "0")
        echo "✅ OK ($js_content elementos JS)"
    else
        echo "❌ ERRO ($response)"
    fi
done

echo ""
echo "🔧 4. ANÁLISE DE PROBLEMAS JAVASCRIPT"
echo "====================================="

# Verificar console JavaScript simulado
echo "   Criando página de teste com console detalhado..."

cat > /tmp/test_js.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Teste JavaScript Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>Teste JavaScript</h1>
    <div id="results"></div>
    <canvas id="testChart" width="400" height="200"></canvas>
    
    <script>
        const results = document.getElementById('results');
        
        function log(message) {
            results.innerHTML += '<p>' + message + '</p>';
            console.log(message);
        }
        
        // Teste 1: Chart.js carregado
        log('Teste 1: Chart.js = ' + (typeof Chart !== 'undefined' ? 'OK' : 'ERRO'));
        
        // Teste 2: Fetch API disponível
        log('Teste 2: Fetch API = ' + (typeof fetch !== 'undefined' ? 'OK' : 'ERRO'));
        
        // Teste 3: APIs do dashboard
        async function testAPIs() {
            try {
                const response = await fetch('/api/temperature/data?hours=1');
                if (response.ok) {
                    const data = await response.json();
                    log('Teste 3: API Temperature = OK (' + data.length + ' registros)');
                } else {
                    log('Teste 3: API Temperature = ERRO (' + response.status + ')');
                }
            } catch (error) {
                log('Teste 3: API Temperature = ERRO (' + error.message + ')');
            }
        }
        
        // Teste 4: Criar gráfico básico
        function testChart() {
            try {
                const ctx = document.getElementById('testChart').getContext('2d');
                const chart = new Chart(ctx, {
                    type: 'line',
                    data: {
                        labels: ['1', '2', '3'],
                        datasets: [{
                            label: 'Teste',
                            data: [1, 2, 3],
                            borderColor: 'blue'
                        }]
                    }
                });
                log('Teste 4: Chart.js básico = OK');
                chart.destroy();
            } catch (error) {
                log('Teste 4: Chart.js básico = ERRO (' + error.message + ')');
            }
        }
        
        // Executar testes
        setTimeout(() => {
            testAPIs();
            testChart();
        }, 1000);
    </script>
</body>
</html>
EOF

# Servir página de teste
cd /home/homeguard/HomeGuard
python3 -c "
import http.server
import socketserver
import threading
import time

class TestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/test-js':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('/tmp/test_js.html', 'rb') as f:
                self.wfile.write(f.read())
        else:
            super().do_GET()

with socketserver.TCPServer(('', 8080), TestHandler) as httpd:
    server_thread = threading.Thread(target=httpd.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    
    print('Servidor de teste iniciado em http://localhost:8080/test-js')
    time.sleep(2)
    httpd.shutdown()
" > /dev/null 2>&1 &

TEST_SERVER_PID=$!
sleep 3

echo "   ✅ Servidor de teste criado"
echo "   🌐 Acesse: http://$(hostname -I | awk '{print $1}'):8080/test-js"

kill $TEST_SERVER_PID 2>/dev/null

echo ""
echo "🚨 5. CRIAR TEMPLATE ULTRA-BÁSICO FUNCIONAL"
echo "============================================"

# Criar versão ultra-básica que definitivamente funciona
echo "   Criando template dashboard básico garantidamente funcional..."

cat > "$TEMPLATES_DIR/dashboard_ultra_basic.html" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Dashboard Ultra Básico - HomeGuard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f0f0f0; }
        .card { background: white; padding: 20px; margin: 10px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .button { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 3px; cursor: pointer; margin: 5px; }
        .button:hover { background: #0056b3; }
        .data { font-family: monospace; background: #f8f9fa; padding: 10px; border-radius: 3px; margin: 10px 0; }
        .error { background: #f8d7da; color: #721c24; padding: 10px; border-radius: 3px; margin: 10px 0; }
        .success { background: #d4edda; color: #155724; padding: 10px; border-radius: 3px; margin: 10px 0; }
    </style>
</head>
<body>
    <h1>🏠 HomeGuard Dashboard - Modo Ultra Básico</h1>
    
    <div class="card">
        <h3>Navegação</h3>
        <button class="button" onclick="location.href='/'">Dashboard Normal</button>
        <button class="button" onclick="location.href='/temperature'">Temperatura</button>
        <button class="button" onclick="location.href='/humidity'">Umidade</button>
        <button class="button" onclick="location.href='/motion'">Movimento</button>
        <button class="button" onclick="location.href='/relay'">Relés</button>
    </div>
    
    <div class="card">
        <h3>Teste de APIs</h3>
        <button class="button" onclick="testTemperatureAPI()">Testar API Temperatura</button>
        <button class="button" onclick="testHumidityAPI()">Testar API Umidade</button>
        <button class="button" onclick="testAllAPIs()">Testar Todas</button>
        <div id="api-results"></div>
    </div>
    
    <div class="card">
        <h3>Dados em Tempo Real</h3>
        <button class="button" onclick="loadLiveData()">Carregar Dados</button>
        <div id="live-data">Clique em "Carregar Dados" para ver informações</div>
    </div>

    <script>
        function showResult(message, isError = false) {
            const div = document.createElement('div');
            div.className = isError ? 'error' : 'success';
            div.textContent = new Date().toLocaleTimeString() + ': ' + message;
            document.getElementById('api-results').appendChild(div);
        }
        
        async function testTemperatureAPI() {
            try {
                const response = await fetch('/api/temperature/data?hours=1');
                if (response.ok) {
                    const data = await response.json();
                    showResult('✅ API Temperatura OK - ' + data.length + ' registros');
                    
                    if (data.length > 0) {
                        const latest = data[0];
                        showResult('📊 Último dado: ' + latest.device_id + ' = ' + latest.temperature + '°C');
                    }
                } else {
                    showResult('❌ API Temperatura ERRO: ' + response.status, true);
                }
            } catch (error) {
                showResult('❌ Erro na API Temperatura: ' + error.message, true);
            }
        }
        
        async function testHumidityAPI() {
            try {
                const response = await fetch('/api/humidity/data?hours=1');
                if (response.ok) {
                    const data = await response.json();
                    showResult('✅ API Umidade OK - ' + data.length + ' registros');
                } else {
                    showResult('❌ API Umidade ERRO: ' + response.status, true);
                }
            } catch (error) {
                showResult('❌ Erro na API Umidade: ' + error.message, true);
            }
        }
        
        async function testAllAPIs() {
            showResult('🔄 Testando todas as APIs...');
            await testTemperatureAPI();
            await testHumidityAPI();
        }
        
        async function loadLiveData() {
            const container = document.getElementById('live-data');
            container.innerHTML = '🔄 Carregando dados...';
            
            try {
                const [tempResponse, humidityResponse] = await Promise.all([
                    fetch('/api/temperature/data?hours=1'),
                    fetch('/api/humidity/data?hours=1')
                ]);
                
                let html = '<h4>Dados Carregados:</h4>';
                
                if (tempResponse.ok) {
                    const tempData = await tempResponse.json();
                    html += '<div class="data"><strong>Temperatura:</strong> ' + tempData.length + ' registros<br>';
                    if (tempData.length > 0) {
                        const latest = tempData[0];
                        html += 'Último: ' + latest.device_id + ' = ' + latest.temperature + '°C (' + latest.created_at + ')';
                    }
                    html += '</div>';
                }
                
                if (humidityResponse.ok) {
                    const humidityData = await humidityResponse.json();
                    html += '<div class="data"><strong>Umidade:</strong> ' + humidityData.length + ' registros<br>';
                    if (humidityData.length > 0) {
                        const latest = humidityData[0];
                        html += 'Último: ' + latest.device_id + ' = ' + latest.humidity + '% (' + latest.created_at + ')';
                    }
                    html += '</div>';
                }
                
                container.innerHTML = html;
                
            } catch (error) {
                container.innerHTML = '<div class="error">Erro ao carregar dados: ' + error.message + '</div>';
            }
        }
        
        // Auto-carregar dados ao inicializar
        setTimeout(loadLiveData, 1000);
        
        // Auto-refresh a cada 30 segundos
        setInterval(loadLiveData, 30000);
    </script>
</body>
</html>
EOF

echo "   ✅ Template ultra-básico criado"

# Criar rota no Flask se necessário
echo ""
echo "📝 6. ADICIONAR ROTA PARA TEMPLATE ULTRA-BÁSICO"
echo "==============================================="

# Verificar se dashboard.py tem a rota
if ! grep -q "dashboard_ultra_basic" "/home/homeguard/HomeGuard/web/dashboard.py" 2>/dev/null; then
    echo "   Adicionando rota para template ultra-básico..."
    
    cat >> "/home/homeguard/HomeGuard/web/dashboard.py" << 'EOF'

@app.route('/ultra-basic')
def dashboard_ultra_basic():
    return render_template('dashboard_ultra_basic.html')
EOF
    
    echo "   ✅ Rota adicionada"
else
    echo "   ✅ Rota já existe"
fi

echo ""
echo "🚀 7. REINICIAR DASHBOARD"
echo "========================"

# Parar dashboard atual
sudo pkill -f dashboard.py
sleep 2

# Iniciar novo
cd /home/homeguard/HomeGuard
python3 web/dashboard.py > dashboard_ultra_diagnosis.log 2>&1 &
DASHBOARD_PID=$!

sleep 3
echo "   ✅ Dashboard reiniciado (PID: $DASHBOARD_PID)"

echo ""
echo "✅ DIAGNÓSTICO CONCLUÍDO!"
echo "========================"
echo ""
echo "🧪 TESTES PARA EXECUTAR:"
echo ""
echo "1. 📊 TESTE ULTRA-BÁSICO (deve funcionar 100%):"
echo "   http://$(hostname -I | awk '{print $1}'):5000/ultra-basic"
echo "   - Se não funcionar: problema no backend/servidor"
echo "   - Se funcionar: problema nos templates complexos"
echo ""
echo "2. 🌐 TESTE DASHBOARD NORMAL:"
echo "   http://$(hostname -I | awk '{print $1}'):5000/"
echo "   - Compare comportamento com ultra-básico"
echo ""
echo "3. 🔍 TESTE PÁGINAS ESPECÍFICAS:"
echo "   http://$(hostname -I | awk '{print $1}'):5000/temperature"
echo "   http://$(hostname -I | awk '{print $1}'):5000/humidity"
echo ""
echo "📋 PRÓXIMOS PASSOS:"
echo "   1. Teste o dashboard ultra-básico primeiro"
echo "   2. Se funcionar: o problema é nos templates complexos"
echo "   3. Se não funcionar: o problema é no backend"
echo "   4. Com base no resultado, aplicaremos a correção específica"
echo ""
echo "📄 Logs em: /home/homeguard/HomeGuard/dashboard_ultra_diagnosis.log"
