#!/usr/bin/env python3
"""Generate original sound effects + music for Shadow Assassin (WAV, 22050 Hz mono).

All sounds are synthesized from scratch with sine/square/triangle waves and
shaped noise - no samples, no copied audio.
"""
import math
import os
import random
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


def noise_burst(dur, vol=0.4, seed=7):
    rng = random.Random(seed)
    n = int(SR * dur)
    out = []
    for i in range(n):
        env = 1.0 - (i / n) ** 2
        out.append((rng.random() * 2 - 1) * vol * env)
    return out


def mix(a, b):
    n = max(len(a), len(b))
    a = a + [0.0] * (n - len(a))
    b = b + [0.0] * (n - len(b))
    return [x + y for x, y in zip(a, b)]


def at(samples, offset_sec):
    """Place samples at an offset (seconds) inside a zero buffer."""
    n = int(SR * offset_sec)
    return [0.0] * n + samples


def pad_to(samples, dur):
    n = int(SR * dur)
    return samples + [0.0] * max(0, n - len(samples))


# ---------------------------------------------------------------- original SFX (kept)
save("click.wav", tone(660, 0.07, 0.4, "square"))
save("coin.wav", seq([(988, 0.07, 0.45), (1319, 0.12, 0.45)]))
save("gem.wav", seq([(784, 0.07, 0.45), (1047, 0.07, 0.45), (1568, 0.14, 0.45)]))
save("poof.wav", mix(noise_burst(0.25, 0.35), tone(300, 0.25, 0.3, "sine", 90)))
save("caught.wav", seq([(392, 0.12, 0.5, "square"), (311, 0.12, 0.5, "square"),
                        (233, 0.25, 0.5, "square")]))

# step: soft footstep (quiet low thump + faint scuff), restyled
save("step.wav", mix(tone(95, 0.07, 0.22, "sine", 55),
                     noise_burst(0.05, 0.07, seed=21)))

# alert: REPLACE - short tense sting (dissonant minor-second hit, twice)
save("alert.wav", seq([(622, 0.16, 0.42, "square"), (659, 0.16, 0.42, "square"),
                       (622, 0.3, 0.42, "square", 580)]))

# win: REPLACE - upbeat ascending arpeggio + resolving chord
win = seq([(523, 0.1, 0.45, "triangle"), (659, 0.1, 0.45, "triangle"),
           (784, 0.1, 0.45, "triangle"), (1047, 0.14, 0.5, "triangle"),
           (1319, 0.3, 0.5, "triangle")])
save("win.wav", win)


# ---------------------------------------------------------------- NEW sounds
def sweep_tone(freq0, freq1, dur, vol, wave_type="sine"):
    """Frequency sweep with continuous phase (no click) and exp decay."""
    n = int(SR * dur)
    out, phase = [], 0.0
    for i in range(n):
        f = freq0 + (freq1 - freq0) * (i / n)
        phase += 2 * math.pi * f / SR
        if wave_type == "sine":
            v = math.sin(phase)
        else:
            v = 1.0 if math.sin(phase) >= 0 else -1.0
            v *= 0.6
        env = math.exp(-4.0 * i / n)
        out.append(v * vol * env)
    return out


def shaped_noise(dur, vol, seed, attack=0.02, decay_pow=2.0):
    """Noise with a fast attack and smooth decay (whoosh / crack body)."""
    rng = random.Random(seed)
    n = int(SR * dur)
    out = []
    a_n = max(1, int(SR * attack))
    for i in range(n):
        if i < a_n:
            env = i / a_n
        else:
            env = (1.0 - (i - a_n) / (n - a_n)) ** decay_pow
        out.append((rng.random() * 2 - 1) * vol * env)
    return out


# kill: knife slash (high sweep down + whoosh) + heavy low thud
kill = mix(
    mix(sweep_tone(2400, 320, 0.14, 0.32),
        at(shaped_noise(0.16, 0.5, seed=41), 0.0)),
    mix(at(sweep_tone(150, 45, 0.28, 0.75), 0.06),
        at(shaped_noise(0.1, 0.3, seed=42), 0.06)))
