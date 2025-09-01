# HomeGuard Flask + Mosquitto: Instalação e Configuração em Ubuntu/Kubuntu (Intel Core i7)

## 1. Instalação do Mosquitto

```sh
sudo apt update
sudo apt install mosquitto mosquitto-clients
```

## 2. Configuração do Mosquitto

Crie um arquivo de senha para autenticação:
```sh
sudo mosquitto_passwd -c /etc/mosquitto/passwd homeguard
```
Digite a senha desejada (exemplo: pu2clr123456).

Edite o arquivo de configuração `/etc/mosquitto/mosquitto.conf` e adicione:
```
allow_anonymous false
password_file /etc/mosquitto/passwd
listener 1883
```

Reinicie o serviço:
```sh
sudo systemctl restart mosquitto
sudo systemctl enable mosquitto
```

## 3. Teste do Broker

Publique e monitore tópicos:
```sh
mosquitto_sub -h localhost -u homeguard -P pu2clr123456 -t "home/#" -v
mosquitto_pub -h localhost -u homeguard -P pu2clr123456 -t "home/test" -m "Hello MQTT"
```

## 4. Instalação do Python e dependências Flask

```sh
sudo apt install python3 python3-pip
cd /caminho/para/HomeGuard/web
pip3 install -r requirements.txt
```
Se não houver `requirements.txt`, instale manualmente:
```sh
pip3 install flask paho-mqtt
```

## 5. Banco de Dados SQLite

O HomeGuard Flask já utiliza SQLite por padrão (`db/homeguard.db`). Não é necessário instalar nada extra.

## 6. Execução do Flask

No diretório `web/`:
```sh
python3 homeguard_flask.py
```
Acesse a interface web pelo navegador em `http://localhost:5000`.

## 7. Comunicação entre dispositivos e broker

Configure seus dispositivos para usar:
- Broker: IP do notebook (ex: 192.168.1.100)
- Porta: 1883
- Usuário: homeguard
- Senha: pu2clr123456

Exemplo de comando MQTT:
```sh
mosquitto_pub -h 192.168.1.100 -u homeguard -P pu2clr123456 -t "home/radio/frequency" -m "10390"
```

---

**Observações:**
- Certifique-se que a porta 1883 está liberada no firewall.
- O Flask pode ser executado em modo de produção com Gunicorn ou outro WSGI server, se necessário.
- Para uso apenas com SQLite, não é preciso configurar MariaDB/MySQL.
