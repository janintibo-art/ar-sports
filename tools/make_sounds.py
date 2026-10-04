"""Synthèse de tous les sons d'AR Sports (aucun fichier externe, aucun droit).

Usage : python3 tools/make_sounds.py   -> écrit sounds/*.ogg (ffmpeg + libvorbis)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ outils

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a=0.005, d=0.1, s=0.6, r=0.2, sustain_time=None):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    if sustain_time is None:
        s_n = max(0, n - a_n - d_n - r_n)
    else:
        s_n = int(sustain_time * SR)
    e = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def exp_env(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, f1, f2, order=2):
    b, a = signal.butter(order, [f1 / (SR / 2), min(f2 / (SR / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def reson(x, f, q):
    b, a = signal.iirpeak(f / (SR / 2), q)
    return signal.lfilter(b, a, x)


def svf(x, fc, q=0.7, mode="lp"):
    """Filtre à variable d'état dont la fréquence peut varier à chaque échantillon."""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    f = 2 * np.sin(np.pi * np.clip(fc, 20, SR / 6) / SR)
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty_like(x)
    for i in range(len(x)):
        low += f[i] * band
        high = x[i] - low - damp * band
        band += f[i] * high
        out[i] = low if mode == "lp" else band
    return out


def noise(n):
    return rng.standard_normal(n)


def brown(n):
    w = np.cumsum(noise(n))
    w = hp(w, 20)
    return w / (np.max(np.abs(w)) + 1e-9)


def reverb(x, seconds=1.2, mix=0.25, damp=4000):
    n = int(seconds * SR)
    ir = noise(n) * np.exp(-np.arange(n) / (seconds / 6.0 * SR))
    ir = lp(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - mix) + wet * mix * 0.9


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x * (peak / m)


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def make_loop(x, xfade=0.3):
    """Rend un son bouclable sans clic (fondu enchaîné fin -> début)."""
    n = int(xfade * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    ramp = np.linspace(0, 1, n)
    mixed = tail * (1 - ramp) + head * ramp
    return np.concatenate([body, mixed])


def save(name, x, quality=4):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", str(quality), dst], check=True)
    os.remove(tmp)
    print(f"{name:14s} {len(x) / SR:5.2f}s  {os.path.getsize(dst) // 1024} Ko")


# ------------------------------------------------------------------ bruitages

def pin_hit(seed, dur=0.35):
    """Choc bois/plastique d'une quille : modes résonants qui décroissent vite."""
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    base = r.uniform(700, 950)
    for k, (mult, amp, tau) in enumerate([(1, 1, 0.05), (1.73, 0.7, 0.035), (2.6, 0.5, 0.025),
                                          (3.9, 0.35, 0.018), (5.2, 0.2, 0.012)]):
        f = base * mult * r.uniform(0.97, 1.03)
        x += amp * np.sin(2 * np.pi * f * t + r.uniform(0, 6)) * np.exp(-t / tau)
    click = bp(noise(n), 1500, 7000) * np.exp(-t / 0.004)
    body = lp(noise(n), 400) * np.exp(-t / 0.03) * 2
    return norm(fade(x + click * 0.8 + body * 0.5))


def crash():
    """Strike : avalanche de chocs de quilles sur ~0,9 s."""
    n = int(1.3 * SR)
    x = np.zeros(n)
    times = np.sort(rng.uniform(0, 0.9, 26) ** 1.6)
    for i, tt in enumerate(times):
        h = pin_hit(100 + i, 0.3) * rng.uniform(0.3, 1.0) * (1.0 - 0.6 * tt)
        s = int(tt * SR)
        x[s:s + len(h)] += h[: n - s]
    thump = lp(noise(n), 180) * exp_env(n, 0.08) * 4
    x += thump
    return norm(reverb(fade(x, 0.001, 0.2), 0.8, 0.18))


def roll_loop():
    """Grondement de boule sur le bois (bouclable)."""
    n = int(3.3 * SR)
    t = np.arange(n) / SR
    rum = lp(brown(n), 160) * 1.0
    mid = bp(noise(n), 200, 900) * 0.12
    wob = 1 + 0.15 * np.sin(2 * np.pi * 5.3 * t) + 0.08 * np.sin(2 * np.pi * 11.1 * t)
    ticks = np.zeros(n)
    for s in rng.integers(0, n, 40):
        ticks[s] = rng.uniform(0.2, 0.6)
    ticks = bp(ticks, 300, 1500) * 0.5
    return norm(make_loop((rum + mid) * wob + ticks, 0.3), 0.8)


def thud():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 90 * np.exp(-t * 6) + 45
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.08)
    x += lp(noise(n), 600) * np.exp(-t / 0.015) * 0.6
    return norm(fade(x))


