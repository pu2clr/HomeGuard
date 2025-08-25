/*
 * HomeGuard Advanced MQTT Client for ESP-01S
 * Features: DHCP, Authentication, Scheduling, MAC-based identification
 * Author: HomeGuard Project
 * Version: 2.0
 */

#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <EEPROM.h>

// ======== Wi-Fi Configuration ========
const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";

// ======== MQTT Broker Configuration ========
const char* mqtt_server = "192.168.18.236";   // e.g., "192.168.1.100"
const int   mqtt_port = 1883;
const char* mqtt_user = "homeguard";              // MQTT username
const char* mqtt_pass = "pu2clr123456";    // MQTT password

// ======== Hardware Configuration ========
#define PIN_RELAY 0      // GPIO0 for relay control
#define PIN_SENSOR 2     // GPIO2 for motion sensor (if available)
#define LED_BUILTIN 1    // GPIO1 for status LED

// ======== Device Configuration ========
String deviceMAC;
String deviceID;
String clientID;

// ======== MQTT Topics ========
String TOPIC_BASE;
String TOPIC_CMD;
String TOPIC_STATUS;
String TOPIC_SCHEDULE;
String TOPIC_HEARTBEAT;
String TOPIC_MOTION;

// ======== Global Variables ========
WiFiClient espClient;
PubSubClient client(espClient);

bool relayState = false;
bool motionDetected = false;
unsigned long lastHeartbeat = 0;
unsigned long lastMotionCheck = 0;
const unsigned long HEARTBEAT_INTERVAL = 30000;  // 30 seconds
const unsigned long MOTION_CHECK_INTERVAL = 500;  // 500ms

// ======== Schedule Structure ========
struct Schedule {
  bool active;
  int hour;
  int minute;
  int duration;  // in minutes
  bool action;   // true = ON, false = OFF
  String days;   // "1234567" for Mon-Sun, "0" for once
};

Schedule currentSchedule;

// ======== WiFi Connection Function ========
void connectWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(1000);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("");
    Serial.println("WiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    Serial.print("MAC address: ");
    Serial.println(WiFi.macAddress());
  } else {
    Serial.println("WiFi connection failed!");
    ESP.restart();
  }
}

// ======== Initialize Device Identity ========
void initializeDevice() {
  deviceMAC = WiFi.macAddress();
  deviceMAC.replace(":", "");
  deviceMAC.toLowerCase();
  
  deviceID = "homeguard_" + deviceMAC.substring(6);  // Use last 6 chars of MAC
  clientID = "ESP01S_" + deviceMAC.substring(8);     // Use last 4 chars for client ID
  
  // Initialize MQTT topics based on device MAC
  TOPIC_BASE = "homeguard/" + deviceID;
  TOPIC_CMD = TOPIC_BASE + "/cmnd";
  TOPIC_STATUS = TOPIC_BASE + "/stat";
  TOPIC_SCHEDULE = TOPIC_BASE + "/schedule";
  TOPIC_HEARTBEAT = TOPIC_BASE + "/heartbeat";
  TOPIC_MOTION = TOPIC_BASE + "/motion";
  
  Serial.println("Device initialized:");
  Serial.println("Device ID: " + deviceID);
  Serial.println("Client ID: " + clientID);
  Serial.println("Base Topic: " + TOPIC_BASE);
}

// ======== MQTT Callback Function ========
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  message.trim();
  
  Serial.println("Message received [" + String(topic) + "]: " + message);
  
  String topicStr = String(topic);
  
  // Handle direct commands
  if (topicStr == TOPIC_CMD) {
    handleDirectCommand(message);
  }
  
  // Handle schedule commands
  else if (topicStr == TOPIC_SCHEDULE) {
    handleScheduleCommand(message);
  }
}

// ======== Handle Direct Commands ========
void handleDirectCommand(String command) {
  command.toUpperCase();
  
  if (command == "ON") {
    setRelay(true);
    publishStatus();
  }
  else if (command == "OFF") {
    setRelay(false);
    publishStatus();
  }
  else if (command == "STATUS") {
    publishStatus();
  }
  else if (command == "RESTART") {
    publishMessage(TOPIC_STATUS, "RESTARTING");
    delay(1000);
    ESP.restart();
  }
}

// ======== Handle Schedule Commands ========
void handleScheduleCommand(String scheduleJson) {
  StaticJsonDocument<300> doc;
  DeserializationError error = deserializeJson(doc, scheduleJson);
  
  if (error) {
    Serial.println("Failed to parse schedule JSON");
    publishMessage(TOPIC_STATUS, "SCHEDULE_ERROR: Invalid JSON");
    return;
  }
  
  currentSchedule.active = doc["active"] | false;
  currentSchedule.hour = doc["hour"] | 0;
  currentSchedule.minute = doc["minute"] | 0;
  currentSchedule.duration = doc["duration"] | 0;
  currentSchedule.action = doc["action"] | false;
  currentSchedule.days = doc["days"] | "0";
  
  // Save schedule to EEPROM (simplified)
  EEPROM.write(0, currentSchedule.active ? 1 : 0);
  EEPROM.write(1, currentSchedule.hour);
  EEPROM.write(2, currentSchedule.minute);
  EEPROM.write(3, currentSchedule.duration);
  EEPROM.write(4, currentSchedule.action ? 1 : 0);
  EEPROM.commit();
  
  publishMessage(TOPIC_STATUS, "SCHEDULE_SET");
  Serial.println("Schedule configured successfully");
}

