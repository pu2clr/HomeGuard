/**
 * HomeGuard DHT11 - Arquivo de Configuração
 * Copie estas configurações para o sketch principal conforme sua necessidade
 */

// ======== CONFIGURAÇÕES DE DISPOSITIVO ========
// Descomente APENAS UMA linha abaixo:

// Para Sensor da Sala:
#define SENSOR_001  // Monitor Sala (IP: 192.168.18.195)
/*
const char* DEVICE_ID = "ESP01_DHT11_001";
const char* DEVICE_NAME = "Monitor Sala";
const char* DEVICE_LOCATION = "Sala";
IPAddress local_IP(192, 168, 18, 195);
*/

// Para Sensor da Cozinha:
// #define SENSOR_002  // Monitor Cozinha (IP: 192.168.18.196)
/*
const char* DEVICE_ID = "ESP01_DHT11_002";
const char* DEVICE_NAME = "Monitor Cozinha";
const char* DEVICE_LOCATION = "Cozinha";
IPAddress local_IP(192, 168, 18, 196);
*/

// Para Sensor do Quarto:
// #define SENSOR_003  // Monitor Quarto (IP: 192.168.18.197)
/*
const char* DEVICE_ID = "ESP01_DHT11_003";
const char* DEVICE_NAME = "Monitor Quarto";
const char* DEVICE_LOCATION = "Quarto";
IPAddress local_IP(192, 168, 18, 197);
*/

// ======== CONFIGURAÇÕES DE REDE ========
const char* ssid = "YOUR_SSID";                    // Nome da rede WiFi
const char* password = "YOUR_PASSWORD";        // Senha da rede WiFi
IPAddress gateway(192, 168, 18, 1);           // Gateway padrão
IPAddress subnet(255, 255, 255, 0);           // Máscara de rede

// ======== CONFIGURAÇÕES MQTT ========
const char* mqtt_server = "192.168.18.236";   // IP do broker MQTT (Raspberry Pi)
const int   mqtt_port   = 1883;               // Porta do broker MQTT
const char* mqtt_user   = "homeguard";        // Usuário MQTT
const char* mqtt_pass   = "pu2clr123456";     // Senha MQTT

// ======== CONFIGURAÇÕES DO SENSOR ========
#define DHT_PIN 2                              // GPIO2 para dados do DHT11
#define DHT_TYPE DHT11                         // Tipo do sensor (DHT11)
#define STATUS_LED_PIN 0                       // GPIO0 para LED de status

// ======== INTERVALOS DE TEMPO ========
const unsigned long READING_INTERVAL = 5000;     // Ler sensor a cada 5 segundos
const unsigned long HEARTBEAT_INTERVAL = 30000;  // Heartbeat a cada 30 segundos  
const unsigned long DATA_SEND_INTERVAL = 60000;  // Enviar dados a cada 60 segundos

// ======== THRESHOLDS DE MUDANÇA ========
const float TEMP_THRESHOLD = 0.5;                // Mudança de temperatura (°C)
const float HUMID_THRESHOLD = 2.0;               // Mudança de umidade (%)

// ======== TÓPICOS MQTT (AUTO-GERADOS) ========
/*
Os tópicos são gerados automaticamente baseados no DEVICE_ID:

Dados publicados:
- home/sensor/ESP01_DHT11_001/data         (dados combinados de temperatura E umidade)
- home/sensor/ESP01_DHT11_001/status       (status do sensor)
- home/sensor/ESP01_DHT11_001/info         (informações do dispositivo)

Comandos aceitos:
- home/sensor/ESP01_DHT11_001/command      (comandos: STATUS, READ, INFO)
*/

// ======== COMANDOS DE TESTE ========
/*
// Monitorar todos os dados do sensor:
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/sensor/ESP01_DHT11_001/+" -v

// Monitorar apenas dados do sensor (temperatura + umidade):
mosquitto_sub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/sensor/ESP01_DHT11_001/data" -v

// Solicitar leitura imediata:
mosquitto_pub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/sensor/ESP01_DHT11_001/command" -m "READ"

// Solicitar status:
mosquitto_pub -h 192.168.18.236 -u homeguard -P pu2clr123456 -t "home/sensor/ESP01_DHT11_001/command" -m "STATUS"
*/
