/**
 * HomeGuard Advanced Relay Control Module for ESP-01S
 * Advanced version with JSON messaging, device identification, and enhanced features
 * 
 * Hardware connections:
 * - Relay Module IN -> GPIO0 (PIN 0)
 * - Relay Module VCC -> 3.3V
 * - Relay Module GND -> GND
 * - Status LED -> GPIO2 (PIN 2) - Optional
 * 
 * Features:
 * - JSON-based MQTT messaging for better integration
 * - Device identification with MAC-based ID
 * - Configurable device location
 * - Status reporting and heartbeat
 * - Multiple command formats support
 * - Remote configuration capabilities
 * - Enhanced debugging and monitoring
 * 
 * MQTT Commands (JSON format):
 * - mosquitto_sub -h 192.168.18.6 -u homeguard -P pu2clr123456 -t "home/relay1/#" -v
 * - mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "ON" -u homeguard -P pu2clr123456
 * - mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "STATUS" -u homeguard -P pu2clr123456
 * - mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "TOGGLE" -u homeguard -P pu2clr123456
 * - mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m "LOCATION_Kitchen" -u homeguard -P pu2clr123456
 */

#include <ESP8266WiFi.h>
#include <PubSubClient.h>

// ======== Wi-Fi Network Configuration ========
const char* ssid = "APRC";
const char* password = "Ap69Rc642023";

// ESP-01S fixed IP
IPAddress local_IP(192, 168, 18, 192);  // Same IP as original relay
IPAddress gateway(192, 168, 18, 1);
IPAddress subnet(255, 255, 255, 0);

// ======== MQTT Broker Configuration ========
const char* mqtt_server = "192.168.18.6"; // Local MQTT broker IP
const int   mqtt_port   = 1883;           // Standard MQTT port
const char* mqtt_user   = "homeguard";    // Username
const char* mqtt_pass   = "pu2clr123456"; // Password

// ======== Hardware Configuration ========
#define PIN_RELAY 0              // GPIO0 for relay control
#define PIN_LED 2                // GPIO2 for status LED (optional)

// ======== MQTT Topics ========
const char* TOPIC_CMD = "home/relay1/cmnd";        // Topic for commands
const char* TOPIC_STATUS = "home/relay1/status";   // Topic for general status
const char* TOPIC_RELAY = "home/relay1/relay";     // Topic for relay events
const char* TOPIC_HEARTBEAT = "home/relay1/heartbeat"; // Topic for heartbeat
const char* TOPIC_CONFIG = "home/relay1/config";   // Topic for configuration

WiFiClient espClient;
PubSubClient client(espClient);

// ======== Relay State Variables ========
bool relayState = false;
bool lastRelayState = false;
unsigned long lastStateChange = 0;
unsigned long lastHeartbeat = 0;

// ======== Configuration Variables ========
unsigned long heartbeatInterval = 60000;    // 60 seconds - heartbeat interval
bool enableHeartbeat = true;
String deviceLocation = "Utility Room";     // Configurable location name
bool enableStatusLED = true;

// ======== Device Information ========
String deviceMAC;
String deviceID;

// ======== Initialize Device Identity ========
void initializeDevice() {
  deviceMAC = WiFi.macAddress();
  deviceMAC.replace(":", "");
  deviceMAC.toLowerCase();
  deviceID = "relay_" + deviceMAC.substring(6); // Use last 6 chars of MAC
  
  Serial.println("=== HomeGuard Advanced Relay Controller ===");
  Serial.println("Device ID: " + deviceID);
  Serial.println("MAC Address: " + WiFi.macAddress());
  Serial.println("Location: " + deviceLocation);
}

// ======== LED Status Indication ========
void updateStatusLED() {
  if (enableStatusLED) {
    digitalWrite(PIN_LED, relayState ? LOW : HIGH); // LED ON when relay is ON
  }
}

// ======== Publish MQTT Message ========
void publishMessage(const char* topic, String message) {
  if (client.connected()) {
    client.publish(topic, message.c_str());
    Serial.println("Published [" + String(topic) + "]: " + message);
  }
}

