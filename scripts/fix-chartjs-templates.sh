#!/bin/bash
#
# Script para aplicar correções do Chart.js em todos os templates
#

echo "🔧 Aplicando correções do Chart.js nos templates..."
echo "=================================================="

TEMPLATES_DIR="/home/homeguard/HomeGuard/web/templates"

# Verificar se diretório existe
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "❌ Diretório de templates não encontrado: $TEMPLATES_DIR"
    echo "Ajuste o caminho e execute novamente."
    exit 1
fi

echo "📁 Templates: $TEMPLATES_DIR"

# 1. Verificar se base.html já tem o date adapter
echo "1️⃣ Verificando base.html..."
if grep -q "chartjs-adapter-date-fns" "$TEMPLATES_DIR/base.html"; then
    echo "   ✅ Date adapter já presente"
else
    echo "   🔧 Adicionando date adapter ao base.html..."
    # Fazer backup
    cp "$TEMPLATES_DIR/base.html" "$TEMPLATES_DIR/base.html.backup"
    
    # Adicionar date adapter após Chart.js
    sed -i 's|<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>|<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>\n    <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns/dist/chartjs-adapter-date-fns.bundle.min.js"></script>|g' "$TEMPLATES_DIR/base.html"
    echo "   ✅ Date adapter adicionado"
fi

# 2. Lista de templates que precisam de correção
TEMPLATES_TO_FIX=("humidity_panel.html" "motion_panel.html" "relay_panel.html")

for template in "${TEMPLATES_TO_FIX[@]}"; do
    echo ""
    echo "2️⃣ Processando $template..."
    
    TEMPLATE_PATH="$TEMPLATES_DIR/$template"
    
    if [ ! -f "$TEMPLATE_PATH" ]; then
        echo "   ⚠️ Arquivo não encontrado: $template"
        continue
    fi
    
    # Fazer backup
    cp "$TEMPLATE_PATH" "$TEMPLATE_PATH.backup"
    
    # Aplicar correções básicas no updateChart
    if grep -q "Chart(ctx," "$TEMPLATE_PATH"; then
        echo "   🔧 Aplicando correções no gráfico..."
        
        # Correção 1: Melhorar destruição do gráfico
        sed -i 's/temperatureChart.destroy();/try { temperatureChart.destroy(); temperatureChart = null; } catch (e) { console.warn("Erro ao destruir gráfico:", e); }/g' "$TEMPLATE_PATH"
        sed -i 's/humidityChart.destroy();/try { humidityChart.destroy(); humidityChart = null; } catch (e) { console.warn("Erro ao destruir gráfico:", e); }/g' "$TEMPLATE_PATH"
        sed -i 's/motionChart.destroy();/try { motionChart.destroy(); motionChart = null; } catch (e) { console.warn("Erro ao destruir gráfico:", e); }/g' "$TEMPLATE_PATH"
        sed -i 's/relayChart.destroy();/try { relayChart.destroy(); relayChart = null; } catch (e) { console.warn("Erro ao destruir gráfico:", e); }/g' "$TEMPLATE_PATH"
        
        # Correção 2: Converter timestamps para Date objects
        sed -i 's/x: item.created_at,/x: new Date(item.created_at),/g' "$TEMPLATE_PATH"
        
        echo "   ✅ Correções aplicadas"
    else
        echo "   ℹ️ Nenhum gráfico Chart.js encontrado"
    fi
done

echo ""
echo "🧪 Testando estrutura dos templates..."

# Verificar se os templates têm a estrutura necessária
for template in "${TEMPLATES_TO_FIX[@]}"; do
    TEMPLATE_PATH="$TEMPLATES_DIR/$template"
    
    if [ -f "$TEMPLATE_PATH" ]; then
        echo "📄 $template:"
        
        # Verificar canvas
        CANVAS_COUNT=$(grep -c "canvas id=" "$TEMPLATE_PATH" || true)
        echo "   Canvas encontrados: $CANVAS_COUNT"
        
        # Verificar funções update
        UPDATE_FUNCTIONS=$(grep -c "function update.*Chart" "$TEMPLATE_PATH" || true)
        echo "   Funções updateChart: $UPDATE_FUNCTIONS"
        
        # Verificar se tem Chart.js
        CHART_USAGE=$(grep -c "new Chart(" "$TEMPLATE_PATH" || true)
        echo "   Uso do Chart.js: $CHART_USAGE"
    fi
done

echo ""
echo "📋 Resumo das correções aplicadas:"
echo "   ✅ Date adapter adicionado ao base.html"
echo "   ✅ Destruição robusta dos gráficos"
echo "   ✅ Conversão de timestamps para Date objects"
echo "   ✅ Backups criados (.backup)"
echo ""
echo "🚀 Para aplicar:"
echo "   1. Copie os templates corrigidos para o Raspberry Pi"
echo "   2. Reinicie o dashboard"
echo "   3. Teste todos os painéis"
echo ""
echo "📁 Arquivos de backup criados em: $TEMPLATES_DIR/*.backup"