def whoosh():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    e = np.sin(np.pi * np.clip(t / 0.45, 0, 1)) ** 2
    out = svf(noise(n), 500 + 2500 * e, 2.5, "bp")
    return norm(fade(lp(out, 5000) * e))


def click():
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.008) + np.sin(2 * np.pi * 2700 * t) * np.exp(-t / 0.005) * 0.5
    return norm(fade(x), 0.6)


def grab():
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    f = 300 + 500 * t / 0.12
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.04)
    return norm(fade(x), 0.6)


def chime():
    """Ding-dong : au tour du joueur suivant."""
    out = []
    for f, d in [(880, 0.35), (659.25, 0.6)]:
        n = int(d * SR)
        t = np.arange(n) / SR
        x = sum(a * np.sin(2 * np.pi * f * m * t) * np.exp(-t / (0.5 / m)) for m, a in [(1, 1), (2, 0.3), (3, 0.12)])
        out.append(x)
    return norm(reverb(fade(np.concatenate(out)), 1.0, 0.25), 0.7)


def crowd(dur, excite=1.0, seed=1):
    """Foule : applaudissements (claquements) + clameur (voyelles bruitées)."""
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    shape = np.minimum(1, t / 0.15) * np.exp(-np.maximum(0, t - 0.4) / (dur / 2.5))
    claps = np.zeros(n)
    for _ in range(int(220 * dur * excite)):
        s = r.integers(0, n)
        cn = int(0.012 * SR)
        c = bp(noise(cn), r.uniform(800, 1500), r.uniform(2500, 5000)) * np.exp(-np.arange(cn) / (0.003 * SR))
        claps[s:s + cn] += c[: n - s] * r.uniform(0.3, 1)
    claps *= shape
    voices = np.zeros(n)
    for _ in range(10):
        f0 = r.uniform(140, 320)
        vib = 1 + 0.03 * np.sin(2 * np.pi * r.uniform(4, 7) * t)
        glide = 1 + 0.25 * np.exp(-t / 0.5) * excite
        ph = np.cumsum(f0 * vib * glide) / SR
        saw = 2 * (ph % 1) - 1
        v = reson(saw, r.uniform(600, 800), 4) + 0.6 * reson(saw, r.uniform(1100, 1300), 5)
        st = r.uniform(0, 0.25)
        voices += v * np.clip((t - st) / 0.1, 0, 1) * r.uniform(0.4, 1)
    voices = lp(voices, 3000) * shape * 0.25 * excite
    return norm(reverb(fade(claps + voices, 0.01, 0.3), 1.4, 0.35), 0.85)


def sad_trombone():
    """Wah wah wah waaah : boule dans la rigole."""
    notes = [(311.13, 0.38), (293.66, 0.38), (277.18, 0.38), (261.63, 1.3)]
    out = []
    for i, (f, d) in enumerate(notes):
        n = int(d * SR)
        t = np.arange(n) / SR
        vib = 1 + (0.025 * np.sin(2 * np.pi * 6 * t) * np.clip((t - 0.3) / 0.2, 0, 1) if i == 3 else 0)
        bend = 1 - (0.03 * np.clip((t - 0.4) / 0.9, 0, 1) if i == 3 else 0)
        ph = np.cumsum(f * vib * bend * np.ones(n)) / SR
        saw = 2 * (ph % 1) - 1
        e = env_adsr(n, 0.03, 0.1, 0.8, 0.12 if i < 3 else 0.4)
        if i < 3:
            wah = 400 + 1500 * np.sin(np.pi * np.clip(t / d, 0, 1))
        else:
            wah = 400 + 1500 * (0.5 + 0.5 * np.sin(2 * np.pi * 2.2 * t - np.pi / 2)) * np.exp(-t / 1.2)
        out.append(svf(saw, wah, 1.5, "lp") * e)
    x = np.concatenate(out)
    return norm(reverb(fade(x), 1.0, 0.2), 0.8)