// ======== Set Relay State ========
void setRelay(bool state) {
  relayState = state;
  digitalWrite(PIN_RELAY, state ? LOW : HIGH);  // Assuming active LOW relay
  
  // Blink LED to indicate state change
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_BUILTIN, LOW);
    delay(100);
    digitalWrite(LED_BUILTIN, HIGH);
    delay(100);
  }
}

// ======== Publish Messages ========
void publishMessage(String topic, String message) {
  if (client.connected()) {
    client.publish(topic.c_str(), message.c_str());
    Serial.println("Published [" + topic + "]: " + message);
  }
}

// ======== Publish Device Status ========
void publishStatus() {
  StaticJsonDocument<200> doc;
  doc["device_id"] = deviceID;
  doc["mac"] = deviceMAC;
  doc["ip"] = WiFi.localIP().toString();
  doc["relay"] = relayState ? "ON" : "OFF";
  doc["motion"] = motionDetected ? "DETECTED" : "CLEAR";
  doc["rssi"] = WiFi.RSSI();
  doc["uptime"] = millis();
  
  String statusJson;
  serializeJson(doc, statusJson);
  publishMessage(TOPIC_STATUS, statusJson);
}

// ======== Publish Heartbeat ========
void publishHeartbeat() {
  StaticJsonDocument<150> doc;
  doc["device_id"] = deviceID;
  doc["timestamp"] = millis();
  doc["status"] = "ONLINE";
  doc["rssi"] = WiFi.RSSI();
  
  String heartbeatJson;
  serializeJson(doc, heartbeatJson);
  publishMessage(TOPIC_HEARTBEAT, heartbeatJson);
}

// ======== MQTT Connection ========
void connectMQTT() {
  while (!client.connected()) {
    Serial.println("Attempting MQTT connection...");
    
    if (client.connect(clientID.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("MQTT connected!");
      
      // Subscribe to topics
      client.subscribe(TOPIC_CMD.c_str());
      client.subscribe(TOPIC_SCHEDULE.c_str());
      
      // Publish initial status
      publishMessage(TOPIC_STATUS, "ONLINE");
      publishStatus();
      
    } else {
      Serial.print("MQTT connection failed, rc=");
      Serial.print(client.state());
      Serial.println(" Retrying in 5 seconds...");
      delay(5000);
    }
  }
}

// ======== Motion Sensor Check ========
void checkMotionSensor() {
  if (millis() - lastMotionCheck > MOTION_CHECK_INTERVAL) {
    bool currentMotion = digitalRead(PIN_SENSOR);
    
    if (currentMotion != motionDetected) {
      motionDetected = currentMotion;
      publishMessage(TOPIC_MOTION, motionDetected ? "DETECTED" : "CLEAR");
      Serial.println("Motion: " + String(motionDetected ? "DETECTED" : "CLEAR"));
    }
    
    lastMotionCheck = millis();
  }
}

// ======== Setup Function ========
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== HomeGuard ESP-01S Starting ===");
  
  // Initialize EEPROM
  EEPROM.begin(512);
  
  // Initialize pins
  pinMode(PIN_RELAY, OUTPUT);
  pinMode(PIN_SENSOR, INPUT);
  pinMode(LED_BUILTIN, OUTPUT);
  
  // Set initial states
  digitalWrite(PIN_RELAY, HIGH);  // Relay OFF
  digitalWrite(LED_BUILTIN, HIGH); // LED OFF (active LOW)
  
  // Connect to WiFi
  connectWiFi();
  
  // Initialize device identity
  initializeDevice();
  
  // Setup MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);
  
  // Load schedule from EEPROM
  currentSchedule.active = EEPROM.read(0) == 1;
  currentSchedule.hour = EEPROM.read(1);
  currentSchedule.minute = EEPROM.read(2);
  currentSchedule.duration = EEPROM.read(3);
  currentSchedule.action = EEPROM.read(4) == 1;
  
  Serial.println("Setup completed!");
}

// ======== Main Loop ========
void loop() {
  // Maintain MQTT connection
  if (!client.connected()) {
    connectMQTT();
  }
  client.loop();
  
  // Check motion sensor
  checkMotionSensor();
  
  // Send heartbeat
  if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL) {
    publishHeartbeat();
    lastHeartbeat = millis();
  }
  
  // Handle schedule (simplified time checking)
  // Note: For real-time scheduling, consider using NTP and RTC
  
  delay(50);  // Small delay to prevent watchdog issues
}
