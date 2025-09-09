/*
 * HomeGuard Motion Sensor Template - TLS Enabled
 * Sensor de movimento PIR com suporte a conexões MQTT seguras
 * 
 * Características:
 * - Conexão WiFi automática
 * - MQTT com TLS/SSL encryption
 * - Certificados de segurança
 * - Heartbeat automático
 * - Configuração por build defines
 * 
 * Compilação:
 * arduino-cli compile --fqbn esp8266:esp8266:generic \
 *   --build-property "compiler.cpp.extra_flags=-DDEVICE_LOCATION=\"Garagem\" -DDEVICE_IP_LAST_OCTET=101 -DMQTT_TOPIC_SUFFIX=\"garagem\"" \
 *   --output-dir build/Garagem_motion_sensor_secure motion_detector_template_secure
 * 
 * Build defines obrigatórios:
 * -DDEVICE_LOCATION="Nome da localização"
 * -DDEVICE_IP_LAST_OCTET=xxx (último octeto do IP)
 * -DMQTT_TOPIC_SUFFIX="sufixo" (para tópicos MQTT)
 * 
 * Build defines opcionais:
 * -DMQTT_SECURE=1 (habilita TLS, padrão: 0)
 * -DMQTT_PORT=8883 (porta MQTT segura, padrão: 1883)
 * -DDEBUG_SERIAL=1 (habilita debug, padrão: 0)
 * 
 * Autor: HomeGuard Project
 * Versão: 2.0 (TLS Support)
 */

#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// ========================================
// Build-time Configuration Validation
// ========================================

#ifndef DEVICE_LOCATION
#error "DEVICE_LOCATION deve ser definido no build (ex: -DDEVICE_LOCATION=\"Garagem\")"
#endif

#ifndef DEVICE_IP_LAST_OCTET
#error "DEVICE_IP_LAST_OCTET deve ser definido no build (ex: -DDEVICE_IP_LAST_OCTET=101)"
#endif

#ifndef MQTT_TOPIC_SUFFIX
#error "MQTT_TOPIC_SUFFIX deve ser definido no build (ex: -DMQTT_TOPIC_SUFFIX=\"garagem\")"
#endif

// ========================================
// Configuration with Defaults
// ========================================

// Network Configuration
const char* WIFI_SSID = "Claro_2G1BC80B";
const char* WIFI_PASSWORD = "8C1BC80B";

// Static IP Configuration
IPAddress local_IP(192, 168, 18, DEVICE_IP_LAST_OCTET);
IPAddress gateway(192, 168, 18, 1);
IPAddress subnet(255, 255, 255, 0);
IPAddress primaryDNS(8, 8, 8, 8);
IPAddress secondaryDNS(8, 8, 4, 4);

// MQTT Configuration
const char* MQTT_BROKER = "192.168.1.102";
const char* MQTT_USERNAME = "homeguard";
const char* MQTT_PASSWORD = "pu2clr123456";

// Build-time MQTT Configuration
#ifndef MQTT_SECURE
#define MQTT_SECURE 0  // Default: sem TLS
#endif

#ifndef MQTT_PORT
#if MQTT_SECURE
#define MQTT_PORT 8883  // Porta segura
#else
#define MQTT_PORT 1883  // Porta padrão
#endif
#endif

#ifndef DEBUG_SERIAL
#define DEBUG_SERIAL 0  // Default: sem debug
#endif

// Device Configuration
const char* DEVICE_ID = "MOTION_" DEVICE_LOCATION "_001";

// MQTT Topics (usando o sufixo definido no build)
const char* TOPIC_STATUS = "home/motion_" MQTT_TOPIC_SUFFIX "/status";
const char* TOPIC_MOTION = "home/motion_" MQTT_TOPIC_SUFFIX "/motion";
const char* TOPIC_HEARTBEAT = "home/motion_" MQTT_TOPIC_SUFFIX "/heartbeat";
const char* TOPIC_COMMAND = "home/motion_" MQTT_TOPIC_SUFFIX "/cmnd";
const char* TOPIC_CONFIG = "home/motion_" MQTT_TOPIC_SUFFIX "/config";

