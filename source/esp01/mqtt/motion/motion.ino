/**
  HomeGuard Motion Detection Module for ESP-01S
  Compatible with Flask Dashboard MQTT System

  Hardware connections:
  - PIR Motion Sensor VCC -> 3.3V
  - PIR Motion Sensor GND -> GND
  - PIR Motion Sensor OUT -> GPIO2 (PIN 2)

  Features:
  - Motion detection with PIR sensor
  - Configurable sensitivity and detection time
  - MQTT status reporting with LWT
  - Remote monitoring capabilities
  - Device identification and heartbeat
  - ISO-8601 timestamp formatting
  - Robust reconnection with backoff

  MQTT Commands:
  - mosquitto_sub -h 192.168.18.198 -u homeguard -P pu2clr123456 -t
  "home/motion/MOTION_01/#" -v
  - mosquitto_pub -h 192.168.18.198 -t home/motion/MOTION_01/command -m "STATUS"
  -u homeguard -P pu2clr123456
  - mosquitto_pub -h 192.168.18.198 -t home/motion/MOTION_01/command -m "ENABLE"
  -u homeguard -P pu2clr123456
*/

// ======== Debug Configuration ========
#define DEBUG 1

// ======== User Parameters (Edit these for your device) ========
#define DEVICE_ID "MOTION_03"         // Unique device ID
#define DEVICE_NAME "MAKER_SPACE"     // Device display name
#define DEVICE_LOCATION "Maker Space" // Location name

#define LOCAL_IP_1 192
#define LOCAL_IP_2 168
#define LOCAL_IP_3 18
#define LOCAL_IP_4 153

#define GATEWAY_1 192
#define GATEWAY_2 168
#define GATEWAY_3 18
#define GATEWAY_4 1

#define SUBNET_1 255
#define SUBNET_2 255
#define SUBNET_3 255
#define SUBNET_4 0

#define MQTT_SERVER "192.168.18.198"
#define MQTT_PORT 1883
#define MQTT_USER "homeguard"    // <-- troque por placeholder ao commitar
#define MQTT_PASS "pu2clr123456" // <-- troque por placeholder ao commitar
#define WIFI_SSID "APRC"         // <-- troque por placeholder ao commitar
#define WIFI_PASS "Ap69Rc642023" // <-- troque por placeholder ao commitar

#include <ESP8266WiFi.h>
#include <PubSubClient.h>

// ======== Network Configuration ========
IPAddress local_IP(LOCAL_IP_1, LOCAL_IP_2, LOCAL_IP_3, LOCAL_IP_4);
IPAddress gateway(GATEWAY_1, GATEWAY_2, GATEWAY_3, GATEWAY_4);
IPAddress subnet(SUBNET_1, SUBNET_2, SUBNET_3, SUBNET_4);

// ======== MQTT Broker Configuration ========
const char *mqtt_server = MQTT_SERVER;
const int mqtt_port = MQTT_PORT;
const char *mqtt_user = MQTT_USER;
const char *mqtt_pass = MQTT_PASS;

// ======== Device Info ========
const char *DEVICE_ID_STR = DEVICE_ID;
const char *DEVICE_NAME_STR = DEVICE_NAME;
const char *DEVICE_LOCATION_STR = DEVICE_LOCATION;

// ======== Wi-Fi Network Configuration ========
const char *ssid = WIFI_SSID;
const char *password = WIFI_PASS;

// ======== Hardware Configuration ========
#define PIR_PIN 2        // GPIO2 for PIR sensor (digital input)
#define STATUS_LED_PIN 0 // GPIO0 for status LED (optional)

WiFiClient espClient;
PubSubClient client(espClient);

// ======== MQTT Topics ========
String TOPIC_STATUS = String("home/motion/") + DEVICE_ID_STR + "/status";
String TOPIC_EVENT = String("home/motion/") + DEVICE_ID_STR + "/event";
String TOPIC_HEARTBEAT = String("home/motion/") + DEVICE_ID_STR + "/heartbeat";
String TOPIC_COMMAND = String("home/motion/") + DEVICE_ID_STR + "/command";
String TOPIC_STATE = String("home/motion/") + DEVICE_ID_STR + "/state";

