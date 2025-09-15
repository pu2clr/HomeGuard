/**
  HomeGuard Grid Monitor for ESP8266 + ZMPT101B
  Parametrized version for easy configuration via Arduino IDE or arduino-cli

  CONFIGURATION:
  - Set parameters below as #define or const values before uploading.
  - You can use "Tools > Define Symbols" in Arduino IDE or --build-property in arduino-cli for automation.

  Hardware connections:
  - ZMPT101B VCC -> 3.3V
  - ZMPT101B GND -> GND
  - ZMPT101B OUT -> Analog Pin (A0)
  - RELÉ -> GPIO4 

  MQTT Interaction Examples (using mosquitto):
  # Monitor grid status:
  mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR/status" -v

  # Monitor device info:
  mosquitto_sub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR/info" -v

  # Command relay ON:
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR/command" -m "ON"

  # Command relay OFF:
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/ESP8266_GRID_MONITOR/command" -m "OFF"

  # Return relay to automatic mode:
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/grid/ESP8266_GRID_MONITOR/command" -m "AUTO"
*/

/*
 * HomeGuard Grid Monitor - ESP8266
 *
 * IMPORTANTE: Acionamento de Relé com Transistor NPN
 * -------------------------------------------------
 * O ESP8266 opera com GPIOs de 3.3V e baixa corrente, enquanto a maioria dos módulos relé espera sinal de 5V e consome mais corrente do que o pino pode fornecer.
 * Para acionar o relé de forma segura e confiável, utilize um transistor NPN (ex: 2N2222, BC547, BC337) como driver:
 *
 *   GPIO5 ----[1kΩ]----|>B   2N2222/BC547 NPN
 *                     |      (ou similar)
 *                    C|----- IN do módulo relé
 *                     |
 *                    E|
 *                     |
 *                   GND (comum ao ESP e ao relé)
 *
 * O VCC do relé deve ser 5V e o GND do relé deve ser comum ao ESP.
 * NÃO acione o relé diretamente do GPIO!
 *
 * Veja detalhes em RELAY_DRIVER_NPN.md
 */

// ======== User Parameters (Edit these for your device) ========

#define DEVICE_ID        "GRID_MONITOR"   // Unique device ID
#define DEVICE_NAME      "Monitor Rede"   // Device display name
#define DEVICE_LOCATION  "Home"         // Location name

// Device local IP
#define LOCAL_IP_1       192
#define LOCAL_IP_2       168
#define LOCAL_IP_3       1
#define LOCAL_IP_4       90

// Network Getway IP
#define GATEWAY_1        192
#define GATEWAY_2        168
#define GATEWAY_3        1
#define GATEWAY_4        1

// Network Subnet IP
#define SUBNET_1         255
#define SUBNET_2         255
#define SUBNET_3         255
#define SUBNET_4         0

// Broker Configuration
#define MQTT_SERVER      "192.168.1.102"         // MQTT broker IP
#define MQTT_PORT        1883                     // MQTT broker port
#define MQTT_USER        "homeguard"              // MQTT username
#define MQTT_PASS        "pu2clr123456"           // MQTT password

// WIFI Configuration
#define WIFI_SSID        "Homeguard"              // WiFi SSID
#define WIFI_PASS        "pu2clr123456"          // WiFi password


#define ZMPT_PIN         A0                        // Analog pin for ZMPT101B
#define RELAY_PIN        5                         // GPIO5 for relay control
#define STATUS_LED_PIN   LED_BUILTIN               // Built-in LED for status indication
#define GRID_THRESHOLD   950                       // Threshold for grid detection (adjust experimentally)

#include <ESP8266WiFi.h>
#include <PubSubClient.h>

// ======== Network Configuration ========
IPAddress local_IP(LOCAL_IP_1, LOCAL_IP_2, LOCAL_IP_3, LOCAL_IP_4);
IPAddress gateway(GATEWAY_1, GATEWAY_2, GATEWAY_3, GATEWAY_4);
IPAddress subnet(SUBNET_1, SUBNET_2, SUBNET_3, SUBNET_4);

// ======== MQTT Broker Configuration ========
const char* mqtt_server = MQTT_SERVER;
const int   mqtt_port   = MQTT_PORT;
const char* mqtt_user   = MQTT_USER;
const char* mqtt_pass   = MQTT_PASS;

// ======== Device Info ========
const char* DEVICE_ID_STR = DEVICE_ID;
const char* DEVICE_NAME_STR = DEVICE_NAME;
const char* DEVICE_LOCATION_STR = DEVICE_LOCATION;

// ======== Wi-Fi Network Configuration ========
const char* ssid = WIFI_SSID;
const char* password = WIFI_PASS;

WiFiClient espClient;
PubSubClient client(espClient);

// ======== MQTT Topics ========
String TOPIC_GRID_STATUS = String("home/grid/") + DEVICE_ID_STR + "/status";
String TOPIC_INFO        = String("home/grid/") + DEVICE_ID_STR + "/info";

