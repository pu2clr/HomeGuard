/*
  AM/FM/SW SI4735 IoT Receiver via MQTT - ESP8266
  Inspirado no exemplo AM_FM_SERIAL_MONITOR.ino
  Controle remoto via MQTT:
    - /home/radio/frequency : altera frequência (int)
    - /home/radio/band      : altera banda ("AM", "FM", "SW")
    - /home/radio/volume    : altera volume (0-63)

  Preencha as credenciais abaixo antes de compilar!
*/

#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <SI4735.h>

// ======== CONFIGURAÇÕES DE REDE E MQTT ========
#define WIFI_SSID     "SEU_SSID_AQUI"
#define WIFI_PASSWORD "SUA_SENHA_AQUI"
#define MQTT_BROKER   "SEU_BROKER_IP_AQUI" // Exemplo: "192.168.1.100"
#define MQTT_PORT     1883

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
  si4735.setAM(9400, 9990, 9600, 5); // SW: 9400-9990kHz
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

  if (strcmp(topic, "/home/radio/frequency") == 0) {
    uint16_t freq = msg.toInt();
    si4735.setFrequency(freq);
    currentFrequency = freq;
  } else if (strcmp(topic, "/home/radio/band") == 0) {
    setBandByString(msg);
  } else if (strcmp(topic, "/home/radio/volume") == 0) {
    int vol = msg.toInt();
    if (vol >= 0 && vol <= 63) {
      si4735.setVolume(vol);
      currentVolume = vol;
    }
  }
}

void reconnectMQTT() {
  while (!client.connected()) {
    if (client.connect("SI4735Radio")) {
      client.subscribe("/home/radio/frequency");
      client.subscribe("/home/radio/band");
      client.subscribe("/home/radio/volume");
    } else {
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(100);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Conectando WiFi...");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" conectado!");

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
