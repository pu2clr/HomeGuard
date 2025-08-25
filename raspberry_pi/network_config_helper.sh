#!/bin/bash

# HomeGuard Network Configuration Helper
# Helps identify network settings for router configuration

echo "🌐 HomeGuard Network Configuration Helper"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 Current Network Information${NC}"
echo "=============================="

# Get current IP information
LOCAL_IP=$(hostname -I | awk '{print $1}')
GATEWAY_IP=$(ip route | grep default | awk '{print $3}')
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to detect")

echo "🖥️  Raspberry Pi IP: $LOCAL_IP"
echo "🌐 Gateway/Router IP: $GATEWAY_IP" 
echo "🌍 External IP: $EXTERNAL_IP"

# Check network interface
INTERFACE=$(ip route | grep default | awk '{print $5}')
echo "🔌 Network Interface: $INTERFACE"

# Check if WiFi or Ethernet
if [[ $INTERFACE == wlan* ]]; then
    echo "📶 Connection Type: WiFi"
    WIFI_INFO=$(iwconfig $INTERFACE 2>/dev/null | grep "ESSID")
    if [ ! -z "$WIFI_INFO" ]; then
        echo "📡 WiFi Network: $WIFI_INFO"
    fi
else
    echo "🔌 Connection Type: Ethernet"
fi

echo ""
echo -e "${YELLOW}⚙️ Router Configuration Required${NC}"
echo "================================"
echo "Access your router at: http://$GATEWAY_IP"
echo "Look for: 'Port Forwarding', 'Virtual Server', or 'NAT'"
echo ""
echo -e "${GREEN}✅ Port Forwarding Rule to Create:${NC}"
echo "┌────────────────────────────────────────┐"
echo "│ Rule Name: HomeGuard-VPN               │"
echo "│ External Port: 51820                   │" 
echo "│ Internal IP: $LOCAL_IP                 │"
echo "│ Internal Port: 51820                   │"
echo "│ Protocol: UDP                          │"
echo "│ Status: Enabled                        │"
echo "└────────────────────────────────────────┘"

echo ""
echo -e "${BLUE}🔒 Security Information${NC}"
echo "======================"
echo "✅ Port 51820 (VPN) - SAFE to expose (encrypted)"
echo "❌ Port 1883 (MQTT) - DO NOT expose directly"
echo "❌ Port 22 (SSH) - DO NOT expose directly"
echo "❌ Other ports - Access only via VPN"

echo ""
echo -e "${YELLOW}📡 Testing Network Connectivity${NC}"
echo "=============================="

# Test internal connectivity
echo "🔍 Testing internal network..."
ping -c 1 $GATEWAY_IP > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Gateway reachable"
else
    echo "❌ Gateway not reachable"
fi

# Test internet connectivity  
ping -c 1 8.8.8.8 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Internet connectivity OK"
else
    echo "❌ No internet connectivity"
fi

# Check if port 51820 is already open
echo ""
echo "🔍 Checking WireGuard service..."
if systemctl is-active --quiet wg-quick@wg0; then
    echo "✅ WireGuard service is running"
    
    # Show WireGuard status
    sudo wg show 2>/dev/null | grep -q "interface: wg0"
    if [ $? -eq 0 ]; then
        echo "✅ WireGuard interface active"
    else
        echo "⚠️ WireGuard service running but no active interface"
    fi
else
    echo "❌ WireGuard service not running"
    echo "   Run: sudo systemctl start wg-quick@wg0"
fi

# Check firewall status
echo ""
echo "🔍 Checking firewall configuration..."
UFW_STATUS=$(sudo ufw status | grep "Status:" | awk '{print $2}')
echo "🔥 UFW Firewall: $UFW_STATUS"

if [ "$UFW_STATUS" = "active" ]; then
    echo "🔍 UFW Rules for WireGuard:"
    sudo ufw status numbered | grep "51820" || echo "⚠️ No WireGuard rules found"
fi

echo ""
echo -e "${BLUE}🧪 Router Configuration Test${NC}"
echo "==========================="

cat << 'EOF'
After configuring port forwarding on your router, test with:

1. From inside your network:
   nmap -sU -p 51820 YOUR_EXTERNAL_IP

2. From outside your network (mobile data):
   Use online port scanner: https://www.yougetsignal.com/tools/open-ports/
   
3. WireGuard client test:
   Try connecting with generated client config

EOF

echo ""
echo -e "${YELLOW}📋 Common Router Interfaces${NC}"
echo "=========================="

cat << 'EOF'
🏠 Popular Router Brands & Default Access:

• TP-Link: http://192.168.1.1 or http://tplinkwifi.net
• Netgear: http://192.168.1.1 or http://routerlogin.net  
• D-Link: http://192.168.1.1 or http://dlinkrouter.local
• Linksys: http://192.168.1.1 or http://myrouter.local
• ASUS: http://192.168.1.1 or http://router.asus.com
• Huawei: http://192.168.1.1 or http://192.168.8.1

Default credentials (check router label if these don't work):
• admin/admin
• admin/password  
• admin/[blank]
• [blank]/admin
EOF

echo ""
echo -e "${GREEN}📋 Step-by-Step Router Configuration${NC}"
echo "=================================="

cat << EOF
1. 🌐 Access router: http://$GATEWAY_IP
2. 🔐 Login with admin credentials
3. 🔍 Find "Port Forwarding" or "Virtual Server" section
4. ➕ Add new rule:
   - Name: HomeGuard-VPN
   - External Port: 51820 
   - Internal IP: $LOCAL_IP
   - Internal Port: 51820
   - Protocol: UDP
   - Enable: Yes
5. 💾 Save configuration
6. 🔄 Restart router if required
7. 🧪 Test connection from external network
EOF

echo ""
echo -e "${BLUE}🔧 Advanced Configuration (Optional)${NC}"
echo "================================="

cat << 'EOF'
🚀 For enhanced security:

1. Change WireGuard port (edit /etc/wireguard/wg0.conf):
   ListenPort = 12345  # Instead of 51820
   
2. Setup Dynamic DNS (if IP changes frequently):
   - No-IP: https://www.noip.com/
   - DuckDNS: https://www.duckdns.org/
   - FreeDNS: https://freedns.afraid.org/
   
3. Setup UPnP (automatic port forwarding):
   sudo apt install upnpc
   upnpc -a $LOCAL_IP 51820 51820 UDP
EOF

echo ""
echo -e "${YELLOW}⚠️ Security Warnings${NC}"
echo "=================="

cat << 'EOF'
🛡️ IMPORTANT Security Notes:

✅ SAFE to expose:
   • Port 51820 UDP (WireGuard VPN) - Fully encrypted

❌ NEVER expose directly:
   • Port 1883 (MQTT) - Unencrypted credentials
   • Port 22 (SSH) - Target for attacks  
   • Port 80/443 (Web) - Unless using HTTPS with auth
   
🔒 All HomeGuard access should go through VPN tunnel!
EOF

echo ""
echo -e "${GREEN}✅ Configuration Summary${NC}"
echo "====================="
echo "Router IP: http://$GATEWAY_IP"
echo "Forward Port: 51820 UDP → $LOCAL_IP:51820"
echo "External IP: $EXTERNAL_IP"
echo "VPN Network: 10.200.200.0/24"
echo ""
echo "After router configuration, generate client with:"
echo "./generate_wireguard_client.sh your_device_name"
