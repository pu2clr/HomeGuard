# HomeGuard Audio Simulator - Primeiro Andar

Este diretório contém o serviço de simulação de presença por áudio para o primeiro andar. O serviço é autônomo, configurável e pode ser instalado como serviço do sistema para iniciar automaticamente no boot do Raspberry Pi.

## Instalação e Execução

1. **Configuração automática do ambiente Python:**
   ```bash
   sudo ./setup_audio_env.sh
   ```
   > Este script instala Python, pip, bibliotecas de áudio e dependências necessárias globalmente.
   > Recomenda-se reiniciar o Raspberry Pi após a execução.

2. **Clone apenas esta pasta no Raspberry Pi do primeiro andar:**
   ```bash
   git clone <repo_url> --depth 1 --filter=blob:none --sparse
   cd HomeGuard
   git sparse-checkout set raspberry_pi3/first
   cd raspberry_pi3/first
   ```
3. **Configure a programação de áudio:**
   - Edite o arquivo `audio_schedule.json` para definir horários, sons e rotinas.
   - Edite `first_config.json` para ajustes finos (broker MQTT, volume, etc).
4. **Teste manualmente:**
   ```bash
   ./start_first_floor.sh
   ```
5. **Instale como serviço systemd:**
   ```bash
   sudo cp homeguard-audio-first.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable homeguard-audio-first
   sudo systemctl start homeguard-audio-first
   ```

## Tópico MQTT
- Publica e escuta em: `home/audio/first`

## Exemplos de Uso
- Simulação de rotina matinal, descanso, ida ao banheiro, etc.
- Programação de sons por horário ou por detecção de movimento.
- Controle remoto via MQTT para ativar/desativar simulação.

## Exemplos de comandos MQTT

- **Ativar simulação de presença (modo home):**
  ```bash
  mosquitto_pub -h <BROKER> -u homeguard -P pu2clr123456 -t home/audio/first/cmnd -m "MODE_HOME"
  ```
- **Ativar modo ausente:**
  ```bash
  mosquitto_pub -h <BROKER> -u homeguard -P pu2clr123456 -t home/audio/first/cmnd -m "MODE_AWAY"
  ```
- **Forçar execução de rotina (exemplo: rotina matinal):**
  ```bash
  mosquitto_pub -h <BROKER> -u homeguard -P pu2clr123456 -t home/audio/first/cmnd -m "RUN_ROUTINE:morning_routine"
  ```
- **Parar qualquer áudio em reprodução:**
  ```bash
  mosquitto_pub -h <BROKER> -u homeguard -P pu2clr123456 -t home/audio/first/cmnd -m "STOP"
  ```
- **Ajustar volume (exemplo: 0.5):**
  ```bash
  mosquitto_pub -h <BROKER> -u homeguard -P pu2clr123456 -t home/audio/first/cmnd -m "VOLUME:0.5"
  ```
- **Recarregar configuração:**
  ```bash
  mosquitto_pub -h <BROKER> -u homeguard -P pu2clr123456 -t home/audio/first/cmnd -m "RELOAD_CONFIG"
  ```

Troque `home/audio/first/cmnd` por `home/audio/ground/cmnd` para comandos no serviço do térreo.

## Categorias de Som Disponíveis

O serviço aceita comandos MQTT para as seguintes categorias de som (pré-definidas em `audio_first.py`):

- `footsteps`   — Passos no corredor/quartos
- `doors`       — Portas dos quartos
- `toilets`     — Banheiro
- `shower`      — Chuveiro
- `bedroom`     — Sons de quarto
- `alerts`      — Alertas de segurança

Para cada categoria, coloque arquivos de áudio (WAV, MP3, etc) na subpasta correspondente em `audio_files/`.

### Exemplo de estrutura de diretórios:
```
audio_files/
  footsteps/
    passo1.wav
    passo2.wav
  doors/
    porta1.wav
  toilets/
    descarga1.wav
  shower/
    chuveiro1.wav
  bedroom/
    cama1.wav
  alerts/
    alarme1.wav
```

## Como adicionar novas categorias de som

1. **Edite o arquivo `audio_first.py`**
   - Adicione a nova categoria em `audio_categories`:
     ```python
     'dogs': [],  # Exemplo de nova categoria
     ```
2. **Crie a pasta correspondente em `audio_files/`**
   - Exemplo: `audio_files/dogs/`
3. **Adicione arquivos de áudio na nova pasta**
4. **Reinicie o serviço de áudio**
5. **Envie o comando MQTT com o nome da nova categoria:**
   ```bash
   mosquitto_pub -h <BROKER> -u homeguard -P pu2clr123456 -t home/audio/first/cmnd -m "dogs"
   ```

> O nome do comando deve ser igual ao nome da categoria definida em `audio_first.py` e ao nome da pasta em `audio_files/`.

## Dicas
- Sempre use letras minúsculas para nomes de categorias.
- Se o comando não for reconhecido, verifique se a categoria existe em `audio_first.py` e se há arquivos de áudio na pasta correspondente.
- Para testar rapidamente, use:
  ```bash
  mosquitto_pub -h <BROKER> -u homeguard -P pu2clr123456 -t home/audio/first/cmnd -m "footsteps"
  ```

## Personalização
- Adicione arquivos de áudio em `audio_files/`.
- Programe eventos em `audio_schedule.json`.
- Ajuste volume e parâmetros em `first_config.json`.

## Logs
- Os logs são salvos em `../logs/`.

## Suporte
- Consulte o README principal do projeto para detalhes avançados.
