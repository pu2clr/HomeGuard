#!/bin/bash

# =============================================================================
# TESTE DE CAMINHOS - HOMEGUARD MQTT SERVICE
# =============================================================================
# Script para verificar se os caminhos estão corretos
# =============================================================================

echo "=== TESTE DE CAMINHOS HOMEGUARD ==="
echo ""

# Configurações (mesma lógica do script principal)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 INFORMAÇÕES DE CAMINHOS:"
echo "  Script atual: ${BASH_SOURCE[0]}"
echo "  SCRIPT_DIR: $SCRIPT_DIR"
echo "  PROJECT_DIR: $PROJECT_DIR"
echo ""

echo "📂 VERIFICAÇÃO DE ESTRUTURA:"
echo ""

# Verificar diretório atual
echo "🔍 Diretório atual (pwd): $(pwd)"
echo ""

# Verificar se PROJECT_DIR existe
if [[ -d "$PROJECT_DIR" ]]; then
    echo "✅ PROJECT_DIR existe: $PROJECT_DIR"
else
    echo "❌ PROJECT_DIR não existe: $PROJECT_DIR"
fi

# Listar conteúdo do PROJECT_DIR
echo ""
echo "📄 Conteúdo do PROJECT_DIR ($PROJECT_DIR):"
if [[ -d "$PROJECT_DIR" ]]; then
    ls -la "$PROJECT_DIR/" | head -20
else
    echo "  Diretório não existe!"
fi

echo ""
echo "🔍 VERIFICAÇÃO DE ARQUIVOS IMPORTANTES:"

# Verificar mqtt_service.py
MQTT_SERVICE_PATH="$PROJECT_DIR/web/mqtt_service.py"
if [[ -f "$MQTT_SERVICE_PATH" ]]; then
    echo "✅ mqtt_service.py encontrado: $MQTT_SERVICE_PATH"
else
    echo "❌ mqtt_service.py NÃO encontrado: $MQTT_SERVICE_PATH"
fi

# Verificar diretório web
WEB_DIR="$PROJECT_DIR/web"
if [[ -d "$WEB_DIR" ]]; then
    echo "✅ Diretório web existe: $WEB_DIR"
    echo "   Conteúdo do diretório web:"
    ls -la "$WEB_DIR/" | head -10
else
    echo "❌ Diretório web NÃO existe: $WEB_DIR"
fi

# Verificar diretório scripts
SCRIPTS_DIR="$PROJECT_DIR/scripts"
if [[ -d "$SCRIPTS_DIR" ]]; then
    echo "✅ Diretório scripts existe: $SCRIPTS_DIR"
else
    echo "❌ Diretório scripts NÃO existe: $SCRIPTS_DIR"
fi

echo ""
echo "🎯 ESTRUTURA ESPERADA:"
echo "  $PROJECT_DIR/"
echo "  ├── web/"
echo "  │   ├── mqtt_service.py"
echo "  │   ├── mqtt_activity_logger.py"
echo "  │   └── ..."
echo "  ├── scripts/"
echo "  │   ├── setup-mqtt-service.sh"
echo "  │   ├── manage-mqtt-service.sh"
echo "  │   └── ..."
echo "  ├── db/"
echo "  ├── docs/"
echo "  └── ..."

echo ""
echo "🔧 SUGESTÕES DE CORREÇÃO:"
echo ""

if [[ ! -f "$MQTT_SERVICE_PATH" ]]; then
    echo "❗ PROBLEMA: mqtt_service.py não encontrado"
    echo ""
    echo "   Possíveis soluções:"
    echo "   1. Verificar se você está no diretório correto:"
    echo "      cd /home/homeguard/HomeGuard"
    echo ""
    echo "   2. Verificar se o projeto foi clonado corretamente:"
    echo "      git status"
    echo ""
    echo "   3. Procurar arquivo mqtt_service.py:"
    echo "      find /home/homeguard -name 'mqtt_service.py' 2>/dev/null"
    echo ""
    echo "   4. Recriar estrutura se necessário:"
    echo "      cd /home/homeguard"
    echo "      rm -rf HomeGuard"
    echo "      git clone https://github.com/pu2clr/HomeGuard.git"
fi

echo ""
echo "=== FIM DO TESTE DE CAMINHOS ==="
