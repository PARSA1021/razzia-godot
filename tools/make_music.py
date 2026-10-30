#!/usr/bin/env python3
"""Background music for Razzia (Phase 26): a slow prohibition-era noir jazz loop, written note by note here and rendered
with FluidSynth + the FluidR3_GM soundfont (MIT licence). Also a tension bed for duels / raids in the same key.

    python3 tools/make_music.py [out_dir]       -> noir_jazz_loop.ogg, tension_loop.ogg, menu_theme.ogg, final_round.ogg

Phase 28 added two cues in the same key (D minor), so the music can cross-fade between them without a jump:
  menu_theme   the title screen: 72 bpm, a slow two-feel ballad - arpeggiated piano, soft string pad, brush swirls, a far
               muted trumpet. More air than the table music; it sets the room before the first card.
  final_round  the last round: 116 bpm, the same harmony family pushed - driving walking bass, sticks on the ride, off-beat
               piano stabs, a low trombone ostinato and a trumpet motif that climbs a half step. Tense, never loud.

Needs: mido (pip), fluidsynth, ffmpeg, /usr/share/sounds/sf2/FluidR3_GM.sf2
Seamless loop: the piece is rendered three times in a row and the middle pass is cut out, so the reverb tail of the end
is already sounding at the start - the loop point is inaudible.

The piece: D minor, 88 bpm swing, 32 bars (AABA). Brushes, walking upright bass, piano comping in rootless voicings,
a muted trumpet that states the theme in A1 and A3 (A2 and the bridge stay quiet - it plays under a card game for a long
time, so it must never become tiring), vibraphone in the bridge.
"""
import os
import random
import subprocess
import sys

import mido

SF2 = "/usr/share/sounds/sf2/FluidR3_GM.sf2"
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
TMP = os.environ.get("TMPDIR", "/tmp")
TPB = 480                      # ticks per beat
BPM = 88
SWING = 2.0 / 3.0              # off-beat eighths land on the third triplet

# --- harmony: 32 bars, each bar = list of (chord, beats)
A1 = [[("Dm6", 4)], [("Dm6", 4)], [("Em7b5", 2), ("A7b9", 2)], [("Dm6", 4)],
      [("Gm7", 4)], [("C7", 4)], [("Fmaj7", 4)], [("Em7b5", 2), ("A7", 2)]]
A2 = [[("Dm6", 4)], [("Dm6", 4)], [("Em7b5", 2), ("A7b9", 2)], [("Dm6", 4)],
      [("Gm7", 4)], [("A7b9", 4)], [("Dm6", 4)], [("Dm6", 4)]]
B = [[("Gm7", 4)], [("C7", 4)], [("Fmaj7", 4)], [("Bbmaj7", 4)],
     [("Em7b5", 4)], [("A7", 4)], [("Dm6", 4)], [("A7alt", 4)]]
A3 = A1[:6] + [[("Dm6", 4)], [("Em7b5", 2), ("A7b9", 2)]]
FORM = A1 + A2 + B + A3

ROOT = {"DmMaj7": 38, "Dm7": 38, "Bb7": 34, "Ebmaj7": 39, "Gm6": 43, "Eb7b5": 39, "Dm": 38, "Dm6": 38, "Em7b5": 40, "A7b9": 33, "A7": 33, "A7alt": 33, "Gm7": 43, "C7": 36, "Fmaj7": 41, "Bbmaj7": 34}
# chord tones for the bass (semitones above the root)
TONES = {"DmMaj7": [0, 3, 7, 11], "Dm7": [0, 3, 7, 10], "Bb7": [0, 4, 7, 10], "Ebmaj7": [0, 4, 7, 11],
         "Gm6": [0, 3, 7, 9], "Eb7b5": [0, 4, 6, 10], "Dm": [0, 3, 7, 12], "Dm6": [0, 3, 7, 9], "Em7b5": [0, 3, 6, 10], "A7b9": [0, 4, 7, 10], "A7": [0, 4, 7, 10], "A7alt": [0, 4, 8, 10],
         "Gm7": [0, 3, 7, 10], "C7": [0, 4, 7, 10], "Fmaj7": [0, 4, 7, 11], "Bbmaj7": [0, 4, 7, 11]}
