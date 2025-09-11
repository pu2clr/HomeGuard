#!/bin/bash
# HomeGuard - Configuração de ambiente Python para áudio (Térreo)
# Uso: sudo ./setup_audio_env.sh

set -e

# Atualiza o sistema
sudo apt-get update
sudo apt-get upgrade -y

# Instala Python 3 e pip
sudo apt-get install -y python3 python3-pip python3-dev python3-setuptools

# Instala dependências de áudio e MQTT
sudo apt-get install -y libsdl2-mixer-2.0-0 libsdl2-2.0-0 libasound2-dev libportaudio2 libportmidi-dev libfreetype6-dev

# Instala dependências Python necessárias globalmente
sudo pip3 install --upgrade pip
sudo pip3 install pygame paho-mqtt schedule

# Mensagem final
echo "\n✅ Ambiente Python para áudio configurado com sucesso!"
echo "Recomenda-se reiniciar o Raspberry Pi para garantir que todos os módulos estejam disponíveis."
