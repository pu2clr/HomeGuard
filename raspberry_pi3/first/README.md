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

## Personalização
- Adicione arquivos de áudio em `audio_files/`.
- Programe eventos em `audio_schedule.json`.
- Ajuste volume e parâmetros em `first_config.json`.

## Logs
- Os logs são salvos em `../logs/`.

## Suporte
- Consulte o README principal do projeto para detalhes avançados.
