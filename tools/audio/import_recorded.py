#!/usr/bin/env python3
"""Cuts the recorded CC0 sounds (Freesound, Kenney) and the CC BY music (Kevin MacLeod) into the
game's audio files. Raw downloads go in RAW (see audio/CREDITS.md for where each came from);
each sound is trimmed to its best part, faded, and levelled to the game's loudness.

    python3 tools/audio/import_recorded.py /path/to/raw
"""
import os
import subprocess
import sys

import numpy as np
import soundfile as sf

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "audio")


def load(path):
    wav = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(wav, dtype=np.float32).copy()


def env(x, win=0.02):
    n = max(1, int(SR * win))
    return np.sqrt(np.convolve(x * x, np.ones(n) / n, mode="same"))


def trim(x, db=-38.0, pad=0.01):
    e = env(x, 0.01)
    on = np.where(e > np.max(e) * 10 ** (db / 20))[0]
    if len(on) == 0:
        return x
    a = max(0, on[0] - int(pad * SR))
    b = min(len(x), on[-1] + int(pad * SR))
    return x[a:b]


def loudest(x, secs):
    """The `secs`-long window with the most energy."""
    n = int(secs * SR)
    if len(x) <= n:
        return x
    e = np.convolve(x * x, np.ones(n), mode="valid")
    a = int(np.argmax(e))
    return x[a:a + n]


def first_hit(x, secs, db=-20.0):
    """From the first strong onset, `secs` long."""
    e = env(x, 0.005)
    on = np.where(e > np.max(e) * 10 ** (db / 20))[0]
    a = max(0, on[0] - int(0.01 * SR)) if len(on) else 0
    return x[a:a + int(secs * SR)]


def fade(x, a=0.004, r=0.08):
    x = x.copy()
    na, nr = min(len(x), int(a * SR)), min(len(x), int(r * SR))
    x[:na] *= np.linspace(0, 1, na)
    x[len(x) - nr:] *= np.linspace(1, 0, nr)
    return x


def level(x, rms_db=-20.0, peak_db=-1.0):
    x = x - np.mean(x)
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (10 ** (rms_db / 20) / r)
    p = np.max(np.abs(x)) + 1e-9
    if p > 10 ** (peak_db / 20):
        x = x * (10 ** (peak_db / 20) / p)
    return x


def pitch_trend(x):
    """Dominant frequency at the start vs the end (for the slide whistle's direction)."""
    def dom(seg):
        s = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
        f = np.fft.rfftfreq(len(seg), 1 / SR)
        s[f < 200] = 0
        return f[np.argmax(s)]
    n = int(0.08 * SR)
    return dom(x[:n]), dom(x[-n:])


def write(rel, x):
    path = os.path.join(ROOT, rel)
    if len(x) > 30 * SR:
        # libsndfile's Vorbis encoder crashes on long files: go through ffmpeg for music.
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                        "-c:a", "libvorbis", "-q:a", "4", path], input=x.astype(np.float32).tobytes(), check=True)
    else:
        sf.write(path, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("%-28s %.2fs" % (rel, len(x) / SR))


def main(raw):
    R = lambda n: load(os.path.join(raw, n))
    write("sfx/pour.ogg", level(fade(loudest(trim(R("pour.ogg")), 2.3), 0.05, 0.4), -19))
    write("sfx/gulp.ogg", level(fade(trim(R("gulp.ogg"))[: int(1.3 * SR)], 0.01, 0.15), -18))
    write("sfx/gasp.ogg", level(fade(trim(R("gasp.ogg"))), -16))
    write("sfx/heartbeat.ogg", level(fade(first_hit(trim(R("heartbeat.ogg")), 0.75), 0.002, 0.2), -16))
    write("sfx/sniff.ogg", level(fade(trim(R("sniff.ogg"))[: int(1.0 * SR)]), -18))
    write("sfx/clink.ogg", level(fade(trim(R("clink.ogg"))), -20))
    write("sfx/toast.ogg", level(fade(first_hit(trim(R("toast.ogg")), 1.6), 0.002, 0.5), -20))
    write("sfx/boing.ogg", level(fade(trim(R("boing.ogg"))[: int(1.2 * SR)]), -17))
    write("sfx/whoosh.ogg", level(fade(loudest(trim(R("whoosh.ogg")), 0.7), 0.02, 0.2), -18))
    # The slide whistle plays as a guest topples: it must go DOWN.
    best = None
    for n in ("slide_whistle_a.ogg", "slide_whistle_b.ogg"):
        x = trim(R(n))
        x = x[: int(1.6 * SR)]
        a, b = pitch_trend(x)
        print("  %s pitch %.0f -> %.0f Hz" % (n, a, b))
        if b < a * 0.8 and best is None:
            best = x
    if best is not None:
        write("sfx/slide_whistle.ogg", level(fade(best, 0.005, 0.15), -18))
    write("sfx/fanfare.ogg", level(fade(trim(R("fanfare.ogg"))[: int(3.4 * SR)], 0.005, 0.6), -17))
    write("sfx/drumroll.ogg", level(fade(trim(R("drumroll.ogg"))[: int(3.0 * SR)], 0.05, 0.25), -18))
    write("sfx/bell.ogg", level(fade(first_hit(trim(R("bell.ogg")), 2.2), 0.002, 0.8), -20))
    write("sfx/ghost.ogg", level(fade(trim(R("ghost.ogg")), 0.05, 0.5), -19))
    write("sfx/switch.ogg", level(fade(trim(R("switch_on.ogg")), 0.001, 0.03), -16))
    write("sfx/candle_out.ogg", level(fade(loudest(trim(R("candle_out.ogg")), 0.9), 0.01, 0.3), -18))
    # Kenney (CC0): real porcelain and wood.
    write("sfx/sit_down.ogg", level(fade(trim(R("kenney_impactWood_light_001.ogg"))), -20))
    write("sfx/card.ogg", level(fade(trim(R("kenney_card-place-1.ogg"))), -20))
    write("sfx/slide.ogg", level(fade(trim(R("kenney_card-slide-3.ogg"))), -20))
    write("sfx/thud.ogg", level(fade(trim(R("kenney_impactSoft_heavy_000.ogg"))), -16))
    write("sfx/coin.ogg", level(fade(trim(R("kenney_handleCoins.ogg"))[: int(0.8 * SR)]), -20))
    # Music (Kevin MacLeod, CC BY 4.0): full tracks, they loop from the top.
    for src, dst in (("Sneaky_Snitch.mp3", "music/sneaky_snitch.ogg"), ("Carefree.mp3", "music/carefree.ogg")):
        x = load(os.path.join(raw, src))
        write(dst, level(fade(trim(x, -50), 0.01, 1.5), -21, -1.0))


if __name__ == "__main__":
    main(sys.argv[1])
