/**
  HomeGuard Temperature & Humidity Monitor for ESP-01S
  Compatible with Flask Dashboard MQTT System
  
  QUICK CONFIG: Uncomment ONE line below for your ESP01:
  // #define SENSOR_001  // Sala (192.168.18.195)
  // #define SENSOR_002  // Cozinha (192.168.18.196)  
  // #define SENSOR_003  // Quarto (192.168.18.197)
  
  Hardware connections:
  - DHT11 VCC -> 3.3V
  - DHT11 GND -> GND
  - DHT11 DATA -> GPIO2 (PIN 2) with 10kΩ pull-up resistor
  - Status LED -> GPIO0 (PIN 0) [Optional]

  MQTT Broker Setup:
  - Install mosquitto broker: sudo apt install mosquitto mosquitto-clients
  - Password setup: sudo mosquitto_passwd -c /etc/mosquitto/passwd homeguard
  - Config authentication in /etc/mosquitto/mosquitto.conf:
    allow_anonymous false
    password_file /etc/mosquitto/passwd
  - Restart: sudo systemctl restart mosquitto

  Testing Commands:
  - Monitor all topics: mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "#" -v
  - Monitor temperature: mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/temperature/ESP01_DHT11_001/data" -v
  - Monitor humidity: mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/humidity/ESP01_DHT11_001/data" -v

*/

// ======== ESP01 Configuration (CHANGE FOR EACH DEVICE) ========
// Uncomment ONE line below:
// #define SENSOR_001  // Sala
#define SENSOR_002  // Cozinha  
// #define SENSOR_003  // Quarto


#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include "wifi_info.h"  // Please rename the file wifi_infoX.h to wifi_info.h and change the SSID and password


// ======== Device Configuration (Auto-selected based on #define above) ========
#if defined(SENSOR_001)
  const char* DEVICE_ID = "ESP01_DHT11_001";
  const char* DEVICE_NAME = "Monitor Sala";
  const char* DEVICE_LOCATION = "Sala";
  IPAddress local_IP(192, 168, 18, 195);
#elif defined(SENSOR_002)  
  const char* DEVICE_ID = "ESP01_DHT11_002";
  const char* DEVICE_NAME = "Monitor Cozinha";
  const char* DEVICE_LOCATION = "Cozinha";
  IPAddress local_IP(192, 168, 18, 196);
#elif defined(SENSOR_003)
  const char* DEVICE_ID = "ESP01_DHT11_003";
  const char* DEVICE_NAME = "Monitor Quarto";
  const char* DEVICE_LOCATION = "Quarto";
  IPAddress local_IP(192, 168, 18, 197);
#else
  // Default configuration - CHANGE THESE VALUES FOR YOUR SETUP
  const char* DEVICE_ID = "ESP01_DHT11_001";         // Must match sensor config
  const char* DEVICE_NAME = "Monitor Sala";          // Device display name 
  const char* DEVICE_LOCATION = "Sala";              // Location name
  IPAddress local_IP(192, 168, 18, 195);             // ESP01_DHT11_001 -> .195, ESP01_DHT11_002 -> .196, etc
#endif

// ======== Wi-Fi Network Configuration ========
const char* ssid = YOUR_SSID;
const char* password = YOUR_PASSWORD;
// ======== Network Configuration ========
IPAddress gateway(192, 168, 18, 1);
IPAddress subnet(255, 255, 255, 0);

// ======== MQTT Broker Configuration (matches Flask config) ========
const char* mqtt_server = "192.168.18.236"; // Must match MQTT_CONFIG['broker_host']
const int   mqtt_port   = 1883;             // Must match MQTT_CONFIG['broker_port']  
const char* mqtt_user   = "homeguard";      // Must match MQTT_CONFIG['username']
const char* mqtt_pass   = "pu2clr123456";   // Must match MQTT_CONFIG['password']

// ======== DHT11 Hardware Configuration ========
#define DHT_PIN 2         // GPIO2 for DHT11 data pin
#define DHT_TYPE DHT11    // DHT 11
#define STATUS_LED_PIN 0  // GPIO0 for status LED (optional)

DHT dht(DHT_PIN, DHT_TYPE);
WiFiClient espClient;
PubSubClient client(espClient);

// ======== MQTT Topics (matches Flask sensor config) ========
String TOPIC_TEMPERATURE = "home/temperature/" + String(DEVICE_ID) + "/data";
String TOPIC_HUMIDITY = "home/humidity/" + String(DEVICE_ID) + "/data";
String TOPIC_STATUS = "home/sensor/" + String(DEVICE_ID) + "/status";
String TOPIC_INFO = "home/sensor/" + String(DEVICE_ID) + "/info";

// ======== Sensor State Variables ========
float temperature = NAN;
float humidity = NAN;
float lastTemperature = NAN;
float lastHumidity = NAN;
unsigned long lastHeartbeat = 0;
unsigned long lastReading = 0;
unsigned long lastDataSend = 0;
int failedReadings = 0;

