/**
  HomeGuard DHT11 Monitor for ESP-01S
  Parametrized version for easy configuration via Arduino IDE or arduino-cli
  
  CONFIGURATION:
  - Set parameters below as #define or const values before uploading.
  - You can use "Tools > Define Symbols" in Arduino IDE or --build-property in arduino-cli for automation.
*/

// ======== User Parameters (Edit these for your device) ========
#define DEVICE_ID        "ESP01_DHT11_MONITOR"   // Unique device ID
#define DEVICE_NAME      "corredor_de_ar"        // Device display name
#define DEVICE_LOCATION  "Área Externa"          // Location name

#define LOCAL_IP_1       192                    // Device local IP
#define LOCAL_IP_2       168
#define LOCAL_IP_3       18
#define LOCAL_IP_4       150

#define GATEWAY_1        192                    // Your network gateway
#define GATEWAY_2        168
#define GATEWAY_3        18
#define GATEWAY_4        1

#define SUBNET_1         255                    // Your network subnet
#define SUBNET_2         255
#define SUBNET_3         255
#define SUBNET_4         0

#define MQTT_SERVER      "192.168.18.236"       // MQTT broker IP
#define MQTT_PORT        1883                   // MQTT broker port
#define MQTT_USER        "homeguard"            // MQTT username
#define MQTT_PASS        "pu2clr123456"         // MQTT password
#define WIFI_SSID        "YOUR_SSID"            // WiFi SSID
#define WIFI_PASS        "YOUR_PASSWORD"        // WiFi password

#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>

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

// ======== DHT11 Hardware Configuration ========
#define DHT_PIN 2         // GPIO2 for DHT11 data pin
#define DHT_TYPE DHT11    // DHT 11
#define STATUS_LED_PIN 0  // GPIO0 for status LED (optional)

DHT dht(DHT_PIN, DHT_TYPE);
WiFiClient espClient;
PubSubClient client(espClient);

// ======== MQTT Topics ========
String TOPIC_TEMPERATURE = String("home/temperature/") + DEVICE_ID_STR + "/data";
String TOPIC_HUMIDITY    = String("home/humidity/") + DEVICE_ID_STR + "/data";
String TOPIC_STATUS      = String("home/sensor/") + DEVICE_ID_STR + "/status";
String TOPIC_INFO        = String("home/sensor/") + DEVICE_ID_STR + "/info";

// ======== Sensor State Variables ========
float temperature = NAN;
float humidity = NAN;
float lastTemperature = NAN;
float lastHumidity = NAN;
unsigned long lastHeartbeat = 0;
unsigned long lastReading = 0;
unsigned long lastDataSend = 0;
int failedReadings = 0;

// Timing intervals
const unsigned long READING_INTERVAL = 120000;   // 2 minutes
const unsigned long HEARTBEAT_INTERVAL = 600000; // 10 minutes
const unsigned long DATA_SEND_INTERVAL = 120000; // 2 minutes
const float TEMP_THRESHOLD = 0.5;
const float HUMID_THRESHOLD = 2.0;

// ======== Device Status ========
struct DeviceStatus {
  bool online;
  bool sensor_ok;
  int rssi;
  unsigned long uptime;
  int failed_readings;
  float last_temp;
  float last_humid;
  unsigned long last_reading_time;
} device_status;

// ======== Read DHT11 sensor ========
void readSensor() {
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();
  if (isnan(temperature) || isnan(humidity)) {
    failedReadings++;
    device_status.sensor_ok = false;
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
    Serial.println("Erro ao ler DHT11!");
  } else {
    failedReadings = 0;
    device_status.sensor_ok = true;
    device_status.last_temp = temperature;
    device_status.last_humid = humidity;
    device_status.last_reading_time = millis();
    digitalWrite(STATUS_LED_PIN, HIGH);
    Serial.printf("Temperatura: %.1f°C, Umidade: %.1f%%\n", temperature, humidity);
  }
  device_status.failed_readings = failedReadings;
  lastReading = millis();
}