// ======== Motion Detection Variables ========
bool motionDetected = false;
bool lastMotionState = false;
bool motionEnabled = true;
unsigned long motionStartTime = 0;
unsigned long lastMotionTime = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastPirRead = 0;
unsigned long bootTime = 0;

// ======== Configuration Variables ========
const unsigned long DEBOUNCE_DELAY = 200;   // 200ms debounce
const unsigned long MOTION_TIMEOUT = 30000; // 30 seconds timeout for inactivity
const unsigned long HEARTBEAT_INTERVAL = 60000; // 60 seconds heartbeat
const unsigned long RECONNECT_INTERVAL = 5000;  // 5 seconds reconnect attempt

// ======== Connection Variables ========
unsigned long lastWifiCheck = 0;
unsigned long lastMqttCheck = 0;
int wifiRetryCount = 0;
int mqttRetryCount = 0;

// ======== Device Status ========
struct DeviceStatus {
  bool online;
  bool motion_enabled;
  int rssi;
  unsigned long uptime;
  bool pir_status;
} device_status;

// ======== Debug Logging ========
#if DEBUG
#define DEBUG_PRINT(x) Serial.print(x)
#define DEBUG_PRINTLN(x) Serial.println(x)
#define DEBUG_PRINTF(format, ...) Serial.printf(format, __VA_ARGS__)
#else
#define DEBUG_PRINT(x)
#define DEBUG_PRINTLN(x)
#define DEBUG_PRINTF(format, ...)
#endif

// ======== Get ISO-8601 Timestamp ========
String getTimestamp() {
  // Simple timestamp - without NTP just use uptime
  unsigned long uptime = (millis() - bootTime) / 1000;
  return String(uptime);
}

// ======== Connect to WiFi ========
bool connectWifi() {
  if (WiFi.status() == WL_CONNECTED) {
    return true;
  }

  DEBUG_PRINTLN("Conectando ao WiFi...");

  // Try static IP first
  WiFi.config(local_IP, gateway, subnet);
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    DEBUG_PRINT(".");
    attempts++;

    // Blink LED during connection
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
  }

  if (WiFi.status() == WL_CONNECTED) {
    DEBUG_PRINTLN("");
    DEBUG_PRINTF("WiFi conectado! IP: %s\n", WiFi.localIP().toString().c_str());
    digitalWrite(STATUS_LED_PIN, HIGH);
    wifiRetryCount = 0;
    return true;
  } else {
    DEBUG_PRINTLN("");
    DEBUG_PRINTLN("Falha na conexão WiFi - tentando DHCP...");

    // Try DHCP as fallback
    WiFi.config(0U, 0U, 0U); // Clear static config
    WiFi.begin(ssid, password);

    attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(500);
      DEBUG_PRINT(".");
      attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      DEBUG_PRINTLN("");
      DEBUG_PRINTF("WiFi conectado via DHCP! IP: %s\n",
                   WiFi.localIP().toString().c_str());
      digitalWrite(STATUS_LED_PIN, HIGH);
      wifiRetryCount = 0;
      return true;
    } else {
      DEBUG_PRINTLN("");
      DEBUG_PRINTLN("Falha total na conexão WiFi!");
      wifiRetryCount++;
      return false;
    }
  }
}

// ======== Connect to MQTT ========
bool connectMqtt() {
  if (!WiFi.isConnected()) {
    return false;
  }

  if (client.connected()) {
    return true;
  }

  DEBUG_PRINTLN("Conectando ao MQTT...");

  String clientId = "HomeGuard_" + String(DEVICE_ID_STR);
  String lwt_topic = TOPIC_STATUS;

  // Set LWT (Last Will Testament)
  if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass, lwt_topic.c_str(),
                     1, true, "offline")) {

    DEBUG_PRINTLN("MQTT conectado!");

    // Subscribe to command topic
    client.subscribe(TOPIC_COMMAND.c_str());
    DEBUG_PRINTF("Subscrito em: %s\n", TOPIC_COMMAND.c_str());

    // Publish online status (retained)
    publishStatus("online");

    // Send initial device state
    publishState();

    // Update device status
    device_status.online = true;
    device_status.rssi = WiFi.RSSI();
    device_status.uptime = millis();

    mqttRetryCount = 0;
    return true;

  } else {
    DEBUG_PRINTF("Falha na conexão MQTT, rc=%d\n", client.state());
    mqttRetryCount++;
    return false;
  }
}

