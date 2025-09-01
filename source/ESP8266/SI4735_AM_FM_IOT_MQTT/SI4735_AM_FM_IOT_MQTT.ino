/*
  This sketch is an example of using the ESP01 (IoT Module based on ESP8266) to control 
  an AM/SW/FM receiver based on the SI4735 DSP using the MQTT protocol. 
  To control the SI4735, this sketch uses the library developed by me and available on the 
  Arduino platform (available at https://github.com/pu2clr/SI4735).


  AM/FM/SW SI4735 IoT Receiver via MQTT - ESP8266


  ESP8266/ESP12F and SI4735-D60 or SI4732-A10 wire up

  | Si4735  | SI4732   | DESC.  | ESP8266  (GPIO)    |
  |---------| -------- |--------|--------------------|
  | pin 15  |  pin 9   | RESET  |   2 (GPIO2)        |
  | pin 18  |  pin 12  | SDIO   |   4 (SDA / GPIO4)  |
  | pin 17  |  pin 11  | SCLK   |   5 (SCL / GPIO5)  |

  
  Inspired by the AM_FM_SERIAL_MONITOR.ino example  
  Remote control via MQTT:
    - home/radio/frequency : change frequency (int)
    - home/radio/band      : change band ("AM", "FM", "SW")
    - home/radio/volume    : change volume (0-63)

  Examples of usage with mosquitto:
  # Change frequency to 10390 (FM 103.9 MHz):

  mosquitto_pub -h 192.168.18.198 -p 1883 -u homeguard -P pu2clr123456 -t "home/radio/band" -m "FM"
  mosquitto_pub -h 192.168.18.198 -p 1883 -u homeguard -P pu2clr123456 -t "home/radio/frequency" -m "10390"


  # Change band to AM:
  mosquitto_pub -h 192.168.18.198 -p 1883 -u homeguard -P pu2clr123456 -t "home/radio/band" -m "AM"

  # Change band to FM:
  mosquitto_pub -h 192.168.18.198 -p 1883 -u homeguard -P pu2clr123456 -t "home/radio/band" -m "FM"

  # Change band to SW:
  mosquitto_pub -h 192.168.18.198 -p 1883 -u homeguard -P pu2clr123456 -t "home/radio/band" -m "SW"

  # Change volume to 30:
  mosquitto_pub -h 192.168.18.198 -p 1883 -u homeguard -P pu2clr123456 -t "home/radio/volume" -m "30"

  # Monitor received commands (debug):
  mosquitto_sub -h 192.168.18.198 -p 1883 -u homeguard -P pu2clr123456 -t "home/radio/#" -v

  Fill in the credentials below before compiling!

  Ricardo Caratti <rcaratti@pu2clr.com>
*/


#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <SI4735.h>

// ======== CONFIGURAÇÕES DE REDE E MQTT ========
// Adicione usuário e senha do broker
#define WIFI_SSID     "APRC"
#define WIFI_PASSWORD "Ap69Rc642023"
#define MQTT_BROKER   "192.168.18.198" 
#define MQTT_PORT     1883
#define MQTT_USER     "homeguard"
#define MQTT_PASS     "pu2clr123456"

// ======== PINOS E DEFINIÇÕES DO SI4735 ========
#define RESET_PIN 2           // (GPIO02)
#define ESP8266_I2C_SDA 4     // (GPIO04)
#define ESP8266_I2C_SCL 5     // (GPIO05)

SI4735 si4735;
WiFiClient espClient;
PubSubClient client(espClient);

// Estado atual
uint16_t currentFrequency = 10390; // FM default
uint8_t currentVolume = 45;
uint8_t currentBand = 0; // 0=FM, 1=AM, 2=SW

void setupSI4735FM() {
  si4735.setFM(8400, 10800, currentFrequency, 10); // FM: 84-108MHz
  currentBand = 0;
}
void setupSI4735AM() {
  si4735.setAM(570, 1710, 810, 10); // AM: 570-1710kHz
  currentBand = 1;
}
void setupSI4735SW() {
  si4735.setAM(5900, 22900, 11780, 5); // SW: 5900-22900kHz
  currentBand = 2;
}

void setBandByString(const String& band) {
  if (band.equalsIgnoreCase("FM")) {
    setupSI4735FM();
  } else if (band.equalsIgnoreCase("AM")) {
    setupSI4735AM();
  } else if (band.equalsIgnoreCase("SW")) {
    setupSI4735SW();
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];

  if (strcmp(topic, "home/radio/frequency") == 0) {
    uint16_t freq = msg.toInt();
    si4735.setFrequency(freq);
    currentFrequency = freq;
  } else if (strcmp(topic, "home/radio/band") == 0) {
    setBandByString(msg);
  } else if (strcmp(topic, "home/radio/volume") == 0) {
    int vol = msg.toInt();
    if (vol >= 0 && vol <= 63) {
      si4735.setVolume(vol);
      currentVolume = vol;
    }
  }
}

void reconnectMQTT() {
  while (!client.connected()) {
    if (client.connect("SI4735Radio", MQTT_USER, MQTT_PASS)) {
      client.subscribe("home/radio/frequency");
      client.subscribe("home/radio/band");
      client.subscribe("home/radio/volume");
    } else {
      delay(2000);
    }
  }
}

void setup() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }

  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(mqttCallback);

  Wire.begin(ESP8266_I2C_SDA, ESP8266_I2C_SCL);
  int si4735Addr = si4735.getDeviceI2CAddress(RESET_PIN);
  si4735.setup(RESET_PIN, 0); // FM por padrão
  delay(300);
  setupSI4735FM();
  si4735.setVolume(currentVolume);
}

void loop() {
  if (!client.connected()) reconnectMQTT();
  client.loop();
}

// Fim do sketch
