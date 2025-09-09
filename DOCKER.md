# Ambiente de Teste Mosquitto MQTT com Docker no macOS

Este guia mostra como instalar e configurar um broker MQTT (Mosquitto) usando Docker no macOS para testes de IoT.

## Pré-requisitos
- Docker Desktop instalado no macOS

## Passo 1: Preparar o ambiente
Abra o Terminal e navegue até a pasta do seu projeto:
```sh
cd /Users/rcaratti/Desenvolvimento/eu/Arduino/HomeGuard
```

## Passo 2: Criar estrutura de pastas para Mosquitto
```sh
mkdir -p mosquitto/config mosquitto/data mosquitto/log
```

## Passo 3: Criar arquivo de configuração do Mosquitto
Crie o arquivo `mosquitto/config/mosquitto.conf` com o conteúdo:
```conf
allow_anonymous true
listener 1883
```

## Passo 4: Criar arquivo docker-compose.yml
Crie o arquivo `docker-compose.yml` na raiz do projeto com o conteúdo:
```yaml
version: '3'
services:
  mosquitto:
    image: eclipse-mosquitto:latest
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
```

## Passo 5: Iniciar o broker Mosquitto
No terminal, execute:
```sh
docker-compose up -d
```

## Passo 6: Testar o broker MQTT
Você pode usar o comando abaixo para testar a conexão:
```sh
mosquitto_sub -h localhost -t "test"
mosquitto_pub -h localhost -t "test" -m "Olá Docker MQTT!"
```

## Observações
- O broker estará disponível na porta 1883 do seu Mac.
- Para parar o serviço:
```sh
docker-compose down
```
- Para visualizar os logs do Mosquitto:
```sh
docker-compose logs mosquitto
```

## Personalização
- Para autenticação, edite o arquivo `mosquitto.conf` e consulte a documentação oficial do Mosquitto.
- Você pode adicionar outros serviços ao `docker-compose.yml` conforme necessidade.

---
Dúvidas ou problemas? Consulte a documentação oficial do Docker e Mosquitto ou peça ajuda aqui!
