# HomeGuard Flask + Mosquitto: Instalação e Configuração em Microsoft Windows (Intel Core i7)

## 1. Instalação do Mosquitto

1. Baixe o instalador do Mosquitto em: https://mosquitto.org/download/
2. Execute o instalador e siga as instruções.
3. Após instalar, adicione o diretório do Mosquitto ao PATH do Windows (opcional para uso via terminal).

## 2. Configuração do Mosquitto

1. Abra o arquivo de configuração `mosquitto.conf` (geralmente em `C:\Program Files\mosquitto` ou `C:\mosquitto`).
2. Adicione as linhas:
```
allow_anonymous false
password_file passwd.txt
listener 1883
```
3. Crie o arquivo de senha usando o terminal (cmd ou PowerShell):
```sh
mosquitto_passwd.exe -c passwd.txt homeguard
```
Digite a senha desejada (exemplo: pu2clr123456).

4. Inicie o Mosquitto:
```sh
mosquitto.exe -c mosquitto.conf
```

## 3. Teste do Broker

Abra um terminal e execute:
```sh
mosquitto_sub.exe -h localhost -u homeguard -P pu2clr123456 -t "home/#" -v
mosquitto_pub.exe -h localhost -u homeguard -P pu2clr123456 -t "home/test" -m "Hello MQTT"
```

## 4. Instalação do Python e dependências Flask

1. Baixe e instale o Python em https://www.python.org/downloads/windows/
2. Abra o terminal (cmd ou PowerShell) e instale o pip (se necessário):
```sh
python -m ensurepip --upgrade
```
3. Instale as dependências:
```sh
cd C:\caminho\para\HomeGuard\web
pip install -r requirements.txt
```
Se não houver `requirements.txt`, instale manualmente:
```sh
pip install flask paho-mqtt
```

## 5. Banco de Dados SQLite

O HomeGuard Flask já utiliza SQLite por padrão (`db/homeguard.db`). Não é necessário instalar nada extra.

## 6. Execução do Flask

No diretório `web/`:
```sh
python homeguard_flask.py
```
Acesse a interface web pelo navegador em `http://localhost:5000`.

## 7. Comunicação entre dispositivos e broker

Configure seus dispositivos para usar:
- Broker: IP do computador (ex: 192.168.1.100)
- Porta: 1883
- Usuário: homeguard
- Senha: pu2clr123456

Exemplo de comando MQTT:
```sh
mosquitto_pub.exe -h 192.168.1.100 -u homeguard -P pu2clr123456 -t "home/radio/frequency" -m "10390"
```

---

**Observações:**
- Certifique-se que a porta 1883 está liberada no firewall do Windows.
- O Flask pode ser executado em modo de produção com servidores WSGI compatíveis com Windows, se necessário.
- Para uso apenas com SQLite, não é preciso configurar MariaDB/MySQL.
