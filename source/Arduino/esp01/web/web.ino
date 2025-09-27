#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// Wi-Fi network configuration
const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";

// Set fixed IP and network parameters 
IPAddress local_IP(192, 168, 18, 191);     // <--- Change to desired IP
IPAddress gateway(192, 168, 18, 1);        // Your router/gateway IP
IPAddress subnet(255, 255, 255, 0);
IPAddress primaryDNS(8, 8, 8, 8);          // Optional
IPAddress secondaryDNS(8, 8, 4, 4);        // Optional

#define PIN_RELAY 0 // Relay control pin (Usually GPIO0 on ESP-01S)

ESP8266WebServer server(80);
bool relayOn = false;

// Relay control functions
void turnOnRelay() {
  digitalWrite(PIN_RELAY, LOW); // Relay active LOW on most modules
  relayOn = true;
  server.send(200, "text/plain", "Relay ON");
}
void turnOffRelay() {
  digitalWrite(PIN_RELAY, HIGH); // Deactivate relay
  relayOn = false;
  server.send(200, "text/plain", "Relay OFF");
}
void relayStatus() {
  String msg = "<html><body><h2>Relay Status:</h2>";
  msg += "<p>Relay is: <b>" + String(relayOn ? "ON" : "OFF") + "</b></p>";
  msg += "<a href=\"/on\">Turn On</a> | <a href=\"/off\">Turn Off</a>";
  msg += "</body></html>";
  server.send(200, "text/html", msg);
}

void setup() {
  pinMode(PIN_RELAY, OUTPUT);
  digitalWrite(PIN_RELAY, HIGH); // Relay starts off

  // Configure Wi-Fi with fixed IP
  WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS);
  WiFi.begin(ssid, password);

  // Wait for connection
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }

  // Initialize web server
  server.on("/", relayStatus);
  server.on("/on", turnOnRelay);
  server.on("/off", turnOffRelay);
  server.begin();
}

void loop() {
  server.handleClient();
}
