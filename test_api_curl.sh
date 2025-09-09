#!/bin/bash
#
# Teste das APIs do Dashboard usando curl
# Execute enquanto o dashboard estiver rodando
#

echo "🧪 Teste das APIs do Dashboard"
echo "======================================"

# URL base - ajustar se necessário
BASE_URL="http://localhost:5000"

echo "🔍 Testando conectividade com o servidor..."
if curl -s --connect-timeout 5 "$BASE_URL/" > /dev/null; then
    echo "✅ Servidor respondeu"
else
    echo "❌ Servidor não está respondendo em $BASE_URL"
    echo "   Inicie com: cd web && python3 dashboard.py"
    exit 1
fi

echo ""
echo "📊 Testando APIs de dados..."

# APIs para testar
declare -a apis=(
    "/api/temperature/data?hours=24&limit=5"
    "/api/humidity/data?hours=24&limit=5" 
    "/api/motion/data?hours=24&limit=5"
    "/api/relay/data?hours=24&limit=5"
)

for api in "${apis[@]}"; do
    echo ""
    echo "🔍 Testando: $api"
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$BASE_URL$api")
    http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    echo "   Status: $http_code"
    
    if [ "$http_code" = "200" ]; then
        # Contar registros JSON
        count=$(echo "$body" | jq '. | length' 2>/dev/null || echo "N/A")
        echo "   ✅ OK - $count registros"
        
        # Mostrar primeiro registro se existir
        first=$(echo "$body" | jq '.[0]' 2>/dev/null)
        if [ "$first" != "null" ] && [ "$first" != "" ]; then
            echo "   📄 Primeiro registro:"
            echo "$first" | jq -C . 2>/dev/null || echo "$first"
        fi
    else
        echo "   ❌ Erro HTTP $http_code"
        echo "   Response: $body"
    fi
done

echo ""
echo "📈 Testando APIs de estatísticas..."

declare -a stats_apis=(
    "/api/temperature/stats?hours=24"
    "/api/humidity/stats?hours=24"
)

for api in "${stats_apis[@]}"; do
    echo ""
    echo "🔍 Testando: $api"
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$BASE_URL$api")
    http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    echo "   Status: $http_code"
    
    if [ "$http_code" = "200" ]; then
        count=$(echo "$body" | jq '. | length' 2>/dev/null || echo "N/A")
        echo "   ✅ OK - $count dispositivos"
    else
        echo "   ❌ Erro HTTP $http_code"
        echo "   Response: $body"
    fi
done

echo ""
echo "======================================"
echo "🏁 Teste concluído!"
echo ""
echo "💡 Dicas:"
echo "   - Se APIs de stats funcionam mas data falham = problema na view ou query"
echo "   - Se ambas falham = problema no Flask ou banco"
echo "   - Se retorna dados mas gráfico não aparece = problema no JavaScript"