// ======== Send sensor data to MQTT ========
void sendSensorData(bool forceUpdate = false) {
  if (!client.connected() || !device_status.sensor_ok) {
    return;
  }
  bool tempChanged = abs(temperature - lastTemperature) >= TEMP_THRESHOLD;
  bool humidChanged = abs(humidity - lastHumidity) >= HUMID_THRESHOLD;
  bool timeToSend = (millis() - lastDataSend) >= DATA_SEND_INTERVAL;
  if (forceUpdate || tempChanged || humidChanged || timeToSend) {
    String tempPayload = "{";
    tempPayload += "\"device_id\":\"" + String(DEVICE_ID_STR) + "\",";
    tempPayload += "\"device_name\":\"" + String(DEVICE_NAME_STR) + "\",";
    tempPayload += "\"location\":\"" + String(DEVICE_LOCATION_STR) + "\",";
    tempPayload += "\"sensor_type\":\"DHT11\",";
    tempPayload += "\"temperature\":" + String(temperature, 1) + ",";
    tempPayload += "\"unit\":\"°C\",";
    tempPayload += "\"rssi\":" + String(WiFi.RSSI()) + ",";
    tempPayload += "\"uptime\":" + String(millis()) + ",";
    tempPayload += "\"timestamp\":\"" + String(millis()) + "\"";
    tempPayload += "}";
    client.publish(TOPIC_TEMPERATURE.c_str(), tempPayload.c_str(), true);
    String humidPayload = "{";
    humidPayload += "\"device_id\":\"" + String(DEVICE_ID_STR) + "\",";
    humidPayload += "\"device_name\":\"" + String(DEVICE_NAME_STR) + "\",";
    humidPayload += "\"location\":\"" + String(DEVICE_LOCATION_STR) + "\",";
    humidPayload += "\"sensor_type\":\"DHT11\",";
    humidPayload += "\"humidity\":" + String(humidity, 1) + ",";
    humidPayload += "\"unit\":\"%\",";
    humidPayload += "\"rssi\":" + String(WiFi.RSSI()) + ",";
    humidPayload += "\"uptime\":" + String(millis()) + ",";
    humidPayload += "\"timestamp\":\"" + String(millis()) + "\"";
    humidPayload += "}";
    client.publish(TOPIC_HUMIDITY.c_str(), humidPayload.c_str(), true);
    lastTemperature = temperature;
    lastHumidity = humidity;
    lastDataSend = millis();
    Serial.printf("Dados enviados via MQTT - Temp: %.1f°C, Humid: %.1f%%\n", temperature, humidity);
  }
}

// ======== Send device status ========
void sendStatus() {
  String status = device_status.sensor_ok ? "online" : "error";
  client.publish(TOPIC_STATUS.c_str(), status.c_str(), true);
}

// ======== Send device information ========
void sendDeviceInfo() {
  String info = "{";
  info += "\"device_id\":\"" + String(DEVICE_ID_STR) + "\",";
  info += "\"device_name\":\"" + String(DEVICE_NAME_STR) + "\",";
  info += "\"location\":\"" + String(DEVICE_LOCATION_STR) + "\",";
  info += "\"sensor_type\":\"DHT11\",";
  info += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  info += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  info += "\"uptime\":" + String(millis()) + ",";
  info += "\"sensor_status\":\"" + String(device_status.sensor_ok ? "ok" : "error") + "\",";
  info += "\"failed_readings\":" + String(device_status.failed_readings) + ",";
  info += "\"last_temperature\":" + String(device_status.last_temp, 1) + ",";
  info += "\"last_humidity\":" + String(device_status.last_humid, 1) + ",";
  info += "\"firmware\":\"HomeGuard_DHT11_v1.0\"";
  info += "}";
  client.publish(TOPIC_INFO.c_str(), info.c_str(), true);
}

// ======== Process MQTT commands ========
void callback(char* topic, byte* payload, unsigned int length) {
  String command;
  for (unsigned int i = 0; i < length; i++) {
    command += (char)payload[i];
  }
  command.trim();
  if (command.equalsIgnoreCase("STATUS")) {
    sendStatus();
    sendDeviceInfo();
  }
  else if (command.equalsIgnoreCase("READ")) {
    readSensor();
    sendSensorData(true);
  }
  else if (command.equalsIgnoreCase("INFO")) {
    sendDeviceInfo();
  }
}

// ======== Reconnect to MQTT ========
void reconnect() {
  int attempts = 0;
  while (!client.connected() && attempts < 3) {
    String clientId = "HomeGuard_" + String(DEVICE_ID_STR);
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      String commandTopic = "home/sensor/" + String(DEVICE_ID_STR) + "/command";
      client.subscribe(commandTopic.c_str());
      sendDeviceInfo();
      sendStatus();
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
  Serial.println("ESP01 DHT11 Monitor iniciando...");
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);
  dht.begin();
  delay(2000);
  device_status.online = false;
  device_status.sensor_ok = false;
  device_status.failed_readings = 0;
  device_status.last_temp = NAN;
  device_status.last_humid = NAN;
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
    readSensor();
    digitalWrite(STATUS_LED_PIN, HIGH);
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
    readSensor();
  }
  if (device_status.sensor_ok) {
    sendSensorData();
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
    digitalWrite(STATUS_LED_PIN, LOW);
  }
  delay(100);
}
