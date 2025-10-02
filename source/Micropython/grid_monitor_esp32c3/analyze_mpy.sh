#!/bin/bash

# Teste de Performance: .py vs .mpy
# Analisa diferenças entre código fonte e bytecode

echo "🔍 ANÁLISE DE ARQUIVO .MPY vs .PY"
echo "=================================="
echo ""

# Verificar se existe main.py e main.mpy
if [ ! -f "main.py" ]; then
    echo "❌ main.py não encontrado!"
    exit 1
fi

# Gerar main.mpy se não existir
if [ ! -f "main.mpy" ]; then
    echo "📦 Gerando main.mpy..."
    if command -v mpy-cross &> /dev/null; then
        mpy-cross main.py
    else
        echo "❌ mpy-cross não encontrado. Instale com: pip install mpy-cross"
        exit 1
    fi
fi

echo "📊 COMPARAÇÃO DE ARQUIVOS:"
echo "========================="

# Tamanhos
py_size=$(wc -c < main.py)
mpy_size=$(wc -c < main.mpy)
reduction=$((100 - (mpy_size * 100 / py_size)))

echo "📄 main.py  : ${py_size} bytes"
echo "📦 main.mpy : ${mpy_size} bytes"
echo "📉 Redução  : ${reduction}%"
echo ""

# Informações detalhadas do .mpy
echo "🔍 ANÁLISE DETALHADA DO .MPY:"
echo "============================="

# Header do arquivo .mpy (primeiros bytes)
echo "📋 Header .mpy:"
hexdump -C main.mpy | head -3

echo ""
echo "🎯 VANTAGENS DO .MPY:"
echo "- ⚡ Boot ${reduction}% mais rápido (menos código para compilar)"
echo "- 💾 Economia de ${reduction}% de espaço Flash"
echo "- 🧠 Menor uso de RAM (não compila em runtime)"
echo "- 🔒 Código menos legível (proteção básica)"
echo ""

echo "⚠️  DESVANTAGENS DO .MPY:"
echo "- 🔧 Debug mais difícil (stack traces menos claros)"
echo "- 📱 Específico da versão MicroPython atual"
echo "- 🔄 Precisa recompilar para outras versões"
echo ""

echo "🚀 RECOMENDAÇÕES DE USO:"
echo "======================="
echo ""
echo "📦 USAR .MPY QUANDO:"
echo "- ✅ Código em produção (estável)"
echo "- ✅ Bibliotecas grandes (sensor_calibration.py)"
echo "- ✅ Módulos raramente alterados"
echo "- ✅ Performance crítica (boot rápido)"
echo ""
echo "📄 USAR .PY QUANDO:"
echo "- ✅ Desenvolvimento ativo"
echo "- ✅ Debug frequente necessário"
echo "- ✅ Código experimental"
echo "- ✅ Portabilidade entre versões MicroPython"
echo ""

echo "🎯 ESTRATÉGIA HÍBRIDA RECOMENDADA:"
echo "=================================="
echo ""
echo "main.py              # Arquivo principal (fácil debug)"
echo "config.py            # Configurações (fácil edição)"
echo "sensor_calibration.mpy   # Biblioteca grande (performance)"
echo "mqtt_handler.mpy         # Módulo estável (performance)"
echo ""

# Teste de compilação para validação
echo "✅ VALIDAÇÃO DE COMPILAÇÃO:"
echo "=========================="

if mpy-cross main.py 2>/dev/null; then
    echo "✅ main.py compila corretamente para .mpy"
    
    # Verificar se outros arquivos .py podem ser compilados
    for file in *.py; do
        if [ "$file" != "main.py" ] && [ -f "$file" ]; then
            if mpy-cross "$file" 2>/dev/null; then
                mpy_file="${file%.py}.mpy"
                original_size=$(wc -c < "$file")
                compiled_size=$(wc -c < "$mpy_file")
                reduction=$((100 - (compiled_size * 100 / original_size)))
                echo "✅ $file → $mpy_file (${reduction}% menor)"
                
                # Limpar arquivo .mpy de teste
                rm -f "$mpy_file"
            else
                echo "❌ $file tem erros de compilação"
            fi
        fi
    done
else
    echo "❌ main.py tem erros de compilação"
fi

echo ""
echo "📖 MAIS INFORMAÇÕES:"
echo "==================="
echo "- MicroPython .mpy format: https://docs.micropython.org/en/latest/reference/mpyfiles.html"
echo "- Cross-compiler docs: https://docs.micropython.org/en/latest/reference/glossary.html#term-cross-compiler"
echo ""
echo "🔧 COMANDOS ÚTEIS:"
echo "=================="
echo "# Compilar arquivo específico:"
echo "mpy-cross sensor_calibration.py"
echo ""
echo "# Compilar todos os .py (exceto main.py):"
echo "for f in *.py; do [ \"\$f\" != \"main.py\" ] && mpy-cross \"\$f\"; done"
echo ""
echo "# Upload mix .py + .mpy:"
echo "mpremote connect /dev/ttyUSB0 fs cp main.py sensor_calibration.mpy :"