# HomeGuard MQTT Broker Setup - Raspberry Pi 4

## Overview
This guide configures a Raspberry Pi 4 (IP: 192.168.1.102) as a secure MQTT broker for the HomeGuard system using Mosquitto with authentication and SSL/TLS encryption.

## Installation

### 1. Update System
```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Install Mosquitto MQTT Broker
```bash
# Install Mosquitto broker and clients
sudo apt install mosquitto mosquitto-clients -y

# Enable and start service
sudo systemctl enable mosquitto
sudo systemctl start mosquitto
```

### 3. Verify Installation
```bash
# Check service status
sudo systemctl status mosquitto

# Check if broker is listening
sudo netstat -tlnp | grep 1883
```

## Security Configuration

### 1. Create Password File
```bash
# Create password file directory
sudo mkdir -p /etc/mosquitto/passwd

# Create user with password
sudo mosquitto_passwd -c /etc/mosquitto/passwd/passwords homeguard

# Add additional users if needed
sudo mosquitto_passwd /etc/mosquitto/passwd/passwords admin
sudo mosquitto_passwd /etc/mosquitto/passwd/passwords homeassistant
sudo mosquitto_passwd /etc/mosquitto/passwd/passwords automation
```

### 2. Configure Access Control List (ACL)
```bash
# Create ACL file
sudo nano /etc/mosquitto/conf.d/acl.conf
```

**ACL Configuration (`/etc/mosquitto/conf.d/acl.conf`):**
```
# HomeGuard MQTT Access Control List

# Admin user - full access
user admin
topic readwrite #

# HomeGuard devices - device-specific access
user homeguard
topic readwrite home/+/+
topic readwrite home/+/+/+
topic read $SYS/broker/uptime
topic read $SYS/broker/clients/connected

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
topic read $SYS/broker/+
```

### 3. Main Mosquitto Configuration
```bash
# Backup original config
sudo cp /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.backup

# Create new configuration
sudo nano /etc/mosquitto/mosquitto.conf
```

**Main Configuration (`/etc/mosquitto/mosquitto.conf`):**
```
# HomeGuard MQTT Broker Configuration
# Raspberry Pi 4 - IP: 192.168.1.102

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
```

### 4. SSL/TLS Configuration (Optional but Recommended)
```bash
# Create certificates directory
sudo mkdir -p /etc/mosquitto/certs
sudo mkdir -p /etc/mosquitto/ca_certificates

# Generate CA certificate
sudo openssl req -new -x509 -days 3650 -extensions v3_ca -keyout /etc/mosquitto/ca_certificates/ca.key -out /etc/mosquitto/ca_certificates/ca.crt -subj "/C=BR/ST=RJ/L=Petropolis/O=HomeGuard/OU=MQTT/CN=HomeGuard-CA"

# Generate server key and certificate
sudo openssl genrsa -out /etc/mosquitto/certs/server.key 2048
sudo openssl req -new -key /etc/mosquitto/certs/server.key -out /etc/mosquitto/certs/server.csr -subj "/C=BR/ST=RJ/L=Petropolis/O=HomeGuard/OU=MQTT/CN=192.168.1.102"
sudo openssl x509 -req -in /etc/mosquitto/certs/server.csr -CA /etc/mosquitto/ca_certificates/ca.crt -CAkey /etc/mosquitto/ca_certificates/ca.key -CAcreateserial -out /etc/mosquitto/certs/server.crt -days 3650

