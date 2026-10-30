#!/usr/bin/env python3
"""
Synthesizes 1920s Chicago speakeasy / casino sound effects (16-bit 44.1kHz mono WAV).
Strictly adheres to project rule: NO nature sounds (no rain, wind, ocean, birds, animals).
"""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT_DIR, exist_ok=True)

def write_wav(filename, samples):
    path = os.path.join(OUT_DIR, filename)
    data = bytearray()
    for s in samples:
        # clamp to 16-bit signed integer
        val = int(max(-32767.0, min(32767.0, s * 32767.0)))
        data.extend(struct.pack('<h', val))
    with wave.open(path, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(data)
    print(f"Generated {filename}: {len(samples)/SAMPLE_RATE:.3f}s ({len(data)} bytes)")

def gen_card_snap():
    # 0.18s: quick felt slide friction + sharp card snap + low body thump
    duration = 0.18
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(42)
    for i in range(n):
        t = i / SAMPLE_RATE
        # early friction (0.0 to 0.03s)
        fric = 0.0
        if t < 0.035:
            fric = rng.uniform(-0.15, 0.15) * math.sin(t / 0.035 * math.pi)
        # sharp snap at 0.035s
        snap = 0.0
        if t >= 0.035:
            dt = t - 0.035
            env_snap = math.exp(-90.0 * dt)
            # snap high frequencies
            snap_hi = (math.sin(2.0 * math.pi * 3200.0 * dt) * 0.4 +
                       math.sin(2.0 * math.pi * 1850.0 * dt) * 0.35 +
                       rng.uniform(-0.25, 0.25)) * env_snap
            # felt table body thump
            env_body = math.exp(-45.0 * dt)
            body = math.sin(2.0 * math.pi * 180.0 * dt) * 0.5 * env_body
            snap = snap_hi + body
        samples[i] = (fric + snap) * 0.85
    return samples

def gen_chip_clink():
    # 0.22s: heavy clay speakeasy chips - first micro-contact at 0.0s, main clink at 0.025s
    duration = 0.22
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(101)
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        # tap 1
        if t < 0.08:
            env1 = math.exp(-60.0 * t)
            val += (math.sin(2.0 * math.pi * 2800.0 * t) * 0.3 +
                    math.sin(2.0 * math.pi * 4400.0 * t) * 0.2) * env1
        # main crisp clink at t = 0.022s
        if t >= 0.022:
            dt = t - 0.022
            env2 = math.exp(-40.0 * dt)
            # ceramic resonance partials
            res = (math.sin(2.0 * math.pi * 2350.0 * dt) * 0.45 +
                   math.sin(2.0 * math.pi * 3720.0 * dt) * 0.35 +
                   math.sin(2.0 * math.pi * 5640.0 * dt) * 0.15 +
                   rng.uniform(-0.1, 0.1) * math.exp(-120.0 * dt)) * env2
            val += res
        samples[i] = val * 0.8
    return samples

def gen_dice_cup():
    # 0.38s: leather dice cup rattle: multiple dice bouncing inside leather
    duration = 0.38
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(77)
    # 4 distinct impact points as dice tumble
    t_hits = [0.02, 0.09, 0.17, 0.25, 0.31]
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        for hit_t in t_hits:
            if t >= hit_t:
                dt = t - hit_t
                if dt < 0.06:
                    env = math.exp(-75.0 * dt)
                    # dull hollow wooden die impact on leather (450Hz, 820Hz, 1400Hz)
                    val += (math.sin(2.0 * math.pi * 480.0 * dt) * 0.35 +
                            math.sin(2.0 * math.pi * 920.0 * dt) * 0.25 +
                            rng.uniform(-0.15, 0.15)) * env
        samples[i] = val * 0.75
    return samples

def gen_gavel():
    # 0.35s: solid mahogany desk knock / deal struck
    duration = 0.35
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(99)
    for i in range(n):
        t = i / SAMPLE_RATE
        env_impact = math.exp(-30.0 * t)
        env_tail = math.exp(-15.0 * t)
        # heavy wooden transient
        transient = rng.uniform(-0.3, 0.3) * math.exp(-140.0 * t)
        wood_low = math.sin(2.0 * math.pi * 145.0 * t) * 0.6 * env_impact
        wood_mid = math.sin(2.0 * math.pi * 380.0 * t) * 0.35 * env_impact
        wood_ring = math.sin(2.0 * math.pi * 620.0 * t) * 0.2 * env_tail
        samples[i] = (transient + wood_low + wood_mid + wood_ring) * 0.85
    return samples

def gen_police_whistle():
    # 0.70s: 1920s brass pea-whistle - dual tone with pea warble (no modern electronic siren)
    duration = 0.70
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(33)
    for i in range(n):
        t = i / SAMPLE_RATE
        # envelope: quick attack, sustained blast, rapid release
        if t < 0.05:
            env = t / 0.05
        elif t > 0.62:
            env = max(0.0, (0.70 - t) / 0.08)
        else:
            env = 1.0
        # pea rattle frequency: ~28Hz modulation
        pea = 1.0 + 0.12 * math.sin(2.0 * math.pi * 28.0 * t)
        f1 = 2650.0 * pea
        f2 = 2980.0 * pea
        tone = (math.sin(2.0 * math.pi * f1 * t) * 0.45 +
                math.sin(2.0 * math.pi * f2 * t) * 0.40)
        # breath air noise
        breath = rng.uniform(-0.12, 0.12)
        samples[i] = (tone + breath) * env * 0.65
    return samples

def gen_tutorial_bell():
    # 0.75s: brass desk call-bell chime for milestone achievement
    duration = 0.75
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        # inharmonic brass bell partials (F6: 1397Hz, 2760Hz, 4120Hz, 5450Hz)
        env1 = math.exp(-6.0 * t)
        env2 = math.exp(-12.0 * t)
        env3 = math.exp(-22.0 * t)
        strike = math.exp(-80.0 * t) * math.sin(2.0 * math.pi * 820.0 * t) * 0.3
        bell = (math.sin(2.0 * math.pi * 1397.0 * t) * 0.50 * env1 +
                math.sin(2.0 * math.pi * 2760.0 * t) * 0.30 * env2 +
                math.sin(2.0 * math.pi * 4120.0 * t) * 0.15 * env3 +
                math.sin(2.0 * math.pi * 5450.0 * t) * 0.08 * env3)
        samples[i] = (strike + bell) * 0.75
    return samples

def gen_relic_chime():
    # 0.85s: vintage speakeasy music-box / brass chime chord in D minor (D5, F5, A5, D6)
    duration = 0.85
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    freqs = [587.33, 698.46, 880.00, 1174.66]  # D5, F5, A5, D6
    delays = [0.0, 0.04, 0.08, 0.12]           # subtle arpeggiation
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        for f, d in zip(freqs, delays):
            if t >= d:
                dt = t - d
                env = math.exp(-5.5 * dt)
                tone = math.sin(2.0 * math.pi * f * dt) * 0.22 * env
                # overtone
                over = math.sin(2.0 * math.pi * f * 2.0 * dt) * 0.08 * math.exp(-10.0 * dt)
                val += tone + over
        samples[i] = val * 0.85
    return samples

if __name__ == "__main__":
    print("Synthesizing 1920s authentic sound effects...")
    write_wav("card_snap.wav", gen_card_snap())
    write_wav("chip_clink.wav", gen_chip_clink())
    write_wav("dice_cup.wav", gen_dice_cup())
    write_wav("gavel.wav", gen_gavel())
    write_wav("police_whistle.wav", gen_police_whistle())
    write_wav("tutorial_bell.wav", gen_tutorial_bell())
    write_wav("relic_chime.wav", gen_relic_chime())
    print("Done! All sound files synthesized.")
