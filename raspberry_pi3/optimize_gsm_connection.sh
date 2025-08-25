#!/bin/bash

# HomeGuard GSM Optimization Script
# Optimizes WireGuard VPN for GSM/4G connections

echo "📡 HomeGuard GSM Connection Optimization"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if WireGuard is installed
if ! command -v wg &> /dev/null; then
    echo -e "${RED}❌ WireGuard not found. Run setup_vpn_server.sh first${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Step 1: Backup Current Configuration${NC}"
sudo cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.backup
echo "✅ Configuration backed up to wg0.conf.backup"

echo -e "${BLUE}📋 Step 2: GSM-Optimized Configuration${NC}"

# Get current server private key
if [ -f "/etc/wireguard/server_private_key" ]; then
    SERVER_PRIVATE_KEY=$(sudo cat /etc/wireguard/server_private_key)
else
    echo -e "${RED}❌ Server private key not found${NC}"
    exit 1
fi

# Create GSM-optimized server configuration
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
# HomeGuard WireGuard Server - GSM Optimized
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.200.200.1/24
ListenPort = 51820
SaveConfig = false

# GSM Optimizations
MTU = 1280

# Enable NAT and forwarding (GSM-friendly)
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE; iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; iptables -t nat -D POSTROUTING -o wlan0 -j MASQUERADE; iptables -t nat -D POSTROUTING -o ppp0 -j MASQUERADE

# Client configurations will be added below

EOF

echo -e "${BLUE}📋 Step 3: Network Optimization${NC}"

# Optimize kernel network settings for GSM
cat > /tmp/gsm_network_optimization.conf << 'EOF'
# GSM/4G Network Optimizations for HomeGuard

# TCP optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Reduce timeouts for mobile connections
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15

# Optimize for variable latency (GSM)
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# WireGuard optimizations
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
EOF

# Apply optimizations
sudo cp /tmp/gsm_network_optimization.conf /etc/sysctl.d/99-homeguard-gsm.conf
sudo sysctl -p /etc/sysctl.d/99-homeguard-gsm.conf

echo "✅ Network optimizations applied"

echo -e "${BLUE}📋 Step 4: Creating GSM-Optimized Client Generator${NC}"

# Create GSM-optimized client generator
cat > ~/generate_gsm_client.sh << 'EOF'
#!/bin/bash

# HomeGuard GSM-Optimized Client Generator
# Creates client configurations optimized for mobile/GSM connections