# Set permissions
sudo chown mosquitto:mosquitto /etc/mosquitto/certs/*
sudo chown mosquitto:mosquitto /etc/mosquitto/ca_certificates/*
sudo chmod 600 /etc/mosquitto/certs/server.key
sudo chmod 600 /etc/mosquitto/ca_certificates/ca.key
```

**SSL Configuration (`/etc/mosquitto/conf.d/ssl.conf`):**
```bash
sudo nano /etc/mosquitto/conf.d/ssl.conf
```

```
# SSL/TLS Configuration
port 8883
cafile /etc/mosquitto/ca_certificates/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key
tls_version tlsv1.2
```

### 5. Logging Configuration
```bash
# Create log directory
sudo mkdir -p /var/log/mosquitto
sudo chown mosquitto:mosquitto /var/log/mosquitto

# Configure log rotation
sudo nano /etc/logrotate.d/mosquitto
```

**Log Rotation (`/etc/logrotate.d/mosquitto`):**
```
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
```

## Firewall Configuration

### 1. Configure UFW (if using)
```bash
# Enable firewall
sudo ufw enable

# Allow SSH
sudo ufw allow ssh

# Allow MQTT
sudo ufw allow 1883/tcp comment 'MQTT'
sudo ufw allow 8883/tcp comment 'MQTT SSL'

# Allow from specific network only (more secure)
sudo ufw allow from 192.168.1.0/24 to any port 1883
sudo ufw allow from 192.168.1.0/24 to any port 8883

# Check status
sudo ufw status
```

### 2. iptables Rules (alternative)
```bash
# Allow MQTT from local network only
sudo iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 1883 -j ACCEPT
sudo iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 8883 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 1883 -j DROP
sudo iptables -A INPUT -p tcp --dport 8883 -j DROP

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

## System Integration

### 1. Create System Service Monitor
```bash
sudo nano /usr/local/bin/mosquitto-monitor.sh
```

```bash
#!/bin/bash
# HomeGuard MQTT Broker Monitor

LOGFILE="/var/log/mosquitto/monitor.log"
BROKER_IP="192.168.1.102"
ADMIN_USER="admin"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOGFILE
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
if ! mosquitto_pub -h $BROKER_IP -t "system/monitor" -m "$(date)" -u $ADMIN_USER -P "your_admin_password" >/dev/null 2>&1; then
    log_message "WARNING: Broker not responding to publish test"
else
    log_message "INFO: Broker health check passed"
fi

# Check connection count
CONNECTIONS=$(mosquitto_sub -h $BROKER_IP -t '$SYS/broker/clients/connected' -C 1 -u $ADMIN_USER -P "your_admin_password" 2>/dev/null)
log_message "INFO: Active connections: $CONNECTIONS"

# Check uptime
UPTIME=$(mosquitto_sub -h $BROKER_IP -t '$SYS/broker/uptime' -C 1 -u $ADMIN_USER -P "your_admin_password" 2>/dev/null)
log_message "INFO: Broker uptime: $UPTIME seconds"
```

```bash
# Make executable
sudo chmod +x /usr/local/bin/mosquitto-monitor.sh

# Create systemd timer
sudo nano /etc/systemd/system/mosquitto-monitor.timer
```

```ini
[Unit]
Description=HomeGuard MQTT Broker Monitor
Requires=mosquitto-monitor.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo nano /etc/systemd/system/mosquitto-monitor.service
```

```ini
[Unit]
Description=HomeGuard MQTT Broker Monitor
After=mosquitto.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mosquitto-monitor.sh
User=mosquitto
```

```bash
# Enable and start timer
sudo systemctl enable mosquitto-monitor.timer
sudo systemctl start mosquitto-monitor.timer
```

## Testing and Validation

### 1. Basic Connection Test
```bash
# Test connection (should fail without credentials)
mosquitto_pub -h 192.168.1.102 -t "test/topic" -m "test message"

# Test with credentials
mosquitto_pub -h 192.168.1.102 -t "test/topic" -m "test message" -u homeguard -P pu2clr123456

# Subscribe test
mosquitto_sub -h 192.168.1.102 -t "test/topic" -u homeguard -P pu2clr123456
```

### 2. HomeGuard Device Test
```bash
# Test relay commands
mosquitto_pub -h 192.168.1.102 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456
mosquitto_pub -h 192.168.1.102 -t home/relay1/cmnd -m "OFF" -u homeguard -P pu2clr123456

# Test motion sensor
mosquitto_sub -h 192.168.1.102 -t "home/motion1/#" -u homeguard -P pu2clr123456 -v

# Monitor all HomeGuard traffic
mosquitto_sub -h 192.168.1.102 -t "home/#" -u homeguard -P pu2clr123456 -v
```

### 3. SSL/TLS Test (if configured)
```bash
# Test SSL connection
mosquitto_pub -h 192.168.1.102 -p 8883 --cafile /etc/mosquitto/ca_certificates/ca.crt -t "test/ssl" -m "ssl test" -u homeguard -P pu2clr123456
```

## Device Configuration Updates

### Update ESP-01S Sketches
You'll need to update the IP address in your Arduino sketches from `192.168.1.102` to `192.168.1.102`:

**For relay.ino:**
```cpp
const char* mqtt_server = "192.168.1.102"; // Updated IP
```

**For motion_detector.ino:**
```cpp
const char* mqtt_server = "192.168.1.102"; // Updated IP
```

**For motion_light_controller.py:**
```python
def __init__(self, broker_host="192.168.1.102", ...):  # Updated IP
```

## Monitoring and Maintenance

### 1. Real-time Monitoring
```bash
# Watch live log
sudo tail -f /var/log/mosquitto/mosquitto.log

# Monitor system topics
mosquitto_sub -h 192.168.1.102 -t '$SYS/#' -u admin -P your_admin_password -v

# Check active connections
mosquitto_sub -h 192.168.1.102 -t '$SYS/broker/clients/connected' -u admin -P your_admin_password
```

### 2. Performance Monitoring
```bash
# Check memory usage
mosquitto_sub -h 192.168.1.102 -t '$SYS/broker/heap/current' -u admin -P your_admin_password

# Check message statistics
mosquitto_sub -h 192.168.1.102 -t '$SYS/broker/messages/received' -u admin -P your_admin_password
mosquitto_sub -h 192.168.1.102 -t '$SYS/broker/messages/sent' -u admin -P your_admin_password
```

### 3. Backup Configuration
```bash
# Create backup script
sudo nano /usr/local/bin/mosquitto-backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/home/pi/mosquitto-backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configuration
sudo tar -czf $BACKUP_DIR/mosquitto-config-$DATE.tar.gz \
    /etc/mosquitto/ \
    /var/lib/mosquitto/ \
    --exclude='*.log'

# Keep only last 7 backups
find $BACKUP_DIR -name "mosquitto-config-*.tar.gz" -mtime +7 -delete

echo "Backup completed: mosquitto-config-$DATE.tar.gz"
```

```bash
# Make executable and add to cron
sudo chmod +x /usr/local/bin/mosquitto-backup.sh

# Add to crontab (daily backup at 2 AM)
echo "0 2 * * * /usr/local/bin/mosquitto-backup.sh" | sudo crontab -
```

## Troubleshooting

### Common Issues

1. **Service won't start:**
   ```bash
   sudo journalctl -u mosquitto -f
   sudo systemctl status mosquitto
   ```

2. **Permission errors:**
   ```bash
   sudo chown -R mosquitto:mosquitto /var/lib/mosquitto/
   sudo chown -R mosquitto:mosquitto /var/log/mosquitto/
   ```

3. **Connection refused:**
   ```bash
   # Check if service is listening
   sudo netstat -tlnp | grep 1883
   
   # Check firewall
   sudo ufw status
   ```

4. **Authentication failures:**
   ```bash
   # Recreate password file
   sudo mosquitto_passwd -c /etc/mosquitto/passwd/passwords homeguard
   sudo systemctl restart mosquitto
   ```

## Quick Commands Summary

```bash
# Service management
sudo systemctl start mosquitto
sudo systemctl stop mosquitto
sudo systemctl restart mosquitto
sudo systemctl status mosquitto

# Configuration test
sudo mosquitto -c /etc/mosquitto/mosquitto.conf -v

# Password management
sudo mosquitto_passwd /etc/mosquitto/passwd/passwords username

# Monitor connections
mosquitto_sub -h 192.168.1.102 -t '$SYS/broker/clients/connected' -u admin -P password
```

This configuration provides a secure, monitored, and maintainable MQTT broker setup for your HomeGuard system.
