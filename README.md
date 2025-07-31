# HomeGuard
Home Security Support Project.



## **Resumo: Procedimento para Configurar e Programar o ESP-01S (ESP8266)**

### **1. Instalação do Ambiente**

* **Arduino IDE:** Instale e atualize.
* **Pacote ESP8266:** Adicione a URL
  `http://arduino.esp8266.com/stable/package_esp8266com_index.json`
  nas Preferências da IDE e instale "ESP8266 by ESP8266 Community" pelo Gerenciador de Placas.

### **2. Montagem para Gravação**

* Use um **adaptador USB-Serial** (CH340, CP2102, FTDI, ou gravador USB para ESP-01S).
* Ligue os fios:

  * **VCC** → 3,3V
  * **GND** → GND
  * **TX** → RX
  * **RX** → TX
  * **CH\_EN (EN/CH\_PD)** → 3,3V
  * **GPIO0** → GND (só para gravação!)

### **3. Modo de Gravação**

* Ligue **GPIO0 ao GND**.
* Energize o módulo (ou plugue na USB).
* Selecione **Generic ESP8266 Module** na Arduino IDE.
* Selecione a **porta serial** correta.
* Compile e faça o **upload** do sketch.
* Após upload, remova **GPIO0 do GND** e reinicie o ESP-01S.

### **4. Uso em Projeto**

* Instale o ESP-01S no circuito do relé, sensor, etc.
* Alimente o módulo (3,3V estável!).
* **CH\_EN deve permanecer em 3,3V** sempre que o chip estiver em uso.
* Programe para conexão Wi-Fi (IP fixo ou DHCP) e controle (HTTP, MQTT etc).

### **5. Dicas**

* Não alimente com 5V!
* Se der erro de conexão, revise o modo de gravação, fonte e conexões.
* Para uso em automação, prefira MQTT ou HTTP.

---

## **Fluxo resumido**

1. Instale a IDE e o suporte ESP8266.
2. Conecte o ESP-01S corretamente para gravação.
3. Ligue GPIO0 ao GND para gravar.
4. Faça upload do firmware.
5. Remova GPIO0 do GND e reinicie para rodar o projeto.

---

Se precisar de esquema visual ou passo a passo para um caso específico (relé, sensor, automação), só pedir!

