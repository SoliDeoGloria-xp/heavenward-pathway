#!/usr/bin/env python3
"""Make the game's placeholder sound effects (short synthesized tones, no samples).

    python3 tools/gen_sfx.py      # writes assets/audio/sfx/<id>.wav

Replace any file with a recorded sound of the same name; the game picks it up unchanged.
"""
import wave
from pathlib import Path
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"

def tone(freq, secs, vol=0.5, decay=6.0, shape="sine"):
    t = np.linspace(0, secs, int(RATE * secs), endpoint=False)
    w = np.sin(2 * np.pi * freq * t) if shape == "sine" else np.sign(np.sin(2 * np.pi * freq * t)) * 0.5
    return w * vol * np.exp(-decay * t)

def noise(secs, vol=0.4, decay=18.0, seed=1):
    t = np.linspace(0, secs, int(RATE * secs), endpoint=False)
    n = np.random.default_rng(seed).uniform(-1, 1, len(t))
    n = np.convolve(n, np.ones(6) / 6, mode="same")          # soften the hiss into a thud
    return n * vol * np.exp(-decay * t)

def seq(*parts):
    return np.concatenate(parts)

def mix(a, b):
    n = max(len(a), len(b)); out = np.zeros(n); out[:len(a)] += a; out[:len(b)] += b
    return out

SOUNDS = {
    "hit": mix(noise(0.09, 0.5), tone(150, 0.09, 0.4, 25)),
    "hurt": mix(noise(0.12, 0.4, 14, 2), tone(95, 0.14, 0.5, 16)),
    "skill": mix(tone(520, 0.22, 0.35, 9), tone(780, 0.22, 0.2, 9)),
    "quest": seq(tone(660, 0.11, 0.4, 7), tone(880, 0.26, 0.4, 6)),
    "level": seq(tone(523, 0.1, 0.4, 5), tone(659, 0.1, 0.4, 5), tone(784, 0.1, 0.4, 5), tone(1047, 0.4, 0.4, 4)),
    "coin": seq(tone(1320, 0.05, 0.3, 20), tone(1760, 0.16, 0.3, 14)),
    "equip": mix(noise(0.05, 0.3, 40, 3), tone(330, 0.12, 0.3, 18)),
    "bell": mix(tone(1568, 0.9, 0.35, 3.5), tone(3136, 0.9, 0.12, 5)),
}

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in SOUNDS.items():
        pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
        with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())
    print(f"gen_sfx: wrote {len(SOUNDS)} sounds to {OUT}")

if __name__ == "__main__":
    main()
