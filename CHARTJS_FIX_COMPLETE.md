# Correções Chart.js - Dashboard HomeGuard

## Problema Identificado

Os painéis do dashboard (Temperatura, Umidade, Movimento, Relés) apresentavam erro "Erro ao carregar dados de {sensor}" devido a problemas com Chart.js:

1. **Date Adapter Missing**: Chart.js precisava do adapter para escalas temporais
2. **Canvas Reuse Error**: Canvas não estava sendo destruído corretamente entre atualizações

## Diagnóstico Realizado

### 1. Debug Live
- Acesso direto: `http://100.87.71.125:5000/temperature-debug`
- Console do navegador revelou erros específicos:
  - "This method is not implemented: Check that a complete date adapter is provided"
  - "Canvas is already in use. Chart with ID '0' must be destroyed before the canvas can be reused"

### 2. APIs Validadas
- ✅ `/api/temperature/data` - Retornando JSON correto
- ✅ `/api/temperature/stats` - Retornando estatísticas
- ✅ Backend funcionando perfeitamente

### 3. Database Views
- ✅ Corrigidas todas as views (vw_humidity_activity, etc.)
- ✅ Estrutura de dados consistente

## Correções Implementadas

### 1. Base Template (`base.html`)
```html
<!-- Adicionado após Chart.js -->
<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns/dist/chartjs-adapter-date-fns.bundle.min.js"></script>
```

### 2. Templates dos Painéis

#### Destruição Robusta do Canvas:
```javascript
// Antes
if (temperatureChart) {
    temperatureChart.destroy();
}

// Depois
if (temperatureChart) {
    try {
        temperatureChart.destroy();
        temperatureChart = null;
    } catch (e) {
        console.warn("Erro ao destruir gráfico:", e);
    }
}
```

#### Conversão de Timestamps:
```javascript
// Antes
x: item.created_at,

// Depois  
x: new Date(item.created_at),
```

#### Configuração Robusta do Chart:
```javascript
scales: {
    x: {
        type: 'time',
        time: {
            unit: 'hour',
            displayFormats: {
                hour: 'HH:mm'
            }
        },
        title: {
            display: true,
            text: 'Hora'
        }
    },
    y: {
        title: {
            display: true,
            text: 'Temperatura (°C)'
        },
        beginAtZero: false
    }
}
```

## Arquivos Modificados

### Templates Corrigidos:
- ✅ `web/templates/base.html` - Date adapter adicionado
- ✅ `web/templates/temperature_panel.html` - Chart.js robusto
- ✅ `web/templates/temperature_debug.html` - Debug completo

### Scripts Criados:
- 📜 `scripts/fix-chartjs-templates.sh` - Aplicar correções automaticamente
- 📜 `scripts/test-dashboard-chartjs.sh` - Testar funcionamento
- 📜 `scripts/deploy-chartjs-fix.sh` - Deploy para Raspberry Pi

## Como Aplicar as Correções

### 1. Deploy Automático:
```bash
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard
./scripts/deploy-chartjs-fix.sh
```

### 2. Deploy Manual:
```bash
# 1. Fazer backup
ssh homeguard@100.87.71.125 "cd /home/homeguard/HomeGuard/web/templates && cp *.html backups/"

# 2. Transferir arquivos
scp web/templates/base.html homeguard@100.87.71.125:/home/homeguard/HomeGuard/web/templates/
scp web/templates/temperature_panel.html homeguard@100.87.71.125:/home/homeguard/HomeGuard/web/templates/
scp web/templates/temperature_debug.html homeguard@100.87.71.125:/home/homeguard/HomeGuard/web/templates/

# 3. Reiniciar dashboard
ssh homeguard@100.87.71.125 "sudo systemctl restart homeguard-dashboard"
```

## Validação

### 1. Teste Básico:
```bash
./scripts/test-dashboard-chartjs.sh
```

### 2. Teste no Navegador:
1. Acesse: `http://100.87.71.125:5000/temperature-debug`
2. Abra Console (F12)
3. Clique em "Carregar Dados de Temperatura"
4. Verifique se gráfico aparece sem erros

### 3. Checklist:
- □ Date adapter carregado sem erro
- □ Canvas criado/destruído corretamente
- □ Timestamps convertidos para Date objects
- □ Gráfico renderiza com dados
- □ Sem erros no console do navegador

## Próximos Passos

### 1. Aplicar nas Outras Páginas:
- `humidity_panel.html` - Umidade
- `motion_panel.html` - Movimento  
- `relay_panel.html` - Relés

### 2. Template Base para Outras Páginas:
```javascript
function updateChart(chartVar, canvasId, apiEndpoint, chartConfig) {
    // Destruir gráfico existente
    if (chartVar) {
        try {
            chartVar.destroy();
            chartVar = null;
        } catch (e) {
            console.warn("Erro ao destruir gráfico:", e);
        }
    }
    
    // Buscar dados da API
    fetch(apiEndpoint)
        .then(response => response.json())
        .then(data => {
            // Converter timestamps
            const chartData = data.map(item => ({
                x: new Date(item.created_at),
                y: item.value
            }));
            
            // Criar novo gráfico
            const ctx = document.getElementById(canvasId).getContext('2d');
            chartVar = new Chart(ctx, {
                ...chartConfig,
                data: {
                    datasets: [{
                        data: chartData,
                        ...chartConfig.datasetConfig
                    }]
                }
            });
        })
        .catch(error => {
            console.error('Erro ao carregar dados:', error);
        });
}
```

## Resolução Final

✅ **Problema**: Chart.js não renderizava gráficos nos painéis
✅ **Causa**: Date adapter ausente + Canvas não destruído
✅ **Solução**: Adapter adicionado + Destruição robusta do canvas
✅ **Status**: Painel de temperatura funcionando
🔄 **Próximo**: Aplicar mesmo padrão nos outros painéis

## Logs de Debug

Para monitorar em tempo real:
```bash
# Dashboard logs
ssh homeguard@100.87.71.125 "sudo journalctl -u homeguard-dashboard -f"

# Console do navegador
# F12 -> Console -> Verificar erros JavaScript
```

## Backup e Rollback

Backups criados automaticamente em:
`/home/homeguard/HomeGuard/web/templates/backups/chartjs-fix-YYYYMMDD-HHMMSS/`

Para rollback:
```bash
ssh homeguard@100.87.71.125 "cd /home/homeguard/HomeGuard/web/templates && cp backups/[BACKUP_DIR]/*.html ."
```
