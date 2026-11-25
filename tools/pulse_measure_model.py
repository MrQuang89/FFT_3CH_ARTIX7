#!/usr/bin/env python3
"""Mo hinh bit-chinh-xac (cung thuat toan) cua FTT_512_NEW_CH123/pulse_measure.vhd
de kiem chung do chinh xac truoc khi nap FPGA.  Chay:  python3 pulse_measure_model.py
Chi dung thu vien chuan."""
import math, random

FS = 230.0           # MHz
TICK_NS = 1000.0 / FS
WIN = 8


def measure(adc, THRESH=600, GAP=12, MIN_PW=4, MAX_PW=60000, ADC_DC=0):
    """adc: list int (bu 2, 14 bit). Tra ve list (pw, long, amp, pri, seq) moi xung."""
    a0 = [min(abs(x - ADC_DC), 16383) for x in adc]
    def wmax(a, w):  # max cua so truot w mau (cua so luc dau = 0)
        return [max(a[max(0, n - w + 1):n + 1]) for n in range(len(a))]
    env = wmax(a0, WIN)
    out, st, since, seq = [], "IDLE", 0xFFFFFF, 0
    el = last = gap = peak = pri = 0
    for e_in in env:
        since = since if since == 0xFFFFFF else since + 1
        if st == "IDLE":
            if e_in >= THRESH:
                st, el, last, gap, peak, pri = "PULSE", 1, 1, 0, e_in, since
        elif st == "PULSE":
            e = el + 1; el = e
            peak = max(peak, e_in)
            if e_in >= THRESH:
                last, gap = e, 0
                if e >= MAX_PW:
                    seq = (seq + 1) & 255
                    out.append((MAX_PW, 1, peak, pri, seq)); since = e; st = "WAIT"
            else:
                if gap >= GAP - 1:
                    pw = last - (WIN - 1) if last > WIN - 1 else 0
                    if pw >= MIN_PW:
                        seq = (seq + 1) & 255
                        out.append((pw, 0, peak, pri, seq)); since = e
                    st = "IDLE"
                else:
                    gap += 1
        else:  # WAIT
            if e_in < THRESH:
                if gap >= GAP - 1: st = "IDLE"
                else: gap += 1
            else: gap = 0
    return out


def make_signal(n, pulses, f_rf, amp=2000, noise=8, edge_ns=10.0, seed=1):
    """pulses: list (start_sample, width_ns). Tin hieu RF f_rf (MHz) lay mau 230 MHz."""
    rnd = random.Random(seed)
    sig = [0.0] * n
    for s, wns in pulses:
        e = s + wns / TICK_NS
        for k in range(max(0, s - 10), min(n, int(e) + 10)):
            t_in, t_out = (k - s) * TICK_NS, (e - k) * TICK_NS
            env = min(1.0, max(0.0, t_in / edge_ns), max(0.0, t_out / edge_ns))
            sig[k] = env
    ph = rnd.random() * 6.28
    return [int(max(-8192, min(8191, round(amp * sig[k] * math.sin(2 * math.pi * f_rf * k / FS + ph) + rnd.gauss(0, noise)))))
            for k in range(n)]


if __name__ == "__main__":
    print("RF(MHz) alias  |  PW that(ns) -> do duoc(ns) [sai so mau]   (nguong 600, bien do 2000, nhieu 8 LSB)")
    worst = 0
    for f in (470, 500, 520, 545, 570):
        row = []
        for w in (200, 400, 800, 2000):
            n = 2000
            s = make_signal(n, [(300, w), (1200, w)], f)
            r = measure(s)
            if len(r) != 2:
                row.append("%d: SO XUNG=%d" % (w, len(r))); worst = 99; continue
            ns = r[0][0] * TICK_NS
            err = r[0][0] - w / TICK_NS
            worst = max(worst, abs(err))
            row.append("%d->%.0f (%+.1f)" % (w, ns, err))
        print("%5d %5.0f | %s" % (f, f - 460, "   ".join(row)))
    # PRI
    s = make_signal(30000, [(1000 + i * 4000, 500) for i in range(5)], 520)
    r = measure(s)
    print("PRI do duoc (mau):", [x[3] for x in r], "(ky vong 4000, xung dau = 16777215 khong hop le)")
    # nhieu: xung tep
    rnd = random.Random(3)
    noise_only = [int(rnd.gauss(0, 30)) for _ in range(200000)]
    print("So xung gia tren 200000 mau nhieu sigma=30 LSB, nguong 600:", len(measure(noise_only)))
    print("Sai so xau nhat (mau): %.2f  (= %.1f ns)" % (worst, worst * TICK_NS))