# rootless piano voicings around middle C
VOICE = {"DmMaj7": [53, 57, 61, 64], "Dm7": [53, 57, 60, 64], "Bb7": [50, 56, 62, 67], "Ebmaj7": [51, 55, 58, 62],
         "Gm6": [52, 58, 62, 67], "Eb7b5": [49, 55, 61, 67], "Dm": [50, 57, 62, 65], "Dm6": [53, 59, 62, 69], "Em7b5": [55, 62, 64, 70], "A7b9": [55, 61, 64, 70], "A7": [55, 61, 66, 71],
         "A7alt": [55, 61, 65, 70], "Gm7": [53, 58, 62, 69], "C7": [52, 58, 62, 69], "Fmaj7": [52, 57, 60, 67],
         "Bbmaj7": [50, 57, 60, 65]}

# --- theme (muted trumpet): (bar index within the 8-bar section, beat, midi note, beats)
N = {"A3": 57, "B3": 59, "C4": 60, "D4": 62, "E4": 64, "F4": 65, "G4": 67, "A4": 69, "Bb4": 70, "B4": 71, "C5": 72,
     "Cs5": 73, "D5": 74, "E5": 76, "F5": 77, "G5": 79, "A5": 81, "Cs4": 61}
THEME = [
    (0, 1.0, "A4", 1.0), (0, 2.0, "B4", 0.5), (0, 2.5, "A4", 0.5), (0, 3.0, "F4", 1.0),
    (1, 0.0, "D4", 3.0),
    (2, 0.0, "E4", 1.0), (2, 1.0, "G4", 1.0), (2, 2.0, "Bb4", 1.0), (2, 3.0, "Cs5", 1.0),
    (3, 0.0, "D5", 2.5), (3, 3.0, "A4", 1.0),
    (4, 0.0, "Bb4", 1.5), (4, 1.5, "A4", 0.5), (4, 2.0, "G4", 2.0),
    (5, 0.0, "E4", 1.0), (5, 1.0, "G4", 0.5), (5, 1.5, "Bb4", 0.5), (5, 2.0, "A4", 2.0),
    (6, 0.0, "A4", 0.5), (6, 0.5, "G4", 0.5), (6, 1.0, "F4", 1.0), (6, 2.0, "E4", 1.0), (6, 3.0, "F4", 1.0),
    (7, 0.0, "E4", 2.0),
]
THEME_END = THEME[:18] + [(6, 0.0, "F4", 0.5), (6, 0.5, "E4", 0.5), (6, 1.0, "D4", 3.0), (7, 2.5, "A3", 0.5), (7, 3.0, "Cs4", 1.0)]
BRIDGE = [  # vibraphone over the bridge
    (0, 0.0, "D5", 1.5), (0, 1.5, "Bb4", 0.5), (0, 2.0, "G4", 2.0),
    (1, 0.0, "E5", 1.0), (1, 1.0, "D5", 0.5), (1, 1.5, "C5", 0.5), (1, 2.0, "Bb4", 2.0),
    (2, 0.0, "A4", 3.0),
    (3, 0.0, "D5", 1.0), (3, 1.0, "F5", 1.0), (3, 2.0, "A5", 2.0),
    (4, 0.0, "G5", 1.5), (4, 1.5, "F5", 0.5), (4, 2.0, "E5", 1.0), (4, 3.0, "D5", 1.0),
    (5, 0.0, "Cs5", 2.0), (5, 2.0, "E5", 1.0), (5, 3.0, "G5", 1.0),
    (6, 0.0, "F5", 2.0), (6, 2.0, "D5", 2.0),
    (7, 0.0, "Cs5", 2.0),
]


def t(beat: float) -> int:
    """beat position -> ticks, with swing on the off-beat eighths"""
    whole = int(beat)
    frac = beat - whole
    if abs(frac - 0.5) < 1e-6:
        frac = SWING
    return int(round((whole + frac) * TPB))


