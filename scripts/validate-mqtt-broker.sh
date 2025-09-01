#!/bin/bash
# HomeGuard MQTT Broker Validation Script
# Tests all aspects of the MQTT broker setup

BROKER_IP="192.168.18.198"
HOMEGUARD_USER="homeguard"
HOMEGUARD_PASS="pu2clr123456"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 HomeGuard MQTT Broker Validation${NC}"
echo "===================================="
echo -e "Testing broker at: ${GREEN}$BROKER_IP${NC}"
echo ""

# Test counters
TESTS_PASSED=0
TESTS_TOTAL=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Function to run test with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    echo -e "${YELLOW}🔍 $test_name${NC}"
    
    if output=$(eval "$test_command" 2>&1); then
        echo -e "${GREEN}✅ PASS${NC}"
        if [ -n "$output" ]; then
            echo "   Output: $output"
        fi
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        if [ -n "$output" ]; then
            echo "   Error: $output"
        fi
        return 1
    fi
}

echo -e "${BLUE}📡 Network Connectivity Tests${NC}"
echo "-----------------------------"

# Test 1: Ping broker
run_test "Broker reachability" "ping -c 1 -W 3 $BROKER_IP"

# Test 2: Port accessibility
run_test "MQTT port 1883" "nc -z $BROKER_IP 1883"

# Test 3: SSL port (if configured)
run_test "MQTT SSL port 8883" "nc -z $BROKER_IP 8883"

echo ""
echo -e "${BLUE}🔐 Authentication Tests${NC}"
echo "----------------------"

# Test 4: Anonymous connection (should fail)
run_test "Anonymous connection rejection" "! mosquitto_pub -h $BROKER_IP -t test/anonymous -m test"

# Test 5: Valid user authentication
run_test "Valid user authentication" "mosquitto_pub -h $BROKER_IP -t test/auth -m 'auth test' -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"

# Test 6: Invalid user authentication (should fail)
run_test "Invalid user rejection" "! mosquitto_pub -h $BROKER_IP -t test/invalid -m test -u invalid -P invalid"

echo ""
echo -e "${BLUE}📋 Topic Access Control Tests${NC}"
echo "-----------------------------"

# Test 7: HomeGuard user can publish to home topics
run_test "HomeGuard user home topic access" "mosquitto_pub -h $BROKER_IP -t home/test/validation -m 'acl test' -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"

# Test 8: HomeGuard user can subscribe to home topics
run_test "HomeGuard user home subscription" "timeout 2 mosquitto_sub -h $BROKER_IP -t home/test/validation -C 1 -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"

echo ""
echo -e "${BLUE}🏠 HomeGuard Device Tests${NC}"
echo "------------------------"

# Test 9: Relay command topic
run_test "Relay command topic" "mosquitto_pub -h $BROKER_IP -t home/relay1/cmnd -m 'TEST' -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"

# Test 10: Motion detector topic
run_test "Motion detector topic" "mosquitto_pub -h $BROKER_IP -t home/motion1/motion -m '{\"test\":\"validation\"}' -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"

echo ""
echo -e "${BLUE}📊 Broker System Information${NC}"
echo "----------------------------"

# Test 11: System topic access
run_test_with_output "Broker uptime" "mosquitto_sub -h $BROKER_IP -t '\$SYS/broker/uptime' -C 1 -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"

# Test 12: Client count
run_test_with_output "Connected clients" "mosquitto_sub -h $BROKER_IP -t '\$SYS/broker/clients/connected' -C 1 -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"

# Test 13: Broker version
run_test_with_output "Broker version" "mosquitto_sub -h $BROKER_IP -t '\$SYS/broker/version' -C 1 -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"

echo ""
echo -e "${BLUE}🔄 Message Flow Tests${NC}"
echo "--------------------"

# Test 14: Publish/Subscribe loop
echo -e "${YELLOW}🔍 Message delivery test${NC}"
((TESTS_TOTAL++))

# Start subscriber in background
mosquitto_sub -h $BROKER_IP -t test/delivery -C 1 -u $HOMEGUARD_USER -P $HOMEGUARD_PASS > /tmp/mqtt_test_result &
SUB_PID=$!

# Wait a moment for subscriber to connect
sleep 1

# Publish message
if mosquitto_pub -h $BROKER_IP -t test/delivery -m "delivery test message" -u $HOMEGUARD_USER -P $HOMEGUARD_PASS; then
    # Wait for message
    sleep 2
    
    # Check if message was received
    if kill -0 $SUB_PID 2>/dev/null; then
        kill $SUB_PID 2>/dev/null
    fi
    
    if [ -f /tmp/mqtt_test_result ] && grep -q "delivery test message" /tmp/mqtt_test_result; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
    
    rm -f /tmp/mqtt_test_result
else
    echo -e "${RED}❌ FAIL${NC}"
    kill $SUB_PID 2>/dev/null
fi

echo ""
echo -e "${BLUE}🚀 Performance Tests${NC}"
echo "------------------"

# Test 15: Message throughput
echo -e "${YELLOW}🔍 Message throughput (10 messages)${NC}"
((TESTS_TOTAL++))

start_time=$(date +%s.%N)
success_count=0

for i in {1..10}; do
    if mosquitto_pub -h $BROKER_IP -t test/performance -m "Message $i" -u $HOMEGUARD_USER -P $HOMEGUARD_PASS; then
        ((success_count++))
    fi
done

end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)

if [ $success_count -eq 10 ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    echo "   Duration: ${duration}s"
    echo "   Messages/second: $(echo "scale=2; 10 / $duration" | bc)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "   Only $success_count/10 messages delivered"
fi

echo ""
echo -e "${BLUE}📈 Test Results Summary${NC}"
echo "======================"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$((TESTS_TOTAL - TESTS_PASSED))${NC}"
echo -e "Total tests: ${BLUE}$TESTS_TOTAL${NC}"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed! MQTT broker is working correctly.${NC}"
    exit 0
else
    echo ""
    echo -e "${YELLOW}⚠️  Some tests failed. Please check broker configuration.${NC}"
    
    echo ""
    echo -e "${BLUE}🔧 Troubleshooting Tips:${NC}"
    echo "- Check if Mosquitto service is running: sudo systemctl status mosquitto"
    echo "- Check broker logs: sudo tail -f /var/log/mosquitto/mosquitto.log"
    echo "- Verify firewall settings: sudo ufw status"
    echo "- Test local connection: mosquitto_pub -h localhost -t test -m test -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"
    exit 1
fi