// Hardware Configuration
const int PIR_PIN = 2;        // GPIO2 (D4 no NodeMCU)
const int LED_PIN = LED_BUILTIN;
const int BUTTON_PIN = 0;     // GPIO0 (FLASH button)

// Timing Configuration
const unsigned long HEARTBEAT_INTERVAL = 30000;    // 30 segundos
const unsigned long MOTION_TIMEOUT = 5000;         // 5 segundos
const unsigned long WIFI_TIMEOUT = 30000;          // 30 segundos
const unsigned long MQTT_TIMEOUT = 10000;          // 10 segundos

// ========================================
// TLS Certificates (incluir certificados aqui)
// ========================================

#if MQTT_SECURE

// Certificado CA (substituir pelo seu certificado)
const char* ca_cert = R"EOF(
-----BEGIN CERTIFICATE-----
[INSERIR CERTIFICADO CA AQUI]
-----END CERTIFICATE-----
)EOF";

// Certificado do cliente (opcional - para autenticação mútua)
const char* client_cert = R"EOF(
-----BEGIN CERTIFICATE-----
[INSERIR CERTIFICADO CLIENTE AQUI]
-----END CERTIFICATE-----
)EOF";

// Chave privada do cliente (opcional - para autenticação mútua)
const char* client_key = R"EOF(
-----BEGIN PRIVATE KEY-----
[INSERIR CHAVE PRIVADA CLIENTE AQUI]
-----END PRIVATE KEY-----
)EOF";

#endif

// ========================================
// Global Variables
// ========================================

// Network clients
#if MQTT_SECURE
WiFiClientSecure secureClient;
PubSubClient mqtt(secureClient);
#else
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);
#endif

// State variables
bool motionDetected = false;
bool motionState = false;
unsigned long lastMotionTime = 0;
unsigned long lastHeartbeat = 0;
unsigned long motionStartTime = 0;
unsigned long bootTime = 0;
int motionCount = 0;

// Network status
bool wifiConnected = false;
bool mqttConnected = false;

// ========================================
// Debug Functions
// ========================================

void debugPrint(const String& message) {
#if DEBUG_SERIAL
  Serial.print("[");
  Serial.print(millis());
  Serial.print("] ");
  Serial.println(message);
#endif
}

void debugPrintln(const String& message) {
#if DEBUG_SERIAL
  Serial.println(message);
#endif
}

// ========================================
// WiFi Functions
// ========================================

void setupWiFi() {
  debugPrint("Configurando WiFi...");
  
  // Configurar IP estático
  if (!WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS)) {
    debugPrint("Erro ao configurar IP estático");
  }
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  unsigned long startTime = millis();
  
  while (WiFi.status() != WL_CONNECTED && (millis() - startTime) < WIFI_TIMEOUT) {
    delay(500);
    digitalWrite(LED_PIN, !digitalRead(LED_PIN)); // Piscar LED
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    digitalWrite(LED_PIN, LOW); // LED ligado = conectado
    
    debugPrint("WiFi conectado!");
    debugPrint("IP: " + WiFi.localIP().toString());
    debugPrint("RSSI: " + String(WiFi.RSSI()) + " dBm");
  } else {
    wifiConnected = false;
    digitalWrite(LED_PIN, HIGH); // LED desligado = erro
    debugPrint("Falha na conexão WiFi");
  }
}

void checkWiFi() {
  if (WiFi.status() != WL_CONNECTED) {
    if (wifiConnected) {
      debugPrint("WiFi desconectado! Tentando reconectar...");
      wifiConnected = false;
      setupWiFi();
    }
  } else {
    wifiConnected = true;
  }
}

// ========================================
// MQTT Functions
// ========================================