def glug_loop():
    """Glouglou de bière (bouclable)."""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    k = 0
    while k < n:
        dur = int(rng.uniform(0.09, 0.16) * SR)
        f0 = rng.uniform(180, 320)
        tt = np.arange(dur) / SR
        f = f0 * (1 + 1.5 * tt / (dur / SR))
        bub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / (dur / SR)) ** 2
        x[k:k + dur] += bub[: n - k]
        k += dur + int(rng.uniform(0.0, 0.04) * SR)
    x += lp(noise(n), 500) * 0.15
    return norm(make_loop(x, 0.15), 0.6)


def burp():
    n = int(0.75 * SR)
    t = np.arange(n) / SR
    f0 = 85 + 15 * np.sin(2 * np.pi * 3 * t) + 8 * noise(n).cumsum() / np.sqrt(np.arange(n) + 1) * 0.02
    jitter = 1 + 0.08 * lp(noise(n), 40)
    ph = np.cumsum(f0 * jitter) / SR
    pulse = (ph % 1 < 0.15).astype(float) - 0.15
    v = reson(pulse, 350, 3) + 0.7 * reson(pulse, 700, 4) + 0.3 * reson(pulse, 2300, 6)
    e = env_adsr(n, 0.04, 0.1, 0.9, 0.25)
    return norm(fade(lp(v, 3500) * e), 0.85)


def clink():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
            for f, a, tau in [(2650, 1, 0.25), (4120, 0.6, 0.15), (5980, 0.4, 0.1), (7300, 0.25, 0.06)])
    x += bp(noise(n), 3000, 9000) * np.exp(-t / 0.003) * 0.5
    return norm(reverb(fade(x), 0.6, 0.15), 0.6)


def pour():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    out = svf(noise(n), 600 + 1400 * t / 1.6, 1.2, "bp")
    e = env_adsr(n, 0.08, 0.1, 0.8, 0.3)
    g = np.resize(glug_loop(), n)
    return norm(fade(out * e + g * e * 0.25), 0.55)


def dart_thud():
    """Fléchette qui se plante dans le liège : toc sec + petit tintement du fût."""
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    f = 260 * np.exp(-t * 40) + 95
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.035)
    x += bp(noise(n), 1200, 5000) * np.exp(-t / 0.006) * 0.7
    x += np.sin(2 * np.pi * 3300 * t) * np.exp(-t / 0.07) * 0.18
    return norm(fade(x), 0.8)


def bull_ding():
    """Cloche du bullseye."""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * 1318.5 * m * t) * np.exp(-t / tau)
            for m, a, tau in [(1, 1, 0.7), (2.76, 0.5, 0.35), (5.4, 0.25, 0.18), (8.9, 0.1, 0.08)])
    return norm(reverb(fade(x), 0.8, 0.2), 0.7)


def pp_paddle():
    """Balle de ping-pong frappée par la raquette : toc sec et brillant."""
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1650 * t) * np.exp(-t / 0.012)
    x += np.sin(2 * np.pi * 2480 * t) * np.exp(-t / 0.008) * 0.6
    x += bp(noise(n), 1500, 6000) * np.exp(-t / 0.004) * 0.7
    x += np.sin(2 * np.pi * 420 * t) * np.exp(-t / 0.03) * 0.3
    return norm(fade(x), 0.8)


def pp_table():
    """Rebond de la balle sur la table : tic clair et léger."""
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1150 * t) * np.exp(-t / 0.018)
    x += np.sin(2 * np.pi * 1900 * t) * np.exp(-t / 0.01) * 0.5
    x += bp(noise(n), 800, 4000) * np.exp(-t / 0.003) * 0.5
    return norm(fade(x), 0.7)


def pp_net():
    """Balle dans le filet : petit bruit mat."""
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = lp(noise(n), 1800) * np.exp(-t / 0.05) * 0.8
    x += np.sin(2 * np.pi * 180 * t) * np.exp(-t / 0.04) * 0.5
    return norm(fade(x), 0.6)


