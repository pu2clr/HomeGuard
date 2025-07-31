#include <ESP8266WiFi.h>
#include <PubSubClient.h>

// ======== Configurações da REDE Wi-Fi ========
const char* ssid = "SEU_SSID";
const char* password = "SUA_SENHA";

// IP fixo do ESP-01S
IPAddress local_IP(192, 168, 18, 101);  // Escolha um IP livre
IPAddress gateway(192, 168, 18, 1);
IPAddress subnet(255, 255, 255, 0);

// ======== Configurações do BROKER MQTT ========
const char* mqtt_server = "192.168.18.2"; // IP do broker MQTT local (ajuste para o seu)
const int   mqtt_port   = 1883;           // Porta padrão MQTT
const char* mqtt_user   = "";             // Usuário, se configurado (ou deixe "")
const char* mqtt_pass   = "";             // Senha, se configurado (ou deixe "")

// ======== Configuração do RELÉ ========
#define PIN_RELE 0    // Use 0 (GPIO0) ou 2 (GPIO2), depende do seu módulo

WiFiClient espClient;
PubSubClient client(espClient);

const char* TOPICO_CMD = "casa/rele1/cmnd";  // Tópico para comandos
const char* TOPICO_STA = "casa/rele1/stat";  // Tópico para status

bool releLigado = false;

// ======== Função para processar mensagens MQTT ========
void callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();

  if (msg.equalsIgnoreCase("ON")) {
    digitalWrite(PIN_RELE, LOW);    // Ativo em LOW na maioria dos módulos
    releLigado = true;
    client.publish(TOPICO_STA, "ON");
  } else if (msg.equalsIgnoreCase("OFF")) {
    digitalWrite(PIN_RELE, HIGH);
    releLigado = false;
    client.publish(TOPICO_STA, "OFF");
  }
}

// ======== Reconectar ao MQTT se necessário ========
void reconnect() {
  while (!client.connected()) {
    if (client.connect("ESP01S_Relay", mqtt_user, mqtt_pass)) {
      client.subscribe(TOPICO_CMD);
      client.publish(TOPICO_STA, releLigado ? "ON" : "OFF");
    } else {
      delay(3000);
    }
  }
}

void setup() {
  pinMode(PIN_RELE, OUTPUT);
  digitalWrite(PIN_RELE, HIGH);  // Relé começa desligado

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
