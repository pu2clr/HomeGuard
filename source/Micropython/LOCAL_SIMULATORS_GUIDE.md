# 🖥️ SIMULADORES MICROPYTHON LOCAIS - GUIA COMPLETO

## ✅ **SIM! Existem excelentes simuladores MicroPython locais**

### 🎯 **OPÇÕES DISPONÍVEIS (do melhor para o seu caso):**

## **1. MICROPYTHON UNIX PORT** ⭐⭐⭐⭐⭐ (RECOMENDADO)

### **Instalação automática:**
```bash
cd source/Micropython
./install_micropython_simulator.sh install
```

### **Instalação manual:**
```bash
# macOS
brew install micropython

# Ubuntu/Debian  
sudo apt-get install micropython

# Arch Linux
sudo pacman -S micropython
```

### **Vantagens:**
- ✅ **100% compatível** com MicroPython real
- ✅ **Mesma sintaxe** e módulos core
- ✅ **Debug nativo** com stack traces completos
- ✅ **REPL interativo** identico ao ESP32
- ✅ **Testa algoritmos** perfeitamente

### **Exemplo prático:**
```bash
# Testar seu código diretamente
micropython main.py

# REPL interativo
micropython
>>> import time, gc
>>> print("MicroPython local funcionando!")
>>> exit()
```

## **2. PYTHON COM STUBS** ⭐⭐⭐⭐ (Alternativa rápida)

### **Setup:**
```bash
pip install micropython-stubs
```

### **Criar adaptador para módulos ESP32:**
```python
# mock_hardware.py - Simula módulos do ESP32
class MockPin:
    def __init__(self, pin, mode=None):
        self.pin = pin
        self.mode = mode
        self._value = 0
    
    def value(self, val=None):
        if val is not None:
            self._value = val
            print(f"GPIO{self.pin} = {val}")
        return self._value

class MockADC:
    def __init__(self, pin):
        self.pin = pin
    
    def read(self):
        # Simular leitura ZMPT101B
        import random
        return random.randint(2400, 3000)
    
    def atten(self, atten):
        pass

class MockMachine:
    Pin = MockPin
    ADC = MockADC
    ATTN_11DB = 3
    
    @staticmethod
    def idle():
        import time
        time.sleep(0.001)
    
    @staticmethod
    def reset():
        print("RESET simulado")
        exit(0)

# Instalar mock
import sys
sys.modules['machine'] = MockMachine()
```

## **3. WOKWI SIMULATOR** ⭐⭐⭐⭐ (Online com hardware visual)

### **URL:** https://wokwi.com
### **Recursos:**
- ✅ **Simulação completa** ESP32-C3
- ✅ **Hardware visual** (LEDs, botões, sensores)
- ✅ **Debug gráfico** em tempo real
- ✅ **Compartilhamento** de projetos

### **Para seu projeto Grid Monitor:**
1. Acesse https://wokwi.com
2. Selecione "ESP32-C3" 
3. Cole seu código `main.py`
4. Adicione componentes: ZMPT101B, Relay, LED
5. Execute e veja funcionamento visual

## **4. MICROPYTHON EMULATOR** ⭐⭐⭐ (Compilação manual)

### **Para desenvolvimento avançado:**
```bash
# Clonar e compilar MicroPython
git clone https://github.com/micropython/micropython.git
cd micropython
make -C mpy-cross
cd ports/unix
make submodules
make

# Executar
./build-standard/micropython
```

## 🚀 **TESTANDO SEU CÓDIGO GRID MONITOR**

### **Exemplo prático com simulador Unix:**

```bash
# 1. Instalar simulador
./install_micropython_simulator.sh install

# 2. Criar versão simulada do seu código
cd micropython_examples
micropython test_sensor_simulation.py
```

### **Saída esperada:**
```
🔌 Iniciando simulação Grid Monitor...
====================================
ADC simulado: min=2845, max=2987, avg_filtered=2901
Leitura 1: 2901 - Grid: ON (stable: 1/3)
ADC simulado: min=2834, max=2976, avg_filtered=2895
Leitura 2: 2895 - Grid: ON (stable: 2/3)
*** MUDANÇA DE ESTADO: Grid OFF (tensão: 2543) ***
Leitura 11: 2543 - Grid: OFF (stable: 3/3)
```

## 📊 **COMPARAÇÃO DE SIMULADORES**

| Simulador | Facilidade | Precisão | Hardware | Debug | Recomendação |
|-----------|------------|----------|----------|-------|--------------|
| **Unix Port** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ | ⭐⭐⭐⭐⭐ | **🏆 MELHOR** |
| **Wokwi** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 🥈 **Visual** |
| **Python+Stubs** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ❌ | ⭐⭐⭐⭐ | 🥉 **Rápido** |
| **Manual Build** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ | ⭐⭐⭐⭐⭐ | **Avançado** |

## 🎯 **RECOMENDAÇÃO PARA SEU PROJETO**

### **WORKFLOW DE DESENVOLVIMENTO:**

```bash
# 1. Desenvolvimento inicial (algoritmos, lógica)
micropython main.py  # ← Unix Port local

# 2. Teste visual (componentes, interface)  
# → Usar Wokwi online com ESP32-C3

# 3. Validação final
./validate_simple.sh main.py  # ← Seu validador

# 4. Deploy real
./test_wdt_fix.sh upload  # ← ESP32-C3 físico
```

### **VANTAGENS ESPECÍFICAS PARA GRID MONITOR:**

#### **Unix Port permite testar:**
- ✅ **Algoritmo de filtragem** (outliers, média)
- ✅ **Lógica de hysteresis** (thresholds alto/baixo)  
- ✅ **Validação de estado** (estabilidade)
- ✅ **Garbage collection** (memória)
- ✅ **Tratamento de exceções**

#### **Wokwi permite testar:**
- ✅ **Interação com ADC** (ZMPT101B simulado)
- ✅ **Controle de GPIO** (relay, LED)
- ✅ **Timing real** (delays, loops)
- ✅ **Comportamento visual** do sistema

## 🔧 **COMANDOS PRÁTICOS**

### **Instalação rápida:**
```bash
# macOS (recomendado)
brew install micropython

# Teste imediato  
micropython -c "print('🚀 MicroPython local OK!')"
```

### **Teste do seu código:**
```bash
# Executar main.py no simulador
micropython main.py

# Debug interativo
micropython
>>> exec(open('main.py').read())
>>> # Testar funções individualmente
```

### **Desenvolvimento híbrido:**
```bash
# 1. Desenvolver localmente
micropython test_algorithms.py

# 2. Validar sintaxe  
./validate_simple.sh main.py

# 3. Testar visualmente
# → Wokwi: https://wokwi.com

# 4. Deploy final
./test_wdt_fix.sh upload
```

## 🎉 **CONCLUSÃO**

**SIM! Existem excelentes simuladores locais para MicroPython:**

### **🏆 RECOMENDAÇÃO PRINCIPAL:**
**MicroPython Unix Port** - Perfeito para desenvolvimento de algoritmos

### **🔧 INSTALAÇÃO:**
```bash
./install_micropython_simulator.sh install
```

### **🚀 USO IMEDIATO:**
```bash
micropython main.py  # Testa seu código grid monitor
```

**O simulador local acelera o desenvolvimento e evita ciclos de upload/teste no ESP32!** 🎯

---

**Data:** 3 de outubro de 2025  
**Versão:** v1.0 - Simuladores Locais  
**Status:** ✅ Pronto para uso