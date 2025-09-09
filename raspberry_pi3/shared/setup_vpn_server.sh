#!/bin/bash

# HomeGuard VPN Setup Script for Raspberry Pi
# Sets up WireGuard VPN server for secure remote access

echo "🔒 HomeGuard VPN Setup - WireGuard Server"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ This script should not be run as root${NC}"
   echo "Please run as pi user with sudo privileges"
   exit 1
fi

# Get current user
CURRENT_USER=$(whoami)
echo -e "${BLUE}👤 Current user: $CURRENT_USER${NC}"

# Get Raspberry Pi local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "${BLUE}🌐 Local IP: $LOCAL_IP${NC}"

echo -e "${BLUE}📋 Step 1: System Update${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "${BLUE}📋 Step 2: Installing WireGuard${NC}"
sudo apt install -y wireguard wireguard-tools qrencode

echo -e "${BLUE}📋 Step 3: Installing Additional Tools${NC}"
sudo apt install -y ufw curl wget dnsutils

echo -e "${BLUE}📋 Step 4: Enable IP Forwarding${NC}"
# Enable IP forwarding permanently
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo -e "${BLUE}📋 Step 5: Generate WireGuard Keys${NC}"
cd /etc/wireguard
sudo wg genkey | sudo tee server_private_key | sudo wg pubkey | sudo tee server_public_key
sudo chmod 600 server_private_key

# Get keys
SERVER_PRIVATE_KEY=$(sudo cat server_private_key)
SERVER_PUBLIC_KEY=$(sudo cat server_public_key)

echo -e "${GREEN}🔑 Server keys generated${NC}"

echo -e "${BLUE}📋 Step 6: Configure WireGuard Server${NC}"

# Get external IP (for configuration reference)
EXTERNAL_IP=$(curl -s ifconfig.me)
echo -e "${YELLOW}🌍 External IP: $EXTERNAL_IP${NC}"

# Create server configuration
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
# HomeGuard WireGuard Server Configuration
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.200.200.1/24
ListenPort = 51820
SaveConfig = false

# Enable NAT and forwarding
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; iptables -t nat -D POSTROUTING -o wlan0 -j MASQUERADE

# Client configurations will be added below
# Use: sudo wg set wg0 peer [client_public_key] allowed-ips [client_ip]/32

EOF

echo -e "${BLUE}📋 Step 7: Configure Firewall${NC}"
# Configure UFW
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow WireGuard
sudo ufw allow 51820/udp comment "WireGuard VPN"

# Allow HomeGuard services
sudo ufw allow 1883/tcp comment "MQTT Broker"
sudo ufw allow 22/tcp comment "SSH"

# Allow local network access
sudo ufw allow from 10.200.200.0/24 comment "WireGuard clients"

echo -e "${BLUE}📋 Step 8: Enable WireGuard Service${NC}"
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

echo -e "${BLUE}📋 Step 9: Creating Client Generation Script${NC}"
# Create script to generate client configs
cat > ~/generate_wireguard_client.sh << 'EOF'
#!/bin/bash

# HomeGuard WireGuard Client Generator
# Usage: ./generate_wireguard_client.sh <client_name>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <client_name>"
    echo "Example: $0 iphone_ricardo"
    exit 1
fi

CLIENT_NAME=$1
SERVER_PUBLIC_KEY=$(sudo cat /etc/wireguard/server_public_key)
SERVER_ENDPOINT=""  # Will be filled manually

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

echo "🔑 Generating config for: $CLIENT_NAME"
echo "📱 Client IP: $CLIENT_IP"

# Get external IP for endpoint
EXTERNAL_IP=$(curl -s ifconfig.me)
echo "🌍 Server endpoint: $EXTERNAL_IP:51820"

# Create client configuration
sudo tee /etc/wireguard/clients/${CLIENT_NAME}.conf > /dev/null <<CLIENTEOF
[Interface]
# HomeGuard VPN Client: $CLIENT_NAME
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/32
DNS = 8.8.8.8, 1.1.1.1

[Peer]
# HomeGuard Server
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $EXTERNAL_IP:51820
AllowedIPs = 10.200.200.0/24, 192.168.18.0/24
PersistentKeepalive = 25
CLIENTEOF

# Add peer to server config
echo "Adding peer to server configuration..."
sudo wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_IP/32

# Create QR code for mobile clients
echo "📱 Generating QR code for mobile setup..."
sudo qrencode -t ansiutf8 < /etc/wireguard/clients/${CLIENT_NAME}.conf
sudo qrencode -o /etc/wireguard/clients/${CLIENT_NAME}_qr.png < /etc/wireguard/clients/${CLIENT_NAME}.conf

echo "✅ Client configuration created successfully!"
echo ""
echo "📁 Files created:"
echo "   Config file: /etc/wireguard/clients/${CLIENT_NAME}.conf"
echo "   QR code: /etc/wireguard/clients/${CLIENT_NAME}_qr.png"
echo ""
echo "📱 Mobile setup:"
echo "   1. Install WireGuard app"
echo "   2. Scan QR code above or import config file"
echo "   3. Connect to VPN"
echo ""
echo "💻 Desktop setup:"
echo "   1. Copy config file to client device"
echo "   2. Import into WireGuard client"
echo ""
echo "🔒 To remove this client later:"
echo "   sudo wg set wg0 peer $CLIENT_PUBLIC_KEY remove"
EOF

