# 🌡️ DHT11/DHT22 no ESP32-C3 - Guia Completo

## 🤔 **Sua Pergunta:**
> "NO ambiente real, devo baixar algum módulo para ler dados reais do DHT11/22?"

## ✅ **Resposta: Na maioria dos casos, NÃO precisa baixar nada!**

O MicroPython para ESP32-C3 já inclui suporte nativo para DHT11/DHT22.

---

## 📋 **Para ESP32-C3 Real:**

### **1. Código Padrão (Recomendado)**
```python
import dht
import machine

# DHT11
sensor = dht.DHT11(machine.Pin(0))

# DHT22 (maior precisão)
sensor = dht.DHT22(machine.Pin(0))

# Leitura
try:
    sensor.measure()
    temperature = sensor.temperature()  # °C
    humidity = sensor.humidity()        # %
    print(f"Temp: {temperature}°C, Humid: {humidity}%")
except OSError as e:
    print(f"Falha na leitura DHT: {e}")
```

### **2. Se o Módulo DHT Não Estiver Disponível**
Alguns firmwares mais antigos podem não incluir. Neste caso:

```python
# No ESP32-C3 via REPL ou boot.py:
import upip
upip.install('micropython-dht')

# Depois:
import dht
```

### **3. Verificar se DHT Está Disponível**
```python
try:
    import dht
    print("✅ Módulo DHT disponível")
except ImportError:
    print("❌ Módulo DHT não encontrado")
    print("Execute: upip.install('micropython-dht')")
```

---

## 🔌 **Conexões de Hardware:**

```
DHT11/DHT22          ESP32-C3
┌─────────────┐     ┌─────────────┐
│ VCC (3.3V)  │ --> │ 3.3V        │
│ GND         │ --> │ GND         │  
│ DATA        │ --> │ GPIO0       │
│ NC (vazio)  │     │             │
└─────────────┘     └─────────────┘
                           │
                    ┌──────┴──────┐
                    │ Resistor    │
                    │ 10kΩ        │ (Pull-up)
                    │ (DATA->3.3V)│
                    └─────────────┘
```

**⚠️ IMPORTANTE:**
- **Pull-up obrigatório:** Resistor 10kΩ entre DATA e 3.3V
- **Alimentação:** Sempre 3.3V (não 5V)
- **Timing:** Aguardar 2 segundos após power-on
- **Frequência:** Máximo 1 leitura a cada 2 segundos

---

## 📊 **Diferenças DHT11 vs DHT22:**

| Característica | DHT11 | DHT22 |
|----------------|-------|-------|
| **Precisão Temp** | ±2°C | ±0.5°C |
| **Precisão Humid** | ±5% | ±2% |
| **Faixa Temp** | 0-50°C | -40-80°C |
| **Faixa Humid** | 20-80% | 0-100% |
| **Resolução** | 1°C/1% | 0.1°C/0.1% |
| **Preço** | $ | $$ |
| **Código** | `dht.DHT11()` | `dht.DHT22()` |

---

## 🧪 **Como Testar no ESP32-C3:**

### **1. Teste Básico**
```python
import dht
import machine
import time

sensor = dht.DHT11(machine.Pin(0))

while True:
    try:
        sensor.measure()
        temp = sensor.temperature()
        humid = sensor.humidity()
        print(f"Temperatura: {temp}°C")
        print(f"Umidade: {humid}%")
        print("-" * 20)
    except OSError as e:
        print(f"Erro: {e}")
    
    time.sleep(3)  # Aguardar 3 segundos
```

### **2. Teste com Validação**
```python
import dht
import machine
import time

def read_dht(pin_num):
    sensor = dht.DHT11(machine.Pin(pin_num))
    
    try:
        sensor.measure()
        temp = sensor.temperature()
        humid = sensor.humidity()
        
        # Validar faixas
        if temp < -40 or temp > 80:
            raise ValueError(f"Temperatura inválida: {temp}°C")
        if humid < 0 or humid > 100:
            raise ValueError(f"Umidade inválida: {humid}%")
            
        return temp, humid
    
    except OSError as e:
        print(f"Erro de hardware: {e}")
        return None, None
    except ValueError as e:
        print(f"Erro de validação: {e}")
        return None, None

# Teste
temp, humid = read_dht(0)
if temp is not None:
    print(f"OK: {temp}°C, {humid}%")
else:
    print("Falha na leitura")
```

---

## 🔧 **Troubleshooting:**

### **❌ "OSError: [Errno 110] ETIMEDOUT"**
**Causas:**
- Sem pull-up de 10kΩ
- Fios muito longos (máx 20cm)
- Alimentação instável
- Sensor defeituoso

**Soluções:**
```python
# Tentar múltiplas vezes
for i in range(3):
    try:
        sensor.measure()
        break
    except OSError:
        if i == 2:
            print("Sensor não responde")
        time.sleep(1)
```

### **❌ "ImportError: no module named 'dht'"**
**Solução:**
```python
# Instalar módulo
import upip
upip.install('micropython-dht')

# Ou usar driver manual
```

### **❌ Leituras sempre NaN ou 0**
**Causas:**
- Conexão DATA incorreta
- Pull-up ausente
- Tensão de alimentação baixa

---

## 📚 **Recursos Adicionais:**

### **Driver DHT Manual (se necessário):**
```python
import machine
import time

class DHT11_Manual:
    def __init__(self, pin):
        self.pin = machine.Pin(pin, machine.Pin.IN, machine.Pin.PULL_UP)
        self.temp = None
        self.humid = None
    
    def measure(self):
        # Implementação bit-bang do protocolo DHT
        # (código mais longo, usar apenas se necessário)
        pass
```

### **Links Úteis:**
- [MicroPython DHT Docs](https://docs.micropython.org/en/latest/esp8266/tutorial/dht.html)
- [DHT11 Datasheet](https://www.mouser.com/datasheet/2/758/DHT11-Technical-Data-Sheet-Translated-Version-1143054.pdf)
- [DHT22 Datasheet](https://www.sparkfun.com/datasheets/Sensors/Temperature/DHT22.pdf)

---

## 🎯 **Resumo para Seu Projeto:**

### **No script main.py atual:**
```python
# ✅ Funciona automaticamente no ESP32-C3
import dht
sensor = dht.DHT11(machine.Pin(0))  # ou DHT22
```

### **Para desenvolvimento local:**
```python
# ✅ Use o dht_simple.py (já criado)
from dht_simple import DHT11, DHT22
```

### **Se der erro no ESP32-C3:**
```python
# ✅ Instale uma vez:
import upip
upip.install('micropython-dht')
```

**🎉 Na maioria dos casos, o código funcionará direto no ESP32-C3 sem instalação adicional!**