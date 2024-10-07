#!/bin/bash

# Function to check if the WAV file is in the correct format
check_wav_format() {
    local file=$1
    local channels
    local sample_rate

    # Get number of channels and sample rate
    channels=$(sox --i -c "$file")
    sample_rate=$(sox --i -r "$file")

    if [ "$channels" -ne 1 ] || [ "$sample_rate" -ne 16000 ]; then
        return 1  # Incorrect format
    fi

    return 0  # Correct format
}

# Check for Homebrew and install if not found
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Python if not found
if ! command -v python3 &> /dev/null; then
    echo "Installing Python..."
    brew install python
fi

# Install SoX for audio format checking
if ! command -v sox &> /dev/null; then
    echo "Installing SoX..."
    brew install sox
fi

# Create a virtual environment
VENV_DIR="venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating a virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate the virtual environment
source "$VENV_DIR/bin/activate"

# Install VOSK
echo "Installing VOSK..."
pip install --upgrade pip
pip install vosk

# Download the VOSK model if not already downloaded
MODEL_URL="https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
MODEL_DIR="vosk-model-small-en-us-0.15"

if [ ! -d "$MODEL_DIR" ]; then
    echo "Downloading VOSK model..."
    curl -LO "$MODEL_URL"
    echo "Unzipping the model..."
    unzip vosk-model-small-en-us-0.15.zip
    rm vosk-model-small-en-us-0.15.zip
else
    echo "Model already downloaded."
fi

# Create the Python transcription script
TRANSCRIPT_SCRIPT="transcribe.py"

cat << 'EOF' > "$TRANSCRIPT_SCRIPT"
import sys
import os
import wave
import json
import glob
from vosk import Model, KaldiRecognizer

# Path to the model
model_path = "vosk-model-small-en-us-0.15"  # Update this if your model path is different

if not os.path.exists(model_path):
    print("Model not found! Please download the model first.")
    sys.exit(1)

# Load the VOSK model
model = Model(model_path)

# Get all WAV files in the current directory
wav_files = glob.glob("*.wav")

if not wav_files:
    print("No WAV files found! Please check the directory.")
    sys.exit(1)

# Iterate through each WAV file
for audio_file_path in wav_files:
    print(f"Transcribing {audio_file_path}...")

    # Open the audio file
    with wave.open(audio_file_path, "rb") as wf:
        if wf.getnchannels() != 1 or wf.getsampwidth() != 2 or wf.getframerate() != 16000:
            print(f"Audio file {audio_file_path} must be WAV format mono PCM.")
            continue

        recognizer = KaldiRecognizer(model, 16000)
        results = []
        
        # Read the audio file and perform recognition
        while True:
            data = wf.readframes(4000)
            if len(data) == 0:
                break
            if recognizer.AcceptWaveform(data):
                results.append(recognizer.Result())
            else:
                recognizer.PartialResult()

        results.append(recognizer.FinalResult())

    # Combine results and write to a text file
    transcription = " ".join([json.loads(r)["text"] for r in results])
    transcription_filename = f"{os.path.splitext(audio_file_path)[0]}_transcription.txt"
    with open(transcription_filename, "w") as f:
        f.write(transcription)

    print(f"Transcription completed for {audio_file_path}! Check '{transcription_filename}' for the result.")
EOF

# Check if combined_audio.wav is in the correct format
if check_wav_format "combined_audio.wav"; then
    echo "The WAV file is in the correct format."
else
    echo "The WAV file is not in the correct format. Converting..."
    ffmpeg -i combined_audio.wav -ac 1 -ar 16000 -c:a pcm_s16le combined_audio_converted.wav
    mv combined_audio_converted.wav combined_audio.wav  # Replace original file with converted one
fi

# Run the transcription script
echo "Running the transcription script..."
python3 "$TRANSCRIPT_SCRIPT"

# Deactivate the virtual environment
deactivate

echo "Transcription finished!"

