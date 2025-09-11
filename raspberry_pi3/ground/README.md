# HomeGuard Audio Simulator - Térreo

Este diretório contém o serviço de simulação de presença por áudio para o térreo. O serviço é autônomo, configurável e pode ser instalado como serviço do sistema para iniciar automaticamente no boot do Raspberry Pi.

## Instalação e Execução

1. **Configuração automática do ambiente Python:**
   ```bash
   sudo ./setup_audio_env.sh
   ```
   > Este script instala Python, pip, bibliotecas de áudio e dependências necessárias globalmente.
   > Recomenda-se reiniciar o Raspberry Pi após a execução.

2. **Clone apenas esta pasta no Raspberry Pi do térreo:**
   ```bash
   git clone <repo_url> --depth 1 --filter=blob:none --sparse
   cd HomeGuard
   git sparse-checkout set raspberry_pi3/ground
   cd raspberry_pi3/ground
   ```
3. **Configure a programação de áudio:**
   - Edite o arquivo `audio_schedule.json` para definir horários, sons e rotinas.
   - Edite `ground_config.json` para ajustes finos (broker MQTT, volume, etc).
4. **Teste manualmente:**
   ```bash
   ./start_ground_floor.sh
   ```
5. **Instale como serviço systemd:**
   ```bash
   sudo cp homeguard-audio-ground.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable homeguard-audio-ground
   sudo systemctl start homeguard-audio-ground
   ```

## Tópico MQTT
- Publica e escuta em: `home/audio/ground`

## Exemplos de Uso
- Simulação de rotina matinal, TV da tarde, cuidado com cães, etc.
- Programação de sons por horário ou por detecção de movimento.
- Controle remoto via MQTT para ativar/desativar simulação.

## Exemplos de comandos MQTT

- **Ativar simulação de presença (modo home):**
  ```bash
  mosquitto_pub -h <BROKER> -t home/audio/ground/cmnd -m "MODE_HOME"
  ```
- **Ativar modo ausente:**
  ```bash
  mosquitto_pub -h <BROKER> -t home/audio/ground/cmnd -m "MODE_AWAY"
  ```
- **Forçar execução de rotina (exemplo: atividade matinal):**
  ```bash
  mosquitto_pub -h <BROKER> -t home/audio/ground/cmnd -m "RUN_ROUTINE:morning_activity"
  ```
- **Parar qualquer áudio em reprodução:**
  ```bash
  mosquitto_pub -h <BROKER> -t home/audio/ground/cmnd -m "STOP"
  ```
- **Ajustar volume (exemplo: 0.5):**
  ```bash
  mosquitto_pub -h <BROKER> -t home/audio/ground/cmnd -m "VOLUME:0.5"
  ```
- **Recarregar configuração:**
  ```bash
  mosquitto_pub -h <BROKER> -t home/audio/ground/cmnd -m "RELOAD_CONFIG"
  ```

Troque `home/audio/ground/cmnd` por `home/audio/first/cmnd` para comandos no serviço do primeiro andar.

## Personalização
- Adicione arquivos de áudio em `audio_files/`.
- Programe eventos em `audio_schedule.json`.
- Ajuste volume e parâmetros em `ground_config.json`.

## Logs
- Os logs são salvos em `../logs/`.

## Suporte
- Consulte o README principal do projeto para detalhes avançados.