class Track:
    def __init__(self, ch: int, program: int, bank: int = 0, vol: int = 100, pan: int = 64, reverb: int = 50):
        self.ch = ch
        self.ev = []           # (tick, order, msg)
        self.ev.append((0, 0, mido.Message("control_change", channel=ch, control=0, value=bank)))
        self.ev.append((0, 0, mido.Message("program_change", channel=ch, program=program)))
        self.ev.append((0, 0, mido.Message("control_change", channel=ch, control=7, value=vol)))
        self.ev.append((0, 0, mido.Message("control_change", channel=ch, control=10, value=pan)))
        self.ev.append((0, 0, mido.Message("control_change", channel=ch, control=91, value=reverb)))

    def note(self, start: int, dur: int, n: int, vel: int) -> None:
        vel = max(1, min(127, vel))
        self.ev.append((start, 2, mido.Message("note_on", channel=self.ch, note=n, velocity=vel)))
        self.ev.append((start + max(10, dur), 1, mido.Message("note_off", channel=self.ch, note=n, velocity=0)))

    def to_track(self) -> mido.MidiTrack:
        tr = mido.MidiTrack()
        last = 0
        for tick, _, msg in sorted(self.ev, key=lambda e: (e[0], e[1])):
            tr.append(msg.copy(time=tick - last))
            last = tick
        return tr


def song(passes: int, seed: int = 7) -> mido.MidiFile:
    rnd = random.Random(seed)
    bars = len(FORM)
    bass = Track(0, 32, vol=112, pan=58, reverb=30)                 # acoustic bass
    piano = Track(1, 0, vol=72, pan=74, reverb=60)                  # grand piano, soft
    horn = Track(2, 59, vol=86, pan=50, reverb=78)                  # muted trumpet
    vibes = Track(3, 11, vol=70, pan=80, reverb=80)                 # vibraphone
    drums = Track(9, 40, vol=92, reverb=40)                          # brush kit (channel 10 = percussion bank)
    for p in range(passes):
        for b, chords in enumerate(FORM):
            bar0 = (p * bars + b) * 4
            # ---- bass: walking quarters, chord tone on the beat, chromatic approach into the next chord
            beat = 0
            for ci, (ch, length) in enumerate(chords):
                nxt = chords[ci + 1][0] if ci + 1 < len(chords) else FORM[(b + 1) % bars][0][0]
                root = ROOT[ch]
                for k in range(length):
                    if k == 0:
                        n = root
                    elif k == length - 1:
                        target = ROOT[nxt]
                        n = target + (1 if rnd.random() < 0.5 else -1)
                    else:
                        n = root + rnd.choice(TONES[ch][1:])
                        if n > 50:
                            n -= 12
                    vel = 92 if k == 0 else 78 + rnd.randint(-6, 6)
                    bass.note(t(bar0 + beat + k), int(TPB * 0.92), n, vel)
                beat += length
            # ---- piano: Charleston comping (or one hit per chord when the bar holds two)
            beat = 0
            for ch, length in chords:
                v = VOICE[ch]
                hits = [(0.0, 0.7), (1.5, 1.4)] if length == 4 else [(0.0, 1.2)]
                if length == 4 and rnd.random() < 0.3:
                    hits = [(0.5, 0.6), (2.0, 1.0), (3.5, 0.4)]
                for off, d in hits:
                    vel = 46 + rnd.randint(-5, 6)
                    for i, n in enumerate(v):
                        piano.note(t(bar0 + beat + off) + i * 6, int(TPB * d), n, vel - (4 if i == 0 else 0))
                beat += length
            # ---- drums: brushes. ride swing pattern, hi-hat foot on 2 & 4, a long swirl on 1, feathered kick
            for q in [0.0, 1.0, 1.5, 2.0, 3.0, 3.5]:
                drums.note(t(bar0 + q), 60, 51, 36 + (7 if q in (1.0, 3.0) else 0) + rnd.randint(-3, 3))
            for q in [1.0, 3.0]:
                drums.note(t(bar0 + q), 60, 44, 40 + rnd.randint(-3, 3))
            drums.note(t(bar0), TPB * 2, 40, 34)                         # brush swirl
            drums.note(t(bar0 + 2.0), TPB * 2, 40, 30)
            if rnd.random() < 0.6:
                drums.note(t(bar0), 60, 36, 30)
            if rnd.random() < 0.35:
                drums.note(t(bar0 + 3.5), 60, 38, 30 + rnd.randint(0, 10))  # brush tap pickup
            if b % 8 == 7:
                drums.note(t(bar0 + 3.0), 60, 38, 46)                    # end-of-phrase tap
                drums.note(t(bar0 + 3.5), 60, 38, 52)
        # ---- melodies (per pass)
        def place(track, phrase, start_bar, vel_base):
            for bar, beat, name, dur in phrase:
                s = t((p * bars + start_bar + bar) * 4 + beat)
                e = t((p * bars + start_bar + bar) * 4 + beat + dur)
                track.note(s, int((e - s) * 0.95), N[name], vel_base + rnd.randint(-6, 6))
        place(horn, THEME, 0, 74)          # A1
        place(vibes, BRIDGE, 16, 70)       # B
        place(horn, THEME_END, 24, 70)     # A3
    mid = mido.MidiFile(ticks_per_beat=TPB)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(BPM), time=0))
    mid.tracks.append(meta)
    for tr in (bass, piano, horn, vibes, drums):
        mid.tracks.append(tr.to_track())
    return mid


