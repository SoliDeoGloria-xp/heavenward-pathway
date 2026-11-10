#!/usr/bin/env python3
"""Arrange public-domain hymn tunes as looping map music (instrumental; no words are used).

    python3 tools/gen_music.py        # writes assets/audio/music/<id>.ogg (needs ffmpeg)

Tunes, all long in the public domain:
  NEW BRITAIN ("Amazing Grace"), Virginia Harmony, 1831
  SLANE ("Be Thou My Vision"), Irish traditional melody
  OLD HUNDREDTH (the Doxology), Genevan Psalter, 1551
  EVENTIDE ("Abide with Me"), W. H. Monk, 1861
Each map gets its own arrangement (instrument, tempo, key, major or minor colouring, with or
without a drum). The sound is synthesized here; replace any .ogg with a recording of the same
name and the game uses it unchanged.
"""
import subprocess, wave
from pathlib import Path
import numpy as np
from scipy.signal import lfilter

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "music"
SEMIS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

TUNES = {   # (tonic, beats per bar, notes as NAME[:beats], default 1 beat)
 "new_britain": ("G", 3, "D4 G4:2 B4:.5 G4:.5 B4:2 A4 G4:2 E4 D4:2 D4 G4:2 B4:.5 G4:.5 B4:2 A4 D5:3 D5:2 B4 D5:1.5 B4:.5 D5:.5 B4:.5 G4:2 D4 E4:1.5 G4:.5 G4:.5 E4:.5 D4:2 D4 G4:2 B4:.5 G4:.5 B4:2 A4 G4:3 G4:2"),
 "slane": ("Eb", 3, "Eb4 Eb4 F4:.5 Eb4:.5 C4 Bb3 C4 Eb4 Eb4 F4 G4:3 F4 F4 F4 F4 G4 Bb4 C5 Bb4 G4 Bb4:3 C5 C5:.5 D5:.5 Eb5:.5 D5:.5 C5 Bb4 G4 Bb4 Eb4 D4 C4:2 Bb3 Eb4 G4 Bb4 C5:.5 Bb4:.5 G4 Eb4:.5 G4:.5 F4 Eb4 Eb4 Eb4:3"),
 "old_hundredth": ("G", 4, "G4:2 G4 F#4 E4 D4 G4:2 A4:2 B4:2 B4:2 B4 B4 A4 G4 C5:2 B4:2 A4:2 G4:2 A4 B4 A4 G4 E4:2 F#4:2 G4:2 D5:2 B4 G4 A4 C5 B4:2 A4:2 G4:4"),
 "eventide": ("Eb", 4, "G4:2 G4 F4 Eb4:2 Bb4:2 C5 Bb4 Bb4 Ab4 G4:4 G4:2 Ab4 Bb4 C5:2 Bb4:2 Ab4 F4 G4 A4 Bb4:4 G4:2 G4 F4 Eb4:2 Bb4:2 Bb4 Ab4 Ab4 G4 F4:4 F4:2 G4 Ab4 G4 F4 Eb4 Ab4 G4:2 F4:2 Eb4:4"),
}
ARRANGE = {  # map music id -> tune, bpm, lead, semitone shift, minor colouring, drum, repeats
 "eden": ("slane", 84, "harp", 0, False, False, 2), "city": ("eventide", 60, "strings", -5, True, False, 1),
 "slough": ("slane", 58, "flute", -3, True, False, 1), "interpreter": ("old_hundredth", 72, "organ", 0, False, False, 2),
 "cross": ("new_britain", 72, "flute", 0, False, False, 2), "hill": ("slane", 108, "harp", 2, False, True, 2),
 "palace": ("old_hundredth", 88, "harp", 5, False, False, 2), "boss": ("old_hundredth", 132, "brass", -2, True, True, 3),
 "valley": ("new_britain", 66, "strings", -2, False, False, 1), "shadow": ("eventide", 50, "pad", -7, True, False, 1),
}

def midi(name: str) -> int:
    letter, rest = name[0], name[1:]
    acc = rest.count("#") - rest.count("b")
    return 12 * (int(rest.lstrip("#b")) + 1) + SEMIS[letter] + acc

def hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)

