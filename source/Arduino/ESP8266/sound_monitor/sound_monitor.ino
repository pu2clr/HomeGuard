/*
  ESP8266 Sound Monitor + Relay Control via MQTT
  Detecta sons acima de um limiar (SOUND_THRESHOLD) e aciona relé.
  Permite controle do relé e ajuste do limiar via comandos MQTT.

  Hardware:
  - Microfone analógico (KY-038, KY-037, etc)
  - VCC -> 3.3V
  - GND -> GND
  - OUT (analógico) -> A0 (ESP8266)
  - Relé -> GPIO0 (D0)

  MQTT Topics:
  - home/sound_monitor/threshold   (ajusta SOUND_THRESHOLD)
  - home/sound_monitor/relay       (comando ON/OFF/AUTO)
  - home/sound_monitor/sound       (publica evento de som detectado)
  - home/sound_monitor/status      (status do relé)

  Exemplo de comandos mosquitto:
  # Ajustar limiar para 700
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/sound_monitor/threshold" -m "700"

  # Ligar relé
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/sound_monitor/relay" -m "ON"

  # Desligar relé
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/sound_monitor/relay" -m "OFF"

  # Modo automático (aciona relé por som)
  mosquitto_pub -h 192.168.1.102 -u homeguard -P pu2clr123456 -t "home/sound_monitor/relay" -m "AUTO"
*/

#include <ESP8266WiFi.h>
#include <PubSubClient.h>

#define WIFI_SSID     "Homeguard"
#define WIFI_PASSWORD "pu2clr123456"
#define MQTT_BROKER   "192.168.1.102"
#define MQTT_PORT     1883
#define MQTT_USER     "homeguard"
#define MQTT_PASS     "pu2clr123456"

#define MIC_PIN       A0
#define RELAY_PIN     0   // GPIO0 (D0)

int SOUND_THRESHOLD = 600; // valor inicial, pode ser ajustado via MQTT
bool relayAutoMode = true;
bool relayState = false;

WiFiClient espClient;
PubSubClient client(espClient);

void setRelay(bool state) {
  relayState = state;
  digitalWrite(RELAY_PIN, state ? HIGH : LOW);
  client.publish("home/sound_monitor/status", state ? "ON" : "OFF", true);
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  msg.trim();
  if (String(topic) == "home/sound_monitor/threshold") {
    int val = msg.toInt();
    if (val > 0 && val < 1024) {
      SOUND_THRESHOLD = val;
      client.publish("home/sound_monitor/threshold", msg.c_str(), true);
    }
  } else if (String(topic) == "home/sound_monitor/relay") {
    if (msg.equalsIgnoreCase("ON")) {
      relayAutoMode = false;
      setRelay(true);
    } else if (msg.equalsIgnoreCase("OFF")) {
      relayAutoMode = false;
      setRelay(false);
    } else if (msg.equalsIgnoreCase("AUTO")) {
      relayAutoMode = true;
    }
  }
}

void reconnectMQTT() {
  while (!client.connected()) {
    if (client.connect("SoundMonitor", MQTT_USER, MQTT_PASS)) {
      client.subscribe("home/sound_monitor/threshold");
      client.subscribe("home/sound_monitor/relay");
    } else {
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(MIC_PIN, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  setRelay(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(mqttCallback);
}

void loop() {
  if (!client.connected()) reconnectMQTT();
  client.loop();
  int soundLevel = analogRead(MIC_PIN);
  if (relayAutoMode && soundLevel > SOUND_THRESHOLD) {
    setRelay(true);
    client.publish("home/sound_monitor/sound", String(soundLevel).c_str(), true);
    delay(500); // Evita múltiplos disparos
  } else if (relayAutoMode && soundLevel <= SOUND_THRESHOLD) {
    setRelay(false);
  }
  delay(100);
}
