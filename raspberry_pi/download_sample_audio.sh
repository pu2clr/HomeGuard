#!/bin/bash
# Sample audio files downloader

echo "🎵 Downloading sample audio files..."

# Create directories
mkdir -p audio_files/{dogs,footsteps,toilets,tv_radio,doors,background,alerts}

# Function to download and convert audio
download_audio() {
    local url="$1"
    local filename="$2"
    local category="$3"
    
    echo "📥 Downloading $filename..."
    wget -q "$url" -O "temp_audio.tmp"
    
    if [ $? -eq 0 ]; then
        # Convert to mp3 if needed
        ffmpeg -i "temp_audio.tmp" -acodec libmp3lame "audio_files/$category/$filename" -y -loglevel quiet
        rm "temp_audio.tmp"
        echo "✅ $filename downloaded and converted"
    else
        echo "❌ Failed to download $filename"
    fi
}

# Note: Add your own audio file URLs here or use text-to-speech
echo "⚠️ Please add your own audio files to the directories or use freesound.org"
echo "   Sample formats: MP3, WAV, OGG"
echo "   For text-to-speech: Use espeak or festival"

# Generate sample footstep sound using sox
echo "🎶 Generating sample footstep sound..."
sox -n "audio_files/footsteps/footstep_sample.wav" synth 0.1 noise band -n 1000 2000 tremolo 20 40 fade 0.01 0.1 0.01

# Generate sample door sound
echo "🎶 Generating sample door sound..."  
sox -n "audio_files/doors/door_sample.wav" synth 0.5 noise band -n 500 1500 fade 0.01 0.5 0.01

echo "✅ Sample audio generation completed"
echo "📁 Add more audio files to enhance the presence simulation"
