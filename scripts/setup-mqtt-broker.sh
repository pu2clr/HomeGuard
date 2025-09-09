#!/bin/bash
# HomeGuard MQTT Broker Setup Script for Raspberry Pi 4
# IP: 192.168.18.198

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
BROKER_IP="192.168.18.198"
HOMEGUARD_USER="homeguard"
HOMEGUARD_PASS="pu2clr123456"
ADMIN_USER="admin"

echo -e "${BLUE}🏠 HomeGuard MQTT Broker Setup${NC}"
echo "========================================"
echo -e "Setting up secure MQTT broker on ${GREEN}$BROKER_IP${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as pi user with sudo privileges."
   exit 1
fi

# Update system
echo -e "${BLUE}📦 Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y
print_status "System updated"

# Install Mosquitto
echo -e "${BLUE}🦟 Installing Mosquitto MQTT broker...${NC}"
sudo apt install mosquitto mosquitto-clients -y
print_status "Mosquitto installed"

# Stop service for configuration
sudo systemctl stop mosquitto

# Backup original configuration
if [ -f /etc/mosquitto/mosquitto.conf ]; then
    sudo cp /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.backup
    print_status "Original configuration backed up"
fi

# Create directories
echo -e "${BLUE}📁 Creating configuration directories...${NC}"
sudo mkdir -p /etc/mosquitto/passwd
sudo mkdir -p /etc/mosquitto/conf.d
sudo mkdir -p /var/log/mosquitto
sudo mkdir -p /etc/mosquitto/certs
sudo mkdir -p /etc/mosquitto/ca_certificates

# Set ownership
sudo chown -R mosquitto:mosquitto /var/log/mosquitto
sudo chown -R mosquitto:mosquitto /etc/mosquitto/passwd
print_status "Directories created"

# Create password file
echo -e "${BLUE}🔐 Setting up authentication...${NC}"
read -s -p "Enter password for admin user: " ADMIN_PASS
echo ""
read -s -p "Confirm admin password: " ADMIN_PASS_CONFIRM
echo ""

if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
    print_error "Passwords don't match!"
    exit 1
fi

# Create users
sudo mosquitto_passwd -c /etc/mosquitto/passwd/passwords $ADMIN_USER <<< "$ADMIN_PASS"
sudo mosquitto_passwd /etc/mosquitto/passwd/passwords $HOMEGUARD_USER <<< "$HOMEGUARD_PASS"
sudo mosquitto_passwd /etc/mosquitto/passwd/passwords homeassistant <<< "homeassistant123"
sudo mosquitto_passwd /etc/mosquitto/passwd/passwords automation <<< "automation123"

print_status "User authentication configured"

# Create ACL file
echo -e "${BLUE}🛡️  Setting up access control...${NC}"
sudo tee /etc/mosquitto/conf.d/acl.conf > /dev/null <<EOF
# HomeGuard MQTT Access Control List

# Admin user - full access
user $ADMIN_USER
topic readwrite #

# HomeGuard devices - device-specific access
user $HOMEGUARD_USER
topic readwrite home/+/+
topic readwrite home/+/+/+
topic read \$SYS/broker/uptime
topic read \$SYS/broker/clients/connected

# Home Assistant integration
user homeassistant
topic readwrite home/+/+
topic readwrite home/+/+/+
topic readwrite homeassistant/+/+
topic readwrite homeassistant/+/+/+

# Automation scripts
user automation
topic readwrite home/+/+
topic readwrite home/+/+/+
topic read \$SYS/broker/+
EOF

print_status "Access control configured"

# Create main configuration
echo -e "${BLUE}⚙️  Creating main configuration...${NC}"
sudo tee /etc/mosquitto/mosquitto.conf > /dev/null <<EOF
# HomeGuard MQTT Broker Configuration
# Raspberry Pi 4 - IP: $BROKER_IP

