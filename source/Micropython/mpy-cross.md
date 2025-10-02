# Guia de Uso do `mpy-cross` no MicroPython (ESP32-C3)

O `mpy-cross` é uma ferramenta que compila arquivos Python (`.py`) em bytecode
(`.mpy`), permitindo rodar código de forma mais eficiente em microcontroladores,
como o **ESP32-C3**. Este guia mostra como instalar, usar e aplicar o `mpy-cross`
em projetos reais.

---

## 🔹 O que é o `mpy-cross`?
- É um **compilador de bytecode** do MicroPython.
- Converte arquivos `.py` em `.mpy` que podem ser executados diretamente no
  firmware MicroPython.
- Otimiza **memória, tempo de importação** e torna o sistema mais robusto em
  projetos grandes.

---

## 🔹 Instalação do `mpy-cross`

1. Clone o repositório do MicroPython:
   ```bash
   git clone https://github.com/micropython/micropython.git
   cd micropython/mpy-cross
   ```

2. Compile o `mpy-cross`:
   ```bash
   make
   ```

3. O binário `mpy-cross` será gerado na pasta `mpy-cross/`.

> 💡 Em alguns sistemas pode estar disponível via pacotes (ex: `brew install mpy-cross`).

---

## 🔹 Compilando módulos

Exemplo: você tem o módulo `meu_modulo.py`.

Compile:
```bash
./mpy-cross meu_modulo.py
```

Será gerado o arquivo:
```
meu_modulo.mpy
```

Envie-o para o ESP32-C3 (pasta `/lib`) com:
```bash
mpremote cp meu_modulo.mpy :lib/
```

No MicroPython:
```python
import meu_modulo
meu_modulo.funcao()
```

---

## 🔹 Compilando o `main.py`

O arquivo principal também pode ser compilado:
```bash
./mpy-cross main.py
```

Envie para o ESP32-C3:
```bash
mpremote cp main.mpy :
```

> O MicroPython executa `main.py` ou `main.mpy` automaticamente na inicialização.

---

## 🔹 Estrutura de Projeto

Um projeto típico pode ficar assim:

```
/flash
 ├── boot.py
 ├── main.mpy
 └── lib/
     ├── meu_modulo.mpy
     └── outro_modulo.mpy
```

---

## 🔹 Fluxo Completo de Trabalho

1. **Desenvolvimento local**  
   - Escreva e teste seus scripts `.py` normalmente.  
   - Use Thonny, mpremote ou rshell para enviar e rodar no ESP32-C3.

2. **Compilação com `mpy-cross`**  
   - Quando o código estiver estável, compile:
     ```bash
     ./mpy-cross main.py
     ./mpy-cross lib/*.py
     ```

3. **Deploy para o ESP32-C3**  
   ```bash
   mpremote cp main.mpy :
   mpremote cp lib/*.mpy :lib/
   ```

4. **Execução automática**  
   - Reinicie o ESP32-C3.  
   - O `main.mpy` será executado automaticamente.

---

## 🔹 Vantagens do uso do `mpy-cross`
- Menor uso de memória RAM e Flash.  
- Importação mais rápida de módulos.  
- Projetos grandes ficam mais estáveis.  
- Código menos legível por terceiros (leve ofuscação).

---

## 🔹 Quando NÃO usar
- Durante o desenvolvimento inicial, pois dificulta a depuração.  
- Quando há muita mudança no código, prefira trabalhar com `.py`.

---

✅ **Resumo:** Use `mpy-cross` para compilar tanto bibliotecas quanto o
`main.py` quando o projeto estiver estável. Isso garante melhor desempenho e
robustez no ESP32-C3.