def tension(passes: int) -> mido.MidiFile:
    """No beat (it plays under the main loop without fighting its groove): low tremolo strings on D with a slow
    minor-second rub (D - Eb), a bowed bass pedal, and a far-off timpani swell every eight beats."""
    bars = 8
    strings = Track(0, 44, vol=90, pan=50, reverb=90)       # tremolo strings
    pedal = Track(1, 42, vol=80, pan=64, reverb=80)         # cello
    timp = Track(2, 47, vol=70, pan=70, reverb=100)         # timpani
    for p in range(passes):
        b0 = p * bars * 4
        for k, (lo, hi) in enumerate([(50, 57), (51, 57), (50, 57), (51, 58)]):
            strings.note(t(b0 + k * 8), TPB * 8 - 30, lo, 52)
            strings.note(t(b0 + k * 8), TPB * 8 - 30, hi, 44)
        pedal.note(t(b0), TPB * 32 - 30, 38, 58)
        for k in range(4):
            timp.note(t(b0 + k * 8 + 6), TPB, 38, 34)
    mid = mido.MidiFile(ticks_per_beat=TPB)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(BPM), time=0))
    mid.tracks.append(meta)
    for tr in (strings, pedal, timp):
        mid.tracks.append(tr.to_track())
    return mid


MENU_BPM = 72
MENU_FORM = [[("DmMaj7", 4)], [("Dm7", 4)], [("Gm7", 4)], [("C7", 4)], [("Fmaj7", 4)], [("Bbmaj7", 4)],
             [("Em7b5", 2), ("A7b9", 2)], [("Dm6", 4)], [("Dm6", 4)], [("Bb7", 4)], [("Ebmaj7", 4)], [("A7", 4)],
             [("Dm6", 4)], [("Gm6", 4)], [("Em7b5", 2), ("A7b9", 2)], [("Dm6", 4)]]
MENU_HORN = [  # far, long notes; bars 4-7 and 12-15 only
    (4, 1.0, "A4", 1.0), (4, 2.0, "C5", 2.0), (5, 0.0, "D5", 3.0), (6, 0.0, "Bb4", 1.5), (6, 1.5, "A4", 0.5), (6, 2.0, "G4", 2.0),
    (7, 0.0, "F4", 2.0), (7, 2.0, "E4", 2.0),
    (12, 1.0, "D5", 1.0), (12, 2.0, "C5", 1.0), (12, 3.0, "A4", 1.0), (13, 0.0, "Bb4", 3.0), (14, 0.0, "G4", 1.0), (14, 1.0, "E4", 1.0),
    (14, 2.0, "G4", 1.0), (14, 3.0, "Cs5", 1.0), (15, 0.0, "D5", 3.5),
]