chmod +x ~/generate_wireguard_client.sh

echo -e "${BLUE}📋 Step 10: Creating Management Scripts${NC}"

# Create status script
cat > ~/wireguard_status.sh << 'EOF'
#!/bin/bash
echo "🔒 HomeGuard WireGuard Server Status"
echo "=================================="

echo "📊 Server Status:"
sudo systemctl status wg-quick@wg0 --no-pager -l

echo ""
echo "🔌 Active Connections:"
sudo wg show

echo ""
echo "🌐 Server Configuration:"
echo "Local IP: $(hostname -I | awk '{print $1}')"
echo "External IP: $(curl -s ifconfig.me)"
echo "WireGuard Port: 51820"

echo ""
echo "👥 Client Configurations:"
ls -la /etc/wireguard/clients/*.conf 2>/dev/null | awk '{print $9}' | xargs basename -s .conf 2>/dev/null || echo "No clients configured yet"

echo ""
echo "🔥 Firewall Status:"
sudo ufw status numbered
EOF

chmod +x ~/wireguard_status.sh

# Create restart script
cat > ~/wireguard_restart.sh << 'EOF'
#!/bin/bash
echo "🔄 Restarting WireGuard server..."
sudo systemctl restart wg-quick@wg0
echo "✅ WireGuard restarted"
./wireguard_status.sh
EOF

chmod +x ~/wireguard_restart.sh

echo -e "${BLUE}📋 Step 11: Creating HomeGuard Remote Access Guide${NC}"

cat > ~/HomeGuard_Remote_Access_Guide.md << 'EOF'
# HomeGuard Remote Access - Setup Guide

## 🔒 VPN Server Information
- **Server IP**: Check with: `curl ifconfig.me`
- **VPN Port**: 51820 (UDP)
- **VPN Network**: 10.200.200.0/24
- **HomeGuard Network**: 192.168.18.0/24

## 📱 Setting up Mobile Clients

### iPhone/iPad:
1. Install "WireGuard" from App Store
2. Run: `./generate_wireguard_client.sh iphone_yourname`
3. Scan QR code displayed
4. Connect to VPN

### Android:
1. Install "WireGuard" from Play Store
2. Run: `./generate_wireguard_client.sh android_yourname`
3. Scan QR code displayed
4. Connect to VPN

## 💻 Setting up Desktop Clients

### macOS:
1. Install "WireGuard" from Mac App Store
2. Run: `./generate_wireguard_client.sh macos_yourname`
3. Copy config file from `/etc/wireguard/clients/macos_yourname.conf`
4. Import config into WireGuard app

### Windows:
1. Download WireGuard from official website
2. Generate client: `./generate_wireguard_client.sh windows_yourname`
3. Copy config file and import

## 🏠 Accessing HomeGuard Services Remotely

Once connected to VPN, access services at:

### MQTT Broker:
- **Host**: 192.168.18.198 (or your Pi's IP)
- **Port**: 1883
- **User**: homeguard
- **Pass**: pu2clr123456

### HomeGuard Devices:
- **Motion Detector**: 192.168.18.193
- **Relay Controller**: 192.168.18.192
- **Audio System**: 192.168.18.198 (Pi IP)

### Example Remote Commands:
```bash
# From mobile/desktop with VPN connected:
mosquitto_pub -h 192.168.18.198 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456
mosquitto_pub -h 192.168.18.198 -t home/audio/cmnd -m "DOGS" -u homeguard -P pu2clr123456
```

## 🛠️ Management Commands

### Check VPN Status:
```bash
./wireguard_status.sh
```

### Generate New Client:
```bash
./generate_wireguard_client.sh client_name
```

### Restart VPN Server:
```bash
./wireguard_restart.sh
```

### Remove Client:
```bash
sudo wg set wg0 peer [CLIENT_PUBLIC_KEY] remove
```

## 🔒 Security Best Practices

1. **Change default MQTT credentials**
2. **Use strong client names**
3. **Regularly update system**
4. **Monitor VPN logs**
5. **Remove unused clients**

## 📡 Router Configuration

### Port Forwarding Required:
- **Port**: 51820 UDP
- **Destination**: Your Raspberry Pi IP
- **Protocol**: UDP

### Dynamic DNS (Optional):
- Use services like No-IP, DuckDNS for dynamic IP
- Update endpoint in client configs when IP changes
EOF

echo -e "${GREEN}✅ WireGuard VPN Server Setup Complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Configure port forwarding on your router:"
echo "   - Port: 51820 UDP → $LOCAL_IP"
echo ""
echo "2. Generate your first client:"
echo "   ./generate_wireguard_client.sh your_phone"
echo ""
echo "3. Check server status:"
echo "   ./wireguard_status.sh"
echo ""
echo "4. Read the complete guide:"
echo "   cat HomeGuard_Remote_Access_Guide.md"
echo ""
echo -e "${BLUE}🔒 Your HomeGuard system is now ready for secure remote access!${NC}"
echo ""
echo -e "${YELLOW}⚠️ Important:${NC}"
echo "- Configure port forwarding on your router"
echo "- Update MQTT credentials for security"
echo "- Test VPN connection from outside your network"
