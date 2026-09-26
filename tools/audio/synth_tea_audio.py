#!/usr/bin/env python3
"""Synthesises the tea-party-specific sounds into audio/ as OGG Vorbis.

Placeholders in the same spirit as Woods' tools/audio/synth_woods_audio.py: the routing (Sfx
autoload, sound ids) is final, so recorded CC0 / licensed files can replace any output at the
same path.

    pip install numpy scipy soundfile
    python3 tools/audio/synth_tea_audio.py

Deterministic: fixed seeds, so re-running produces identical files.
"""
import os

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "audio")
rng = np.random.default_rng(4242)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def band(x, lo, hi, order=4):
    return signal.sosfilt(signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def lowpass(x, f, order=4):
    return signal.sosfilt(signal.butter(order, f, btype="low", fs=SR, output="sos"), x)


def highpass(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="high", fs=SR, output="sos"), x)


def norm_peak(x, db=-3.0):
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (db / 20)


def fade(x, a=0.003, r=0.03):
    n = len(x)
    env = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na:
        env[:na] = np.linspace(0, 1, na)
    if nr:
        env[-nr:] *= np.linspace(1, 0, nr)
    return x * env


def room(x, decay=0.35, wet=0.18):
    """Small parlour reverb: a few damped comb echoes."""
    out = np.concatenate([x, np.zeros(int(decay * SR))])
    for d, g in [(0.023, 0.5), (0.031, 0.42), (0.043, 0.36), (0.057, 0.3)]:
        k = int(d * SR)
        y = np.zeros_like(out)
        y[k:] = out[:-k] * g
        out = out + wet * lowpass(y, 5000, 2)
    return out


def mix(*parts):
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[: len(p)] += p
    return out


def place(out, at, snd, gain=1.0):
    i = int(at * SR)
    end = min(len(out), i + len(snd))
    out[i:end] += snd[: end - i] * gain