save("kill.wav", pad_to(kill, 0.5))

# shoot: sharp crack - fast noise burst + low square punch
shoot = mix(shaped_noise(0.09, 0.9, seed=55, attack=0.002, decay_pow=3.0),
            mix(sweep_tone(190, 65, 0.13, 0.45, "square"),
                at(noise_burst(0.14, 0.16, seed=56), 0.02)))
save("shoot.wav", pad_to(shoot, 0.3))

# cash: register pop + ascending coin cascade
cash = mix(at(shaped_noise(0.03, 0.4, seed=61, attack=0.002), 0.0),
           mix(at(tone(1319, 0.09, 0.35), 0.05),
               mix(at(tone(1568, 0.09, 0.35), 0.14),
                   mix(at(tone(1760, 0.09, 0.35), 0.23),
                       mix(at(tone(2093, 0.12, 0.35), 0.32),
                           at(tone(2637, 0.2, 0.32), 0.44))))))
save("cash.wav", pad_to(cash, 0.7))

# multikill: short triumphant sting - fast major arpeggio + chord hit
multi = mix(
    mix(at(tone(523, 0.11, 0.4, "triangle"), 0.0),
        mix(at(tone(659, 0.11, 0.4, "triangle"), 0.09),
            mix(at(tone(784, 0.11, 0.4, "triangle"), 0.18),
                at(tone(1047, 0.3, 0.45, "triangle"), 0.27)))),
    mix(at(tone(523, 0.4, 0.16, "sine"), 0.27),
        mix(at(tone(659, 0.4, 0.16, "sine"), 0.27),
            at(tone(784, 0.4, 0.16, "sine"), 0.27))))
save("multikill.wav", pad_to(multi, 0.8))

# lose: low descending defeat sting over a dark drone
lose = mix(
    mix(at(tone(233, 0.28, 0.42, "triangle"), 0.0),
        mix(at(tone(196, 0.28, 0.42, "triangle"), 0.26),
            mix(at(tone(155, 0.3, 0.42, "triangle"), 0.52),
                at(tone(110, 0.5, 0.45, "triangle"), 0.78)))),
    tone(55, 1.2, 0.14, "sine"))
save("lose.wav", pad_to(lose, 1.3))


# hurt: player hit - low thud + short grunt-ish tone, ~0.3 s
hurt = mix(
    mix(sweep_tone(170, 85, 0.22, 0.5, "square"),
        at(sweep_tone(120, 45, 0.2, 0.8), 0.0)),
    at(shaped_noise(0.08, 0.25, seed=71, attack=0.002), 0.0))
save("hurt.wav", pad_to(hurt, 0.3))

# explode: trap explosion - loud noise burst + deep low boom, ~0.8 s
explode = mix(
    mix(shaped_noise(0.55, 0.9, seed=73, attack=0.002, decay_pow=2.5),
        at(shaped_noise(0.3, 0.6, seed=74, attack=0.002), 0.02)),
    mix(at(sweep_tone(130, 28, 0.7, 0.85), 0.0),
        at(sweep_tone(90, 35, 0.5, 0.5, "square"), 0.05)))
save("explode.wav", pad_to(explode, 0.8))

# freeze: cryo mine - descending icy shimmer, ~0.6 s
freeze = mix(
    mix(sweep_tone(2400, 650, 0.5, 0.22),
        at(sweep_tone(3200, 900, 0.4, 0.12), 0.02)),
    mix(at(tone(2093, 0.1, 0.25), 0.0),
        mix(at(tone(1760, 0.1, 0.25), 0.12),
            mix(at(tone(1319, 0.12, 0.25), 0.24),
                at(tone(1047, 0.2, 0.22), 0.36)))))
save("freeze.wav", pad_to(freeze, 0.6))