# Basic settings
pid_file /run/mosquitto/mosquitto.pid
persistence true
persistence_location /var/lib/mosquitto/

# Logging
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true
connection_messages true
log_timestamp_format %Y-%m-%d %H:%M:%S

# Network settings
bind_address 0.0.0.0
port 1883

# Security settings
allow_anonymous false
password_file /etc/mosquitto/passwd/passwords
acl_file /etc/mosquitto/conf.d/acl.conf

# Connection limits
max_connections 100
max_inflight_messages 20
max_queued_messages 100

# Message size limits
message_size_limit 1024
memory_limit 50MB

# Keep alive
keepalive_interval 60

# Include additional config files
include_dir /etc/mosquitto/conf.d
EOF

print_status "Main configuration created"

# Create log rotation
echo -e "${BLUE}📝 Setting up log rotation...${NC}"
sudo tee /etc/logrotate.d/mosquitto > /dev/null <<EOF
/var/log/mosquitto/mosquitto.log {
    weekly
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    copytruncate
    postrotate
        systemctl reload mosquitto
    endscript
}
EOF

print_status "Log rotation configured"

# Create monitoring script
echo -e "${BLUE}👁️  Setting up monitoring...${NC}"
sudo tee /usr/local/bin/mosquitto-monitor.sh > /dev/null <<EOF
#!/bin/bash
# HomeGuard MQTT Broker Monitor

LOGFILE="/var/log/mosquitto/monitor.log"
BROKER_IP="$BROKER_IP"
ADMIN_USER="$ADMIN_USER"
ADMIN_PASS="$ADMIN_PASS"

# Function to log messages
log_message() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> \$LOGFILE
}

# Check if mosquitto is running
if ! systemctl is-active --quiet mosquitto; then
    log_message "ERROR: Mosquitto service is not running. Attempting restart..."
    sudo systemctl restart mosquitto
    sleep 5
    
    if systemctl is-active --quiet mosquitto; then
        log_message "SUCCESS: Mosquitto service restarted successfully"
    else
        log_message "CRITICAL: Failed to restart Mosquitto service"
        exit 1
    fi
fi

# Check if broker is responding
if ! mosquitto_pub -h \$BROKER_IP -t "system/monitor" -m "\$(date)" -u \$ADMIN_USER -P "\$ADMIN_PASS" >/dev/null 2>&1; then
    log_message "WARNING: Broker not responding to publish test"
else
    log_message "INFO: Broker health check passed"
fi

# Check connection count
CONNECTIONS=\$(mosquitto_sub -h \$BROKER_IP -t '\$SYS/broker/clients/connected' -C 1 -u \$ADMIN_USER -P "\$ADMIN_PASS" 2>/dev/null)
log_message "INFO: Active connections: \$CONNECTIONS"

# Check uptime
UPTIME=\$(mosquitto_sub -h \$BROKER_IP -t '\$SYS/broker/uptime' -C 1 -u \$ADMIN_USER -P "\$ADMIN_PASS" 2>/dev/null)
log_message "INFO: Broker uptime: \$UPTIME seconds"
EOF

sudo chmod +x /usr/local/bin/mosquitto-monitor.sh
print_status "Monitoring script created"

# Create systemd service and timer for monitoring
sudo tee /etc/systemd/system/mosquitto-monitor.service > /dev/null <<EOF
[Unit]
Description=HomeGuard MQTT Broker Monitor
After=mosquitto.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mosquitto-monitor.sh
User=mosquitto
EOF

sudo tee /etc/systemd/system/mosquitto-monitor.timer > /dev/null <<EOF
[Unit]
Description=HomeGuard MQTT Broker Monitor
Requires=mosquitto-monitor.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

print_status "Monitoring service configured"

# Create backup script
echo -e "${BLUE}💾 Setting up backup system...${NC}"
sudo tee /usr/local/bin/mosquitto-backup.sh > /dev/null <<EOF
#!/bin/bash
BACKUP_DIR="/home/pi/mosquitto-backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

