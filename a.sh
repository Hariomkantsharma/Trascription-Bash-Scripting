#!/bin/bash

# Step 1: Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew is already installed."
fi

# Step 2: Install FFmpeg via Homebrew if not already installed
if ! command -v ffmpeg &> /dev/null; then
  echo "FFmpeg not found. Installing FFmpeg..."
  brew install ffmpeg
else
  echo "FFmpeg is already installed."
fi

# Step 3: Install Python3 if not already installed
if ! command -v python3 &> /dev/null; then
  echo "Python3 not found. Installing Python3..."
  brew install python
else
  echo "Python3 is already installed."
fi

# Step 4: Set up a Python virtual environment
echo "Setting up a Python virtual environment..."
python3 -m venv venv

# Step 5: Activate the virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Step 6: Install necessary Python packages (Whisper, PyTorch)
echo "Installing necessary Python packages..."
pip install --upgrade pip
pip install torch torchvision torchaudio whisper

# Step 7: Define variables for combining audio and transcription
output_audio="combined_audio.wav"    # Output file name for combined audio
output_text="transcription.txt"      # Output file for transcript

# Ensure the audio test directory exists
audio_dir="/Users/hariomkantsharma/Downloads/audio test"
if [ ! -d "$audio_dir" ]; then
  echo "Error: Audio directory '$audio_dir' does not exist."
  exit 1
fi

# Gather all audio files in the specified directory
audio_files=()

# Loop through supported audio file types
for ext in mp3 wav ogg m4a; do
  for file in "$audio_dir"/*.$ext; do
    if [ -f "$file" ]; then
      audio_files+=("$file")
    fi
  done
done

# Check if we have found any audio files
if [ ${#audio_files[@]} -eq 0 ]; then
  echo "Error: No audio files found in the directory."
  exit 1
fi

# Create a file list for FFmpeg
file_list="filelist.txt"
> "$file_list"

# Write file paths to filelist.txt with proper quoting
for file in "${audio_files[@]}"; do
  echo "file '$(realpath "$file")'" >> "$file_list"
done

# Combine the audio files using FFmpeg with re-encoding to PCM
echo "Combining audio files into $output_audio..."
ffmpeg -f concat -safe 0 -i "$file_list" -c:a pcm_s16le -ar 44100 -ac 2 "$output_audio" -loglevel error

if [ $? -ne 0 ]; then
  echo "Error: FFmpeg failed to combine audio files."
  exit 1
fi
echo "Audio files successfully combined into $output_audio."

# Step 5: Activate the virtual environment
echo "Activating virtual environment..."
source venv/bin/activate  # This assumes your venv is in the current directory

# Step 11: Transcribe the combined audio using Whisper
echo "Transcribing audio with Whisper..."
python3 -m whisper "$output_audio" --model small --language en --output_format txt

# Rename the transcript file and move it to the desired output
transcript_file="${output_audio%.wav}.txt"

if [ -f "$transcript_file" ]; then
  mv "$transcript_file" "$output_text"
  echo "Transcription saved as $output_text"
else
  echo "Error: Whisper failed to generate a transcript."
  exit 1
fi

# Cleanup
echo "Cleaning up temporary files..."
rm "$file_list"

# Deactivate virtual environment after completion
deactivate

echo "Done!"