def menu_song(passes: int, seed: int = 11) -> mido.MidiFile:
    rnd = random.Random(seed)
    bars = len(MENU_FORM)
    bass = Track(0, 32, vol=100, pan=58, reverb=50)
    piano = Track(1, 0, vol=70, pan=72, reverb=85)
    horn = Track(2, 59, vol=70, pan=44, reverb=110)
    pad = Track(3, 49, vol=46, pan=64, reverb=100)        # slow strings, very soft: the room
    drums = Track(9, 40, vol=78, reverb=70)
    for p in range(passes):
        for b, chords in enumerate(MENU_FORM):
            bar0 = (p * bars + b) * 4
            beat = 0
            for ch, length in chords:
                root = ROOT[ch]
                # two-feel bass: root, then the fifth (or the root again on a short chord)
                bass.note(t(bar0 + beat), int(TPB * min(2, length) * 0.95), root, 80)
                if length == 4:
                    bass.note(t(bar0 + beat + 2), int(TPB * 1.9), root + 7 if root + 7 <= 50 else root - 5, 70)
                # piano: one slow broken voicing per chord, low to high
                v = VOICE[ch]
                for i, n in enumerate(v):
                    if i * (length / 4.0) >= length:
                        break
                    piano.note(t(bar0 + beat + i * (length / 4.0)), int(TPB * (length - i * (length / 4.0))), n, 40 + rnd.randint(-4, 4) - i * 2)
                pad.note(t(bar0 + beat), int(TPB * length) - 20, v[0] - 12, 34)
                pad.note(t(bar0 + beat), int(TPB * length) - 20, v[2], 30)
                beat += length
            drums.note(t(bar0), TPB * 4, 40, 26 + rnd.randint(-3, 3))           # one long brush swirl a bar
            drums.note(t(bar0 + 1.0), 60, 51, 22)
            drums.note(t(bar0 + 3.0), 60, 51, 24)
            if b % 4 == 3:
                drums.note(t(bar0 + 3.5), 60, 38, 26)
        for bar, beat, name, dur in MENU_HORN:
            s0 = t((p * bars + bar) * 4 + beat)
            e0 = t((p * bars + bar) * 4 + beat + dur)
            horn.note(s0, int((e0 - s0) * 0.95), N[name], 58 + rnd.randint(-5, 5))
    mid = mido.MidiFile(ticks_per_beat=TPB)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(MENU_BPM), time=0))
    mid.tracks.append(meta)
    for tr in (bass, piano, horn, pad, drums):
        mid.tracks.append(tr.to_track())
    return mid


FINAL_BPM = 116
FINAL_FORM = [[("Dm", 4)], [("Dm", 4)], [("Bb7", 4)], [("A7", 4)], [("Dm", 4)], [("Dm", 4)], [("Eb7b5", 4)], [("A7alt", 4)],
              [("Gm7", 4)], [("Gm7", 4)], [("Dm", 4)], [("Dm", 4)], [("Bb7", 4)], [("A7", 4)], [("Dm", 4)], [("A7alt", 4)]]
FINAL_MOTIF = [(0, 0.0, "A4", 0.5), (0, 0.5, "Bb4", 0.5), (0, 1.0, "A4", 1.5), (0, 3.0, "F4", 1.0),
               (1, 0.0, "D4", 2.0), (1, 2.5, "E4", 0.5), (1, 3.0, "F4", 1.0)]


