#!/usr/bin/env python3
"""Generate test-owned synthetic tone fixtures for development.

These files are NOT Quran recitation and must never be presented as such. They exist so
playback, transitions, resume, and CarPlay flows can be exercised before production audio
permissions are resolved. Output is small AAC (.m4a) created with the macOS `afconvert`.

Usage: Scripts/generate-test-audio.py [output-dir]
Default output: App/Resources/TestAudio
"""
import math
import os
import struct
import subprocess
import sys
import tempfile
import wave

SAMPLE_RATE = 22050

# (name, base frequency Hz, duration seconds, beeps per second)
FIXTURES = [
    ("test-tone-a", 440.0, 12.0, 1.0),
    ("test-tone-b", 554.4, 18.0, 2.0),
    ("test-tone-c", 659.3, 24.0, 0.5),
]


def render(freq: float, seconds: float, beeps_per_second: float) -> bytes:
    frames = bytearray()
    total = int(seconds * SAMPLE_RATE)
    beep_period = SAMPLE_RATE / beeps_per_second
    for i in range(total):
        t = i / SAMPLE_RATE
        phase_in_beep = (i % beep_period) / beep_period
        # 40% duty-cycle beep with a short fade to avoid clicks.
        if phase_in_beep < 0.4:
            edge = min(phase_in_beep / 0.02, (0.4 - phase_in_beep) / 0.02, 1.0)
            amplitude = 0.3 * edge
        else:
            amplitude = 0.0
        # Rising pitch over the file so position is audible when seeking/resuming.
        f = freq * (1.0 + 0.5 * (t / seconds))
        sample = int(32767 * amplitude * math.sin(2 * math.pi * f * t))
        frames += struct.pack("<h", sample)
    return bytes(frames)


def main() -> int:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "App", "Resources", "TestAudio")
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, freq, seconds, bps in FIXTURES:
            wav_path = os.path.join(tmp, f"{name}.wav")
            with wave.open(wav_path, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SAMPLE_RATE)
                w.writeframes(render(freq, seconds, bps))
            m4a_path = os.path.join(out_dir, f"{name}.m4a")
            subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "48000", wav_path, m4a_path], check=True)
            print(f"wrote {m4a_path} ({os.path.getsize(m4a_path)} bytes, {seconds:.0f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
