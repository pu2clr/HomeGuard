/**
  HomeGuard Simple Power Monitor for ESP8266 + ZMPT101B
  Simplified version focused only on power outage detection and relay control

  FEATURES:
  - Detects power outages using ZMPT101B voltage sensor
  - Controls relay when power fails (emergency lighting, UPS, etc.)
  - Sends power failure alerts via MQTT with timestamp and device info
  - Minimal heartbeat every 5 minutes to confirm system is online
  - Simple, reliable operation

  Hardware connections:
  - ZMPT101B VCC -> 3.3V
  - ZMPT101B GND -> GND
  - ZMPT101B OUT -> Analog Pin (A0)
  - RELAY -> GPIO5 (through NPN transistor - see comments below)

  IMPORTANT: Relay Driver Circuit
  ------------------------------
  ESP8266 GPIOs output 3.3V with limited current. Use NPN transistor to drive relay:
  
    GPIO5 ----[1kΩ]----|>B   2N2222/BC547 NPN
                      |      
                     C|----- IN pin of relay module
                      |
                     E|
                      |
                    GND (common to ESP and relay)
  
  Relay module VCC should be 5V, GND common with ESP.
  DO NOT drive relay directly from GPIO!

  MQTT Examples:
  # Monitor power status:
  mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/power/POWER_MONITOR_01/status" -v

  # Monitor power failures:
  mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/power/POWER_MONITOR_01/alert" -v

  # Get device info:
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/power/POWER_MONITOR_01/command" -m "INFO"

  # Manual relay control:
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/power/POWER_MONITOR_01/command" -m "ON"
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/power/POWER_MONITOR_01/command" -m "OFF"
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/power/POWER_MONITOR_01/command" -m "AUTO"

  Author: HomeGuard System
  Date: September 14, 2025
  Version: 1.0
*/

// ======== Device Configuration (EDIT FOR YOUR DEVICE) ========
#define DEVICE_ID           "POWER_MONITOR_01"    // Unique device identifier
#define DEVICE_NAME         "Monitor Energia"     // Friendly device name
#define DEVICE_LOCATION     "Quadro Principal"    // Installation location

// Network Configuration
#define LOCAL_IP_1          192
#define LOCAL_IP_2          168  
#define LOCAL_IP_3          1
#define LOCAL_IP_4          91                    // Change for each device

#define GATEWAY_IP          "192.168.1.1"
#define SUBNET_MASK         "255.255.255.0"

// WiFi Configuration
#define WIFI_SSID           "Homeguard"           // Your WiFi network name
#define WIFI_PASSWORD       "pu2clr123456"        // Your WiFi password

// MQTT Broker Configuration
#define MQTT_SERVER         "192.168.1.102"       // MQTT broker IP
#define MQTT_PORT           1883                   // MQTT broker port
#define MQTT_USER           "homeguard"            // MQTT username
#define MQTT_PASSWORD       "pu2clr123456"         // MQTT password

// Hardware Configuration
#define ZMPT_PIN            A0                     // ZMPT101B analog output pin
#define RELAY_PIN           5                      // GPIO5 for relay control (via transistor)
#define STATUS_LED_PIN      LED_BUILTIN            // Built-in LED for status

// Detection Configuration
#define POWER_THRESHOLD     950                    // Adjust based on your mains voltage
#define SAMPLES_COUNT       50                     // Number of samples for reliable detection
#define SAMPLE_DELAY_MS     2                      // Delay between samples
#define DETECTION_DELAY     3000                   // Wait 3s before confirming power failure

// Timing Configuration
#define HEARTBEAT_INTERVAL  300000                 // 5 minutes heartbeat
#define READING_INTERVAL    5000                   // Check power every 5 seconds
#define RECONNECT_DELAY     10000                  // MQTT reconnect delay

// ======== Includes ========
#include <ESP8266WiFi.h>
#include <PubSubClient.h>

// ======== Network Setup ========
IPAddress local_IP(LOCAL_IP_1, LOCAL_IP_2, LOCAL_IP_3, LOCAL_IP_4);
IPAddress gateway(192, 168, 1, 1);
IPAddress subnet(255, 255, 255, 0);

WiFiClient espClient;
PubSubClient client(espClient);

// ======== MQTT Topics ========
const String TOPIC_STATUS    = "home/power/" + String(DEVICE_ID) + "/status";
const String TOPIC_ALERT     = "home/power/" + String(DEVICE_ID) + "/alert";
const String TOPIC_INFO      = "home/power/" + String(DEVICE_ID) + "/info";
const String TOPIC_COMMAND   = "home/power/" + String(DEVICE_ID) + "/command";