// ======== Publish Device Status ========
void publishDeviceStatus() {
  // Create JSON status message
  String status = "{";
  status += "\"device_id\":\"" + deviceID + "\",";
  status += "\"location\":\"" + deviceLocation + "\",";
  status += "\"mac\":\"" + WiFi.macAddress() + "\",";
  status += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  status += "\"relay_state\":\"" + String(relayState ? "ON" : "OFF") + "\",";
  status += "\"last_change\":\"" + String((millis() - lastStateChange) / 1000) + "s ago\",";
  status += "\"uptime\":\"" + String(millis() / 1000) + "s\",";
  status += "\"heartbeat_enabled\":\"" + String(enableHeartbeat ? "true" : "false") + "\",";
  status += "\"heartbeat_interval\":\"" + String(heartbeatInterval / 1000) + "s\",";
  status += "\"rssi\":\"" + String(WiFi.RSSI()) + "dBm\"";
  status += "}";
  
  publishMessage(TOPIC_STATUS, status);
}

// ======== Publish Relay Event ========
void publishRelayEvent(String event, String reason = "") {
  String message = "{";
  message += "\"device_id\":\"" + deviceID + "\",";
  message += "\"location\":\"" + deviceLocation + "\",";
  message += "\"event\":\"" + event + "\",";
  message += "\"state\":\"" + String(relayState ? "ON" : "OFF") + "\",";
  message += "\"timestamp\":\"" + String(millis()) + "\"";
  if (reason.length() > 0) {
    message += ",\"reason\":\"" + reason + "\"";
  }
  message += ",\"rssi\":\"" + String(WiFi.RSSI()) + "\"";
  message += "}";
  
  publishMessage(TOPIC_RELAY, message);
}

// ======== Publish Heartbeat ========
void publishHeartbeat() {
  String heartbeat = "{";
  heartbeat += "\"device_id\":\"" + deviceID + "\",";
  heartbeat += "\"timestamp\":\"" + String(millis()) + "\",";
  heartbeat += "\"status\":\"ONLINE\",";
  heartbeat += "\"location\":\"" + deviceLocation + "\",";
  heartbeat += "\"relay_state\":\"" + String(relayState ? "ON" : "OFF") + "\",";
  heartbeat += "\"uptime\":\"" + String(millis() / 1000) + "s\",";
  heartbeat += "\"rssi\":\"" + String(WiFi.RSSI()) + "\"";
  heartbeat += "}";
  
  publishMessage(TOPIC_HEARTBEAT, heartbeat);
}

// ======== Set Relay State ========
void setRelayState(bool newState, String reason = "") {
  if (newState != relayState) {
    relayState = newState;
    lastStateChange = millis();
    
    // Control physical relay (assuming active LOW)
    digitalWrite(PIN_RELAY, relayState ? LOW : HIGH);
    
    // Update status LED
    updateStatusLED();
    
    // Publish relay event
    publishRelayEvent(relayState ? "RELAY_ON" : "RELAY_OFF", reason);
    
    Serial.println("Relay " + String(relayState ? "ON" : "OFF") + 
                   (reason.length() > 0 ? " (" + reason + ")" : ""));
  }
}

// ======== Function to process MQTT messages ========
void callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();
  
  Serial.println("Received [" + String(topic) + "]: " + msg);
  
  // Handle relay control commands
  if (msg.equalsIgnoreCase("ON") || msg.equalsIgnoreCase("RELAY_ON")) {
    setRelayState(true, "REMOTE_COMMAND");
  }
  else if (msg.equalsIgnoreCase("OFF") || msg.equalsIgnoreCase("RELAY_OFF")) {
    setRelayState(false, "REMOTE_COMMAND");
  }
  else if (msg.equalsIgnoreCase("TOGGLE")) {
    setRelayState(!relayState, "TOGGLE_COMMAND");
  }
  else if (msg.equalsIgnoreCase("STATUS")) {
    publishDeviceStatus();
  }
  else if (msg.equalsIgnoreCase("RESET")) {
    publishMessage(TOPIC_STATUS, "RESETTING");
    delay(1000);
    ESP.restart();
  }
  
  // Configuration commands
  else if (msg.equalsIgnoreCase("HEARTBEAT_ON")) {
    enableHeartbeat = true;
    publishMessage(TOPIC_CONFIG, "HEARTBEAT_ENABLED");
  }
  else if (msg.equalsIgnoreCase("HEARTBEAT_OFF")) {
    enableHeartbeat = false;
    publishMessage(TOPIC_CONFIG, "HEARTBEAT_DISABLED");
  }
  else if (msg.startsWith("HEARTBEAT_")) {
    // Set heartbeat interval: HEARTBEAT_30 (30 seconds)
    String intervalStr = msg.substring(10);
    unsigned long newInterval = intervalStr.toInt() * 1000;
    if (newInterval >= 10000 && newInterval <= 300000) { // 10s to 5min
      heartbeatInterval = newInterval;
      publishMessage(TOPIC_CONFIG, "HEARTBEAT_INTERVAL_" + String(newInterval/1000) + "s");
    }
  }
  else if (msg.startsWith("LOCATION_")) {
    // Set device location: LOCATION_Kitchen
    deviceLocation = msg.substring(9);
    publishMessage(TOPIC_CONFIG, "LOCATION_SET_" + deviceLocation);
  }
  else if (msg.equalsIgnoreCase("LED_ON")) {
    enableStatusLED = true;
    updateStatusLED();
    publishMessage(TOPIC_CONFIG, "STATUS_LED_ENABLED");
  }
  else if (msg.equalsIgnoreCase("LED_OFF")) {
    enableStatusLED = false;
    digitalWrite(PIN_LED, HIGH); // Turn off LED
    publishMessage(TOPIC_CONFIG, "STATUS_LED_DISABLED");
  }
  
  // JSON command support (future enhancement)
  else if (msg.startsWith("{") && msg.endsWith("}")) {
    // Handle JSON commands - basic implementation
    if (msg.indexOf("\"relay\":\"ON\"") > 0) {
      setRelayState(true, "JSON_COMMAND");
    }
    else if (msg.indexOf("\"relay\":\"OFF\"") > 0) {
      setRelayState(false, "JSON_COMMAND");
    }
    else if (msg.indexOf("\"command\":\"STATUS\"") > 0) {
      publishDeviceStatus();
    }
  }
  
  // Unknown command
  else {
    publishMessage(TOPIC_CONFIG, "UNKNOWN_COMMAND: " + msg);
  }
}

