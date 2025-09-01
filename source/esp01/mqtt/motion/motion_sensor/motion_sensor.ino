/**
 * HomeGuard Motion Detection Module for ESP-01S
 * Based on the working mqtt.ino configuration
 * 
 * Hardware connections:
 * - PIR Motion Sensor VCC -> 3.3V
 * - PIR Motion Sensor GND -> GND  
 * - PIR Motion Sensor OUT -> GPIO2 (PIN 2)
 * 
 * Features:
 * - Motion detection with PIR sensor
 * - Configurable sensitivity and detection time
 * - MQTT status reporting
 * - Remote monitoring capabilities
 * - Device identification and heartbeat
 * 
 * MQTT Commands:
 * - mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t "home/motion_sensor/+/#" -v
 * - mosquitto_pub -h 192.168.18.198 -t home/motion_sensor/{device_id}/cmnd -m "STATUS" -u homeguard -P pu2clr123456
 * - mosquitto_pub -h 192.168.18.198 -t home/motion_sensor/{device_id}/cmnd -m "SENSITIVITY_HIGH" -u homeguard -P pu2clr123456
 */

#include <ESP8266WiFi.h>
#include <PubSubClient.h>


// ======== Wi-Fi Network Configuration ========
const char* ssid = "APRC";
const char* password = "Ap69Rc642023";

// ESP-01S using DHCP (no fixed IP)
// IPAddress local_IP(192, 168, 18, 140);  // Different IP from relay module
// IPAddress gateway(192, 168, 18, 1);
// IPAddress subnet(255, 255, 255, 0);

// ======== MQTT Broker Configuration ========
const char* mqtt_server = "192.168.18.198"; // Local MQTT broker IP
const int   mqtt_port   = 1883;           // Standard MQTT port
const char* mqtt_user   = "homeguard";    // Username
const char* mqtt_pass   = "pu2clr123456"; // Password

// ======== Motion Sensor Configuration ========
#define PIN_MOTION_SENSOR 2    // GPIO2 for PIR sensor (digital input)
#define PIN_LED 0              // GPIO0 for status LED (optional)

// ======== MQTT Topics (dynamic by deviceID) ========
String TOPIC_CMD;
String TOPIC_STATUS;
String TOPIC_MOTION;
String TOPIC_HEARTBEAT;
String TOPIC_CONFIG;

WiFiClient espClient;
PubSubClient client(espClient);

// ======== Motion Detection Variables ========
bool motionDetected = false;
bool lastMotionState = false;
unsigned long motionStartTime = 0;
unsigned long lastMotionTime = 0;
unsigned long lastHeartbeat = 0;

// ======== Configuration Variables ========
unsigned long motionTimeout = 30000;        // 30 seconds - time to keep "DETECTED" status
unsigned long heartbeatInterval = 60000;    // 60 seconds - heartbeat interval
unsigned long debounceDelay = 2000;         // 2 seconds - debounce delay to avoid false triggers
bool enableHeartbeat = true;
//String deviceLocation = "Living Room";       // Configurable location name
String deviceLocation = "Maker Space";       // Configurable location name


// ======== Device Information ========
String deviceMAC;
String deviceID;

// ======== Initialize Device Identity ========
void initializeDevice() {
  deviceMAC = WiFi.macAddress();
  deviceMAC.replace(":", "");
  deviceMAC.toLowerCase();
  deviceID = "motion_" + deviceMAC.substring(6); // Use last 6 chars of MAC
  
  // Define topics dynamically based on device_id
  TOPIC_CMD      = "home/motion_sensor/" + deviceID + "/cmnd";
  TOPIC_STATUS   = "home/motion_sensor/" + deviceID + "/status";
  TOPIC_MOTION   = "home/motion_sensor/" + deviceID + "/motion";
  TOPIC_HEARTBEAT= "home/motion_sensor/" + deviceID + "/heartbeat";
  TOPIC_CONFIG   = "home/motion_sensor/" + deviceID + "/config";
  
  Serial.println("=== HomeGuard Motion Detector ===");
  Serial.println("Device ID: " + deviceID);
  Serial.println("MAC Address: " + WiFi.macAddress());
  Serial.println("Location: " + deviceLocation);
}

