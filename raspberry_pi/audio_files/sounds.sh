#!/bin/bash

# Caminho para a pasta dos áudios
AUDIO_DIR="$HOME/audios"

# Lista de arquivos a serem reproduzidos (adicione ou remova conforme necessário)
FILES=(
  "arroto1.aiff"
  "arroto2.flac"
  "banheiro1.wav"
  "descarga1.wav"
  "descarga2.wav"
  "descarga3.wav"
  "dog1.wav"
  "dog2.wav"
  "dog3.m4a"
  "passos1.wav"
  "passos2.mp3"
  "peido1.wav"
  "peido2.wav"
  "peido_curto.mp3"
)

# INTERVALO=1800 # 30 minutos em segundos
INTERVALO=90

for FILE in "${FILES[@]}"; do
    if [ -f "$AUDIO_DIR/$FILE" ]; then
        echo "Reproduzindo: $FILE"
        cvlc --play-and-exit "$AUDIO_DIR/$FILE"
    else
        echo "Arquivo não encontrado: $FILE"
    fi
    echo "Aguardando 30 minutos..."
    sleep $INTERVALO
done