def env(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n)
    a, r = min(n // 2, int(attack * RATE)), min(n // 2, int(release * RATE))
    if a: e[:a] = np.linspace(0, 1, a)
    if r: e[-r:] *= np.linspace(1, 0, r)
    return e

def voice(kind: str, f: float, secs: float) -> np.ndarray:
    ring = {"harp": 1.4, "brass": 0.15}.get(kind, 0.25)
    n = int((secs + ring) * RATE)
    t = np.arange(n) / RATE
    if kind == "harp":
        w = sum(np.sin(2 * np.pi * f * k * t) / k ** 1.6 for k in range(1, 7)) * np.exp(-t * 2.6)
        return w * env(n, 0.004, 0.1)
    if kind == "flute":
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t * 3, 0, 1)
        w = np.sin(2 * np.pi * f * vib * t) + 0.18 * np.sin(4 * np.pi * f * vib * t) + 0.05 * np.sin(6 * np.pi * f * t)
        return w * env(n, 0.07, 0.22)
    if kind == "organ":
        w = sum(a * np.sin(2 * np.pi * f * k * t) for k, a in ((1, 1), (2, 0.5), (3, 0.25), (4, 0.2), (6, 0.08)))
        return w * env(n, 0.03, 0.2) * 0.7
    if kind == "brass":
        w = sum(np.sin(2 * np.pi * f * k * t) / k for k in range(1, 9)) * (0.7 + 0.3 * np.exp(-t * 6))
        return w * env(n, 0.03, 0.12) * 0.6
    # strings and pad: two slightly detuned stacks with a slow bow
    w = sum(np.sin(2 * np.pi * f * d * k * t) / k ** 1.3 for d in (0.997, 1.003) for k in range(1, 6))
    return w * env(n, 0.22 if kind == "pad" else 0.12, 0.3) * 0.45

def reverb(x: np.ndarray, wet: float = 0.28) -> np.ndarray:
    out = x.copy()
    for ms, g in ((53, 0.42), (79, 0.36), (113, 0.3), (167, 0.24)):
        d = int(RATE * ms / 1000)
        a = np.zeros(d + 1); a[0] = 1; a[d] = -g
        out += wet * lfilter([1], a, x) / 4
    return out

def render(music_id: str) -> np.ndarray:
    tune, bpm, lead, shift, minor, drum, repeats = ARRANGE[music_id]
    tonic, per_bar, score = TUNES[tune]
    beat = 60.0 / bpm
    tonic_pc = (SEMIS[tonic[0]] + tonic.count("#") - tonic.count("b")) % 12
    notes = []
    for tok in score.split():
        name, _, beats = tok.partition(":")
        m = midi(name)
        if minor and (m - tonic_pc) % 12 in (4, 9, 11):      # lower the 3rd, 6th and 7th
            m -= 1
        notes.append((m + shift, float(beats or 1)))
    total_beats = sum(b for _, b in notes)
    length = int((total_beats * repeats * beat + 3.0) * RATE)
    mix = np.zeros(length)
    def put(sig: np.ndarray, at: float, vol: float) -> None:
        i = int(at * RATE); j = min(length, i + len(sig))
        mix[i:j] += sig[:j - i] * vol
    low = 36 + (tonic_pc + shift) % 12                          # tonic in the bass octave
    for rep in range(repeats):
        t0 = rep * total_beats * beat
        pos = 0.0
        for m, beats in notes:
            put(voice(lead, hz(m), beats * beat), t0 + pos * beat, 0.5)
            if rep % 2 == 1 or lead in ("organ", "brass"):      # second time through, an octave below joins
                put(voice("strings", hz(m - 12), beats * beat), t0 + pos * beat, 0.16)
            pos += beats
        bars = int(np.ceil(total_beats / per_bar))
        for bar in range(bars):                                 # open fifth drone, re-bowed every bar: an old, plain harmony
            at = t0 + bar * per_bar * beat
            put(voice("pad", hz(low), per_bar * beat), at, 0.22)
            put(voice("pad", hz(low + 7), per_bar * beat), at, 0.13)
            if lead == "harp":
                for k, step in enumerate((0, 7, 12)[:per_bar]):
                    put(voice("harp", hz(low + 12 + step), beat), at + k * beat, 0.16)
            if drum:
                for k in range(per_bar):
                    n = int(0.16 * RATE); tt = np.arange(n) / RATE
                    thud = np.sin(2 * np.pi * (70 if k == 0 else 110) * tt) * np.exp(-tt * 26)
                    put(thud, at + k * beat, 0.5 if k == 0 else 0.22)
    mix = reverb(mix)
    return mix / (np.abs(mix).max() + 1e-9) * 0.82

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for music_id in ARRANGE:
        pcm = (render(music_id) * 32767).astype("<i2")
        wav = OUT / f"{music_id}.wav"
        with wave.open(str(wav), "wb") as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3", str(OUT / f"{music_id}.ogg")], check=True)
        wav.unlink()
        print(f"  {music_id}: {len(pcm) / RATE:.0f} s")
    print(f"gen_music: wrote {len(ARRANGE)} loops")

if __name__ == "__main__":
    main()
