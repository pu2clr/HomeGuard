# MOSQUITTO

Mosquitto é um servidor e um conjunto de utilitários open source que implementam o protocolo MQTT, permitindo a comunicação rápida e leve entre dispositivos de Internet das Coisas (IoT) por meio de mensagens publicadas em tópicos.

## Instalação e Uso do Mosquitto (Cliente MQTT)

O projeto **HomeGuard** pode ser testado facilmente usando os utilitários de linha de comando `mosquitto_pub` e `mosquitto_sub`, que fazem parte do pacote Mosquitto.

Abaixo, veja como instalar e utilizar essas ferramentas em diferentes sistemas operacionais.

---

### macOS

1. **Instale o Homebrew** (caso não tenha):
    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

2. **Instale o Mosquitto:**
    ```bash
    brew install mosquitto
    ```

3. O comando `mosquitto_pub` estará disponível no terminal.

---

### Linux (Ubuntu/Debian)

1. **Atualize o repositório e instale:**
    ```bash
    sudo apt update
    sudo apt install mosquitto-clients
    ```

2. Os comandos `mosquitto_pub` e `mosquitto_sub` ficarão disponíveis.

---

### Windows

1. **Baixe o instalador do Mosquitto:**
    - Acesse: [https://mosquitto.org/download/](https://mosquitto.org/download/)
    - Baixe o instalador para Windows e siga as instruções.

2. Após a instalação, adicione o diretório dos executáveis (`mosquitto_pub.exe` e `mosquitto_sub.exe`) ao PATH do sistema (opcional, mas recomendado para usar no terminal/cmd).

---

## Exemplos de Uso

### Publicando mensagens (publish)

```bash
mosquitto_pub -h <BROKER_IP> -t homeguard/relay1/cmnd -m ON
