"""Procedural background music for Toxic Wasteland.

Writes a seamless 32 second ambient loop (A minor, 60 BPM, 8 bars) to
Assets/Music/wasteland_loop.wav. Pure stdlib (wave/math/random).

Run: python tools/gen_music.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
BPM = 60.0
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
BARS = 8
DUR = BAR * BARS          # 32 s
N = int(SR * DUR)
OUT = os.path.join("Assets", "Music")

# A minor: i - VI - III - VII, two bars each
CHORDS = [
    (55.00, [220.00, 261.63, 329.63, 440.00]),    # Am
    (43.65, [174.61, 220.00, 261.63, 349.23]),    # F
    (65.41, [196.00, 261.63, 329.63, 392.00]),    # C
    (49.00, [196.00, 246.94, 293.66, 392.00]),    # G
]

PENTA = [440.00, 523.25, 587.33, 659.25, 783.99, 880.00]


def add(buf, i, v):
    if 0 <= i < N:
        buf[i] += v


def drone(buf, freq, amp):
    """Very low sustained tone with slow breathing."""
    for i in range(N):
        t = i / SR
        env = 0.75 + 0.25 * math.sin(2.0 * math.pi * t / 16.0)
        add(buf, i, amp * env * math.sin(2.0 * math.pi * freq * t))


def pad_note(buf, freq, start, dur, amp):
    """Soft detuned pad with slow attack/release."""
    a = 1.6
    r = 2.4
    end = start + dur
    for i in range(max(0, int(start * SR)), min(N, int(end * SR))):
        t = i / SR
        lt = t - start
        if lt < a:
            env = lt / a
        elif t > end - r:
            env = max(0.0, (end - t) / r)
        else:
            env = 1.0
        env = env * env * (3.0 - 2.0 * env)
        phase = 2.0 * math.pi * freq * t
        v = math.sin(phase) + 0.5 * math.sin(phase * 1.003) + 0.35 * math.sin(phase * 0.5)
        add(buf, i, amp * env * v / 1.85)


def bass(buf, freq, start, amp):
    """Plucked low pulse on the bar downbeat."""
    dur = 1.8
    for i in range(max(0, int(start * SR)), min(N, int((start + dur) * SR))):
        t = i / SR - start
        env = math.exp(-2.6 * t) * min(1.0, t * 60.0)
        v = math.sin(2.0 * math.pi * freq * t) + 0.25 * math.sin(4.0 * math.pi * freq * t)
        add(buf, i, amp * env * v)


def bell(buf, freq, start, amp):
    """Sparse melody note: two partials, long decay."""
    dur = 3.2
    for i in range(max(0, int(start * SR)), min(N, int((start + dur) * SR))):
        t = i / SR - start
        env = math.exp(-1.9 * t) * min(1.0, t * 90.0)
        v = math.sin(2.0 * math.pi * freq * t) + 0.4 * math.sin(2.0 * math.pi * freq * 2.01 * t)
        add(buf, i, amp * env * v / 1.4)


def wind(buf, amp, seed=7):
    """One-pole filtered noise bed, slowly swelling."""
    rng = random.Random(seed)
    lp = 0.0
    for i in range(N):
        lp += (rng.uniform(-1.0, 1.0) - lp) * 0.035
        t = i / SR
        env = 0.55 + 0.45 * math.sin(2.0 * math.pi * t / 21.0 + 0.7)
        add(buf, i, amp * env * lp)


def build():
    buf = [0.0] * N

    drone(buf, 55.00, 0.115)          # A1
    drone(buf, 82.41, 0.055)          # E2
    drone(buf, 110.0, 0.035)          # A2

    for bar in range(BARS):
        root, tones = CHORDS[(bar // 2) % len(CHORDS)]
        start = bar * BAR
        bass(buf, root, start, 0.20)
        for k, f in enumerate(tones):
            pad_note(buf, f, start, BAR * 2.05, 0.052 - k * 0.006)

    # melody: one or two notes per bar, pentatonic, leaving space
    rng = random.Random(19)
    for bar in range(BARS):
        if bar % 2 == 1:
            continue
        start = bar * BAR + BEAT * 2.0
        bell(buf, rng.choice(PENTA[:4]), start, 0.085)
        if bar % 4 == 0:
            bell(buf, rng.choice(PENTA[2:]), start + BEAT * 1.5, 0.055)

    wind(buf, 0.055)

    # seam: fade the continuous layers so the loop point is silent-clean
    fade = int(SR * 0.45)
    for i in range(fade):
        k = i / fade
        buf[i] *= k
        buf[N - 1 - i] *= k

    peak = max(1e-6, max(abs(v) for v in buf))
    gain = 0.82 / peak
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "wasteland_loop.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for v in buf:
            s = int(max(-1.0, min(1.0, v * gain)) * 32767)
            frames += struct.pack("<h", s)
        w.writeframes(bytes(frames))
    print("wrote", path, "%.1fs" % DUR)


if __name__ == "__main__":
    build()