// Timing intervals - Otimizado para menor frequência (2 minutos)
const unsigned long READING_INTERVAL = 120000;   // Read sensor every 120 seconds (2 minutos)
const unsigned long HEARTBEAT_INTERVAL = 600000; // Send heartbeat every 10 minutes  
const unsigned long DATA_SEND_INTERVAL = 120000; // Send data every 120 seconds (2 minutos)
const float TEMP_THRESHOLD = 0.5;                // Temperature change threshold (°C)
const float HUMID_THRESHOLD = 2.0;               // Humidity change threshold (%)

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
    
    // Blink LED to indicate error
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
    
    Serial.println("Erro ao ler DHT11!");
  } else {
    failedReadings = 0;
    device_status.sensor_ok = true;
    device_status.last_temp = temperature;
    device_status.last_humid = humidity;
    device_status.last_reading_time = millis();
    
    // Turn on LED to indicate successful reading
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
    // Send temperature data
    String tempPayload = "{";
    tempPayload += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
    tempPayload += "\"device_name\":\"" + String(DEVICE_NAME) + "\",";
    tempPayload += "\"location\":\"" + String(DEVICE_LOCATION) + "\",";
    tempPayload += "\"sensor_type\":\"DHT11\",";
    tempPayload += "\"temperature\":" + String(temperature, 1) + ",";
    tempPayload += "\"unit\":\"°C\",";
    tempPayload += "\"rssi\":" + String(WiFi.RSSI()) + ",";
    tempPayload += "\"uptime\":" + String(millis()) + ",";
    tempPayload += "\"timestamp\":\"" + String(millis()) + "\"";
    tempPayload += "}";
    
    client.publish(TOPIC_TEMPERATURE.c_str(), tempPayload.c_str(), true);
    
    // Send humidity data
    String humidPayload = "{";
    humidPayload += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
    humidPayload += "\"device_name\":\"" + String(DEVICE_NAME) + "\",";
    humidPayload += "\"location\":\"" + String(DEVICE_LOCATION) + "\",";
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
  info += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  info += "\"device_name\":\"" + String(DEVICE_NAME) + "\",";
  info += "\"location\":\"" + String(DEVICE_LOCATION) + "\",";
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
  // Convert payload to string
  String command;
  for (unsigned int i = 0; i < length; i++) {
    command += (char)payload[i];
  }
  command.trim();
  
  // Process commands
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

// ======== Reconnect to MQTT with better error handling ========
void reconnect() {
  int attempts = 0;
  
  while (!client.connected() && attempts < 3) {
    String clientId = "HomeGuard_" + String(DEVICE_ID);
    
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      // Successfully connected
      String commandTopic = "home/sensor/" + String(DEVICE_ID) + "/command";
      client.subscribe(commandTopic.c_str());
      
      // Send initial device info and status
      sendDeviceInfo();
      sendStatus();
      
      // Update device status
      device_status.online = true;
      device_status.rssi = WiFi.RSSI();
      device_status.uptime = millis();
      
      Serial.println("MQTT conectado!");
      break;
    } else {
      attempts++;
      Serial.printf("Falha na conexão MQTT, tentativa %d/3\n", attempts);
      delay(2000 * attempts); // Exponential backoff
    }
  }
}

// ======== Setup function ========
void setup() {
  // Initialize Serial
  Serial.begin(115200);
  Serial.println("ESP01 DHT11 Monitor iniciando...");
  
  // Initialize hardware pins
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);
  
  // Initialize DHT sensor
  dht.begin();
  delay(2000); // DHT11 needs time to stabilize
  
  // Initialize device status
  device_status.online = false;
  device_status.sensor_ok = false;
  device_status.failed_readings = 0;
  device_status.last_temp = NAN;
  device_status.last_humid = NAN;
  device_status.last_reading_time = 0;
  
  // Configure static IP
  WiFi.config(local_IP, gateway, subnet);
  
  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Conectando ao WiFi");
  
  int wifi_attempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifi_attempts < 20) {
    delay(500);
    Serial.print(".");
    wifi_attempts++;
    
    // Blink status LED during connection
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
  }
  
  // Check WiFi connection
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.printf("WiFi conectado! IP: %s\n", WiFi.localIP().toString().c_str());
    
    // Setup MQTT
    client.setServer(mqtt_server, mqtt_port);
    client.setCallback(callback);
    
    // Initial sensor reading
    readSensor();
    
    // Turn on status LED to indicate successful setup
    digitalWrite(STATUS_LED_PIN, HIGH);
  } else {
    Serial.println("Falha na conexão WiFi!");
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
  
  // Read sensor periodically
  if (currentTime - lastReading >= READING_INTERVAL) {
    readSensor();
  }
  
  // Send sensor data
  if (device_status.sensor_ok) {
    sendSensorData();
  }
  
  // Send periodic heartbeat
  if (currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    if (client.connected()) {
      sendDeviceInfo();
      device_status.rssi = WiFi.RSSI();
      device_status.uptime = currentTime;
    }
    lastHeartbeat = currentTime;
  }
  
  // Handle sensor errors (turn off LED if too many failures)
  if (failedReadings > 10) {
    digitalWrite(STATUS_LED_PIN, LOW);
  }
  
  // Small delay to prevent watchdog reset
  delay(100);
}