def pet_clack():
    """Deux boules d'acier qui s'entrechoquent : clac métallique sec."""
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 2350 * t) * np.exp(-t / 0.05)
    x += np.sin(2 * np.pi * 3720 * t) * np.exp(-t / 0.035) * 0.6
    x += np.sin(2 * np.pi * 5480 * t) * np.exp(-t / 0.02) * 0.35
    x += bp(noise(n), 2000, 8000) * np.exp(-t / 0.004) * 0.8
    return norm(fade(x), 0.8)


def pet_land():
    """Boule qui retombe dans le gravier : crissement sourd."""
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    x = lp(noise(n), 2500) * np.exp(-t / 0.07) * 0.9
    x += np.sin(2 * np.pi * 110 * t) * np.exp(-t / 0.05) * 0.5
    return norm(fade(x), 0.6)


def pinsetter():
    """Machine qui replace les quilles : moteur + clac."""
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    motor = np.sign(np.sin(2 * np.pi * 55 * t)) * 0.3 + np.sin(2 * np.pi * 110 * t) * 0.3
    motor = lp(motor, 700) * env_adsr(n, 0.1, 0.1, 0.8, 0.3) * 0.6
    rattle = bp(noise(n), 1000, 3000) * (0.2 + 0.2 * np.sin(2 * np.pi * 17 * t)) * env_adsr(n, 0.1, 0.1, 0.6, 0.3)
    clack = np.zeros(n)
    for s in (0.75, 0.8):
        h = pin_hit(int(s * 100), 0.25) * 0.6
        k = int(s * SR)
        clack[k:k + len(h)] += h[: n - k]
    return norm(fade(motor + rattle * 0.5 + clack), 0.6)


# ------------------------------------------------------------------ musique