// ======== State Variables ========
bool gridOnline = false;
bool lastGridOnline = false;
unsigned long lastHeartbeat = 0;
unsigned long lastReading = 0;
unsigned long lastDataSend = 0;
int failedReadings = 0;
bool relayManualOverride = false; // Se true, ignora controle automático
bool relayManualState = false;    // Estado desejado do relé via comando
int sensorValue;

// Timing intervals
const unsigned long READING_INTERVAL = 10000;     // 10 seconds
const unsigned long HEARTBEAT_INTERVAL = 60000;   // 1 minute
const unsigned long DATA_SEND_INTERVAL = 10000;   // 10 seconds

// ======== Device Status ========
struct DeviceStatus {
  bool online;
  bool grid_ok;
  int rssi;
  unsigned long uptime;
  int failed_readings;
  bool last_grid_online;
  unsigned long last_reading_time;
} device_status;


// ======== Send grid status to MQTT ========
void sendGridStatus(bool forceUpdate = false) {
  if (!client.connected() || !device_status.grid_ok) {
    return;
  }
  bool statusChanged = gridOnline != lastGridOnline;
  bool timeToSend = (millis() - lastDataSend) >= DATA_SEND_INTERVAL;
  if (forceUpdate || statusChanged || timeToSend) {
    String statusPayload = "{";
    statusPayload += "\"device_id\":\"" + String(DEVICE_ID_STR) + "\",";
    statusPayload += "\"device_name\":\"" + String(DEVICE_NAME_STR) + "\",";
    statusPayload += "\"location\":\"" + String(DEVICE_LOCATION_STR) + "\",";
    statusPayload += "\"sensor_type\":\"ZMPT101B\",";
    statusPayload += "\"grid_status\":\"" + String(gridOnline ? "online" : "offline") + "\",";
    statusPayload += "\"sensor_value\":" + String(sensorValue) + ",";
    statusPayload += "\"ligth_status\":\"" + String( (gridOnline )? "ON" : "OFF" ) + "\",";
    statusPayload += "\"rssi\":" + String(WiFi.RSSI()) + ",";
    statusPayload += "\"uptime\":" + String(millis()) + ",";
    statusPayload += "\"timestamp\":\"" + String(millis()) + "\"";
    statusPayload += "}";
    client.publish(TOPIC_GRID_STATUS.c_str(), statusPayload.c_str(), true);
    lastGridOnline = gridOnline;
    lastDataSend = millis();
    Serial.printf("Status da rede enviado via MQTT: %s\n", gridOnline ? "ONLINE" : "OFFLINE");
  }
}

// ======== Send device information ========
void sendDeviceInfo() {
  String info = "{";
  info += "\"device_id\":\"" + String(DEVICE_ID_STR) + "\",";
  info += "\"device_name\":\"" + String(DEVICE_NAME_STR) + "\",";
  info += "\"location\":\"" + String(DEVICE_LOCATION_STR) + "\",";
  info += "\"sensor_type\":\"ZMPT101B\",";
  info += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  info += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  info += "\"uptime\":" + String(millis()) + ",";
  info += "\"grid_status\":\"" + String(gridOnline ? "online" : "offline") + "\",";
  info += "\"sensor_value\":" + String(sensorValue) + ",";
  info += "\"ligth_status\":\"" + String( (gridOnline)? "ON" : "OFF" ) + "\",";
  info += "\"failed_readings\":" + String(device_status.failed_readings) + ",";
  info += "\"firmware\":\"HomeGuard_GRID_v1.0\"";
  info += "}";
  client.publish(TOPIC_INFO.c_str(), info.c_str(), true);
}

// ======== Read ZMPT101B sensor ========
void readGridSensor() {
  const int NUM_SAMPLES = 20;           // Número de amostras
  const int SAMPLE_DELAY_MS = 2;        // Intervalo entre amostras (ms)
  int maxValue = 0;
  for (int i = 0; i < NUM_SAMPLES; i++) {
    int val = analogRead(ZMPT_PIN);
    if (val > maxValue) maxValue = val;
    delay(SAMPLE_DELAY_MS);
  }
  int sensorValue = maxValue;
  bool previousGridOnline = gridOnline;
  gridOnline = sensorValue > GRID_THRESHOLD;
  if (sensorValue < 0) {
    failedReadings++;
    device_status.grid_ok = false;
    Serial.println("Erro ao ler ZMPT101B!");
  } else {
    failedReadings = 0;
    device_status.grid_ok = gridOnline;
    device_status.last_grid_online = gridOnline;
    device_status.last_reading_time = millis();
    // Controle do relé: automático (falta de energia) ou manual (override)
    if (relayManualOverride) {
      digitalWrite(RELAY_PIN, relayManualState ? HIGH : LOW);
      Serial.printf("Relay manual mode: %s (GPIO%d = %s)\n", relayManualState ? "ON" : "OFF", RELAY_PIN, relayManualState ? "HIGH" : "LOW");
    } else {
      digitalWrite(RELAY_PIN, gridOnline ? LOW : HIGH); // HIGH aciona relé (luz emergência)
      Serial.printf("Relay auto mode: Grid %s -> Relay %s (GPIO%d = %s)\n", gridOnline ? "ONLINE" : "OFFLINE", gridOnline ? "OFF" : "ON", RELAY_PIN, gridOnline ? "LOW" : "HIGH");
    }
    Serial.printf("Grid: %s (Valor: %d)\n", gridOnline ? "ONLINE" : "OFFLINE", sensorValue);
    // Enviar status imediatamente ao detectar falta de energia
    if (!previousGridOnline && gridOnline) {
      sendDeviceInfo();
      Serial.println("Status enviado: Falta de energia detectada!");
    }
  }
  device_status.failed_readings = failedReadings;
  lastReading = millis();
}



