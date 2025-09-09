#!/bin/bash
#
# Script para restaurar pasta source do commit específico
# Commit ID: 957c792e19ff6cb1bd15851017a2c36124c8f332
#

echo "🔄 RESTAURAÇÃO: Pasta source do commit específico"
echo "================================================="
echo ""
echo "🎯 Commit ID: 957c792e19ff6cb1bd15851017a2c36124c8f332"
echo "📂 Pasta: source"
echo ""

# Usar diretório atual (onde o script está sendo executado)
HOMEGUARD_DIR="/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard"
COMMIT_ID="957c792e19ff6cb1bd15851017a2c36124c8f332"

# Verificar se estamos no diretório correto
if [ ! -d "$HOMEGUARD_DIR" ]; then
    echo "❌ Diretório não encontrado: $HOMEGUARD_DIR"
    echo "   🔍 Diretório atual: $(pwd)"
    echo "   💡 Execute este script do diretório HomeGuard"
    exit 1
fi

cd "$HOMEGUARD_DIR" || exit 1
echo "📂 Trabalhando em: $(pwd)"

echo "1️⃣ VERIFICANDO REPOSITÓRIO GIT"
echo "=============================="

# Verificar se é um repositório Git
if [ ! -d ".git" ]; then
    echo "❌ Não é um repositório Git!"
    echo "   Esta operação requer Git"
    exit 1
fi

echo "   ✅ Repositório Git encontrado"

# Verificar se o commit existe
if git cat-file -e "$COMMIT_ID" 2>/dev/null; then
    echo "   ✅ Commit $COMMIT_ID encontrado"
else
    echo "   ❌ Commit $COMMIT_ID não encontrado!"
    echo "   🔍 Verificando commits recentes..."
    git log --oneline -10
    exit 1
fi

echo ""
echo "2️⃣ BACKUP DA PASTA SOURCE ATUAL"
echo "==============================="

if [ -d "source" ]; then
    BACKUP_DIR="source_backup_$(date +%Y%m%d_%H%M%S)"
    cp -r source "$BACKUP_DIR"
    echo "   📦 Backup criado: $BACKUP_DIR"
else
    echo "   ⚠️ Pasta source não existe atualmente"
fi

echo ""
echo "3️⃣ VERIFICANDO O CONTEÚDO DO COMMIT"
echo "==================================="

# Mostrar arquivos na pasta source naquele commit
echo "   📋 Arquivos em source/ no commit $COMMIT_ID:"
git ls-tree -r --name-only "$COMMIT_ID" | grep "^source/" | head -10
TOTAL_FILES=$(git ls-tree -r --name-only "$COMMIT_ID" | grep "^source/" | wc -l)
echo "   📊 Total de arquivos: $TOTAL_FILES"

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "   ❌ Nenhum arquivo encontrado em source/ neste commit!"
    exit 1
fi

echo ""
echo "4️⃣ RESTAURANDO PASTA SOURCE"
echo "=========================="

# Remover pasta source atual se existir
if [ -d "source" ]; then
    rm -rf source
    echo "   🗑️ Pasta source atual removida"
fi

# Restaurar pasta source do commit específico
echo "   🔄 Restaurando source/ do commit $COMMIT_ID..."

# Extrair apenas a pasta source do commit específico
git archive "$COMMIT_ID" source | tar -x

if [ $? -eq 0 ]; then
    echo "   ✅ Pasta source restaurada com sucesso!"
else
    echo "   ❌ Erro na restauração!"
    
    # Tentar restaurar backup se falhou
    if [ -d "$BACKUP_DIR" ]; then
        cp -r "$BACKUP_DIR" source
        echo "   🔄 Backup restaurado para evitar perda"
    fi
    exit 1
fi

echo ""
echo "5️⃣ VERIFICANDO RESTAURAÇÃO"
echo "========================="

if [ -d "source" ]; then
    SOURCE_FILES=$(find source -type f | wc -l)
    echo "   📊 Arquivos restaurados: $SOURCE_FILES"
    
    # Mostrar estrutura principal
    echo "   📂 Estrutura restaurada:"
    find source -type d -maxdepth 2 | sort | while read dir; do
        echo "      $dir/"
    done
    
    # Verificar alguns arquivos específicos importantes
    echo ""
    echo "   🔍 Verificando arquivos críticos:"
    
    CRITICAL_FILES=(
        "source/esp01/mqtt/relay/relay.ino"
        "source/esp01/mqtt/dht11/dht11_monitor/dht11_monitor.ino"
        "source/esp01/mqtt/motion/motion.ino"
    )
    
    for file in "${CRITICAL_FILES[@]}"; do
        if [ -f "$file" ]; then
            SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "?")
            echo "      ✅ $file ($SIZE bytes)"
        else
            echo "      ❌ $file - não encontrado"
        fi
    done
    
else
    echo "   ❌ Pasta source não foi criada!"
    exit 1
fi

echo ""
echo "6️⃣ VERIFICANDO CONFIGURAÇÕES NOS ARQUIVOS"
echo "========================================="

# Verificar IPs nos arquivos .ino restaurados
echo "   🔍 Verificando IPs nos arquivos ESP..."

find source -name "*.ino" -exec grep -l "192\.168\." {} \; | while read file; do
    IPS=$(grep -o "192\.168\.[0-9]\+\.[0-9]\+" "$file" | sort -u)
    echo "      📄 $file:"
    echo "$IPS" | while read ip; do
        echo "         - $ip"
    done
done

echo ""
echo "7️⃣ COMPARANDO COM ESTADO ATUAL"
echo "============================="

# Verificar se há diferenças significativas
if [ -d "$BACKUP_DIR" ]; then
    echo "   🔍 Comparando com backup anterior..."
    
    # Contar arquivos
    OLD_COUNT=$(find "$BACKUP_DIR" -type f | wc -l)
    NEW_COUNT=$(find source -type f | wc -l)
    
    echo "      📊 Arquivos antes: $OLD_COUNT"
    echo "      📊 Arquivos agora: $NEW_COUNT"
    
    if [ "$NEW_COUNT" -gt "$OLD_COUNT" ]; then
        echo "      ✅ Mais arquivos restaurados (+$((NEW_COUNT - OLD_COUNT)))"
    elif [ "$NEW_COUNT" -lt "$OLD_COUNT" ]; then
        echo "      ⚠️ Menos arquivos (-$((OLD_COUNT - NEW_COUNT)))"
    else
        echo "      ✅ Mesmo número de arquivos"
    fi
fi

echo ""
echo "✅ RESTAURAÇÃO CONCLUÍDA!"
echo "========================"
echo ""
echo "📊 RESULTADO:"
echo "   🎯 Commit: $COMMIT_ID"
echo "   📂 Pasta: source/ restaurada"
echo "   📊 Arquivos: $SOURCE_FILES"
echo "   💾 Backup: $BACKUP_DIR"
echo ""
echo "🔍 VERIFICAÇÕES RECOMENDADAS:"
echo "   1. Verificar IPs nos arquivos .ino"
echo "   2. Confirmar configurações MQTT"
echo "   3. Testar compilação se necessário"
echo ""
echo "💾 BACKUP DISPONÍVEL:"
echo "   📦 $BACKUP_DIR (pasta anterior)"
echo ""
echo "🎯 PRÓXIMOS PASSOS:"
echo "   1. Verificar se os arquivos estão corretos"
echo "   2. Ajustar IPs se necessário (192.168.1.102)"
echo "   3. Fazer commit se satisfeito com a restauração"