// ======== Publish Status ========
void publishStatus(const char *status) {
  if (client.connected()) {
    client.publish(TOPIC_STATUS.c_str(), status, true); // retained
    DEBUG_PRINTF("Status publicado: %s\n", status);
  }
}

// ======== Publish Motion Event ========
void publishEvent(bool motion) {
  if (!client.connected() || !motionEnabled) {
    return;
  }

  // Create JSON payload
  String payload = "{";
  payload += "\"motion\":" + String(motion ? 1 : 0) + ",";
  payload += "\"ts\":\"" + getTimestamp() + "\",";
  payload += "\"device_id\":\"" + String(DEVICE_ID_STR) + "\",";
  payload += "\"name\":\"" + String(DEVICE_NAME_STR) + "\",";
  payload += "\"location\":\"" + String(DEVICE_LOCATION_STR) + "\"";
  payload += "\"ip\":\"" + WiFi.localIP().toString() + "\"";
  payload += "}";

  client.publish(TOPIC_EVENT.c_str(), payload.c_str(), false); // not retained
  DEBUG_PRINTF("Evento publicado: %s\n", payload.c_str());
}

// ======== Publish Heartbeat ========
void publishHeartbeat() {
  if (!client.connected()) {
    return;
  }

  unsigned long uptime = (millis() - bootTime) / 1000;

  String payload = "{";
  payload += "\"uptime\":" + String(uptime) + ",";
  payload += "\"rssi\":" + String(WiFi.RSSI());
  payload += "}";

  client.publish(TOPIC_HEARTBEAT.c_str(), payload.c_str(),
                 false); // not retained
  DEBUG_PRINTF("Heartbeat: %s\n", payload.c_str());
}

// ======== Publish Device State ========
void publishState() {
  if (!client.connected()) {
    return;
  }

  String payload = "{";
  payload += "\"enabled\":" + String(motionEnabled ? "true" : "false");
  payload += "}";

  client.publish(TOPIC_STATE.c_str(), payload.c_str(), false);
  DEBUG_PRINTF("Estado publicado: %s\n", payload.c_str());
}

// ======== Handle MQTT Commands ========
void handleCommand(const String &command) {
  DEBUG_PRINTF("Comando recebido: %s\n", command.c_str());

  if (command.equalsIgnoreCase("ENABLE")) {
    motionEnabled = true;
    publishState();
    DEBUG_PRINTLN("Detecção de movimento HABILITADA");

  } else if (command.equalsIgnoreCase("DISABLE")) {
    motionEnabled = false;
    publishState();
    DEBUG_PRINTLN("Detecção de movimento DESABILITADA");

  } else if (command.equalsIgnoreCase("STATUS")) {
    publishStatus("online");
    publishState();
    publishHeartbeat();
    DEBUG_PRINTLN("Status enviado");

  } else {
    DEBUG_PRINTF("Comando não reconhecido: %s\n", command.c_str());
  }
}

// ======== MQTT Callback ========
void callback(char *topic, byte *payload, unsigned int length) {
  String command;
  for (unsigned int i = 0; i < length; i++) {
    command += (char)payload[i];
  }
  command.trim();

  DEBUG_PRINTF("MQTT recebido [%s]: %s\n", topic, command.c_str());

  if (strcmp(topic, TOPIC_COMMAND.c_str()) == 0) {
    handleCommand(command);
  }
}