def ep_note(f, dur, vel=0.6):
    """Piano électrique façon FM (type Rhodes)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * 1.0 * t) * 1.6 * np.exp(-t / 0.25)
    tine = np.sin(2 * np.pi * f * 14 * t) * 0.08 * np.exp(-t / 0.03)
    x = np.sin(2 * np.pi * f * t + mod) + tine
    x *= np.exp(-t / 1.6) * env_adsr(n, 0.004, 0.2, 0.9, 0.15)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.5 * t)
    return x * trem * vel


def bass_note(f, dur, vel=0.8):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ph = f * t
    x = np.sin(2 * np.pi * ph) + 0.35 * (2 * (ph % 1) - 1)
    x = lp(x, 600 + 900 * np.exp(-0.0) , 2)
    return x * env_adsr(n, 0.008, 0.15, 0.7, 0.06) * vel


def kick():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    f = 50 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)


def snare():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.04) * 0.5
    nz = bp(noise(n), 1500, 8000) * np.exp(-t / 0.07)
    return (body + nz) * 0.6


def hat(open_=False):
    n = int((0.25 if open_ else 0.05) * SR)
    t = np.arange(n) / SR
    return hp(noise(n), 7000) * np.exp(-t / (0.08 if open_ else 0.012)) * 0.35


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def music():
    bpm = 94
    beat = 60 / bpm
    bars = 16
    total = int(bars * 4 * beat * SR)
    mix = np.zeros(total + SR * 2)
    drums = np.zeros(total + SR * 2)

    def put(x, start_s, gain=1.0, bus=None):
        bus = mix if bus is None else bus
        s = int(start_s * SR)
        bus[s:s + len(x)] += x * gain

    # Progression lounge : Dm9 G13 Cmaj9 A7(b13) puis Fmaj7 Em7 Dm9 G13
    prog = [
        ([50], [62, 65, 69, 72, 76]),
        ([43], [59, 64, 65, 69, 71]),
        ([48], [59, 62, 64, 67, 71]),
        ([45], [61, 64, 65, 67, 73]),
        ([41], [60, 64, 65, 69, 72]),
        ([40], [59, 62, 64, 67, 71]),
        ([50], [62, 65, 69, 72, 76]),
        ([43], [59, 64, 65, 69, 71]),
    ]
    for bar in range(bars):
        bass_root, chord = prog[bar % 8]
        b0 = bar * 4 * beat
        # accords : comping syncopé
        for off, length, vel in [(0, 1.4, 0.55), (1.5, 0.45, 0.35), (2.5, 1.3, 0.45)]:
            for m in chord:
                put(ep_note(midi(m), length * beat + 0.3, vel * 0.32), b0 + off * beat + rng.uniform(0, 0.012))
        # basse
        r = bass_root[0]
        pattern = [(0, r, 1.4), (1.5, r + 12, 0.4), (2.0, r + 7, 0.9), (3.0, r + 10, 0.4), (3.5, r + 9, 0.45)]
        for off, m, ln in pattern:
            put(bass_note(midi(m), ln * beat, 0.7), b0 + off * beat, 0.55)
        # batterie (douce, balais)
        for b in range(4):
            tb = b0 + b * beat
            if b in (0, 2):
                put(kick(), tb, 0.55, drums)
            if b == 2 and bar % 2 == 1:
                put(kick(), tb + 0.75 * beat, 0.35, drums)
            if b in (1, 3):
                put(snare(), tb, 0.18, drums)
            for sub in (0, 0.5):
                swing = 0.08 * beat if sub else 0
                put(hat(open_=(b == 3 and sub)), tb + sub * beat + swing, 0.14 if sub else 0.2, drums)
        # petite mélodie au vibraphone sur la 2e moitié
        if bar >= 8:
            mel = [(0, 74), (0.75, 76), (1.5, 77), (2.5, 76), (3.25, 72)] if bar % 2 == 0 else [(0.5, 74), (1.5, 72), (2.5, 69)]
            for off, m in mel:
                n = int(0.9 * SR)
                t = np.arange(n) / SR
                vib = np.sin(2 * np.pi * midi(m) * t) + 0.25 * np.sin(2 * np.pi * midi(m) * 4 * t) * np.exp(-t / 0.1)
                vib *= np.exp(-t / 0.6) * (1 + 0.2 * np.sin(2 * np.pi * 5 * t))
                put(vib, b0 + off * beat, 0.12)
    mix = reverb(mix + lp(drums, 8000) * 0.8, 1.6, 0.22, 6000)
    loop_len = total
    tail = mix[loop_len:loop_len + int(1.5 * SR)]
    body = mix[:loop_len].copy()
    body[: len(tail)] += tail  # la queue de réverb retombe sur le début : boucle parfaite
    body = np.tanh(norm(body, 1.0) * 1.2) * 0.8
    return body


def alley_ambience():
    """Brouhaha lointain de bowling (bouclable)."""
    n = int(14 * SR)
    t = np.arange(n) / SR
    murmur = np.zeros(n)
    for _ in range(14):
        f0 = rng.uniform(110, 240)
        ph = np.cumsum(f0 * (1 + 0.05 * lp(noise(n), 3) * 40)) / SR
        saw = 2 * (ph % 1) - 1
        talk = np.clip(lp(noise(n), 2.5) * 30, 0, 1)
        v = reson(saw, rng.uniform(500, 900), 3) * talk
        murmur += v
    murmur = lp(murmur, 1800) * 0.25
    events = np.zeros(n)
    for s in (2.3, 6.8, 11.2):
        c = crash()[: int(1.0 * SR)] * 0.25
        k = int(s * SR)
        events[k:k + len(c)] += lp(c, 1500)
    room = lp(brown(n), 300) * 0.15
    x = reverb(murmur + events + room, 1.8, 0.5, 2500)
    return norm(make_loop(x, 1.0), 0.6)


if __name__ == "__main__":
    for i in range(3):
        save(f"pin_hit_{i + 1}", pin_hit(i + 1))
    save("strike_crash", crash())
    save("roll_loop", roll_loop())
    save("ball_thud", thud())
    save("whoosh", whoosh())
    save("ui_click", click())
    save("grab", grab())
    save("next_player", chime())
    save("cheer_big", crowd(3.2, 1.0, 1))
    save("cheer_small", crowd(1.8, 0.55, 2))
    save("gutter", sad_trombone())
    save("glug_loop", glug_loop())
    save("burp", burp())
    save("clink", clink())
    save("pour", pour())
    save("pinsetter", pinsetter())
    save("dart_thud", dart_thud())
    save("bull_ding", bull_ding())
    save("pp_paddle", pp_paddle())
    save("pp_table", pp_table())
    save("pp_net", pp_net())
    save("pet_clack", pet_clack())
    save("pet_land", pet_land())
    save("ambience_loop", alley_ambience(), 2)
    save("music_lounge", music(), 3)