// ======== Global Variables ========
bool powerOnline = true;
bool lastPowerState = true;
bool relayAutoMode = true;
bool relayState = false;

unsigned long lastHeartbeat = 0;
unsigned long lastReading = 0;
unsigned long lastPowerChange = 0;
unsigned long powerFailureStart = 0;

int currentSensorValue = 0;
int failedReadings = 0;

// ======== Device Status Structure ========
struct {
  bool mqtt_connected;
  bool wifi_connected;
  unsigned long uptime;
  unsigned long total_power_failures;
  unsigned long last_failure_duration;
  String last_failure_time;
  int rssi;
} deviceStatus;

// ======== Power Detection Function ========
bool readPowerStatus() {
  int maxValue = 0;
  int validSamples = 0;
  
  // Take multiple samples for reliable detection
  for (int i = 0; i < SAMPLES_COUNT; i++) {
    int reading = analogRead(ZMPT_PIN);
    
    if (reading >= 0 && reading <= 1024) {
      if (reading > maxValue) {
        maxValue = reading;
      }
      validSamples++;
    }
    
    delay(SAMPLE_DELAY_MS);
  }
  
  // Check if we got enough valid samples
  if (validSamples < (SAMPLES_COUNT * 0.8)) {
    failedReadings++;
    Serial.printf("⚠️ Sensor read failed. Valid samples: %d/%d\n", validSamples, SAMPLES_COUNT);
    return powerOnline; // Return last known state if sensor fails
  }
  
  failedReadings = 0;
  currentSensorValue = maxValue;
  
  bool powerDetected = (maxValue > POWER_THRESHOLD);
  
  Serial.printf("🔌 Power reading: %d (threshold: %d) -> %s\n", 
                maxValue, POWER_THRESHOLD, powerDetected ? "ONLINE" : "OFFLINE");
  
  return powerDetected;
}

// ======== Relay Control Function ========
void controlRelay(bool activate) {
  if (relayAutoMode) {
    relayState = activate;
    digitalWrite(RELAY_PIN, activate ? HIGH : LOW);
    
    Serial.printf("🔄 Relay %s (GPIO%d = %s)\n", 
                  activate ? "ACTIVATED" : "DEACTIVATED",
                  RELAY_PIN,
                  activate ? "HIGH" : "LOW");
  }
}

// ======== Send Power Failure Alert ========
void sendPowerFailureAlert(bool powerFailed) {
  if (!client.connected()) return;
  
  String alert = "{";
  alert += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  alert += "\"device_name\":\"" + String(DEVICE_NAME) + "\",";
  alert += "\"location\":\"" + String(DEVICE_LOCATION) + "\",";
  alert += "\"alert_type\":\"" + String(powerFailed ? "POWER_FAILURE" : "POWER_RESTORED") + "\",";
  alert += "\"timestamp\":" + String(millis()) + ",";
  alert += "\"sensor_value\":" + String(currentSensorValue) + ",";
  alert += "\"relay_activated\":" + String(relayState ? "true" : "false") + ",";
  alert += "\"uptime\":" + String(millis()) + ",";
  alert += "\"rssi\":" + String(WiFi.RSSI());
  alert += "}";
  
  client.publish(TOPIC_ALERT.c_str(), alert.c_str(), true);
  
  Serial.printf("🚨 ALERT SENT: %s\n", powerFailed ? "POWER FAILURE" : "POWER RESTORED");
  
  // Update statistics
  if (powerFailed) {
    deviceStatus.total_power_failures++;
    powerFailureStart = millis();
    deviceStatus.last_failure_time = String(millis());
  } else {
    if (powerFailureStart > 0) {
      deviceStatus.last_failure_duration = millis() - powerFailureStart;
      powerFailureStart = 0;
    }
  }
}

// ======== Send Device Status ========
void sendDeviceStatus() {
  if (!client.connected()) return;
  
  String status = "{";
  status += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  status += "\"device_name\":\"" + String(DEVICE_NAME) + "\",";
  status += "\"location\":\"" + String(DEVICE_LOCATION) + "\",";
  status += "\"power_status\":\"" + String(powerOnline ? "online" : "offline") + "\",";
  status += "\"sensor_value\":" + String(currentSensorValue) + ",";
  status += "\"relay_state\":" + String(relayState ? "true" : "false") + ",";
  status += "\"relay_mode\":\"" + String(relayAutoMode ? "auto" : "manual") + "\",";
  status += "\"uptime\":" + String(millis()) + ",";
  status += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  status += "\"failed_readings\":" + String(failedReadings);
  status += "}";
  
  client.publish(TOPIC_STATUS.c_str(), status.c_str(), true);
  
  Serial.println("📊 Status sent via MQTT");
}