# ---------------------------------------------------------------- NEW: background music loop (seamless, 32 s)
# 120 BPM, 4/4: beat = 0.5 s, bar = 2 s, 16 bars = 32 s.
# Tense and minimal: pulsing minor bassline + soft kick each beat + dark drone
# pad + sparse offbeat ticks. Every element is periodic over the 32 s loop
# (integer cycles / envelopes that decay to zero inside their beat), so the
# seam is click-free.
def music_loop():
    dur = 32.0
    n = int(SR * dur)
    out = [0.0] * n
    # Bassline: one eighth-note (0.25 s) per step, Am / F / C / G roots.
    # Phase accumulates continuously, so pitch steps never click.
    roots = [55.0, 55.0, 55.0, 55.0,   # Am
             43.65, 43.65, 43.65, 43.65,  # F
             65.41, 65.41, 65.41, 65.41,  # C
             49.0, 49.0, 49.0, 49.0]      # G
    steps = [0, 0, 1, 0, 2, 0, 1, 0]  # scale degrees per bar (root, root, 3rd...)
    # note freqs per chord: root, minor/major 3rd, 5th (x2 octave for pulse)
    chord_notes = {
        55.0: [55.0, 65.41, 82.41, 110.0],
        43.65: [43.65, 52.0, 65.41, 87.31],
        65.41: [65.41, 82.41, 98.0, 130.81],
        49.0: [49.0, 61.74, 73.42, 98.0],
    }
    phase = 0.0
    step_len = int(SR * 0.25)
    for bar in range(16):
        root = roots[bar]
        notes = chord_notes[root]
        for s in range(8):
            f = notes[steps[s]]
            for i in range(step_len):
                idx = bar * 8 * step_len + s * step_len + i
                if idx >= n:
                    break
                phase += 2 * math.pi * f / SR
                env = 0.9 if i < step_len // 8 else math.exp(-3.0 * (i - step_len // 8) / step_len)
                out[idx] += math.sin(phase) * 0.30 * env
                out[idx] += math.sin(phase * 2.0) * 0.08 * env  # octave shimmer
    # Kick: soft sine drop on every beat, decayed fully inside the beat.
    for beat in range(64):
        start = int(SR * beat * 0.5)
        klen = int(SR * 0.16)
        ph = 0.0
        for i in range(klen):
            f = 120.0 + (38.0 - 120.0) * (i / klen)
            ph += 2 * math.pi * f / SR
            out[start + i] += math.sin(ph) * 0.42 * math.exp(-6.0 * i / klen)
    # Dark drone pad: frequencies with an integer number of cycles in 32 s,
    # slow 8 s LFO (4 cycles in the loop) - perfectly periodic, no seam.
    for k, (freq, vol) in enumerate([(55.0, 0.05), (110.0, 0.035),
                                     (164.8125, 0.025), (220.0, 0.018)]):
        for i in range(n):
            t = i / SR
            lfo = 0.75 + 0.25 * math.sin(2 * math.pi * (i / (SR * 8.0)) + k)
            out[i] += math.sin(2 * math.pi * freq * t) * vol * lfo
    # Sparse offbeat ticks (hat): short noise, decayed inside the beat.
    rng = random.Random(99)
    for beat in range(64):
        start = int(SR * (beat * 0.5 + 0.25))
        tlen = int(SR * 0.04)
        for i in range(tlen):
            out[start + i] += (rng.random() * 2 - 1) * 0.07 * (1.0 - i / tlen) ** 2
    # Sparse tense ping every 2 bars, decayed long before the next one.
    for bar in (2, 6, 10, 14):
        start = int(SR * bar * 2.0)
        plen = int(SR * 0.9)
        for i in range(plen):
            t = i / SR
            out[start + i] += math.sin(2 * math.pi * 880.0 * t) * 0.05 * math.exp(-4.0 * t)
    return [max(-0.95, min(0.95, s)) for s in out]


save("music_loop.wav", music_loop())
print("done")
