"""Validate the PCM WAV assets decoded by prepare_door_audio.gd."""
from pathlib import Path
import wave

for event in ("door_open", "door_close"):
    with wave.open(str(Path("assets/audio") / f"{event}.wav")) as source:
        assert source.getnchannels() == 1 and source.getsampwidth() == 2
        assert source.getnframes() > 0
        print(event, source.getframerate(), source.getnframes() / source.getframerate(), "seconds")
