/*
  Controle do rádio RDA5807 via MQTT
  Exemplos de comandos usando mosquitto:

  Para saber mais sobre o RDA5807, consulte o repositório do github https://github.com/pu2clr/RDA5807
  

  ESP8266 Dev Module Wire up
  | Device name               | RDA5807 Pin          | ESP8266 Dev Module |
  | ------------------------- | -------------------- | ------------------ |
  | RDA5807                   |                      |                    | 
  |                           | VCC                  |      3.3V          |
  |                           | GND                  |      GND           |    
  |                           | SDIO / SDA (pin 2)   |      GPIO4         |
  |                           | SCLK (pin 1)         |      GPIO5         |
  | ------------------------- | -------------------- | ------------------ |



  # Mudar frequência para 103.9 MHz (10390 kHz)
  mosquitto_pub -h <BROKER_IP> -t /home/RDA5807/frequency -m "10390"

  # Mudar volume para 10
  mosquitto_pub -h <BROKER_IP> -t /home/RDA5807/volume -m "10"

  # Você pode usar o mosquitto_sub para monitorar os tópicos
  mosquitto_sub -h <BROKER_IP> -t /home/RDA5807/frequency
  mosquitto_sub -h <BROKER_IP> -t /home/RDA5807/volume

  Tests:

  mosquitto_pub -h 192.168.18.236  -u homeguard  -P pu2clr123456  -t "home/RDA5807/volume" -m "30"
  mosquitto_pub -h 192.168.18.236  -u homeguard  -P pu2clr123456  -t "home/RDA5807/frequency" -m "10390"

  Placa recomendada: ESP32 ou ESP8266
*/

#include <Wire.h>
#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <RDA5807.h>

#define ESP8266_I2C_SDA 4
#define ESP8266_I2C_SCL 5

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

  if (strcmp(topic, "/home/RDA5807/frequency") == 0) {
    int freq = msg.toInt();
    rx.setFrequency(freq); // freq em kHz, ex: 10390 para 103.9 MHz
  }
  if (strcmp(topic, "/home/RDA5807/volume") == 0) {
    int vol = msg.toInt();
    rx.setVolume(vol); // volume de 0 a 15
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
      client.subscribe("/home/RDA5807/frequency");
      client.subscribe("/home/RDA5807/volume");
    } else {
      delay(5000);
    }
  }
}

void setup() {

  Wire.begin(ESP8266_I2C_SDA, ESP8266_I2C_SCL);
  rx.setup();
  rx.setFrequency(9390);
  rx.setVolume(14);

  setup_wifi();
  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) reconnect();
  client.loop();
}
