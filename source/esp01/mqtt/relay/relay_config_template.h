// ============================================
// ESP01 HomeGuard Relay - Configuration Template
// Copy this section for each new ESP01
// ============================================

// ======== CONFIGURAÇÃO PARA CADA ESP01 ========
// 📝 ALTERE ESTAS CONFIGURAÇÕES PARA CADA DISPOSITIVO:

// Device #1 - ESP01_RELAY_001
#if defined(RELAY_001)
  const char* DEVICE_ID = "ESP01_RELAY_001";
  const char* DEVICE_NAME = "Luz da Sala";
  const char* DEVICE_LOCATION = "Sala";
  IPAddress local_IP(192, 168, 18, 192);

// Device #2 - ESP01_RELAY_002  
#elif defined(RELAY_002)
  const char* DEVICE_ID = "ESP01_RELAY_002";
  const char* DEVICE_NAME = "Luz da Cozinha";
  const char* DEVICE_LOCATION = "Cozinha";
  IPAddress local_IP(192, 168, 18, 193);

// Device #3 - ESP01_RELAY_003
#elif defined(RELAY_003)
  const char* DEVICE_ID = "ESP01_RELAY_003";
  const char* DEVICE_NAME = "Bomba d'Água";
  const char* DEVICE_LOCATION = "Externa";
  IPAddress local_IP(192, 168, 18, 194);

// Device #4 - ESP01_RELAY_004
#elif defined(RELAY_004)
  const char* DEVICE_ID = "ESP01_RELAY_004";
  const char* DEVICE_NAME = "Luz do Quarto";
  const char* DEVICE_LOCATION = "Quarto";
  IPAddress local_IP(192, 168, 18, 195);

// Device #5 - ESP01_RELAY_005
#elif defined(RELAY_005)
  const char* DEVICE_ID = "ESP01_RELAY_005";
  const char* DEVICE_NAME = "Ventilador";
  const char* DEVICE_LOCATION = "Sala";
  IPAddress local_IP(192, 168, 18, 196);

// Default - ESP01_RELAY_DEFAULT (for testing)
#else
  const char* DEVICE_ID = "ESP01_RELAY_DEFAULT";
  const char* DEVICE_NAME = "Relé de Teste";
  const char* DEVICE_LOCATION = "Teste";
  IPAddress local_IP(192, 168, 18, 200);
  #warning "Usando configuração padrão - defina RELAY_001, RELAY_002, etc."
#endif

// ============================================
// INSTRUÇÕES DE USO:
// ============================================
// 
// Para compilar para cada ESP01, adicione uma destas linhas
// no início do arquivo .ino (ANTES dos #include):
//
// #define RELAY_001  // Para primeiro ESP01
// #define RELAY_002  // Para segundo ESP01  
// #define RELAY_003  // Para terceiro ESP01
// etc...
//
// Ou configure via Arduino IDE:
// Tools > Board > ESP8266 > Generic ESP8266 Module
// Tools > Build Options > Debug Level > -DRELAY_001
// ============================================

/* 
EXEMPLO DE USO:

1. Para ESP01 #1 (Luz da Sala):
   - Adicione: #define RELAY_001
   - Compile e upload

2. Para ESP01 #2 (Luz da Cozinha):  
   - Mude para: #define RELAY_002
   - Compile e upload

3. Para ESP01 #3 (Bomba d'Água):
   - Mude para: #define RELAY_003
   - Compile e upload

Desta forma cada ESP01 terá configuração única automaticamente!
*/