void setupMQTT() {
  debugPrint("Configurando MQTT...");
  
#if MQTT_SECURE
  // Configurar certificados SSL
  secureClient.setCACert(ca_cert);
  
  // Configurar certificado cliente (se disponível)
  if (strlen(client_cert) > 10 && strlen(client_key) > 10) {
    secureClient.setCertificate(client_cert);
    secureClient.setPrivateKey(client_key);
    debugPrint("Certificado cliente configurado");
  }
  
  // Configurar validação de certificado
  secureClient.setInsecure(); // Para desenvolvimento - remover em produção
  
  debugPrint("TLS habilitado - conectando na porta " + String(MQTT_PORT));
#endif
  
  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setKeepAlive(60);
  mqtt.setSocketTimeout(15);
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  debugPrint("MQTT recebido [" + String(topic) + "]: " + message);
  
  // Processar comandos
  if (String(topic) == TOPIC_COMMAND) {
    if (message == "STATUS") {
      publishStatus();
    } else if (message == "RESET") {
      debugPrint("Reset solicitado via MQTT");
      ESP.restart();
    }
  }
}

bool connectMQTT() {
  if (!wifiConnected) return false;
  
  if (!mqtt.connected()) {
    debugPrint("Conectando ao broker MQTT...");
    
    // Criar cliente ID único
    String clientId = DEVICE_ID + String("_") + String(ESP.getChipId(), HEX);
    
    // Last Will Testament
    String lwt = "{\"device_id\":\"" + String(DEVICE_ID) + "\",\"status\":\"OFFLINE\",\"timestamp\":" + String(millis()) + "}";
    
    if (mqtt.connect(clientId.c_str(), MQTT_USERNAME, MQTT_PASSWORD, 
                     TOPIC_STATUS, 1, true, lwt.c_str())) {
      mqttConnected = true;
      debugPrint("MQTT conectado como " + clientId);
      
      // Subscrever tópico de comandos
      mqtt.subscribe(TOPIC_COMMAND);
      
      // Publicar status online
      publishOnlineStatus();
      publishStatus();
      
      return true;
    } else {
      mqttConnected = false;
      debugPrint("Falha MQTT, rc=" + String(mqtt.state()));
      
#if MQTT_SECURE && DEBUG_SERIAL
      // Debug adicional para TLS
      if (mqtt.state() == -2) {
        debugPrint("Erro TLS - verifique certificados");
      }
#endif
      return false;
    }
  }
  return true;
}

void checkMQTT() {
  if (wifiConnected && !mqtt.connected()) {
    if (mqttConnected) {
      debugPrint("MQTT desconectado! Tentando reconectar...");
      mqttConnected = false;
    }
    connectMQTT();
  }
  
  if (mqtt.connected()) {
    mqtt.loop();
  }
}

// ========================================
// MQTT Publishing Functions
// ========================================

void publishOnlineStatus() {
  if (!mqtt.connected()) return;
  
  mqtt.publish(TOPIC_STATUS, "ONLINE", true);
  debugPrint("Status ONLINE publicado");
}

void publishStatus() {
  if (!mqtt.connected()) return;
  
  StaticJsonDocument<512> doc;
  doc["device_id"] = DEVICE_ID;
  doc["location"] = DEVICE_LOCATION;
  doc["ip"] = WiFi.localIP().toString();
  doc["mac"] = WiFi.macAddress();
  doc["rssi"] = WiFi.RSSI();
  doc["uptime"] = millis() - bootTime;
  doc["motion"] = motionState ? "DETECTED" : "CLEAR";
  doc["motion_count"] = motionCount;
  doc["last_motion"] = lastMotionTime;
  doc["free_heap"] = ESP.getFreeHeap();
  doc["timestamp"] = millis();
  doc["secure"] = MQTT_SECURE;
  
  String statusJson;
  serializeJson(doc, statusJson);
  
  mqtt.publish(TOPIC_STATUS, statusJson.c_str());
  debugPrint("Status completo publicado");
}

void publishMotionEvent(bool detected) {
  if (!mqtt.connected()) return;
  
  StaticJsonDocument<384> doc;
  doc["device_id"] = DEVICE_ID;
  doc["location"] = DEVICE_LOCATION;
  doc["event"] = detected ? "MOTION_DETECTED" : "MOTION_CLEARED";
  doc["timestamp"] = millis();
  doc["rssi"] = WiFi.RSSI();
  doc["count"] = motionCount;
  
  if (!detected && motionStartTime > 0) {
    doc["duration"] = millis() - motionStartTime;
  }
  
  String motionJson;
  serializeJson(doc, motionJson);
  
  mqtt.publish(TOPIC_MOTION, motionJson.c_str());
  
  String eventMsg = detected ? "MOTION DETECTED" : "MOTION CLEARED";
  debugPrint(eventMsg + " em " + String(DEVICE_LOCATION));
}

