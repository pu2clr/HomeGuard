#!/bin/bash
# Test script for HomeGuard Dual Pi3 Audio System

echo "🧪 HomeGuard Audio System - Test Suite"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Directory Structure
echo -e "\n${BLUE}🗂️  Test 1: Directory Structure${NC}"
test_directories() {
    local all_good=0
    
    # Check main directories
    [ -d "raspberry_pi3/shared" ] || all_good=1
    [ -d "raspberry_pi3/ground" ] || all_good=1
    [ -d "raspberry_pi3/first" ] || all_good=1
    [ -d "raspberry_pi3/logs" ] || all_good=1
    
    # Check shared files
    [ -f "raspberry_pi3/shared/base_audio_simulator.py" ] || all_good=1
    
    # Check ground floor files
    [ -f "raspberry_pi3/ground/audio_ground.py" ] || all_good=1
    [ -f "raspberry_pi3/ground/ground_config.json" ] || all_good=1
    [ -x "raspberry_pi3/ground/start_ground_floor.sh" ] || all_good=1
    
    # Check first floor files
    [ -f "raspberry_pi3/first/audio_first.py" ] || all_good=1
    [ -f "raspberry_pi3/first/first_config.json" ] || all_good=1
    [ -x "raspberry_pi3/first/start_first_floor.sh" ] || all_good=1
    
    return $all_good
}

test_directories
print_result $? "Directory structure and files"

# Test 2: Python Syntax Check
echo -e "\n${BLUE}🐍 Test 2: Python Syntax${NC}"
test_python_syntax() {
    local all_good=0
    
    # Test shared module
    python3 -m py_compile raspberry_pi3/shared/base_audio_simulator.py 2>/dev/null || all_good=1
    
    # Test ground floor (ignore import errors for now)
    python3 -c "
import ast, sys
try:
    with open('raspberry_pi3/ground/audio_ground.py', 'r') as f:
        ast.parse(f.read())
except SyntaxError:
    sys.exit(1)
" || all_good=1
    
    # Test first floor (ignore import errors for now)
    python3 -c "
import ast, sys
try:
    with open('raspberry_pi3/first/audio_first.py', 'r') as f:
        ast.parse(f.read())
except SyntaxError:
    sys.exit(1)
" || all_good=1
    
    return $all_good
}

test_python_syntax
print_result $? "Python syntax validation"

# Test 3: JSON Configuration
echo -e "\n${BLUE}📋 Test 3: JSON Configuration${NC}"
test_json_config() {
    local all_good=0
    
    # Test ground config
    python3 -c "import json; json.load(open('raspberry_pi3/ground/ground_config.json'))" 2>/dev/null || all_good=1
    
    # Test first config
    python3 -c "import json; json.load(open('raspberry_pi3/first/first_config.json'))" 2>/dev/null || all_good=1
    
    return $all_good
}

test_json_config
print_result $? "JSON configuration files"

# Test 4: Required Python Packages
echo -e "\n${BLUE}📦 Test 4: Python Dependencies${NC}"
test_dependencies() {
    local all_good=0
    
    python3 -c "import pygame" 2>/dev/null || all_good=1
    python3 -c "import paho.mqtt.client" 2>/dev/null || all_good=1
    python3 -c "import schedule" 2>/dev/null || all_good=1
    
    return $all_good
}

test_dependencies
if [ $? -eq 0 ]; then
    print_result 0 "Python dependencies available"
else
    print_result 1 "Python dependencies missing (run: pip3 install pygame paho-mqtt schedule)"
fi

# Test 5: MQTT Broker Connectivity
echo -e "\n${BLUE}🔌 Test 5: MQTT Connectivity${NC}"
test_mqtt_connection() {
    if ! command -v mosquitto_pub &> /dev/null; then
        return 2  # Skip test
    fi
    
    # Test MQTT connection
    timeout 5s mosquitto_pub -h 192.168.18.6 -u homeguard -P pu2clr123456 \
        -t "homeguard/test/connection" -m "test" 2>/dev/null
    return $?
}

test_mqtt_connection
case $? in
    0) print_result 0 "MQTT broker connectivity" ;;
    2) echo -e "${YELLOW}⏭️  SKIP${NC}: MQTT test (mosquitto-clients not installed)" ;;
    *) print_result 1 "MQTT broker connectivity" ;;
esac

# Test 6: Audio Directories Structure
echo -e "\n${BLUE}🎵 Test 6: Audio Directories${NC}"
test_audio_structure() {
    local all_good=0
    
    # Ground floor audio directories
    [ -d "raspberry_pi3/ground/audio_files/dogs" ] || all_good=1
    [ -d "raspberry_pi3/ground/audio_files/doors" ] || all_good=1
    [ -d "raspberry_pi3/ground/audio_files/footsteps" ] || all_good=1
    [ -d "raspberry_pi3/ground/audio_files/tv_radio" ] || all_good=1
    [ -d "raspberry_pi3/ground/audio_files/alerts" ] || all_good=1
    
    # First floor audio directories
    [ -d "raspberry_pi3/first/audio_files/doors" ] || all_good=1
    [ -d "raspberry_pi3/first/audio_files/footsteps" ] || all_good=1
    [ -d "raspberry_pi3/first/audio_files/toilets" ] || all_good=1
    [ -d "raspberry_pi3/first/audio_files/shower" ] || all_good=1
    [ -d "raspberry_pi3/first/audio_files/bedroom" ] || all_good=1
    [ -d "raspberry_pi3/first/audio_files/alerts" ] || all_good=1
    
    return $all_good
}

test_audio_structure
print_result $? "Audio directory structure"

# Test 7: Configuration Validation
echo -e "\n${BLUE}⚙️  Test 7: Configuration Validation${NC}"
test_config_validation() {
    local all_good=0
    
    # Test ground config content
    python3 -c "
import json
config = json.load(open('raspberry_pi3/ground/ground_config.json'))
assert config['floor'] == 'ground'
assert config['mqtt_broker'] == '192.168.18.6'
assert 'motion_responses' in config
assert 'schedules' in config
" 2>/dev/null || all_good=1
    
    # Test first config content
    python3 -c "
import json
config = json.load(open('raspberry_pi3/first/first_config.json'))
assert config['floor'] == 'first'
assert config['mqtt_broker'] == '192.168.18.6'
assert 'motion_responses' in config
assert 'schedules' in config
" 2>/dev/null || all_good=1
    
    return $all_good
}

test_config_validation
print_result $? "Configuration validation"

# Test Summary
echo -e "\n${BLUE}📊 Test Results Summary${NC}"
echo "======================================"
echo -e "${GREEN}Tests Passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Tests Failed: ${TESTS_FAILED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! System ready to deploy.${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some tests failed. Please fix issues before deployment.${NC}"
    exit 1
fi