def final_song(passes: int, seed: int = 23) -> mido.MidiFile:
    rnd = random.Random(seed)
    bars = len(FINAL_FORM) * 2                              # the form twice: the second time the motif climbs a half step
    bass = Track(0, 32, vol=118, pan=58, reverb=25)
    piano = Track(1, 0, vol=70, pan=76, reverb=45)
    bone = Track(2, 57, vol=66, pan=40, reverb=55)          # trombone: the low ostinato
    horn = Track(3, 59, vol=78, pan=52, reverb=70)          # muted trumpet: the motif
    drums = Track(9, 0, vol=86, reverb=35)                  # standard kit (sticks): ride, hat, rim
    for p in range(passes):
        for b in range(bars):
            chords = FINAL_FORM[b % len(FINAL_FORM)]
            nxt = FINAL_FORM[(b + 1) % len(FINAL_FORM)][0][0]
            bar0 = (p * bars + b) * 4
            ch, length = chords[0]
            root = ROOT[ch]
            for k in range(4):
                if k == 0:
                    n = root
                elif k == 3:
                    n = ROOT[nxt] + (1 if rnd.random() < 0.5 else -1)
                else:
                    n = root + rnd.choice(TONES[ch][1:])
                    if n > 50:
                        n -= 12
                bass.note(t(bar0 + k), int(TPB * 0.8), n, (100 if k == 0 else 88) + rnd.randint(-5, 5))
            v = VOICE[ch]
            for off in [1.5, 3.5]:                         # off-beat stabs, short
                for i, n in enumerate(v):
                    piano.note(t(bar0 + off) + i * 4, int(TPB * 0.35), n, 50 + rnd.randint(-4, 4))
            if b % 2 == 0:                                 # ostinato over two bars: root - root - minor third - second
                for off, iv, d in [(0.0, 0, 1.0), (1.5, 0, 0.5), (2.0, 3, 1.0), (3.0, 2, 1.0), (4.0, 0, 2.0)]:
                    bone.note(t(bar0 + off), int(TPB * d * 0.9), root + 12 + iv if root < 40 else root + iv, 58 + rnd.randint(-4, 4))
            for q in [0.0, 1.0, 1.5, 2.0, 3.0, 3.5]:
                drums.note(t(bar0 + q), 60, 51, 44 + (8 if q in (1.0, 3.0) else 0) + rnd.randint(-4, 4))
            for q in [1.0, 3.0]:
                drums.note(t(bar0 + q), 60, 42, 50)
            if rnd.random() < 0.5:
                drums.note(t(bar0 + 2.5), 60, 37, 34)       # rim click ghost
            if b % 8 == 7:
                drums.note(t(bar0 + 3.0), 120, 38, 62)
                drums.note(t(bar0 + 3.5), 120, 38, 70)
        for half in range(2):
            lift = half                                     # the second time a half step higher: the pressure rises
            for start in [4, 12]:
                for bar, beat, name, dur in FINAL_MOTIF:
                    s0 = t((p * bars + half * 16 + start + bar) * 4 + beat)
                    e0 = t((p * bars + half * 16 + start + bar) * 4 + beat + dur)
                    horn.note(s0, int((e0 - s0) * 0.9), N[name] + lift, 66 + rnd.randint(-5, 5))
    mid = mido.MidiFile(ticks_per_beat=TPB)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(FINAL_BPM), time=0))
    mid.tracks.append(meta)
    for tr in (bass, piano, bone, horn, drums):
        mid.tracks.append(tr.to_track())
    return mid


def render(mid: mido.MidiFile, loop_beats: int, name: str, gain: float, lufs: float, bpm: float = BPM) -> None:
    mpath = os.path.join(TMP, name + ".mid")
    wpath = os.path.join(TMP, name + ".wav")
    mid.save(mpath)
    subprocess.run(["fluidsynth", "-ni", "-g", str(gain), "-r", "44100", "-F", wpath, SF2, mpath], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    loop_s = loop_beats * 60.0 / bpm
    out = os.path.join(OUT, name + ".ogg")
    # the middle pass of three: its start already carries the previous pass's reverb tail -> a seamless loop
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.6f" % loop_s, "-t", "%.6f" % loop_s, "-i", wpath,
                    "-af", "highpass=f=35,loudnorm=I=%.1f:TP=-2:LRA=11" % lufs, "-ar", "44100", "-c:a", "libvorbis",
                    "-q:a", "5", out], check=True)
    print("wrote", out, "%.1f s" % loop_s)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    render(song(3), len(FORM) * 4, "noir_jazz_loop", 0.7, -18.0)       # the mix in ui/audio.gd was tuned for about -17 LUFS
    render(tension(3), 32, "tension_loop", 0.6, -20.0)
    render(menu_song(3), len(MENU_FORM) * 4, "menu_theme", 0.7, -19.0, MENU_BPM)             # a little softer: no game sounds over it
    render(final_song(3), len(FINAL_FORM) * 2 * 4, "final_round_loop", 0.7, -18.0, FINAL_BPM)
