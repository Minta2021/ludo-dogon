"""Synthèse des sons de Ludo Dogon (aucun fichier externe : tout est calculé).

- de.wav        : le dé secoué dans la main puis qui roule sur le plateau
- cri_avale.wav : coup de djembé + cri « Hé-yaaa ! » quand un pion est avalé
"""
import os
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

FS = 44100
rng = np.random.default_rng(7)


def t_axis(duration):
    return np.arange(int(duration * FS)) / FS


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (FS / 2), hi / (FS / 2)], btype='band')
    return lfilter(b, a, x)


def highpass(x, f, order=2):
    b, a = butter(order, f / (FS / 2), btype='high')
    return lfilter(b, a, x)


def lowpass(x, f, order=2):
    b, a = butter(order, f / (FS / 2), btype='low')
    return lfilter(b, a, x)


def place(buf, sig, at):
    i = int(at * FS)
    n = min(len(sig), len(buf) - i)
    if n > 0:
        buf[i:i + n] += sig[:n]


# ---------------------------------------------------------------------------
# Le dé


def impact(amp, bright=1.0, wood=True):
    """Un choc du dé : quelques modes amortis + un petit souffle de bruit."""
    t = t_axis(0.09)
    out = np.zeros_like(t)
    base = [1250, 2350, 3550, 5300] if wood else [2600, 4100, 6200, 8300]
    for k, f in enumerate(base):
        f *= rng.uniform(0.92, 1.08) * bright
        decay = rng.uniform(0.006, 0.018) / (1 + 0.35 * k)
        out += rng.uniform(0.5, 1.0) / (1 + 0.5 * k) * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / decay)
    noise = highpass(rng.normal(0, 1, len(t)), 1800) * np.exp(-t / 0.0018)
    out += 0.6 * noise
    if wood:
        out += 0.5 * np.sin(2 * np.pi * rng.uniform(160, 220) * t) * np.exp(-t / 0.012)
    return amp * out


def dice_sound():
    dur = 0.72
    buf = np.zeros(int(dur * FS))
    # 1) Le dé secoué dans la main : petits cliquetis rapides.
    tt = 0.0
    for i in range(5):
        tt += rng.uniform(0.032, 0.046)
        for j in range(rng.integers(1, 3)):
            place(buf, impact(0.18 + 0.05 * rng.random(), bright=1.25, wood=False), tt + 0.006 * j)
    # 2) Le dé lancé sur le plateau : rebonds de plus en plus rapprochés.
    t0 = 0.27
    gaps = [0.075, 0.058, 0.045, 0.036, 0.029, 0.024, 0.02, 0.017, 0.015]
    amp = 1.0
    tt = t0
    place(buf, impact(amp), tt)
    for g in gaps:
        tt += g * rng.uniform(0.9, 1.1)
        amp *= rng.uniform(0.62, 0.74)
        place(buf, impact(amp), tt)
    # 3) Un léger roulement entre les rebonds.
    roll = bandpass(rng.normal(0, 1, len(buf)), 900, 4000)
    env = np.zeros(len(buf))
    i0, i1 = int(t0 * FS), int((tt + 0.06) * FS)
    env[i0:i1] = np.linspace(0.06, 0.0, i1 - i0)
    buf += roll * env
    buf = highpass(buf, 90)
    fade = int(0.03 * FS)
    buf[-fade:] *= np.linspace(1, 0, fade)
    return buf


# ---------------------------------------------------------------------------
# Le cri


def resonator_cascade(x, formants, bandwidths):
    """Filtre de formants à la Klatt (cascade de résonateurs), variable dans
    le temps : formants[k] et bandwidths[k] sont des tableaux par échantillon."""
    y = x.copy()
    T = 1.0 / FS
    for F, B in zip(formants, bandwidths):
        C = -np.exp(-2 * np.pi * B * T)
        B1 = 2 * np.exp(-np.pi * B * T) * np.cos(2 * np.pi * F * T)
        A = 1 - B1 - C
        out = np.zeros_like(y)
        y1 = y2 = 0.0
        for n in range(len(y)):
            v = A[n] * y[n] + B1[n] * y1 + C[n] * y2
            out[n] = v
            y2, y1 = y1, v
        y = out
    return y


def interp(times, values, t):
    return np.interp(t, times, values)


