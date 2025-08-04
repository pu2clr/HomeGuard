#include <ESP8266WiFi.h>
#include <PubSubClient.h>

// ======== Wi-Fi Network Configuration ========
const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";

// ESP-01S fixed IP
IPAddress local_IP(192, 168, 18, 101);  // Choose a free IP
IPAddress gateway(192, 168, 18, 1);
IPAddress subnet(255, 255, 255, 0);

// ======== MQTT Broker Configuration ========
const char* mqtt_server = "192.168.18.2"; // Local MQTT broker IP (adjust to yours)
const int   mqtt_port   = 1883;           // Standard MQTT port
const char* mqtt_user   = "";             // Username, if configured (or leave "")
const char* mqtt_pass   = "";             // Password, if configured (or leave "")

// ======== Relay Configuration ========
#define PIN_RELAY 0    // Use 0 (GPIO0) or 2 (GPIO2), depends on your module

WiFiClient espClient;
PubSubClient client(espClient);

const char* TOPIC_CMD = "home/relay1/cmnd";  // Topic for commands
const char* TOPIC_STA = "home/relay1/stat";  // Topic for status

bool relayOn = false;

// ======== Function to process MQTT messages ========
void callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();

  if (msg.equalsIgnoreCase("ON")) {
    digitalWrite(PIN_RELAY, LOW);    // Active LOW on most modules
    relayOn = true;
    client.publish(TOPIC_STA, "ON");
  } else if (msg.equalsIgnoreCase("OFF")) {
    digitalWrite(PIN_RELAY, HIGH);
    relayOn = false;
    client.publish(TOPIC_STA, "OFF");
  }
}

// ======== Reconnect to MQTT if necessary ========
void reconnect() {
  while (!client.connected()) {
    if (client.connect("ESP01S_Relay", mqtt_user, mqtt_pass)) {
      client.subscribe(TOPIC_CMD);
      client.publish(TOPIC_STA, relayOn ? "ON" : "OFF");
    } else {
      delay(3000);
    }
  }
}

void setup() {
  pinMode(PIN_RELAY, OUTPUT);
  digitalWrite(PIN_RELAY, HIGH);  // Relay starts off

  WiFi.config(local_IP, gateway, subnet);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
}
