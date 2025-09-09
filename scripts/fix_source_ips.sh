#!/bin/bash
#
# Script para ajustar IPs na pasta source após restauração do commit
#

echo "🔧 AJUSTE DE IPs: Pasta source restaurada"
echo "========================================="
echo ""

HOMEGUARD_DIR="/Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard"
OLD_IP="192.168.1.102"
NEW_IP="192.168.1.102"

cd "$HOMEGUARD_DIR" || exit 1
echo "📂 Trabalhando em: $(pwd)"

if [ ! -d "source" ]; then
    echo "❌ Pasta source não encontrada!"
    echo "   Execute primeiro o script de restauração"
    exit 1
fi

echo "🎯 Ajustando IPs:"
echo "   📤 De: $OLD_IP"
echo "   📥 Para: $NEW_IP"
echo ""

echo "1️⃣ VERIFICANDO ARQUIVOS COM IP ANTIGO"
echo "====================================="

# Encontrar arquivos com IP antigo
FILES_WITH_OLD_IP=$(grep -r "$OLD_IP" source/ --include="*.ino" --include="*.cpp" --include="*.h" -l 2>/dev/null)

if [ -z "$FILES_WITH_OLD_IP" ]; then
    echo "   ✅ Nenhum arquivo encontrado com IP antigo"
    echo "   💡 Pode já estar correto ou usar IP diferente"
    
    # Verificar outros IPs
    echo ""
    echo "   🔍 Outros IPs encontrados:"
    grep -r "192\.168\." source/ --include="*.ino" --include="*.cpp" --include="*.h" -h 2>/dev/null | \
    grep -o "192\.168\.[0-9]\+\.[0-9]\+" | sort -u | while read ip; do
        echo "      - $ip"
    done
    
else
    echo "   📄 Arquivos com IP antigo encontrados:"
    echo "$FILES_WITH_OLD_IP" | while read file; do
        OCCURRENCES=$(grep -c "$OLD_IP" "$file")
        echo "      - $file ($OCCURRENCES ocorrências)"
    done
fi

echo ""
echo "2️⃣ BACKUP ANTES DA CORREÇÃO"
echo "=========================="

if [ -n "$FILES_WITH_OLD_IP" ]; then
    BACKUP_DIR="source_before_ip_fix_$(date +%Y%m%d_%H%M%S)"
    cp -r source "$BACKUP_DIR"
    echo "   📦 Backup criado: $BACKUP_DIR"
    
    echo ""
    echo "3️⃣ CORRIGINDO IPs"
    echo "================"
    
    TOTAL_CHANGES=0
    
    echo "$FILES_WITH_OLD_IP" | while read file; do
        if [ -f "$file" ]; then
            echo "   🔧 Processando: $file"
            
            # Contar ocorrências antes
            BEFORE=$(grep -c "$OLD_IP" "$file")
            
            # Fazer a substituição
            sed -i.bak "s/$OLD_IP/$NEW_IP/g" "$file"
            
            # Contar ocorrências depois
            AFTER=$(grep -c "$OLD_IP" "$file")
            CHANGED=$((BEFORE - AFTER))
            
            echo "      📊 Mudanças: $CHANGED"
            
            # Remover arquivo .bak
            rm -f "$file.bak"
        fi
    done
    
    echo ""
    echo "4️⃣ VERIFICANDO CORREÇÕES"
    echo "======================"
    
    # Verificar se ainda há IP antigo
    REMAINING=$(grep -r "$OLD_IP" source/ --include="*.ino" --include="*.cpp" --include="*.h" -l 2>/dev/null | wc -l)
    
    if [ "$REMAINING" -eq 0 ]; then
        echo "   ✅ Todos os IPs corrigidos com sucesso!"
    else
        echo "   ⚠️ Ainda restam $REMAINING arquivos com IP antigo"
        echo "   🔍 Arquivos restantes:"
        grep -r "$OLD_IP" source/ --include="*.ino" --include="*.cpp" --include="*.h" -l 2>/dev/null
    fi
    
    # Mostrar arquivos que agora têm o IP novo
    NEW_IP_COUNT=$(grep -r "$NEW_IP" source/ --include="*.ino" --include="*.cpp" --include="*.h" -l 2>/dev/null | wc -l)
    echo "   📊 Arquivos com IP novo: $NEW_IP_COUNT"
    
fi

echo ""
echo "5️⃣ VERIFICAÇÃO FINAL"
echo "=================="

echo "   📋 Resumo de IPs na pasta source:"
grep -r "192\.168\." source/ --include="*.ino" --include="*.cpp" --include="*.h" -h 2>/dev/null | \
grep -o "192\.168\.[0-9]\+\.[0-9]\+" | sort | uniq -c | while read count ip; do
    echo "      $ip: $count ocorrências"
done

echo ""
echo "   🔍 Arquivos principais verificados:"

MAIN_FILES=(
    "source/esp01/mqtt/relay/relay.ino"
    "source/esp01/mqtt/dht11/dht11_monitor/dht11_monitor.ino"
    "source/esp01/mqtt/motion/motion.ino"
)

for file in "${MAIN_FILES[@]}"; do
    if [ -f "$file" ]; then
        IP_IN_FILE=$(grep -o "192\.168\.[0-9]\+\.[0-9]\+" "$file" | head -1)
        echo "      ✅ $file: $IP_IN_FILE"
    else
        echo "      ❌ $file: não encontrado"
    fi
done

echo ""
echo "✅ AJUSTE DE IPs CONCLUÍDO!"
echo "=========================="
echo ""
echo "📊 RESULTADO:"
echo "   🔄 IP antigo: $OLD_IP"
echo "   ✅ IP novo: $NEW_IP"
echo "   📊 Arquivos com IP novo: $NEW_IP_COUNT"
echo ""

if [ -n "$FILES_WITH_OLD_IP" ]; then
    echo "💾 BACKUP DISPONÍVEL:"
    echo "   📦 $BACKUP_DIR"
    echo ""
fi

echo "🎯 PRÓXIMOS PASSOS:"
echo "   1. Verificar arquivos principais manualmente"
echo "   2. Testar compilação dos .ino se necessário"
echo "   3. Fazer commit das mudanças"
echo ""
echo "🧪 TESTE SUGERIDO:"
echo "   grep -r '192.168.1.102' source/ --include='*.ino' | head -5"
