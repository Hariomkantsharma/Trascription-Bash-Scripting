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