// ======== Send Device Information ========
void sendDeviceInfo() {
  if (!client.connected()) return;
  
  String info = "{";
  info += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  info += "\"device_name\":\"" + String(DEVICE_NAME) + "\",";
  info += "\"location\":\"" + String(DEVICE_LOCATION) + "\",";
  info += "\"firmware\":\"HomeGuard_PowerMonitor_v1.0\",";
  info += "\"sensor_type\":\"ZMPT101B\",";
  info += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  info += "\"mac\":\"" + WiFi.macAddress() + "\",";
  info += "\"uptime\":" + String(millis()) + ",";
  info += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  info += "\"total_power_failures\":" + String(deviceStatus.total_power_failures) + ",";
  info += "\"last_failure_duration\":" + String(deviceStatus.last_failure_duration) + ",";
  info += "\"power_threshold\":" + String(POWER_THRESHOLD) + ",";
  info += "\"heartbeat_interval\":" + String(HEARTBEAT_INTERVAL / 1000) + ",";
  info += "\"current_power\":\"" + String(powerOnline ? "online" : "offline") + "\"";
  info += "}";
  
  client.publish(TOPIC_INFO.c_str(), info.c_str(), true);
  
  Serial.println("ℹ️ Device info sent via MQTT");
}

// ======== MQTT Message Callback ========
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String command;
  for (unsigned int i = 0; i < length; i++) {
    command += (char)payload[i];
  }
  command.trim();
  command.toUpperCase();
  
  Serial.printf("📨 MQTT Command received: %s\n", command.c_str());
  
  if (command == "INFO") {
    sendDeviceInfo();
  }
  else if (command == "STATUS") {
    sendDeviceStatus();
  }
  else if (command == "ON") {
    relayAutoMode = false;
    digitalWrite(RELAY_PIN, HIGH);
    relayState = true;
    Serial.println("🔧 Manual relay ON");
  }
  else if (command == "OFF") {
    relayAutoMode = false;
    digitalWrite(RELAY_PIN, LOW);
    relayState = false;
    Serial.println("🔧 Manual relay OFF");
  }
  else if (command == "AUTO") {
    relayAutoMode = true;
    Serial.println("🔄 Relay back to AUTO mode");
    // Immediately update relay state based on current power status
    controlRelay(!powerOnline);
  }
  else if (command == "READ") {
    powerOnline = readPowerStatus();
    sendDeviceStatus();
  }
  else {
    Serial.printf("❓ Unknown command: %s\n", command.c_str());
  }
}

// ======== MQTT Connection ========
void connectMQTT() {
  if (WiFi.status() != WL_CONNECTED) return;
  
  int attempts = 0;
  while (!client.connected() && attempts < 3) {
    Serial.printf("🔄 Connecting to MQTT (attempt %d/3)...\n", attempts + 1);
    
    String clientId = "HomeGuard_" + String(DEVICE_ID) + "_" + String(ESP.getChipId(), HEX);
    
    if (client.connect(clientId.c_str(), MQTT_USER, MQTT_PASSWORD)) {
      Serial.println("✅ MQTT connected!");
      
      // Subscribe to command topic
      client.subscribe(TOPIC_COMMAND.c_str());
      Serial.printf("📡 Subscribed to: %s\n", TOPIC_COMMAND.c_str());
      
      // Send initial info
      sendDeviceInfo();
      sendDeviceStatus();
      
      deviceStatus.mqtt_connected = true;
      
    } else {
      Serial.printf("❌ MQTT connection failed, rc=%d\n", client.state());
      attempts++;
      delay(2000);
    }
  }
}

// ======== WiFi Connection ========
void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.config(local_IP, gateway, subnet);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  Serial.printf("🔄 Connecting to WiFi: %s", WIFI_SSID);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
    
    // Blink LED during connection
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n✅ WiFi connected! IP: %s\n", WiFi.localIP().toString().c_str());
    deviceStatus.wifi_connected = true;
    digitalWrite(STATUS_LED_PIN, LOW); // LED ON (inverted logic)
  } else {
    Serial.println("\n❌ WiFi connection failed!");
    deviceStatus.wifi_connected = false;
    digitalWrite(STATUS_LED_PIN, HIGH); // LED OFF
  }
}

