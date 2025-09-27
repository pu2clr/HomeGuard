# Diagrama de Conexões - ESP-01S + DHT11

```
        DHT11 Sensor                    ESP-01S (Vista de cima)
    ┌─────────────────┐               
    │  [1] [2] [3] [4]│                   [ANT]
    │   │   │   │   │ │               ┌─────────┐
    └───┼───┼───┼───┼─┘               │  •   •  │ VCC  3.3V
        │   │   │   │                 │ RST  0  │ GPIO0 (LED Status)
        │   │   │   │                 │  2   •  │ GPIO2 (DHT11 DATA) 
        │   │   │   │                 │ GND  •  │ GND
        │   │   │   └─ VCC (3.3V)     └─────────┘
        │   │   │
        │   │   └───── DATA ──┐
        │   │               │
        │   └─────────── NC  │        Resistor Pull-up
        │                   │        ┌─[10kΩ]─┐
        └───────────── GND  │        │        │
                            │        │        │
                          ┌─┴─┐    ┌─┴─┐    ┌─┴─┐
                          │DHT│────│ESP│────│VCC│
                          │DA2│    │GP2│    │3V3│
                          └───┘    └───┘    └───┘


Conexões:
========
DHT11 Pin 1 (VCC)  →  ESP-01S VCC (3.3V)
DHT11 Pin 2 (DATA) →  ESP-01S GPIO2 + Resistor 10kΩ para VCC
DHT11 Pin 3 (NC)   →  Não conectar  
DHT11 Pin 4 (GND)  →  ESP-01S GND

Opcional:
=========
LED Status         →  ESP-01S GPIO0 (com resistor 330Ω)


Notas importantes:
==================
1. DHT11 precisa de pull-up de 10kΩ no pino DATA
2. Alimentação deve ser 3.3V estável (não 5V)
3. GPIO2 é usado para DATA (não GPIO0, pois é usado para programação)
4. Aguardar 2 segundos após ligar antes da primeira leitura
5. Não fazer leituras com intervalo menor que 2 segundos
```
