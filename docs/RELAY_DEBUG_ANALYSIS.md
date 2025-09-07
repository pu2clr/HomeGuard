# ESP8266 Grid Monitor - Relay Control Debug

## Problema Identificado
**Sintoma**: Relé no GPIO5 não está respondendo aos comandos
**Hardware**: ESP8266 com módulo relé conectado ao GPIO5

## Análise do Código Original

### Problemas Encontrados:

1. **Setup() com digitalWrite conflitantes:**
   ```cpp
   digitalWrite(RELAY_PIN, HIGH); // Relé desligado
   delay(1000);
   digitalWrite(RELAY_PIN, LOW);  // Relé desligado  
   delay(1000);
   digitalWrite(RELAY_PIN, HIGH); // Relé desligado
   ```
   **Problema**: Três comandos consecutivos, sendo o último que define o estado inicial

2. **Variáveis não declaradas** (RESOLVIDO):
   - `relayManualOverride` e `relayManualState` já estavam declaradas corretamente

3. **Falta de debug para diagnóstico**

## Correções Implementadas

### 1. Limpeza do Setup()
```cpp
// ANTES - Confuso
digitalWrite(RELAY_PIN, HIGH); 
delay(1000);
digitalWrite(RELAY_PIN, LOW); 
delay(1000);
digitalWrite(RELAY_PIN, HIGH);

// DEPOIS - Claro
digitalWrite(RELAY_PIN, LOW);  // Relé ligado inicialmente
Serial.printf("Relay initialized on GPIO%d: %s\n", RELAY_PIN, "ON (LOW)");
```

### 2. Debug Detalhado Adicionado
```cpp
// Debug no controle automático
Serial.printf("Relay auto mode: Grid %s -> Relay %s (GPIO%d = %s)\n", 
             gridOnline ? "ONLINE" : "OFFLINE", 
             gridOnline ? "OFF" : "ON",
             RELAY_PIN,
             gridOnline ? "LOW" : "HIGH");

// Debug nos comandos MQTT
Serial.printf("MQTT Command ON: GPIO%d set to HIGH\n", RELAY_PIN);
Serial.printf("MQTT Command OFF: GPIO%d set to LOW\n", RELAY_PIN);
```

## Lógica do Relé Esclarecida

### Estados do Sistema:
- **Grid ONLINE**: Relé OFF (GPIO5 = LOW) - Luz normal funcionando
- **Grid OFFLINE**: Relé ON (GPIO5 = HIGH) - Luz de emergência ativada
- **Manual ON**: Relé ON (GPIO5 = HIGH) - Forçado por comando
- **Manual OFF**: Relé OFF (GPIO5 = LOW) - Forçado por comando

### Comandos MQTT:
- `home/grid/{DEVICE_ID}/cmd` com payload "ON" - Liga relé manualmente
- `home/grid/{DEVICE_ID}/cmd` com payload "OFF" - Desliga relé manualmente  
- `home/grid/{DEVICE_ID}/cmd` com payload "AUTO" - Volta ao controle automático

## Passos para Teste

### 1. Verificação Básica:
```bash
# Compilar e carregar o código corrigido
# Observar o Serial Monitor para debug
```

### 2. Teste de Hardware:
```bash
# Usar gpio5_relay_test.ino para verificar se GPIO5 funciona
# Observar se o relé clica ou LED indica mudança de estado
```

### 3. Teste MQTT:
```bash
# Enviar comandos via MQTT
mosquitto_pub -h SEU_BROKER -t "home/grid/ESP8266_GRID_01/cmd" -m "ON"
mosquitto_pub -h SEU_BROKER -t "home/grid/ESP8266_GRID_01/cmd" -m "OFF"
mosquitto_pub -h SEU_BROKER -t "home/grid/ESP8266_GRID_01/cmd" -m "AUTO"
```

## Possíveis Problemas de Hardware

### 1. Módulo Relé:
- **Lógica Invertida**: Alguns módulos são ativados com LOW, outros com HIGH
- **Alimentação**: Verificar se o módulo está recebendo 3.3V ou 5V adequadamente
- **Corrente**: ESP8266 pode não fornecer corrente suficiente

### 2. Conexões:
- **VCC**: Conectado a 3.3V ou 5V conforme especificação do módulo
- **GND**: Conectado ao GND do ESP8266
- **IN/Signal**: Conectado ao GPIO5 (D1 no NodeMCU)

### 3. Multímetro:
- Medir tensão no GPIO5: deve alternar entre 0V e 3.3V
- Verificar se o módulo relé está recebendo o sinal

## Arquivos Criados para Debug:
1. `gpio5_relay_test.ino` - Teste simples do GPIO5
2. `ESP8266_GPIO_NOTES.md` - Informações sobre GPIO do ESP8266
3. Código principal com debug detalhado adicionado

## Próximos Passos:
1. Upload do código corrigido
2. Monitorar Serial para debug
3. Testar com gpio5_relay_test.ino se necessário
4. Verificar conexões físicas do módulo relé