def write(name, x, db=-3.0):
    path = os.path.join(ROOT, name + ".ogg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, norm_peak(fade(x), db).astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("wrote", path)


# ----------------------------------------------------------------- building blocks

def bubble(f0, dur, rise, amp=1.0):
    t = t_axis(dur)
    freq = f0 * (1.0 + rise * t / dur)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    env = np.exp(-t / (dur * 0.3)) * (1 - np.exp(-t / 0.001))
    return amp * env * np.sin(phase)


def porcelain(f0, dur=1.2, amp=1.0, bright=1.0):
    """Inharmonic ringing partials of a small china cup."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for ratio, a, d in [(1.0, 1.0, 0.55), (2.32, 0.6, 0.35), (4.25, 0.35 * bright, 0.2), (6.63, 0.2 * bright, 0.12), (9.1, 0.1 * bright, 0.07)]:
        x += a * np.exp(-t / (d * dur)) * np.sin(2 * np.pi * f0 * ratio * t + rng.random() * 6)
    click = highpass(rng.standard_normal(len(t)), 3000) * np.exp(-t / 0.002) * 0.4
    return amp * (x + click)


def noise(dur):
    return rng.standard_normal(int(dur * SR))


# ----------------------------------------------------------------- sounds

def pour():
    dur = 1.8
    t = t_axis(dur)
    env = np.clip(t / 0.12, 0, 1) * np.clip((dur - t) / 0.25, 0, 1)
    # Stream: band noise whose centre rises as the cup fills.
    stream = np.zeros_like(t)
    chunks = 18
    for i in range(chunks):
        a, b = int(i * len(t) / chunks), int((i + 1) * len(t) / chunks)
        lo = 500 + 600 * i / chunks
        seg = band(noise((b - a) / SR + 0.05), lo, lo * 3.2)[: b - a]
        stream[a:b] = seg
    x = stream * env * 0.5
    for _ in range(70):
        at = rng.uniform(0.05, dur - 0.2)
        f = rng.uniform(500, 900) + 900 * at / dur
        place(x, at, bubble(f, rng.uniform(0.02, 0.05), 0.6, rng.uniform(0.15, 0.4)))
    write("sfx/pour", room(x))


def clink():
    x = mix(porcelain(2350, 1.1), porcelain(2780, 1.0, 0.7))
    write("sfx/clink", room(x))


def toast():
    out = np.zeros(int(2.4 * SR))
    for i in range(6):
        place(out, 0.05 + i * rng.uniform(0.04, 0.09), porcelain(rng.uniform(2100, 3100), 1.3, rng.uniform(0.5, 1.0)))
    write("sfx/toast", room(out, 0.5, 0.25))


def plip():
    x = mix(bubble(820, 0.09, 1.2), 0.4 * bubble(1400, 0.05, 0.8))
    write("sfx/plip", room(x))


def sugar():
    out = np.zeros(int(0.5 * SR))
    place(out, 0.0, porcelain(3600, 0.25, 0.5, 1.4))
    place(out, 0.05, bubble(700, 0.12, 1.0, 0.9))
    write("sfx/sugar", room(out))


def gulp():
    out = np.zeros(int(1.2 * SR))
    for i, at in enumerate([0.0, 0.38, 0.74]):
        t = t_axis(0.2)
        f = 170 + 90 * t / 0.2
        v = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.06) * (1 - np.exp(-t / 0.004))
        v = mix(v, 0.5 * bubble(320, 0.1, 1.4))
        place(out, at, lowpass(v, 1800), 1.0 - i * 0.1)
    write("sfx/gulp", out)


def gasp():
    dur = 0.7
    t = t_axis(dur)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    n = noise(dur)
    x = np.zeros_like(t)
    for lo, hi, g in [(700, 1300, 1.0), (1800, 2600, 0.6), (3000, 4200, 0.25)]:
        x += band(n, lo, hi) * g
    write("sfx/gasp", room(x * env * np.linspace(0.6, 1.0, len(t))))


def thud():
    dur = 1.0
    t = t_axis(dur)
    body = np.sin(2 * np.pi * (70 - 25 * t) * t) * np.exp(-t / 0.12)
    rustle = band(noise(dur), 300, 3000) * np.exp(-t / 0.18) * 0.35
    x = body + rustle
    # A chair scrape before the fall.
    scrape = band(noise(0.35), 900, 2400) * np.linspace(0.2, 0.6, int(0.35 * SR)) * 0.4
    out = np.zeros(int(1.4 * SR))
    place(out, 0.0, scrape)
    place(out, 0.32, x)
    write("sfx/thud", room(out))


def rattle():
    out = np.zeros(int(0.9 * SR))
    at = 0.0
    while at < 0.7:
        place(out, at, porcelain(rng.uniform(2600, 3400), 0.18, rng.uniform(0.3, 0.8), 1.5))
        at += rng.uniform(0.028, 0.06)
    write("sfx/rattle", room(out))


def ghost():
    dur = 2.2
    t = t_axis(dur)
    env = np.sin(np.pi * t / dur) ** 2
    whoosh = band(noise(dur), 300, 1400) * env * 0.6
    f = 520 + 180 * np.sin(2 * np.pi * 0.7 * t)
    wail = np.sin(2 * np.pi * np.cumsum(f) / SR) * env * 0.35
    wail += 0.15 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * env
    write("sfx/ghost", room(mix(whoosh, wail), 0.8, 0.3))


def heartbeat():
    out = np.zeros(int(1.6 * SR))
    for at, g in [(0.0, 1.0), (0.24, 0.7), (0.8, 1.0), (1.04, 0.7)]:
        t = t_axis(0.25)
        beat = np.sin(2 * np.pi * (55 - 10 * t) * t) * np.exp(-t / 0.05)
        place(out, at, lowpass(beat, 200), g)
    write("sfx/heartbeat", out, -2.0)


def drumroll():
    dur = 2.6
    out = np.zeros(int(dur * SR))
    at = 0.0
    while at < dur - 0.3:
        t = t_axis(0.08)
        hit = band(noise(0.08), 1500, 6000) * np.exp(-t / 0.02) + np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.03) * 0.5
        place(out, at, hit, 0.4 + 0.6 * at / dur)
        at += 0.045
    t = t_axis(0.8)
    crash = highpass(noise(0.8), 3000) * np.exp(-t / 0.25)
    place(out, dur - 0.8, crash, 1.4)
    write("sfx/drumroll", room(out))


def sniff():
    out = np.zeros(int(0.8 * SR))
    for at in [0.0, 0.26]:
        dur = 0.18
        t = t_axis(dur)
        s = band(noise(dur), 2500, 6500) * np.sin(np.pi * t / dur) ** 2
        place(out, at, s)
    write("sfx/sniff", out)


def card():
    dur = 0.12
    t = t_axis(dur)
    x = band(noise(dur), 1500, 8000) * np.exp(-t / 0.018)
    write("sfx/card", x)


def slide():
    dur = 0.6
    t = t_axis(dur)
    env = np.sin(np.pi * t / dur)
    x = band(noise(dur), 1200, 3800) * env * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t))
    out = np.concatenate([x, np.zeros(int(0.4 * SR))])
    place(out, dur - 0.04, porcelain(2900, 0.4, 0.4))
    write("sfx/slide", room(out))


def bell():
    t = t_axis(2.0)
    x = np.zeros_like(t)
    for r, a, d in [(1.0, 1.0, 0.9), (2.0, 0.5, 0.6), (2.76, 0.4, 0.5), (5.4, 0.25, 0.2), (8.93, 0.1, 0.1)]:
        x += a * np.exp(-t / d) * np.sin(2 * np.pi * 1320 * r * t)
    tremolo = 1 + 0.3 * np.sin(2 * np.pi * 7 * t) * np.exp(-t / 0.3)
    write("sfx/bell", room(x * tremolo, 0.6, 0.25))


def pluck(freq, dur, bright=0.6, amp=1.0):
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = bright * 0.5 * (buf[i % period] + buf[(i + 1) % period]) + (1 - bright) * buf[i % period] * 0.996
    return amp * out * np.exp(-np.arange(n) / SR / (dur * 0.5))


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def fanfare():
    out = np.zeros(int(2.4 * SR))
    for i, m in enumerate([72, 76, 79, 84]):
        place(out, i * 0.14, pluck(midi(m), 1.6, 0.5))
    for m in [72, 76, 79, 84, 88]:
        place(out, 0.62, pluck(midi(m), 1.7, 0.5, 0.6))
    write("sfx/fanfare", room(out, 0.6, 0.25))


def sting():
    """The reveal: a low, sour music-box chord."""
    out = np.zeros(int(2.6 * SR))
    for i, m in enumerate([50, 53, 56, 59]):
        place(out, i * 0.05, pluck(midi(m), 2.4, 0.4, 0.8))
    write("sfx/sting", room(out, 0.8, 0.3))


def music_box(tone_f, dur, amp=1.0):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for r, a, d in [(1.0, 1.0, 0.8), (3.0, 0.3, 0.25), (5.9, 0.12, 0.1)]:
        x += a * np.exp(-t / (d * dur * 0.6)) * np.sin(2 * np.pi * tone_f * r * t)
    x *= 1 - np.exp(-t / 0.002)
    return amp * x


def waltz():
    """A loopable music-box waltz for the menus (3/4, 16 bars, ~27 s)."""
    beat = 0.56
    bars = 16
    total = bars * 3 * beat
    out = np.zeros(int((total + 2.0) * SR))
    # (root, chord intervals) per bar; I - vi - IV - V, twice, then a turn.
    prog = [0, 9, 5, 7, 0, 9, 2, 7, 0, 4, 5, 7, 9, 5, 7, 0]
    melody = [
        [76, 79, 84], [81, 79, 76], [77, 76, 74], [74, 79, 83],
        [84, 83, 81], [79, 76, 72], [74, 76, 77], [79, None, None],
        [76, 79, 84], [83, 81, 79], [81, 77, 76], [74, 79, 83],
        [84, 86, 88], [89, 88, 84], [86, 83, 79], [84, None, None],
    ]
    for b in range(bars):
        root = 48 + prog[b]
        t0 = b * 3 * beat
        place(out, t0, music_box(midi(root), 1.4, 0.55))
        third = 4 if prog[b] in (0, 5, 7) else 3
        for k in (1, 2):
            place(out, t0 + k * beat, music_box(midi(root + 12 + third), 0.8, 0.3))
            place(out, t0 + k * beat, music_box(midi(root + 19), 0.8, 0.3))
        for k, m in enumerate(melody[b]):
            if m is not None:
                place(out, t0 + k * beat, music_box(midi(m), 1.6 if k == 0 else 1.0, 0.6))
    out = room(out, 1.0, 0.3)
    n = int(total * SR)
    loop = out[:n].copy()
    tail = out[n:]
    loop[: len(tail)] += tail[: len(loop)]
    sf.write(os.path.join(ROOT, "music", "waltz_loop.ogg"), norm_peak(loop, -4.0).astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("wrote waltz_loop")


if __name__ == "__main__":
    for fn in [pour, clink, toast, plip, sugar, gulp, gasp, thud, rattle, ghost, heartbeat, drumroll, sniff, card, slide, bell, fanfare, sting, waltz]:
        fn()
