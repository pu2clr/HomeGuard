# Grid Monitor com ESP32-C3 e MicroPython

Este projeto implementa um monitor de rede elétrica com ESP32-C3 usando MicroPython. Ele aciona um relé, monitora a rede elétrica via sensor analógico (ex: ZMPT101B) e publica eventos via MQTT.

## Estrutura de Pastas

```
Micropython/
└── grid_monitor/
    └── main.py   # Script principal para o ESP32-C3
```

## Instalação do MicroPython no ESP32-C3

### 1. Baixar o firmware MicroPython
- Acesse: https://micropython.org/download/esp32c3/
- Baixe o arquivo `.bin` mais recente para ESP32-C3.

### 2. Instalar o firmware
#### Linux/macOS:
```bash
pip install esptool
esptool.py --chip esp32c3 erase_flash
esptool.py --chip esp32c3 --baud 460800 write_flash -z 0x0 <firmware.bin>
```
#### Windows:
- Instale Python e esptool via `pip install esptool`
- Use o prompt de comando com os comandos acima.

### 3. Usar a IDE Thonny
- Baixe em https://thonny.org/
- Abra Thonny, selecione "MicroPython (ESP32)" como interpretador.
- Conecte o ESP32-C3 via USB, selecione a porta correta.
- Faça upload do arquivo `main.py` da pasta `grid_monitor` para o ESP32-C3.

## Dependências MicroPython
O firmware MicroPython para ESP32-C3 normalmente não inclui o gerenciador de pacotes `upip`. Por isso, a instalação do pacote MQTT deve ser feita manualmente:

### Instalação manual do pacote MQTT (micropython-umqtt.simple)

1. Baixe o arquivo `micropython-umqtt.simple.py` em:
    https://github.com/micropython/micropython-lib/blob/master/micropython/umqtt.simple/umqtt/simple.py
    (Clique em "Raw" e salve como `micropython-umqtt.simple.py`)
2. Abra a IDE Thonny, conecte o ESP32-C3 e selecione o interpretador MicroPython.
3. No menu "Arquivos" da Thonny, envie o arquivo `micropython-umqtt.simple.py` para o ESP32-C3 (pasta raiz ou junto do seu `main.py`).
4. No seu `main.py`, importe normalmente:
    ```python
    from micropython_umqtt_simple import MQTTClient
    ```

Se preferir, renomeie o arquivo para `umqtt_simple.py` e importe como:
```python
from umqtt_simple import MQTTClient
```
### Como instalar o pacote MQTT no ESP32-C3

Se aparecer erro de memória ou conexão, tente novamente ou use uma rede WiFi estável.

**Dica:** Se o pacote não funcionar, confira se o arquivo está no mesmo diretório do seu `main.py` e se o nome do arquivo e do import estão corretos.


## Pin configuration
- Adjust the pins at the beginning of `main.py` according to your Super Mini model.
- ZMPT_PIN: ADC0 (GPIO0)
- RELAY_PIN: GPIO7
- LED_PIN: GPIO8

## Usage
- The monitor connects to WiFi, listens for MQTT commands, and publishes status.
- Supported commands: ON, OFF, AUTO, STATUS
- The relay is triggered automatically in case of power failure or manually via MQTT.

## Supported operating systems
- Linux, Windows, macOS (for firmware upload and Thonny usage)

## Tips
- Check the ESP32-C3 Super Mini documentation to correctly map the pins.
- Test the ZMPT101B sensor and adjust the GRID_THRESHOLD according to your grid.
- The file must be named `main.py` for automatic execution on ESP32-C3.

## ADC Resolution Note
- **Important:** The ADC resolution varies by platform:
    - ESP8266: 10 bits (0-1023)
    - ESP32-C3: 12 bits (0-4095)
- You must adjust the threshold (GRID_THRESHOLD) and logic according to the platform and sensor used. Always calibrate for your hardware.