// ======== Read PIR Sensor with Debounce ========
void readPirSensor() {
  unsigned long currentTime = millis();

  // Debounce check
  if (currentTime - lastPirRead < DEBOUNCE_DELAY) {
    return;
  }

  lastPirRead = currentTime;

  bool currentMotionReading = digitalRead(PIR_PIN);
  device_status.pir_status = currentMotionReading;

  // Motion detected (rising edge)
  if (currentMotionReading && !lastMotionState) {
    motionDetected = true;
    motionStartTime = currentTime;
    lastMotionTime = currentTime;

    publishEvent(true);

    // Blink LED to indicate motion detection
    digitalWrite(STATUS_LED_PIN, LOW);
    delay(50);
    digitalWrite(STATUS_LED_PIN, HIGH);

    DEBUG_PRINTF("Movimento DETECTADO em %s\n", DEVICE_LOCATION_STR);
  }

  // Check if motion timeout has expired
  if (motionDetected && (currentTime - motionStartTime > MOTION_TIMEOUT)) {
    motionDetected = false;

    publishEvent(false);
    DEBUG_PRINTF("Movimento FINALIZADO em %s (timeout)\n", DEVICE_LOCATION_STR);
  }

  // Motion cleared (falling edge)
  if (!currentMotionReading && lastMotionState && motionDetected) {
    motionDetected = false;

    publishEvent(false);
    DEBUG_PRINTF("Movimento FINALIZADO em %s (sensor)\n", DEVICE_LOCATION_STR);
  }

  lastMotionState = currentMotionReading;
}

// ======== Reconnection Management ========
void handleReconnections() {
  unsigned long currentTime = millis();

  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    device_status.online = false;

    if (currentTime - lastWifiCheck >= RECONNECT_INTERVAL) {
      lastWifiCheck = currentTime;
      DEBUG_PRINTLN("WiFi desconectado - tentando reconectar...");

      if (connectWifi()) {
        DEBUG_PRINTLN("WiFi reconectado!");
      }
    }
    return;
  }

  // Check MQTT connection
  if (!client.connected()) {
    device_status.online = false;

    if (currentTime - lastMqttCheck >= RECONNECT_INTERVAL) {
      lastMqttCheck = currentTime;
      DEBUG_PRINTLN("MQTT desconectado - tentando reconectar...");

      if (connectMqtt()) {
        DEBUG_PRINTLN("MQTT reconectado!");
      }
    }
  }
}

// ======== Setup Function ========
void setup() {
  bootTime = millis();

#if DEBUG
  Serial.begin(115200);
  delay(100);
  DEBUG_PRINTLN("\n=== HomeGuard Motion Detector ===");
  DEBUG_PRINTF("Device ID: %s\n", DEVICE_ID_STR);
  DEBUG_PRINTF("Device Name: %s\n", DEVICE_NAME_STR);
  DEBUG_PRINTF("Location: %s\n", DEVICE_LOCATION_STR);
#endif

  // Initialize hardware pins
  pinMode(PIR_PIN, INPUT_PULLUP);
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);

  // Initialize device status
  device_status.online = false;
  device_status.motion_enabled = true;
  device_status.pir_status = false;
  device_status.rssi = 0;
  device_status.uptime = 0;

  // Initialize motion state
  motionDetected = false;
  lastMotionState = false;
  motionEnabled = true;

  // Connect to WiFi
  if (connectWifi()) {
    DEBUG_PRINTLN("Inicialização WiFi bem-sucedida");

    // Setup MQTT
    client.setServer(mqtt_server, mqtt_port);
    client.setCallback(callback);

    // Connect to MQTT
    if (connectMqtt()) {
      DEBUG_PRINTLN("Inicialização MQTT bem-sucedida");
    }
  }

  DEBUG_PRINTLN("=== Setup completo ===");
  digitalWrite(STATUS_LED_PIN, HIGH);
}

// ======== Main Loop ========
void loop() {
  unsigned long currentTime = millis();

  // Handle reconnections
  handleReconnections();

  // Process MQTT messages
  client.loop();

  // Read PIR sensor
  if (motionEnabled) {
    readPirSensor();
  }

  // Send periodic heartbeat
  if (currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    if (client.connected()) {
      publishHeartbeat();
      device_status.rssi = WiFi.RSSI();
      device_status.uptime = currentTime;
    }
    lastHeartbeat = currentTime;
  }

  // Small delay to prevent watchdog issues
  delay(50);
}

// ======== End of HomeGuard Motion Detector ========
