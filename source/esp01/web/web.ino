#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// Configuração da rede Wi-Fi
const char* ssid = "SEU_SSID";
const char* password = "SUA_SENHA";

// Defina o IP fixo e os parâmetros da rede
IPAddress local_IP(192, 168, 18, 100);     // <--- Troque para o IP desejado
IPAddress gateway(192, 168, 18, 1);        // IP do seu roteador/gateway
IPAddress subnet(255, 255, 255, 0);
IPAddress primaryDNS(8, 8, 8, 8);          // Opcional
IPAddress secondaryDNS(8, 8, 4, 4);        // Opcional

#define PIN_RELE 0 // Pino de controle do relé (Geralmente GPIO0 no ESP-01S)

ESP8266WebServer server(80);
bool releLigado = false;

// Funções de controle do relé
void ligaRele() {
  digitalWrite(PIN_RELE, LOW); // Relé ativo em LOW na maioria dos módulos
  releLigado = true;
  server.send(200, "text/plain", "Relé LIGADO");
}
void desligaRele() {
  digitalWrite(PIN_RELE, HIGH); // Desativa o relé
  releLigado = false;
  server.send(200, "text/plain", "Relé DESLIGADO");
}
void statusRele() {
  String msg = "<html><body><h2>Status do Relé:</h2>";
  msg += "<p>Relé está: <b>" + String(releLigado ? "LIGADO" : "DESLIGADO") + "</b></p>";
  msg += "<a href=\"/on\">Ligar</a> | <a href=\"/off\">Desligar</a>";
  msg += "</body></html>";
  server.send(200, "text/html", msg);
}

void setup() {
  pinMode(PIN_RELE, OUTPUT);
  digitalWrite(PIN_RELE, HIGH); // Relé começa desligado

  // Configura Wi-Fi com IP fixo
  WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS);
  WiFi.begin(ssid, password);

  // Aguarda conexão
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }

  // Inicializa o servidor web
  server.on("/", statusRele);
  server.on("/on", ligaRele);
  server.on("/off", desligaRele);
  server.begin();
}

void loop() {
  server.handleClient();
}
