#!/usr/bin/env python3
"""Generate tiny original sound effects for Shadow Assassin (WAV, 22050 Hz mono).

All sounds are synthesized from scratch with sine/square waves - no samples.
"""
import math
import os
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 22050


def save(name, samples):
    samples = [max(-1.0, min(1.0, s)) for s in samples]
    data = b"".join(struct.pack("<h", int(s * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote", name, f"{len(samples) / SR:.2f}s")


def tone(freq, dur, vol=0.5, wave_type="sine", slide_to=None):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = freq if slide_to is None else freq + (slide_to - freq) * (i / n)
        ph = 2 * math.pi * f * t
        if wave_type == "sine":
            v = math.sin(ph)
        elif wave_type == "square":
            v = 1.0 if math.sin(ph) >= 0 else -1.0
            v *= 0.6
        else:  # triangle
            v = 2 * abs(2 * (t * f % 1) - 1) - 1
        env = 1.0 - (i / n)  # linear decay
        out.append(v * vol * env)
    return out


def seq(notes):
    """notes: list of (freq, dur, vol, wave_type, slide_to)"""
    out = []
    for nt in notes:
        out.extend(tone(*nt))
    return out


def noise_burst(dur, vol=0.4):
    import random
    random.seed(7)
    n = int(SR * dur)
    out = []
    for i in range(n):
        env = 1.0 - (i / n) ** 2
        out.append((random.random() * 2 - 1) * vol * env)
    return out


def mix(a, b):
    n = max(len(a), len(b))
    a = a + [0.0] * (n - len(a))
    b = b + [0.0] * (n - len(b))
    return [x + y for x, y in zip(a, b)]


save("click.wav", tone(660, 0.07, 0.4, "square"))
save("coin.wav", seq([(988, 0.07, 0.45), (1319, 0.12, 0.45)]))
save("gem.wav", seq([(784, 0.07, 0.45), (1047, 0.07, 0.45), (1568, 0.14, 0.45)]))
save("poof.wav", mix(noise_burst(0.25, 0.35), tone(300, 0.25, 0.3, "sine", 90)))
save("alert.wav", seq([(440, 0.1, 0.5, "square"), (330, 0.14, 0.5, "square")]))
save("caught.wav", seq([(392, 0.12, 0.5, "square"), (311, 0.12, 0.5, "square"),
                        (233, 0.25, 0.5, "square")]))
save("win.wav", seq([(523, 0.1, 0.45), (659, 0.1, 0.45), (784, 0.1, 0.45),
                     (1047, 0.22, 0.5)]))
save("step.wav", tone(220, 0.05, 0.18, "triangle"))
print("done")
