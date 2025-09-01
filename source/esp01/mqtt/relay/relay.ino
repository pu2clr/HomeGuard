/**
  HomeGuard Relay Control Module for ESP-01S
  Compatible with Flask Dashboard MQTT System
  
  QUICK CONFIG: Uncomment ONE line below for your ESP01:
  // #define RELAY_001  // Luz da Sala (192.168.18.192)
  // #define RELAY_002  // Luz da Cozinha (192.168.18.193)  
  // #define RELAY_003  // Bomba d'Água (192.168.18.194)
  
  Hardware connections:
  - Relay Module IN -> GPIO0 (PIN 0) 
  - Relay Module VCC -> 3.3V
  - Relay Module GND -> GND
  - Status LED -> GPIO2 (PIN 2) [Optional]

  MQTT Broker Setup:
  - Install mosquitto broker: sudo apt install mosquitto mosquitto-clients
  - Password setup: sudo mosquitto_passwd -c /etc/mosquitto/passwd homeguard
  - Config authentication in /etc/mosquitto/mosquitto.conf:
    allow_anonymous false
    password_file /etc/mosquitto/passwd
  - Restart: sudo systemctl restart mosquitto

  Testing Commands:
  - Monitor all topics: mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "#" -v
  - Send command: mosquitto_pub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/command" -m "ON"
  - Check status: mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "home/relay/ESP01_RELAY_001/status" -v

*/

// ======== ESP01 Configuration (CHANGE FOR EACH DEVICE) ========
// Uncomment ONE line below:
// #define RELAY_001  // Luz da Sala
// #define RELAY_002  // Luz da Área de Serviço   
// #define RELAY_003  // Bomba d'Água


#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include "wifi_info.h"  // Please rename the file wifi_infoX.h to wifi_info.h and change the SSID and password


// ======== Device Configuration (Auto-selected based on #define above) ========
#if defined(RELAY_001)
  const char* DEVICE_ID = "ESP01_RELAY_001";
  const char* RELAY_NAME = "Luz da Sala";
  const char* RELAY_LOCATION = "Sala";
  IPAddress local_IP(192, 168, 18, 192);
#elif defined(RELAY_002)  
  const char* DEVICE_ID = "ESP01_RELAY_002";
  const char* RELAY_NAME = "Área de Serviço";
  const char* RELAY_LOCATION = "AreaServico";
  IPAddress local_IP(192, 168, 18, 193);
#elif defined(RELAY_003)
  const char* DEVICE_ID = "ESP01_RELAY_003";
  const char* RELAY_NAME = "Bomba d'Água";
  const char* RELAY_LOCATION = "Externa";
  IPAddress local_IP(192, 168, 18, 194);
#else
  // Default configuration - CHANGE THESE VALUES FOR YOUR SETUP
  const char* DEVICE_ID = "ESP01_RELAY_001";        // Must match RELAYS_CONFIG[n]['id']
  const char* RELAY_NAME = "Luz da Sala";          // Must match RELAYS_CONFIG[n]['name'] 
  const char* RELAY_LOCATION = "Sala";             // Must match RELAYS_CONFIG[n]['location']
  IPAddress local_IP(192, 168, 18, 192);            // ESP01_RELAY_001 -> .192, ESP01_RELAY_002 -> .193, etc
#endif

// ======== Wi-Fi Network Configuration ========
const char* ssid = YOUR_SSID;
const char* password = YOUR_PASSWORD;
// ======== Network Configuration ========
IPAddress gateway(192, 168, 18, 1);
IPAddress subnet(255, 255, 255, 0);

// ======== MQTT Broker Configuration (matches Flask config) ========
const char* mqtt_server = "192.168.18.198"; // Must match MQTT_CONFIG['broker_host']
const int   mqtt_port   = 1883;             // Must match MQTT_CONFIG['broker_port']  
const char* mqtt_user   = "homeguard";      // Must match MQTT_CONFIG['username']
const char* mqtt_pass   = "pu2clr123456";   // Must match MQTT_CONFIG['password']

// ======== Relay Hardware Configuration ========
#define PIN_RELAY 0       // GPIO0 for relay control
#define PIN_STATUS_LED 2  // GPIO2 for status LED (optional)
#define RELAY_ACTIVE_LOW true  // Changed: Your relay activates with HIGH, so it's ACTIVE HIGH

WiFiClient espClient;
PubSubClient client(espClient);

// ======== MQTT Topics (matches Flask RELAYS_CONFIG) ========
String TOPIC_COMMAND = "home/relay/" + String(DEVICE_ID) + "/command";  // Receive commands
String TOPIC_STATUS = "home/relay/" + String(DEVICE_ID) + "/status";    // Send status
String TOPIC_INFO = "home/relay/" + String(DEVICE_ID) + "/info";        // Send device info

// ======== Relay State Variables ========
bool relayState = false;
bool lastRelayState = false;
unsigned long lastHeartbeat = 0;
unsigned long lastStatusSend = 0;
const unsigned long HEARTBEAT_INTERVAL = 30000;  // 30 seconds heartbeat
const unsigned long STATUS_SEND_INTERVAL = 5000; // Send status every 5 seconds if changed

// ======== Device Status ========
struct DeviceStatus {
  bool online;
  bool relay_on;
  int rssi;
  unsigned long uptime;
  String last_command;
  unsigned long last_command_time;
} device_status;