// ======== Reconnect to MQTT if necessary ========
void reconnect() {
  while (!client.connected()) {
    Serial.println("Attempting MQTT connection...");
    
    String clientId = "ESP01S_AdvRelay_" + deviceID;
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("MQTT connected!");
      
      // Subscribe to command topic
      client.subscribe(TOPIC_CMD);
      
      // Announce device online
      publishMessage(TOPIC_STATUS, "ONLINE");
      publishDeviceStatus();
      
    } else {
      Serial.print("MQTT connection failed, rc=");
      Serial.print(client.state());
      Serial.println(" Retrying in 5 seconds...");
      delay(5000);
    }
  }
}

// ======== Setup Function ========
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== HomeGuard Advanced Relay Controller Starting ===");
  
  // Initialize pins
  pinMode(PIN_RELAY, OUTPUT);
  pinMode(PIN_LED, OUTPUT);
  
  // Relay starts OFF (assuming active LOW relay)
  digitalWrite(PIN_RELAY, HIGH);
  digitalWrite(PIN_LED, HIGH); // LED OFF initially
  
  // Connect to WiFi
  WiFi.config(local_IP, gateway, subnet);
  WiFi.begin(ssid, password);
  
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("");
    Serial.println("WiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("WiFi connection failed!");
    ESP.restart();
  }
  
  // Initialize device identity
  initializeDevice();
  
  // Setup MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  
  // Connect to MQTT
  reconnect();
  
  // Update LED status
  updateStatusLED();
  
  Serial.println("=== Advanced Relay Controller Ready ===");
  Serial.println("Device Location: " + deviceLocation);
  Serial.println("Heartbeat Interval: " + String(heartbeatInterval/1000) + " seconds");
  Serial.println("Status LED: " + String(enableStatusLED ? "Enabled" : "Disabled"));
  Serial.println("\nAvailable Commands:");
  Serial.println("- ON/OFF: Control relay");
  Serial.println("- TOGGLE: Toggle relay state");
  Serial.println("- STATUS: Get device status");
  Serial.println("- LOCATION_<name>: Set location");
  Serial.println("- HEARTBEAT_ON/OFF: Enable/disable heartbeat");
  Serial.println("- LED_ON/OFF: Enable/disable status LED");
  Serial.println("- RESET: Restart device");
}

// ======== Main Loop ========
void loop() {
  // Maintain MQTT connection
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  
  // Send heartbeat if enabled
  if (enableHeartbeat && (millis() - lastHeartbeat > heartbeatInterval)) {
    publishHeartbeat();
    lastHeartbeat = millis();
  }
  
  // Check for relay state changes (in case of external changes)
  bool currentPhysicalState = (digitalRead(PIN_RELAY) == LOW); // Assuming active LOW
  if (currentPhysicalState != relayState) {
    relayState = currentPhysicalState;
    publishRelayEvent(relayState ? "RELAY_ON" : "RELAY_OFF", "EXTERNAL_CHANGE");
    updateStatusLED();
  }
  
  delay(100); // Small delay to prevent watchdog issues
}