# Backup configuration
sudo tar -czf \$BACKUP_DIR/mosquitto-config-\$DATE.tar.gz \\
    /etc/mosquitto/ \\
    /var/lib/mosquitto/ \\
    --exclude='*.log'

# Keep only last 7 backups
find \$BACKUP_DIR -name "mosquitto-config-*.tar.gz" -mtime +7 -delete

echo "Backup completed: mosquitto-config-\$DATE.tar.gz"
EOF

sudo chmod +x /usr/local/bin/mosquitto-backup.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mosquitto-backup.sh") | crontab -

print_status "Backup system configured"

# Configure firewall
echo -e "${BLUE}🔥 Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    sudo ufw allow from 192.168.18.0/24 to any port 1883 comment 'MQTT HomeGuard'
    sudo ufw allow from 192.168.18.0/24 to any port 8883 comment 'MQTT SSL HomeGuard'
    print_status "UFW firewall configured"
else
    print_warning "UFW not installed. Please configure firewall manually."
fi

# Test configuration
echo -e "${BLUE}🧪 Testing configuration...${NC}"
if sudo mosquitto -c /etc/mosquitto/mosquitto.conf -t; then
    print_status "Configuration test passed"
else
    print_error "Configuration test failed"
    exit 1
fi

# Enable and start services
echo -e "${BLUE}🚀 Starting services...${NC}"
sudo systemctl enable mosquitto
sudo systemctl start mosquitto
sudo systemctl enable mosquitto-monitor.timer
sudo systemctl start mosquitto-monitor.timer

# Wait for service to start
sleep 3

# Test connection
echo -e "${BLUE}🔌 Testing connection...${NC}"
if mosquitto_pub -h $BROKER_IP -t "test/setup" -m "Setup complete" -u $HOMEGUARD_USER -P $HOMEGUARD_PASS; then
    print_status "Connection test passed"
else
    print_error "Connection test failed"
fi

# Show summary
echo ""
echo -e "${GREEN}🎉 HomeGuard MQTT Broker Setup Complete!${NC}"
echo "========================================"
echo -e "Broker IP: ${BLUE}$BROKER_IP${NC}"
echo -e "Port: ${BLUE}1883${NC}"
echo ""
echo -e "${YELLOW}📋 User Accounts Created:${NC}"
echo -e "  Admin: ${BLUE}$ADMIN_USER${NC} (full access)"
echo -e "  HomeGuard: ${BLUE}$HOMEGUARD_USER${NC} (device access)"
echo -e "  Home Assistant: ${BLUE}homeassistant${NC} (integration access)"
echo -e "  Automation: ${BLUE}automation${NC} (script access)"
echo ""
echo -e "${YELLOW}🧪 Test Commands:${NC}"
echo "  mosquitto_pub -h $BROKER_IP -t test/topic -m 'Hello' -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"
echo "  mosquitto_sub -h $BROKER_IP -t test/topic -u $HOMEGUARD_USER -P $HOMEGUARD_PASS"
echo ""
echo -e "${YELLOW}📊 Monitor Broker:${NC}"
echo "  mosquitto_sub -h $BROKER_IP -t '\$SYS/#' -u $ADMIN_USER -P [admin_password]"
echo ""
echo -e "${YELLOW}📝 Log Files:${NC}"
echo "  Main log: /var/log/mosquitto/mosquitto.log"
echo "  Monitor log: /var/log/mosquitto/monitor.log"
echo ""
echo -e "${YELLOW}⚠️  Next Steps:${NC}"
echo "1. Update ESP-01S sketches with new IP: $BROKER_IP"
echo "2. Update Python scripts with new IP: $BROKER_IP"
echo "3. Test device connections"
echo "4. Configure SSL/TLS if needed (see documentation)"
echo ""
print_status "Setup completed successfully!"