def shout():
    dur = 1.05
    t = t_axis(dur)
    n = len(t)

    # Hauteur de la voix : « hé » court, puis « yaaa » qui monte, tient et retombe.
    f0 = interp([0.0, 0.14, 0.19, 0.30, 0.75, 0.98],
                [235, 250, 255, 335, 320, 230], t)
    vib = 1 + 0.025 * np.sin(2 * np.pi * 5.6 * t) * interp([0, 0.35, 0.5, 1.0], [0, 0, 1, 1], t)
    jitter = 1 + 0.008 * lowpass(rng.normal(0, 1, n), 40) * 6
    f0 = f0 * vib * jitter
    phase = 2 * np.cumsum(np.pi * f0 / FS)

    # Source glottique : harmoniques avec une pente douce (voix forcée).
    src = np.zeros(n)
    kmax = int(0.45 * FS / f0.max())
    for k in range(1, kmax + 1):
        src += np.sin(k * phase) / (k ** 1.05)
    src /= np.max(np.abs(src))
    aspiration = highpass(rng.normal(0, 1, n), 600) * 0.25

    # Voyelles : é -> (coupure) -> i -> a
    #           t:  0    0.13  0.165 0.19  0.26  0.98
    times = [0.0, 0.13, 0.17, 0.19, 0.27, 1.05]
    F1 = interp(times, [420, 430, 330, 310, 880, 860], t)
    F2 = interp(times, [1950, 1950, 2150, 2200, 1280, 1250], t)
    F3 = interp(times, [2600, 2600, 2900, 2950, 2550, 2500], t)
    F4 = np.full(n, 3500.0)
    F5 = np.full(n, 4300.0)
    BW = [np.full(n, 80.0), np.full(n, 100.0), np.full(n, 140.0), np.full(n, 200.0), np.full(n, 260.0)]

    # Enveloppes : souffle du « h », voix du « é », silence bref, « yaaa ».
    voice_env = interp([0.0, 0.03, 0.05, 0.12, 0.145, 0.175, 0.20, 0.26, 0.82, 1.0, 1.05],
                       [0.0, 0.0, 0.75, 0.8, 0.0, 0.0, 0.5, 1.0, 0.95, 0.0, 0.0], t)
    breath_env = interp([0.0, 0.01, 0.05, 0.07, 0.8, 1.0], [0.0, 0.9, 0.3, 0.12, 0.12, 0.0], t)
    shimmer = 1 + 0.05 * lowpass(rng.normal(0, 1, n), 30) * 5

    excitation = src * voice_env * shimmer + aspiration * breath_env
    voice = resonator_cascade(excitation, [F1, F2, F3, F4, F5], BW)
    voice /= np.max(np.abs(voice))

    # Djembé : basse qui tombe + claquement, juste avant la voix.
    td = t_axis(0.45)
    bass_f = 70 + 75 * np.exp(-td / 0.04)
    bass = np.sin(2 * np.pi * np.cumsum(bass_f) / FS) * np.exp(-td / 0.16)
    slap = bandpass(rng.normal(0, 1, len(td)), 900, 5000) * np.exp(-td / 0.03)
    tone = (np.sin(2 * np.pi * 680 * td) + 0.6 * np.sin(2 * np.pi * 1090 * td)) * np.exp(-td / 0.05)
    drum = 0.9 * bass + 0.55 * slap + 0.35 * tone

    mix = np.zeros(n)
    place(mix, drum, 0.0)
    place(mix, drum * 0.55, 0.16)
    place(mix, voice * 1.0, 0.02)

    # Saturation légère (voix forte), puis petit écho de case en banco.
    mix = np.tanh(2.0 * mix) / np.tanh(2.0)
    room = np.zeros(n)
    for delay, gain in [(0.023, 0.22), (0.041, 0.16), (0.067, 0.11), (0.097, 0.07)]:
        place(room, lowpass(mix, 3500) * gain, delay)
    mix = mix + room
    mix = highpass(mix, 60)
    fade = int(0.04 * FS)
    mix[-fade:] *= np.linspace(1, 0, fade)
    return mix


def save(name, x, peak=0.95):
    x = x / np.max(np.abs(x)) * peak
    pcm = np.int16(np.clip(x, -1, 1) * 32767)
    wavfile.write(name, FS, pcm)
    print(name, f'{len(pcm) / FS:.2f} s', os.path.getsize(name), 'octets')


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, 'de.wav'), dice_sound(), peak=0.9)
    save(os.path.join(out, 'cri_avale.wav'), shout(), peak=0.97)