if [ $# -eq 0 ]; then
    echo "Usage: $0 <client_name> [server_endpoint]"
    echo "Example: $0 iphone_ricardo your-gsm-ip.com"
    echo "         $0 android_maria 192.168.1.100"
    exit 1
fi

CLIENT_NAME=$1
SERVER_ENDPOINT=${2:-"YOUR_GSM_IP"}

SERVER_PUBLIC_KEY=$(sudo cat /etc/wireguard/server_public_key 2>/dev/null)
if [ -z "$SERVER_PUBLIC_KEY" ]; then
    echo "❌ Server public key not found"
    exit 1
fi

# Check if client already exists
if [ -f "/etc/wireguard/clients/${CLIENT_NAME}_private_key" ]; then
    echo "❌ Client $CLIENT_NAME already exists"
    exit 1
fi

# Create clients directory
sudo mkdir -p /etc/wireguard/clients

# Generate client keys
cd /etc/wireguard/clients
sudo wg genkey | sudo tee ${CLIENT_NAME}_private_key | sudo wg pubkey | sudo tee ${CLIENT_NAME}_public_key
sudo chmod 600 ${CLIENT_NAME}_private_key

CLIENT_PRIVATE_KEY=$(sudo cat ${CLIENT_NAME}_private_key)
CLIENT_PUBLIC_KEY=$(sudo cat ${CLIENT_NAME}_public_key)

# Get next available IP
CLIENT_COUNT=$(ls -1 /etc/wireguard/clients/*_private_key 2>/dev/null | wc -l)
CLIENT_IP="10.200.200.$((CLIENT_COUNT + 1))"

echo "🔑 Generating GSM-optimized config for: $CLIENT_NAME"
echo "📱 Client IP: $CLIENT_IP"
echo "📡 Server endpoint: $SERVER_ENDPOINT:51820"

# Create GSM-optimized client configuration
sudo tee /etc/wireguard/clients/${CLIENT_NAME}.conf > /dev/null <<CLIENTEOF
[Interface]
# HomeGuard VPN Client (GSM-Optimized): $CLIENT_NAME
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/32

# GSM Optimizations
MTU = 1280

# DNS servers (reliable for mobile)
DNS = 8.8.8.8, 1.1.1.1

[Peer]
# HomeGuard Server (GSM Connection)
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT:51820

# Allow HomeGuard networks
AllowedIPs = 10.200.200.0/24, 192.168.18.0/24

# Mobile connection optimizations
PersistentKeepalive = 25
CLIENTEOF

# Add peer to server config
echo "Adding peer to server configuration..."
sudo wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_IP/32

# Create QR code for mobile clients
echo "📱 Generating QR code for mobile setup..."
sudo qrencode -t ansiutf8 < /etc/wireguard/clients/${CLIENT_NAME}.conf
sudo qrencode -o /etc/wireguard/clients/${CLIENT_NAME}_gsm_qr.png < /etc/wireguard/clients/${CLIENT_NAME}.conf

echo "✅ GSM-optimized client configuration created!"
echo ""
echo "📁 Files created:"
echo "   Config: /etc/wireguard/clients/${CLIENT_NAME}.conf"
echo "   QR Code: /etc/wireguard/clients/${CLIENT_NAME}_gsm_qr.png"
echo ""
echo "📡 GSM Connection Benefits:"
echo "   • Optimized MTU (1280) for mobile networks"
echo "   • Enhanced keepalive (25s) for stable connection"
echo "   • Mobile-friendly DNS servers"
echo "   • Reduced timeouts for variable latency"
echo ""
echo "📱 Setup Instructions:"
echo "   1. Configure port forwarding on GSM router: 51820 UDP"
echo "   2. Update SERVER_ENDPOINT in client config if needed"
echo "   3. Scan QR code in WireGuard mobile app"
echo "   4. Test connection from external network"
EOF

chmod +x ~/generate_gsm_client.sh

echo -e "${BLUE}📋 Step 5: GSM Router Configuration Guide${NC}"

cat > ~/GSM_Router_Configuration.md << 'EOF'
# HomeGuard GSM Router Configuration Guide

## 📡 GSM Modem/Router Setup

### Typical GSM Router Access:
- **Huawei**: http://192.168.8.1 or http://192.168.1.1
- **ZTE**: http://192.168.0.1 or http://192.168.1.1  
- **Netgear**: http://192.168.5.1
- **TP-Link**: http://192.168.1.1

### Login Credentials:
- **Default**: admin/admin or admin/password
- **Check**: Router label or manual
- **Huawei**: admin/admin or admin/[WiFi password]

## ⚙️ Required Configuration

### 1. Port Forwarding:
```
Service Name: HomeGuard-VPN
External Port: 51820
Internal IP: [Raspberry Pi IP]
Internal Port: 51820  
Protocol: UDP
Status: Enabled
```

### 2. Firewall Settings:
```
Allow incoming: Port 51820 UDP
Block all other incoming ports
Allow all outgoing
```

### 3. Quality of Service (QoS):
```
High Priority:
- VPN traffic (port 51820)
- HomeGuard MQTT (port 1883) - internal only

Low Priority:  
- Other internet traffic
```

### 4. GSM Connection Settings:
```
APN: [Your carrier APN]
Connection Mode: Auto
Network Type: 4G/LTE preferred
```

## 📊 GSM Data Usage Optimization

### HomeGuard Traffic Estimates:
- **VPN Overhead**: ~10% additional data
- **MQTT Messages**: ~100 bytes each
- **Heartbeat**: ~1KB per minute per device
- **Audio Commands**: ~500 bytes each
- **Status Updates**: ~1KB each

### Monthly Data Usage (3 devices):
- **Minimal**: ~50MB (status only)
- **Normal**: ~200MB (regular monitoring)
- **Heavy**: ~500MB (frequent commands)

### Data Saving Tips:
```
1. Increase heartbeat intervals (60s → 300s)
2. Reduce status update frequency  
3. Use compressed payloads
4. Implement data usage monitoring
```

## 🔧 Advanced GSM Optimizations

### Connection Monitoring:
```bash
# Check signal strength
sudo mmcli -m 0 --signal-get

# Monitor data usage
sudo mmcli -m 0 --bearer-list
```

### Automatic Reconnection:
```bash
# Add to crontab
*/5 * * * * /home/pi/check_gsm_connection.sh
```

### Backup Internet Detection:
```bash
# Automatic failover to GSM
# When main internet fails
```

## 📱 Mobile App Configuration

### For GSM Connection:
```
VPN Settings:
- MTU: 1280 (important for GSM)
- Keepalive: 25 seconds
- Allowed IPs: 10.200.200.0/24, 192.168.18.0/24

MQTT Settings:
- Host: 192.168.18.236 (via VPN)
- Keep-alive: 60 seconds
- Clean Session: true
```

## 🛡️ Security Considerations

### GSM-Specific Security:
```
✅ Benefits:
- Isolated network
- Carrier-grade encryption
- Physical security (no ethernet access)
- Geographically distributed

⚠️ Considerations:
- Potential IMSI tracking
- Carrier can monitor metadata
- Signal can be jammed
- Data costs
```

### Recommended Security Layers:
1. **WireGuard VPN** (primary encryption)
2. **MQTT Authentication** (secondary auth)  
3. **Device-specific keys** (device auth)
4. **Regular key rotation** (key management)

## 📡 Carrier Recommendations

### Best for IoT/Security:
- **Verizon**: Excellent coverage, IoT plans
- **AT&T**: Good IoT support, fixed IPs available
- **T-Mobile**: Competitive pricing, good speeds

### IoT-Specific Plans:
- Static/Fixed IP addresses
- Lower data limits but consistent speeds
- Machine-to-Machine (M2M) rates
- No throttling for small data usage

## 🧪 Testing GSM Connection

### From Raspberry Pi:
```bash
# Test GSM modem
sudo mmcli -L

# Test internet via GSM
ping -c 4 8.8.8.8

# Test port forwarding
nmap -sU -p 51820 [your_gsm_external_ip]
```

### From External:
```bash
# Test VPN connectivity
# Use mobile data (different network)
# Try connecting WireGuard client
```
EOF

echo -e "${BLUE}📋 Step 6: Restart Services${NC}"
sudo systemctl restart wg-quick@wg0

echo -e "${GREEN}✅ GSM Optimization Complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps for GSM Setup:${NC}"
echo "1. Configure port forwarding on GSM router/modem"
echo "2. Generate client: ./generate_gsm_client.sh your_phone [gsm_ip]"
echo "3. Test connection from external network (mobile data)"
echo "4. Read GSM guide: cat GSM_Router_Configuration.md"
echo ""
echo -e "${BLUE}📡 GSM Connection Benefits:${NC}"
echo "• Isolated security network"
echo "• Full router control"
echo "• Backup internet connection"  
echo "• Optimized for mobile devices"
echo "• Professional security setup"
