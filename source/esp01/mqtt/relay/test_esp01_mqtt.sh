#!/bin/bash

# HomeGuard ESP01 Relay - Test Script
# Testa comunicação MQTT com os relés ESP01

# Configurações MQTT (devem coincidir com mqtt_relay_config.py)
BROKER="192.168.18.236"
PORT="1883"
USER="homeguard"
PASS="pu2clr123456"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔌 HomeGuard ESP01 Relay - Test Suite${NC}"
echo "=========================================="
echo "Broker: $BROKER:$PORT"
echo "User: $USER"
echo ""

# Função para testar um relé
test_relay() {
    local relay_id=$1
    local relay_name=$2
    
    echo -e "${YELLOW}🧪 Testando $relay_name ($relay_id)${NC}"
    echo "----------------------------------------"
    
    # Tópicos
    local topic_command="home/relay/$relay_id/command"
    local topic_status="home/relay/$relay_id/status"
    local topic_info="home/relay/$relay_id/info"
    
    echo "📡 Tópico comando: $topic_command"
    echo "📩 Tópico status:  $topic_status"
    echo "ℹ️  Tópico info:    $topic_info"
    echo ""
    
    # Monitor em background por 10 segundos
    echo -e "${BLUE}📡 Monitorando respostas...${NC}"
    timeout 10s mosquitto_sub -h $BROKER -p $PORT -u $USER -P $PASS -t "home/relay/$relay_id/#" -v &
    monitor_pid=$!
    
    sleep 1
    
    # Testar comandos
    echo -e "${GREEN}📤 Enviando: ON${NC}"
    mosquitto_pub -h $BROKER -p $PORT -u $USER -P $PASS -t "$topic_command" -m "ON"
    sleep 2
    
    echo -e "${GREEN}📤 Enviando: OFF${NC}"
    mosquitto_pub -h $BROKER -p $PORT -u $USER -P $PASS -t "$topic_command" -m "OFF"
    sleep 2
    
    echo -e "${GREEN}📤 Enviando: TOGGLE${NC}"
    mosquitto_pub -h $BROKER -p $PORT -u $USER -P $PASS -t "$topic_command" -m "TOGGLE"
    sleep 2
    
    echo -e "${GREEN}📤 Enviando: STATUS${NC}"
    mosquitto_pub -h $BROKER -p $PORT -u $USER -P $PASS -t "$topic_command" -m "STATUS"
    sleep 3
    
    # Parar monitor
    kill $monitor_pid 2>/dev/null
    wait $monitor_pid 2>/dev/null
    
    echo -e "${YELLOW}✅ Teste $relay_name concluído${NC}"
    echo ""
}

# Menu de testes
echo "Escolha um teste:"
echo "1) Testar ESP01_RELAY_001 (Luz da Sala)"
echo "2) Testar ESP01_RELAY_002 (Luz da Cozinha)"
echo "3) Testar ESP01_RELAY_003 (Bomba d'Água)"
echo "4) Testar todos os relés"
echo "5) Monitor contínuo de todos os tópicos"
echo "6) Teste rápido de conectividade"
echo ""

read -p "Digite sua escolha (1-6): " choice

case $choice in
    1)
        test_relay "ESP01_RELAY_001" "Luz da Sala"
        ;;
    2)
        test_relay "ESP01_RELAY_002" "Luz da Cozinha"
        ;;
    3)
        test_relay "ESP01_RELAY_003" "Bomba d'Água"
        ;;
    4)
        echo -e "${BLUE}🔄 Testando todos os relés...${NC}"
        test_relay "ESP01_RELAY_001" "Luz da Sala"
        test_relay "ESP01_RELAY_002" "Luz da Cozinha"
        test_relay "ESP01_RELAY_003" "Bomba d'Água"
        echo -e "${GREEN}✅ Todos os testes concluídos!${NC}"
        ;;
    5)
        echo -e "${BLUE}📡 Monitor contínuo (Ctrl+C para parar)${NC}"
        echo "Monitorando: home/relay/+/+"
        mosquitto_sub -h $BROKER -p $PORT -u $USER -P $PASS -t "home/relay/+/+" -v
        ;;
    6)
        echo -e "${BLUE}🔍 Teste rápido de conectividade${NC}"
        echo "Testando conexão MQTT..."
        
        # Testar conexão
        timeout 5s mosquitto_pub -h $BROKER -p $PORT -u $USER -P $PASS -t "home/test" -m "ping"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Conexão MQTT OK${NC}"
        else
            echo -e "${RED}❌ Falha na conexão MQTT${NC}"
            echo "Verifique:"
            echo "  • Broker rodando em $BROKER:$PORT"
            echo "  • Credenciais: $USER / $PASS"
            echo "  • Firewall / network"
        fi
        ;;
    *)
        echo -e "${RED}❌ Opção inválida${NC}"
        ;;
esac

echo ""
echo -e "${BLUE}📋 Comandos úteis:${NC}"
echo "• Monitor geral: mosquitto_sub -h $BROKER -u $USER -P $PASS -t \"#\" -v"
echo "• Ligar relé:    mosquitto_pub -h $BROKER -u $USER -P $PASS -t \"home/relay/ESP01_RELAY_001/command\" -m \"ON\""
echo "• Status relé:   mosquitto_sub -h $BROKER -u $USER -P $PASS -t \"home/relay/ESP01_RELAY_001/status\" -v"