// ======== Function to control relay ========
void setRelay(bool state) {
  relayState = state;
  
  if (RELAY_ACTIVE_LOW) {
    digitalWrite(PIN_RELAY, !state);  // Invert for active LOW
  } else {
    digitalWrite(PIN_RELAY, state);   // Direct for active HIGH
  }
  
  // Update status LED (optional) - but keep it OFF during boot
  if (device_status.online) {  // Only update LED if MQTT is connected
    digitalWrite(PIN_STATUS_LED, state);
  }
  
  // Send status immediately (only if MQTT is connected)
  if (device_status.online) {
    sendStatus();
  }
  
  // Update device status
  device_status.relay_on = state;
  device_status.last_command_time = millis();
}

// ======== Send device status to MQTT ========
void sendStatus() {
  String status = relayState ? "on" : "off";
  client.publish(TOPIC_STATUS.c_str(), status.c_str(), true); // Retained message
  lastStatusSend = millis();
}

// ======== Send device information ========
void sendDeviceInfo() {
  String info = "{";
  info += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  info += "\"name\":\"" + String(RELAY_NAME) + "\",";
  info += "\"location\":\"" + String(RELAY_LOCATION) + "\",";
  info += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  info += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  info += "\"uptime\":" + String(millis()) + ",";
  info += "\"relay_state\":\"" + String(relayState ? "on" : "off") + "\",";
  info += "\"last_command\":\"" + device_status.last_command + "\",";
  info += "\"firmware\":\"HomeGuard_v1.0\"";
  info += "}";
  
  client.publish(TOPIC_INFO.c_str(), info.c_str(), true);
}

// ======== Process MQTT commands (matches Flask RELAY_COMMANDS) ========
void callback(char* topic, byte* payload, unsigned int length) {
  // Convert payload to string
  String command;
  for (unsigned int i = 0; i < length; i++) {
    command += (char)payload[i];
  }
  command.trim();
  
  // Store last command
  device_status.last_command = command;
  device_status.last_command_time = millis();
  
  // Process command (matches Flask RELAY_COMMANDS)
  if (command.equalsIgnoreCase("ON")) {
    setRelay(true);
  } 
  else if (command.equalsIgnoreCase("OFF")) {
    setRelay(false);
  }
  else if (command.equalsIgnoreCase("TOGGLE")) {
    setRelay(!relayState);
  }
  else if (command.equalsIgnoreCase("STATUS")) {
    sendStatus();
    sendDeviceInfo();
  }
  else {
    // Unknown command - send current status
    sendStatus();
  }
}

// ======== Reconnect to MQTT with better error handling ========
void reconnect() {
  int attempts = 0;
  
  while (!client.connected() && attempts < 3) {
    String clientId = "HomeGuard_" + String(DEVICE_ID);
    
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      // Successfully connected
      client.subscribe(TOPIC_COMMAND.c_str());
      
      // Send device info and initial status
      sendDeviceInfo();
      sendStatus();
      
      // Update device status
      device_status.online = true;
      device_status.rssi = WiFi.RSSI();
      device_status.uptime = millis();
      
      break;
    } else {
      attempts++;
      delay(2000 * attempts); // Exponential backoff
    }
  }
}

// ======== Setup function ========
void setup() {
  // Optional: Enable Serial for debugging (comment out for production)
  // Serial.begin(115200);
  // Serial.println("ESP01 RELAY iniciando...");
  
  // Initialize hardware pins
  pinMode(PIN_RELAY, OUTPUT);
  pinMode(PIN_STATUS_LED, OUTPUT);
  
  // FORCE initial relay state to OFF immediately (before WiFi connection)
  // Since your relay is ACTIVE HIGH: LOW = OFF, HIGH = ON
  digitalWrite(PIN_RELAY, LOW);   // Force LOW = OFF for active HIGH relays
  delay(200);  // Longer delay to ensure relay module responds
  
  // Serial.println("Relé forçado para LOW (OFF)");
  
  // Initialize device status BEFORE calling setRelay
  device_status.online = false;
  device_status.relay_on = false;
  device_status.last_command = "BOOT";
  device_status.last_command_time = millis();
  
  // Set initial relay state (OFF) - this won't send MQTT since device_status.online = false
  setRelay(false);

  // Configure static IP
  WiFi.config(local_IP, gateway, subnet);
  
  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  int wifi_attempts = 0;
  
  while (WiFi.status() != WL_CONNECTED && wifi_attempts < 20) {
    delay(500);
    wifi_attempts++;
    
    // Blink status LED during connection
    digitalWrite(PIN_STATUS_LED, !digitalRead(PIN_STATUS_LED));
  }
  
  // If connected, setup MQTT
  if (WiFi.status() == WL_CONNECTED) {
    client.setServer(mqtt_server, mqtt_port);
    client.setCallback(callback);
    
    // Turn on status LED to indicate successful connection
    digitalWrite(PIN_STATUS_LED, true);
  }
}

// ======== Main loop ========
void loop() {
  unsigned long currentTime = millis();
  
  // Ensure MQTT connection
  if (!client.connected()) {
    device_status.online = false;
    reconnect();
  }
  
  // Process MQTT messages
  client.loop();
  
  // Send periodic heartbeat
  if (currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    if (client.connected()) {
      sendDeviceInfo();
      device_status.rssi = WiFi.RSSI();
      device_status.uptime = currentTime;
    }
    lastHeartbeat = currentTime;
  }
  
  // Send status if state changed
  if (relayState != lastRelayState && 
      currentTime - lastStatusSend >= STATUS_SEND_INTERVAL) {
    sendStatus();
    lastRelayState = relayState;
  }
}