// ======== Process MQTT commands ========
void callback(char* topic, byte* payload, unsigned int length) {
  (void)topic; // Suppress unused parameter warning
  
  // Serial.println("Teste: ");
  // Serial.println(topic);
  // Serial.println((char *) payload);

  String command;
  for (unsigned int i = 0; i < length; i++) {
    command += (char)payload[i];
  }
  command.trim();
  if (command.equalsIgnoreCase("STATUS")) {
    sendGridStatus(true);
    sendDeviceInfo();
  }
  else if (command.equalsIgnoreCase("READ")) {
    readGridSensor();
    sendGridStatus(true);
  }
  else if (command.equalsIgnoreCase("INFO")) {
    sendDeviceInfo();
  }
  else if (command.equalsIgnoreCase("ON")) {
    relayManualOverride = true;
    relayManualState = true;
    digitalWrite(RELAY_PIN, HIGH);
    Serial.printf("MQTT Command ON: GPIO%d set to HIGH\n", RELAY_PIN);
  }
  else if (command.equalsIgnoreCase("OFF")) {
    relayManualOverride = true;
    relayManualState = false;
    digitalWrite(RELAY_PIN, LOW);
    Serial.printf("MQTT Command OFF: GPIO%d set to LOW\n", RELAY_PIN);
  }
  else if (command.equalsIgnoreCase("AUTO")) {
    relayManualOverride = false;
    Serial.println("Comando remoto: AUTO (controle automático)");
    // O controle volta a ser feito pelo sensor
    readGridSensor();
  }
}

// ======== Reconnect to MQTT ========
void reconnect() {
  int attempts = 0;
  while (!client.connected() && attempts < 3) {
    String clientId = "HomeGuard_" + String(DEVICE_ID_STR);
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      String commandTopic = "home/grid/" + String(DEVICE_ID_STR) + "/command";
      client.subscribe(commandTopic.c_str());
      sendDeviceInfo();
      sendGridStatus(true);
      device_status.online = true;
      device_status.rssi = WiFi.RSSI();
      device_status.uptime = millis();
      Serial.println("MQTT conectado!");
      break;
    } else {
      attempts++;
      Serial.printf("Falha na conexão MQTT, tentativa %d/3\n", attempts);
      delay(2000 * attempts);
    }
  }
}

// ======== Setup function ========
void setup() {
  Serial.begin(115200);
  Serial.println("ESP8266 Grid Monitor iniciando...");
  
  // Configure pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  
  digitalWrite(RELAY_PIN, LOW);  // Relé ligado inicialmente (grid ainda não verificada)
  Serial.printf("Relay initialized on GPIO%d: %s\n", RELAY_PIN, "ON (LOW)");
  digitalWrite(RELAY_PIN, HIGH);  
  delay(1000);
  digitalWrite(RELAY_PIN, LOW);  
   

  digitalWrite(STATUS_LED_PIN, HIGH); // LED off initially (inverted logic)
  
  device_status.online = false;
  device_status.grid_ok = false;
  device_status.failed_readings = 0;
  device_status.last_grid_online = false;
  device_status.last_reading_time = 0;
  WiFi.config(local_IP, gateway, subnet);
  WiFi.begin(ssid, password);
  Serial.print("Conectando ao WiFi");
  int wifi_attempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifi_attempts < 20) {
    delay(500);
    Serial.print(".");
    wifi_attempts++;
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.printf("WiFi conectado! IP: %s\n", WiFi.localIP().toString().c_str());
    client.setServer(mqtt_server, mqtt_port);
    client.setCallback(callback);
    readGridSensor();
    digitalWrite(STATUS_LED_PIN, gridOnline ? LOW : HIGH); // LED_BUILTIN is inverted (LOW = ON)
  } else {
    Serial.println("Falha na conexão WiFi!");
  }
}

// ======== Main loop ========
void loop() {
  unsigned long currentTime = millis();
  if (!client.connected()) {
    device_status.online = false;
    reconnect();
  }
  client.loop();
  if (currentTime - lastReading >= READING_INTERVAL) {
    readGridSensor();
  }
  if (device_status.grid_ok) {
    sendGridStatus();
  }
  if (currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    if (client.connected()) {
      sendDeviceInfo();
      device_status.rssi = WiFi.RSSI();
      device_status.uptime = currentTime;
    }
    lastHeartbeat = currentTime;
  }
  if (failedReadings > 10) {
    digitalWrite(STATUS_LED_PIN, HIGH); // LED_BUILTIN OFF when too many failures
  }
  delay(100);
}