// ======== Function to process MQTT messages ========
void callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();
  
  Serial.println("Received [" + String(topic) + "]: " + msg);
  
  // Handle commands
  if (msg.equalsIgnoreCase("STATUS")) {
    publishDeviceStatus();
  }
  else if (msg.equalsIgnoreCase("RESET")) {
    publishMessage(TOPIC_STATUS, "RESETTING");
    delay(1000);
    ESP.restart();
  }
  else if (msg.equalsIgnoreCase("HEARTBEAT_ON")) {
    enableHeartbeat = true;
    publishMessage(TOPIC_CONFIG, "HEARTBEAT_ENABLED");
  }
  else if (msg.equalsIgnoreCase("HEARTBEAT_OFF")) {
    enableHeartbeat = false;
    publishMessage(TOPIC_CONFIG, "HEARTBEAT_DISABLED");
  }
  else if (msg.startsWith("TIMEOUT_")) {
    // Set motion timeout: TIMEOUT_60 (60 seconds)
    String timeoutStr = msg.substring(8);
    unsigned long newTimeout = timeoutStr.toInt() * 1000;
    if (newTimeout > 0 && newTimeout <= 300000) { // Max 5 minutes
      motionTimeout = newTimeout;
      publishMessage(TOPIC_CONFIG, "TIMEOUT_SET_" + String(newTimeout/1000) + "s");
    }
  }
  else if (msg.startsWith("LOCATION_")) {
    // Set device location: LOCATION_Kitchen
    deviceLocation = msg.substring(9);
    publishMessage(TOPIC_CONFIG, "LOCATION_SET_" + deviceLocation);
  }
  else if (msg.equalsIgnoreCase("SENSITIVITY_HIGH")) {
    debounceDelay = 1000; // 1 second
    publishMessage(TOPIC_CONFIG, "SENSITIVITY_HIGH");
  }
  else if (msg.equalsIgnoreCase("SENSITIVITY_NORMAL")) {
    debounceDelay = 2000; // 2 seconds
    publishMessage(TOPIC_CONFIG, "SENSITIVITY_NORMAL");
  }
  else if (msg.equalsIgnoreCase("SENSITIVITY_LOW")) {
    debounceDelay = 5000; // 5 seconds
    publishMessage(TOPIC_CONFIG, "SENSITIVITY_LOW");
  }
}

// ======== Publish MQTT Message ========
void publishMessage(String topic, String message) {
  if (client.connected()) {
    client.publish(topic.c_str(), message.c_str());
    Serial.println("Published [" + topic + "]: " + message);
  }
}

// ======== Publish Device Status ========
void publishDeviceStatus() {
  // Create JSON-like status message
  String status = "{";
  status += "\"device_id\":\"" + deviceID + "\",";
  status += "\"location\":\"" + deviceLocation + "\",";
  status += "\"mac\":\"" + WiFi.macAddress() + "\",";
  status += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  status += "\"motion\":\"" + String(motionDetected ? "DETECTED" : "CLEAR") + "\",";
  status += "\"last_motion\":\"" + String((millis() - lastMotionTime) / 1000) + "s ago\",";
  status += "\"timeout\":\"" + String(motionTimeout / 1000) + "s\",";
  status += "\"sensitivity\":\"" + String(debounceDelay / 1000) + "s\",";
  status += "\"uptime\":\"" + String(millis() / 1000) + "s\",";
  status += "\"rssi\":\"" + String(WiFi.RSSI()) + "dBm\"";
  status += "}";
  
  publishMessage(TOPIC_STATUS, status);
}

