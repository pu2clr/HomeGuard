# Acionamento Seguro de Relé com ESP8266 usando Transistor NPN

## Problema
O ESP8266 (e também o Raspberry Pi) opera com GPIOs de 3.3V e baixa corrente, enquanto a maioria dos módulos relé de mercado espera um sinal de 5V e consome mais corrente do que o pino pode fornecer. Acionar o relé diretamente pelo GPIO pode travar o sistema, causar mau funcionamento ou até danificar o microcontrolador.

## Solução: Driver com Transistor NPN
Utilize um transistor NPN (ex: 2N2222, BC547, BC337) como chave para acionar o relé de forma segura.

## Esquema de ligação

```
ESP8266 GPIO5 ----[1kΩ]----|>B   2N2222/BC547 NPN
                          |      (ou similar)
                         C|----- IN do módulo relé
                          |
                         E|
                          |
                        GND (comum ao ESP e ao relé)

Relé VCC ---- 5V
Relé GND ---- GND (comum ao ESP)
```

- **GPIO5**: Sinal de controle (pode ser outro GPIO)
- **Resistor 1kΩ**: Limita corrente na base do transistor
- **IN do relé**: Entrada de sinal do módulo relé
- **VCC do relé**: 5V (NUNCA do GPIO)
- **GND**: Comum ao ESP e ao relé

## Funcionamento
- GPIO HIGH: Transistor conduz, IN do relé vai para GND → relé ativa (a maioria dos módulos é ativada com LOW)
- GPIO LOW: Transistor não conduz, IN do relé fica em HIGH → relé desativa

## Dicas
- Se o relé não acionar, inverta a lógica no código (HIGH/LOW)
- Certifique-se de que o GND do relé e do ESP8266 estão conectados
- Não acione o relé diretamente do GPIO
- Para maior proteção, pode-se adicionar um diodo 1N4148 entre base e emissor (catodo na base)

## Segurança
- Nunca acione cargas AC diretamente do ESP8266
- O relé deve ser alimentado por fonte adequada (5V)
- O transistor protege o microcontrolador e garante acionamento confiável
