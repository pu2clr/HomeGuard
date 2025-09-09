#!/bin/bash
#
# Restauração LOCAL da pasta source - EXECUTAR NO SEU MAC
# Commit ID: 957c792e19ff6cb1bd15851017a2c36124c8f332
#

echo "🖥️  RESTAURAÇÃO LOCAL: Pasta source do commit específico"
echo "======================================================="
echo ""
echo "🎯 Commit ID: 957c792e19ff6cb1bd15851017a2c36124c8f332"
echo "💻 Executando no: macOS"
echo ""

# Usar diretório atual (deve ser executado de dentro do HomeGuard)
COMMIT_ID="957c792e19ff6cb1bd15851017a2c36124c8f332"

# Verificar se estamos no diretório correto
if [ ! -d ".git" ]; then
    echo "❌ Não é um repositório Git!"
    echo "📂 Diretório atual: $(pwd)"
    echo "💡 Execute este script de dentro da pasta HomeGuard"
    exit 1
fi

if [ ! -f "README.md" ] || ! grep -q "HomeGuard" README.md 2>/dev/null; then
    echo "❌ Não parece ser o diretório HomeGuard correto"
    echo "📂 Diretório atual: $(pwd)"
    exit 1
fi

echo "✅ Diretório HomeGuard confirmado: $(pwd)"
echo ""

echo "1️⃣ VERIFICANDO COMMIT"
echo "===================="

# Verificar se o commit existe
if git cat-file -e "$COMMIT_ID" 2>/dev/null; then
    echo "   ✅ Commit $COMMIT_ID encontrado"
    
    # Mostrar informações do commit
    echo "   📅 Data: $(git show -s --format=%cd --date=short "$COMMIT_ID")"
    echo "   👤 Autor: $(git show -s --format=%an "$COMMIT_ID")"
    echo "   💬 Mensagem: $(git show -s --format=%s "$COMMIT_ID")"
else
    echo "   ❌ Commit $COMMIT_ID não encontrado!"
    echo "   🔍 Últimos commits:"
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
    
    # Contar arquivos no backup
    BACKUP_FILES=$(find "$BACKUP_DIR" -type f | wc -l | tr -d ' ')
    echo "   📊 Arquivos no backup: $BACKUP_FILES"
else
    echo "   ⚠️ Pasta source não existe atualmente"
fi

echo ""
echo "3️⃣ ANÁLISE DO COMMIT"
echo "==================="

# Verificar o que existe na pasta source naquele commit
SOURCE_FILES_COUNT=$(git ls-tree -r --name-only "$COMMIT_ID" | grep "^source/" | wc -l | tr -d ' ')
echo "   📊 Arquivos em source/ no commit: $SOURCE_FILES_COUNT"

if [ "$SOURCE_FILES_COUNT" -eq 0 ]; then
    echo "   ❌ Nenhum arquivo em source/ neste commit!"
    exit 1
fi

echo "   📋 Principais diretórios em source/:"
git ls-tree --name-only "$COMMIT_ID" source/ | head -10 | while read item; do
    echo "      - $item"
done

echo ""
echo "4️⃣ RESTAURAÇÃO"
echo "=============="

# Confirmar antes de prosseguir
read -p "   ❓ Continuar com a restauração? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "   🛑 Operação cancelada pelo usuário"
    exit 0
fi

# Remover pasta source atual
if [ -d "source" ]; then
    rm -rf source
    echo "   🗑️ Pasta source atual removida"
fi

# Restaurar pasta source do commit específico
echo "   🔄 Restaurando source/ do commit $COMMIT_ID..."

# Usar git archive para extrair apenas a pasta source
if git archive "$COMMIT_ID" source | tar -x; then
    echo "   ✅ Pasta source restaurada com sucesso!"
else
    echo "   ❌ Erro na restauração!"
    
    # Tentar restaurar backup se existe
    if [ -d "$BACKUP_DIR" ]; then
        echo "   🔄 Restaurando backup..."
        cp -r "$BACKUP_DIR" source
        echo "   ✅ Backup restaurado"
    fi
    exit 1
fi

echo ""
echo "5️⃣ VERIFICAÇÃO"
echo "=============="

if [ -d "source" ]; then
    RESTORED_FILES=$(find source -type f | wc -l | tr -d ' ')
    echo "   📊 Arquivos restaurados: $RESTORED_FILES"
    
    # Mostrar estrutura principal
    echo "   📂 Estrutura restaurada:"
    find source -type d -maxdepth 2 | sort | while read dir; do
        echo "      $dir/"
    done | head -15
    
    echo ""
    echo "   🔍 Arquivos .ino principais:"
    find source -name "*.ino" | while read file; do
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        echo "      ✅ $file ($SIZE bytes)"
    done | head -10
    
else
    echo "   ❌ Pasta source não foi criada!"
    exit 1
fi

echo ""
echo "6️⃣ ANÁLISE DE IPs"
echo "================"

echo "   🔍 IPs encontrados nos arquivos:"
find source -name "*.ino" -o -name "*.cpp" -o -name "*.h" | xargs grep -h "192\.168\." 2>/dev/null | \
grep -o "192\.168\.[0-9]\+\.[0-9]\+" | sort -u | while read ip; do
    COUNT=$(find source -name "*.ino" -o -name "*.cpp" -o -name "*.h" | xargs grep -c "$ip" 2>/dev/null | awk '{sum+=$1} END {print sum}')
    echo "      $ip: $COUNT ocorrências"
done

echo ""
echo "✅ RESTAURAÇÃO LOCAL CONCLUÍDA!"
echo "==============================="
echo ""
echo "📊 RESULTADO:"
echo "   🎯 Commit: $COMMIT_ID"
echo "   📂 Pasta: source/ restaurada"
echo "   📊 Arquivos: $RESTORED_FILES"
if [ -n "$BACKUP_DIR" ]; then
    echo "   💾 Backup: $BACKUP_DIR"
fi
echo ""
echo "🔧 PRÓXIMOS PASSOS:"
echo "   1. Verificar se precisa ajustar IPs:"
echo "      ./scripts/fix_source_ips.sh"
echo ""
echo "   2. Verificar arquivos específicos:"
echo "      ls -la source/esp01/mqtt/relay/"
echo "      ls -la source/esp01/mqtt/dht11/"
echo ""
echo "   3. Se satisfeito, fazer commit:"
echo "      git add source/"
echo "      git commit -m \"Restore source/ from commit $COMMIT_ID\""
echo ""
echo "   4. Transferir para Raspberry Pi se necessário"
echo ""
echo "🎉 Restauração local concluída com sucesso!"