// ======== Publish Heartbeat ========
void publishHeartbeat() {
  String heartbeat = "{";
  heartbeat += "\"device_id\":\"" + deviceID + "\",";
  heartbeat += "\"timestamp\":\"" + String(millis()) + "\",";
  heartbeat += "\"status\":\"ONLINE\",";
  heartbeat += "\"location\":\"" + deviceLocation + "\",";
  heartbeat += "\"rssi\":\"" + String(WiFi.RSSI()) + "\"";
  heartbeat += "}";
  
  publishMessage(TOPIC_HEARTBEAT, heartbeat);
}

// ======== Motion Detection Logic ========
void checkMotionSensor() {
  bool currentMotionReading = digitalRead(PIN_MOTION_SENSOR);
  unsigned long currentTime = millis();
  
  // Motion detected (rising edge with debounce)
  if (currentMotionReading && !lastMotionState && 
      (currentTime - lastMotionTime > debounceDelay)) {
    
    motionDetected = true;
    motionStartTime = currentTime;
    lastMotionTime = currentTime;
    
    // Publish motion detection
    String motionEvent = "{";
    motionEvent += "\"device_id\":\"" + deviceID + "\",";
    motionEvent += "\"device_name\":\"Motion Sensor " + deviceID + "\",";
    motionEvent += "\"location\":\"" + deviceLocation + "\",";
    motionEvent += "\"event\":\"MOTION_DETECTED\",";
    motionEvent += "\"timestamp\":\"" + String(currentTime) + "\",";
    motionEvent += "\"rssi\":\"" + String(WiFi.RSSI()) + "\"";
    motionEvent += "}";
    
    publishMessage(TOPIC_MOTION, motionEvent);
    
    // Blink LED to indicate motion detection
    digitalWrite(PIN_LED, LOW);
    delay(100);
    digitalWrite(PIN_LED, HIGH);
    
    Serial.println("Motion DETECTED at " + deviceLocation);
  }
  
  // Check if motion timeout has expired
  if (motionDetected && (currentTime - motionStartTime > motionTimeout)) {
    motionDetected = false;
    
    // Publish motion cleared
    String motionEvent = "{";
    motionEvent += "\"device_id\":\"" + deviceID + "\",";
    motionEvent += "\"device_name\":\"Motion Sensor " + deviceID + "\",";
    motionEvent += "\"location\":\"" + deviceLocation + "\",";
    motionEvent += "\"event\":\"MOTION_CLEARED\",";
    motionEvent += "\"timestamp\":\"" + String(currentTime) + "\",";
    motionEvent += "\"duration\":\"" + String((currentTime - motionStartTime) / 1000) + "s\"";
    motionEvent += "}";
    
    publishMessage(TOPIC_MOTION, motionEvent);
    
    Serial.println("Motion CLEARED at " + deviceLocation);
  }
  
  lastMotionState = currentMotionReading;
}

// ======== Reconnect to MQTT if necessary ========
void reconnect() {
  while (!client.connected()) {
    Serial.println("Attempting MQTT connection...");
    
    String clientId = "ESP01S_Motion_" + deviceID;
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("MQTT connected!");
      
      // Subscribe to command topic
      client.subscribe(TOPIC_CMD.c_str());
      
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
  Serial.println("\n=== HomeGuard Motion Detector Starting ===");
  
  // Initialize pins
  pinMode(PIN_MOTION_SENSOR, INPUT);
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, HIGH); // LED OFF (assuming active LOW)
  
  // Connect to WiFi using DHCP
  // WiFi.config(local_IP, gateway, subnet);
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
  
  Serial.println("=== Motion Detector Ready ===");
  Serial.println("Monitoring location: " + deviceLocation);
  Serial.println("Motion timeout: " + String(motionTimeout/1000) + " seconds");
  Serial.println("Debounce delay: " + String(debounceDelay/1000) + " seconds");
}

// ======== Main Loop ========
void loop() {
  // Maintain MQTT connection
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  
  // Check motion sensor
  checkMotionSensor();
  
  // Send heartbeat if enabled
  if (enableHeartbeat && (millis() - lastHeartbeat > heartbeatInterval)) {
    publishHeartbeat();
    lastHeartbeat = millis();
  }
  
  delay(100); // Small delay to prevent watchdog issues
}
