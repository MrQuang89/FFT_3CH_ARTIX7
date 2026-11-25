#!/usr/bin/env python3
"""Mo hinh kiem chung kich FFT tu du lieu ADC (pulse_measure.trig + duong tre PRE_DELAY).
Chay: python3 trigger_model.py   (chi dung thu vien chuan)"""
import math, random, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pulse_measure_model import make_signal, FS, TICK_NS, WIN

THRESH, C, PRE = 600, 16, 8
PRE_DELAY = C + 5 + PRE          # phai trung voi hang so trong FFT_512_CH.vhd
PIPE = 4                          # a0 -> m2 -> m4 -> env (4 thanh ghi)


def envelope(x, dc=0):
    a = [min(abs(v - dc), 16383) for v in x]
    return [max(a[max(0, n - WIN + 1):n + 1]) for n in range(len(a))]


def triggers(x):
    """Tra ve list (chi so mau dau tien tren nguong s', chu ky co trig, chu ky bat dau ghi FIFO)."""
    env, out, n = envelope(x), [], 0
    N = len(env)
    while n < N:
        if env[n] >= THRESH:
            s, run, k = n, 1, n + 1
            fired = False
            while k < N:
                if env[k] >= THRESH:
                    run += 1
                    if run == C and not fired:
                        fired = True
                        trig_cycle = (s + C - 1) + PIPE + 1       # trig_r hien o chu ky nay
                        out.append((s, trig_cycle, trig_cycle + 1))   # FSM thay trig, S_CAPTURE o chu ky ke tiep
                else:
                    gap = 0
                    while k + gap < N and env[k + gap] < THRESH and gap < 12:
                        gap += 1
                    if gap >= 12 or k + gap >= N:
                        break
                    run = 0
                    k += gap - 1
                k += 1
            n = k + 1
        else:
            n += 1
    return out


def dft_peak(w, nb=256):
    best, bi = -1, 0
    for k in range(nb):
        re = sum(w[n] * math.cos(2 * math.pi * k * n / 512) for n in range(512))
        im = sum(w[n] * math.sin(2 * math.pi * k * n / 512) for n in range(512))
        p = re * re + im * im
        if p > best: best, bi = p, k
    return bi


if __name__ == "__main__":
    print("PRE_DELAY = %d mau (= %d + 5 + %d)" % (PRE_DELAY, C, PRE))
    print("RF(MHz) | bin ky vong | mau dau khung - mau dau xung | bin do duoc (FFT khung bat dau o trig)")
    for f in (470, 500, 520, 545, 570):
        alias = (f - 460) % 230
        exp_bin = alias * 512 / FS
        x = make_signal(3000, [(500, 400)], f, amp=2000, noise=8, seed=5)
        tr = triggers(x)
        assert len(tr) == 1, tr
        s, tcyc, first_cap_cycle = tr[0]
        first_sample = first_cap_cycle - PRE_DELAY       # mau ADC dau tien duoc ghi (adc_cap = x[cycle - D])
        w = x[first_sample:first_sample + 512]
        print("%5d   | %8.1f    | %+d                           | %d" % (f, exp_bin, first_sample - s, dft_peak(w)))
    # xung ngan 200 ns va xung dai
    for w_ns in (200, 2000):
        x = make_signal(3000, [(500, w_ns)], 520, seed=2)
        s, t, c = triggers(x)[0]
        fs_ = c - PRE_DELAY
        print("PW %4d ns: kich sau mau dau tren nguong %d mau, khung bat dau %d mau truoc xung" % (w_ns, t - s, s - fs_))
    # nhieu thuan: so lan kich gia
    rnd = random.Random(7)
    for sig in (10, 30, 80):
        nz = [int(rnd.gauss(0, sig)) for _ in range(400000)]
        print("nhieu sigma=%d LSB, nguong %d: so lan kich gia trong 400000 mau (1.74 ms) = %d" % (sig, THRESH, len(triggers(nz))))
    # 2 xung PRI 50 us
    x = make_signal(40000, [(1000, 300), (1000 + 11500, 300), (1000 + 23000, 300)], 500, seed=9)
    print("3 xung PRI 50 us -> so kich:", len(triggers(x)))
