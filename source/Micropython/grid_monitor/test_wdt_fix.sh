#!/bin/bash

# Script de teste para Grid Monitor ESP32-C3
# Verifica correção do erro WDT timeout

echo "🔧 TESTE DE CORREÇÃO - GRID MONITOR ESP32-C3"
echo "=============================================="
echo ""

# Configurações
MQTT_HOST="192.168.1.102"
MQTT_USER="homeguard"
MQTT_PASS="pu2clr123456"
DEVICE_TOPIC="home/grid/GRID_MONITOR_C3B"
DEVICE_PORT="/dev/ttyUSB0"  # Ajustar conforme necessário

# Função para testar MQTT
test_mqtt() {
    echo "📡 Testando comunicação MQTT..."
    
    # Solicitar status
    echo "→ Solicitando status do device..."
    mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "${DEVICE_TOPIC}/command" -m "STATUS"
    
    sleep 2
    
    # Testar comando ON
    echo "→ Testando comando ON..."
    mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "${DEVICE_TOPIC}/command" -m "ON"
    
    sleep 2
    
    # Testar comando OFF
    echo "→ Testando comando OFF..."
    mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "${DEVICE_TOPIC}/command" -m "OFF"
    
    sleep 2
    
    # Voltar para AUTO
    echo "→ Retornando para modo AUTO..."
    mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "${DEVICE_TOPIC}/command" -m "AUTO"
    
    echo "✅ Testes MQTT enviados"
}

# Função para testar calibração do sensor
test_sensor_calibration() {
    echo "🔧 Testando calibração do sensor ZMPT101B..."
    
    echo "→ Aplicando preset residencial..."
    mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "${DEVICE_TOPIC}/command" -m "PRESET_RESIDENTIAL"
    
    sleep 2
    
    echo "→ Solicitando relatório de calibração..."
    mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "${DEVICE_TOPIC}/command" -m "CALIBRATION_REPORT"
    
    sleep 2
    
    echo "→ Solicitando estatísticas de tensão..."
    mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "${DEVICE_TOPIC}/command" -m "VOLTAGE_STATS"
    
    echo "✅ Testes de calibração enviados"
    echo "📊 Monitore os logs do device para ver os resultados"
}

# Função para monitorar logs
monitor_logs() {
    echo "📊 Monitorando logs do device (pressione Ctrl+C para parar)..."
    echo ""
    
    if command -v mpremote &> /dev/null; then
        echo "Usando mpremote para monitorar..."
        mpremote connect $DEVICE_PORT
    elif command -v screen &> /dev/null; then
        echo "Usando screen para monitorar..."
        echo "Para sair: Ctrl+A, depois K"
        screen $DEVICE_PORT 115200
    else
        echo "❌ mpremote ou screen não encontrado"
        echo "Instale com: pip install mpremote"
        echo "Ou: sudo apt-get install screen"
    fi
}

# Função para monitorar status MQTT
monitor_mqtt() {
    echo "📡 Monitorando status MQTT (pressione Ctrl+C para parar)..."
    echo ""
    
    mosquitto_sub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "${DEVICE_TOPIC}/status" -v
}

# Função para upload do arquivo corrigido
upload_fix() {
    echo "📤 Fazendo upload do arquivo corrigido..."
    
    if [ ! -f "main_fixed.py" ]; then
        echo "❌ Arquivo main_fixed.py não encontrado!"
        echo "Certifique-se de estar na pasta correta:"
        echo "cd source/Micropython/grid_monitor"
        exit 1
    fi
    
    # Backup do arquivo atual
    if command -v mpremote &> /dev/null; then
        echo "→ Fazendo backup do main.py atual..."
        mpremote connect $DEVICE_PORT fs cp :main.py :main_backup.py 2>/dev/null || true
        
        echo "→ Enviando arquivo corrigido..."
        mpremote connect $DEVICE_PORT fs cp main_fixed.py :main.py
        
        echo "→ Reiniciando device..."
        mpremote connect $DEVICE_PORT reset
        
        echo "✅ Upload concluído e device reiniciado"
        sleep 3
    else
        echo "❌ mpremote não encontrado!"
        echo "Instale com: pip install mpremote"
        exit 1
    fi
}

# Função para diagnóstico completo
full_diagnostic() {
    echo "🔍 DIAGNÓSTICO COMPLETO"
    echo "======================"
    echo ""
    
    echo "1. Verificando conectividade MQTT..."
    if mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
        -t "test/connection" -m "test" 2>/dev/null; then
        echo "✅ MQTT broker acessível"
    else
        echo "❌ MQTT broker inacessível"
        echo "Verifique se o broker está rodando em $MQTT_HOST"
    fi
    
    echo ""
    echo "2. Verificando device serial..."
    if [ -e "$DEVICE_PORT" ]; then
        echo "✅ Device serial encontrado em $DEVICE_PORT"
    else
        echo "❌ Device serial não encontrado em $DEVICE_PORT"
        echo "Devices disponíveis:"
        ls /dev/tty* | grep -E "(USB|ACM)" || echo "Nenhum device USB encontrado"
    fi
    
    echo ""
    echo "3. Verificando dependências..."
    
    if command -v mosquitto_pub &> /dev/null; then
        echo "✅ mosquitto-clients instalado"
    else
        echo "❌ mosquitto-clients não encontrado"
        echo "Instale com: sudo apt-get install mosquitto-clients"
    fi
    
    if command -v mpremote &> /dev/null; then
        echo "✅ mpremote instalado"
    else
        echo "❌ mpremote não encontrado"
        echo "Instale com: pip install mpremote"
    fi
    
    echo ""
    echo "4. Testando comunicação com device..."
    test_mqtt
}

# Menu principal
show_menu() {
    echo ""
    echo "OPÇÕES DISPONÍVEIS:"
    echo "1. Upload da correção (main_fixed.py)"
    echo "2. Testar comandos MQTT"
    echo "3. Testar calibração do sensor"
    echo "4. Monitorar logs do device"
    echo "5. Monitorar status MQTT"
    echo "6. Diagnóstico completo"
    echo "7. Sair"
    echo ""
    read -p "Escolha uma opção (1-7): " choice
    
    case $choice in
        1)
            upload_fix
            ;;
        2)
            test_mqtt
            ;;
        3)
            test_sensor_calibration
            ;;
        4)
            monitor_logs
            ;;
        5)
            monitor_mqtt
            ;;
        6)
            full_diagnostic
            ;;
        7)
            echo "👋 Saindo..."
            exit 0
            ;;
        *)
            echo "❌ Opção inválida!"
            ;;
    esac
}

# Verificar argumentos da linha de comando
if [ "$1" = "upload" ]; then
    upload_fix
elif [ "$1" = "test" ]; then
    test_mqtt
elif [ "$1" = "calibration" ]; then
    test_sensor_calibration
elif [ "$1" = "monitor" ]; then
    monitor_logs
elif [ "$1" = "mqtt" ]; then
    monitor_mqtt
elif [ "$1" = "diagnostic" ]; then
    full_diagnostic
else
    # Menu interativo
    while true; do
        show_menu
        echo ""
        read -p "Pressione Enter para continuar ou Ctrl+C para sair..."
    done
fi