// ======== Setup Function ========
void setup() {
  Serial.begin(115200);
  Serial.println("\n🚀 HomeGuard Power Monitor Starting...");
  Serial.printf("📋 Device: %s (%s)\n", DEVICE_NAME, DEVICE_ID);
  Serial.printf("📍 Location: %s\n", DEVICE_LOCATION);
  
  // Initialize pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  
  // Initialize relay OFF (no power failure detected yet)
  digitalWrite(RELAY_PIN, LOW);
  digitalWrite(STATUS_LED_PIN, HIGH); // LED OFF initially
  
  Serial.printf("🔧 Relay initialized on GPIO%d: OFF\n", RELAY_PIN);
  
  // Initialize device status
  memset(&deviceStatus, 0, sizeof(deviceStatus));
  
  // Connect to WiFi
  connectWiFi();
  
  // Setup MQTT
  if (deviceStatus.wifi_connected) {
    client.setServer(MQTT_SERVER, MQTT_PORT);
    client.setCallback(mqttCallback);
    connectMQTT();
  }
  
  // Initial power reading
  powerOnline = readPowerStatus();
  lastPowerState = powerOnline;
  
  // Set initial relay state (activate if no power)
  controlRelay(!powerOnline);
  
  Serial.printf("✅ Setup complete. Initial power state: %s\n", 
                powerOnline ? "ONLINE" : "OFFLINE");
  
  lastReading = millis();
  lastHeartbeat = millis();
}

// ======== Main Loop ========
void loop() {
  unsigned long currentTime = millis();
  
  // Handle WiFi reconnection
  if (WiFi.status() != WL_CONNECTED) {
    if (deviceStatus.wifi_connected) {
      Serial.println("⚠️ WiFi disconnected!");
      deviceStatus.wifi_connected = false;
    }
    // Try to reconnect every 30 seconds
    static unsigned long lastWiFiAttempt = 0;
    if (currentTime - lastWiFiAttempt > 30000) {
      connectWiFi();
      lastWiFiAttempt = currentTime;
    }
  }
  
  // Handle MQTT connection
  if (deviceStatus.wifi_connected && !client.connected()) {
    if (deviceStatus.mqtt_connected) {
      Serial.println("⚠️ MQTT disconnected!");
      deviceStatus.mqtt_connected = false;
    }
    
    static unsigned long lastMqttAttempt = 0;
    if (currentTime - lastMqttAttempt > RECONNECT_DELAY) {
      connectMQTT();
      lastMqttAttempt = currentTime;
    }
  }
  
  // Process MQTT messages
  if (client.connected()) {
    client.loop();
  }
  
  // Read power status
  if (currentTime - lastReading >= READING_INTERVAL) {
    bool newPowerState = readPowerStatus();
    
    // Check for power state change
    if (newPowerState != lastPowerState) {
      // Wait for confirmation to avoid false alarms
      if (currentTime - lastPowerChange < DETECTION_DELAY) {
        Serial.println("⏳ Waiting for power state confirmation...");
      } else {
        powerOnline = newPowerState;
        
        Serial.printf("🔄 Power state changed: %s -> %s\n",
                      lastPowerState ? "ONLINE" : "OFFLINE",
                      powerOnline ? "ONLINE" : "OFFLINE");
        
        // Control relay based on power state
        controlRelay(!powerOnline);
        
        // Send alert
        sendPowerFailureAlert(!powerOnline);
        
        // Update LED status
        digitalWrite(STATUS_LED_PIN, powerOnline ? LOW : HIGH);
        
        lastPowerState = powerOnline;
      }
    } else {
      lastPowerChange = currentTime;
    }
    
    lastReading = currentTime;
  }
  
  // Send heartbeat every 5 minutes
  if (currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    if (client.connected()) {
      sendDeviceStatus();
      Serial.println("💓 Heartbeat sent");
    }
    
    deviceStatus.uptime = currentTime;
    deviceStatus.rssi = WiFi.RSSI();
    lastHeartbeat = currentTime;
  }
  
  // Update LED based on connection status
  if (!deviceStatus.wifi_connected || !deviceStatus.mqtt_connected) {
    // Blink LED if connection issues
    static unsigned long lastBlink = 0;
    if (currentTime - lastBlink > 1000) {
      digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
      lastBlink = currentTime;
    }
  }
  
  delay(100);
}