void publishHeartbeat() {
  if (!mqtt.connected()) return;
  
  StaticJsonDocument<256> doc;
  doc["device_id"] = DEVICE_ID;
  doc["location"] = DEVICE_LOCATION;
  doc["timestamp"] = millis();
  doc["uptime"] = millis() - bootTime;
  doc["rssi"] = WiFi.RSSI();
  doc["free_heap"] = ESP.getFreeHeap();
  doc["status"] = "OK";
  doc["secure"] = MQTT_SECURE;
  
  String heartbeatJson;
  serializeJson(doc, heartbeatJson);
  
  mqtt.publish(TOPIC_HEARTBEAT, heartbeatJson.c_str());
  
  lastHeartbeat = millis();
  debugPrint("Heartbeat enviado");
}

// ========================================
// Motion Detection Functions
// ========================================

void checkMotion() {
  bool currentMotion = digitalRead(PIR_PIN) == HIGH;
  
  if (currentMotion && !motionDetected) {
    // Movimento detectado
    motionDetected = true;
    motionState = true;
    motionStartTime = millis();
    motionCount++;
    
    publishMotionEvent(true);
    digitalWrite(LED_PIN, HIGH); // LED desligado quando movimento detectado
    
  } else if (!currentMotion && motionDetected) {
    // Movimento pode ter parado - aguardar timeout
    if (millis() - motionStartTime >= MOTION_TIMEOUT) {
      motionDetected = false;
      motionState = false;
      lastMotionTime = millis();
      
      publishMotionEvent(false);
      digitalWrite(LED_PIN, LOW); // LED ligado quando movimento para
    }
  }
}

// ========================================
// Setup Function
// ========================================

void setup() {
#if DEBUG_SERIAL
  Serial.begin(115200);
  delay(100);
  Serial.println();
  Serial.println("========================================");
  Serial.println("HomeGuard Motion Sensor - TLS Enabled");
  Serial.println("Device: " + String(DEVICE_LOCATION));
  Serial.println("ID: " + String(DEVICE_ID));
  Serial.println("Secure: " + String(MQTT_SECURE ? "YES" : "NO"));
  Serial.println("Port: " + String(MQTT_PORT));
  Serial.println("========================================");
#endif
  
  bootTime = millis();
  
  // Configurar pinos
  pinMode(PIR_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  digitalWrite(LED_PIN, HIGH); // LED desligado inicialmente
  
  // Aguardar estabilização do sensor PIR
  debugPrint("Aguardando estabilização do sensor PIR...");
  for (int i = 30; i > 0; i--) {
    debugPrint("Aguardando " + String(i) + " segundos...");
    delay(1000);
    digitalWrite(LED_PIN, !digitalRead(LED_PIN)); // Piscar durante inicialização
  }
  
  // Configurar rede
  setupWiFi();
  setupMQTT();
  
  // Conectar MQTT
  if (wifiConnected) {
    connectMQTT();
  }
  
  debugPrint("Setup concluído!");
  debugPrint("Monitorando movimento em: " + String(DEVICE_LOCATION));
}

// ========================================
// Main Loop
// ========================================

void loop() {
  // Verificar conectividade
  checkWiFi();
  checkMQTT();
  
  // Verificar movimento
  checkMotion();
  
  // Heartbeat periódico
  if (millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    publishHeartbeat();
  }
  
  // Botão para status manual
  if (digitalRead(BUTTON_PIN) == LOW) {
    delay(50); // Debounce
    if (digitalRead(BUTTON_PIN) == LOW) {
      publishStatus();
      while (digitalRead(BUTTON_PIN) == LOW) {
        delay(10);
      }
    }
  }
  
  delay(100); // Pequeno delay para estabilidade
}
