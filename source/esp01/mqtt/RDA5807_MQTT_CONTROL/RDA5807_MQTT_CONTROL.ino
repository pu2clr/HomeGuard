/*
  This sketch is an example of using the ESP01 (IoT Module based on ESP8266) to control an FM receiver 
  based on the RDA5807 DSP using the MQTT protocol. To control the RDA5807, this sketch uses the library 
  developed by me and available on the Arduino platform (available at https://github.com/pu2clr/RDA5807).

  RDA5807 radio control via MQTT

  For more information about the RDA5807, please check the GitHub repository: https://github.com/pu2clr/RDA5807
  

  ESP8266 Dev Module Wire up
  | Device name               | RDA5807 Pin          | ESP8266 Dev Module |
  | ------------------------- | -------------------- | ------------------ |
  | RDA5807                   |                      |                    | 
  |                           | VCC                  |      3.3V          |
  |                           | GND                  |      GND           |    
  |                           | SDIO / SDA (pin 2)   |      GPIO0         |
  |                           | SCLK (pin 1)         |      GPIO2         |
  | ------------------------- | -------------------- | ------------------ |

  #  Examples of commands using mosquitto:

  # Change frequency to 103.9 MHz (10390 kHz)
  mosquitto_pub -h <BROKER_IP> -t home/RDA5807/frequency -m "10390"

  # Change volume to 10
  mosquitto_pub -h <BROKER_IP> -t home/RDA5807/volume -m "10"

  # You can use mosquitto_sub to monitor the topics
  mosquitto_sub -h <BROKER_IP> -t home/RDA5807/frequency
  mosquitto_sub -h <BROKER_IP> -t home/RDA5807/volume

  Tests:

  mosquitto_pub -h 192.168.18.236  -u homeguard  -P pu2clr123456  -t "home/RDA5807/volume" -m "10"
  mosquitto_pub -h 192.168.18.236  -u homeguard  -P pu2clr123456  -t "home/RDA5807/frequency" -m "10390"

  Recommended board: ESP32 or ESP8266

  Author: Ricardo Lima Caratti.

*/


#include <Wire.h>
#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <RDA5807.h>

#define ESP01_I2C_SDA 0     // GPIO0
#define ESP01_I2C_SCL 2     // GPIO2 

const char* ssid = "APRC";
const char* password = "Ap69Rc642023";
const char* mqtt_server = "192.168.18.236";
const char* mqtt_user = "homeguard";
const char* mqtt_pass = "pu2clr123456";

WiFiClient espClient;
PubSubClient client(espClient);
RDA5807 rx;

void callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];

  if (strcmp(topic, "home/RDA5807/frequency") == 0) {
    int freq = msg.toInt();
    rx.setFrequency(freq); // freq em kHz, ex: 10390 para 103.9 MHz
  }
  if (strcmp(topic, "home/RDA5807/volume") == 0) {
    int vol = msg.toInt();
    rx.setVolume(vol); // volume de 0 a 15
    if (vol == 0) {
      rx.setMute(true);
      client.publish("home/RDA5807/status", "Muted");
    } else {
      rx.setMute(false);
      client.publish("home/RDA5807/status", "Unmuted");
    }
  }
}

void setup_wifi() {

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
 
}

void reconnect() {
  while (!client.connected()) {
    if (client.connect("RDA5807Client", mqtt_user, mqtt_pass)) {
      client.subscribe("home/RDA5807/frequency");
      client.subscribe("home/RDA5807/volume");
    } else {
      delay(5000);
    }
  }
}

void setup() {

  Wire.begin(ESP01_I2C_SDA, ESP01_I2C_SCL);
  rx.setup();
  delay(300);

  setup_wifi();
  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);

  rx.setFrequency(10390);
  delay(100);
  rx.setVolume(9);
}

void loop() {
  if (!client.connected()) reconnect();
  client.loop();
}
