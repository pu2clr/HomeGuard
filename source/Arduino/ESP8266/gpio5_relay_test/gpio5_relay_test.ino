/*
 * ESP8266 GPIO5 Relay Test
 * Simple test to verify GPIO5 relay control functionality
 */

#define RELAY_PIN 5  // GPIO5

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("=== ESP8266 GPIO5 Relay Test ===");
  
  pinMode(RELAY_PIN, OUTPUT);
  Serial.printf("GPIO%d configured as OUTPUT\n", RELAY_PIN);
  
  // Initial state
  digitalWrite(RELAY_PIN, LOW);
  Serial.printf("GPIO%d set to LOW (Relay ON for active-low modules)\n", RELAY_PIN);
  delay(2000);
  
  digitalWrite(RELAY_PIN, HIGH);
  Serial.printf("GPIO%d set to HIGH (Relay OFF for active-low modules)\n", RELAY_PIN);
  delay(2000);
}

void loop() {
  Serial.println("Testing relay ON/OFF cycle...");
  
  // Turn relay ON (assuming active-low module)
  digitalWrite(RELAY_PIN, LOW);
  Serial.printf("GPIO%d = LOW (Relay ON)\n", RELAY_PIN);
  delay(3000);
  
  // Turn relay OFF
  digitalWrite(RELAY_PIN, HIGH);
  Serial.printf("GPIO%d = HIGH (Relay OFF)\n", RELAY_PIN);
  delay(3000);
  
  // Test with active-high logic (some relay modules)
  Serial.println("Testing active-high logic...");
  
  digitalWrite(RELAY_PIN, HIGH);
  Serial.printf("GPIO%d = HIGH (Relay ON for active-high modules)\n", RELAY_PIN);
  delay(3000);
  
  digitalWrite(RELAY_PIN, LOW);
  Serial.printf("GPIO%d = LOW (Relay OFF for active-high modules)\n", RELAY_PIN);
  delay(3000);
  
  Serial.println("--- Cycle complete ---");
  delay(2000);
}
