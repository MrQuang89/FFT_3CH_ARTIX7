#!/usr/bin/env python3
"""
Phan mem PC kiem tra ket noi + hien thi ket qua FFT 3 kenh gui tu FPGA qua UDP.

Dinh dang goi (theo Ethernet_module.vhd, payload 256 byte, ~3.3 goi/giay toi da):
  byte0 = 00 | 1: AA | 2: 81 | 3: H1 | 4: L1 | 5: 82 | 6: H2 | 7: L2 | 8: 83 | 9: H3 | 10: L3 | 11..255 = 00
  index_kenh = (H << 7) | L          (H: 0..7, L: 0..127)
  tan_so (MHz) = index * 230 / 512 + 460     (lay mau 230 MHz, bang tan so 460..575 MHz)

Cau hinh mang cua FPGA (co dinh trong VHDL):
  FPGA : IP 10.0.0.5  MAC 00:12:34:56:78:90  cong 1026 (0x0402)
  PC   : IP 10.0.0.4  MAC F0:DE:F1:14:0B:14  <- FPGA gui thang toi MAC nay (khong ARP)
  => dat IP tinh 10.0.0.4/24 cho card mang noi voi FPGA (hoac sua desMacAddr trong VHDL).

Chay:
  python fpga_udp_monitor.py             # giao dien do hoa (tkinter)
  python fpga_udp_monitor.py --cli       # dong lenh, khong can GUI
  python fpga_udp_monitor.py --simulate  # gia lap FPGA gui goi toi 127.0.0.1 (thu phan mem)
Chi dung thu vien chuan cua Python 3.
"""
import argparse, socket, struct, sys, threading, time, random, collections

PORT = 1026
FS_MHZ, BAND_OFFSET_MHZ, NFFT = 230.0, 460.0, 512
PAYLOAD_LEN = 256
CH_COLORS = ("#d62728", "#2ca02c", "#1f77b4")


def idx_to_mhz(idx, fs=FS_MHZ, off=BAND_OFFSET_MHZ):
    return idx * fs / NFFT + off


def parse_payload(p):
    """Tra ve (idx1, idx2, idx3) hoac None neu sai khuon dang."""
    for o in range(0, min(4, len(p))):       # chiu duoc lech vai byte dau
        if len(p) >= o + 11 and p[o] == 0xAA and p[o+1] == 0x81 and p[o+4] == 0x82 and p[o+7] == 0x83:
            idx = lambda h, l: ((h & 0x07) << 7) | (l & 0x7F)
            return (idx(p[o+2], p[o+3]), idx(p[o+5], p[o+6]), idx(p[o+8], p[o+9]))
    return None


class Receiver(threading.Thread):
    def __init__(self, bind_ip, port):
        super().__init__(daemon=True)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((bind_ip, port))
        self.sock.settimeout(0.5)
        self.lock = threading.Lock()
        self.total = self.bad = 0
        self.src = None
        self.last_len = 0
        self.last = (None, None, None)
        self.changes = [0, 0, 0]
        self.rate_win = collections.deque(maxlen=2000)   # thoi diem nhan goi
        self.hist = [collections.deque(maxlen=1200) for _ in range(3)]  # (t, MHz) 20 mau/s
        self.last_hist_t = 0.0
        self.first_t = None
        self.log = collections.deque(maxlen=200)
        self.running = True

    def run(self):
        while self.running:
            try:
                data, addr = self.sock.recvfrom(4096)
            except socket.timeout:
                continue
            except OSError:
                break
            now = time.time()
            res = parse_payload(data)
            with self.lock:
                self.total += 1
                self.src, self.last_len = addr, len(data)
                self.rate_win.append(now)
                if self.first_t is None:
                    self.first_t = now
                if res is None:
                    self.bad += 1
                    self.log.append("%.3f goi sai khuon dang (%d byte): %s" % (now, len(data), data[:16].hex(" ")))
                    continue
                for c in range(3):
                    if self.last[c] is not None and res[c] != self.last[c]:
                        self.changes[c] += 1
                self.last = res
                if now - self.last_hist_t >= 0.05:
                    self.last_hist_t = now
                    for c in range(3):
                        self.hist[c].append((now, idx_to_mhz(res[c])))

    def snapshot(self):
        with self.lock:
            now = time.time()
            r = [t for t in self.rate_win if now - t <= 2.0]
            rate = len(r) / 2.0
            return dict(total=self.total, bad=self.bad, src=self.src, length=self.last_len,
                        last=self.last, changes=list(self.changes), rate=rate,
                        age=(now - self.rate_win[-1]) if self.rate_win else None,
                        hist=[list(h) for h in self.hist], log=list(self.log))

    def stop(self):
        self.running = False
        self.sock.close()


def diagnose(s):
    if s["total"] == 0:
        return ("CHUA NHAN GOI NAO. Kiem tra: (1) cap mang/den PHY; (2) card mang PC dat IP tinh 10.0.0.4/24; "
                "(3) firewall cho phep UDP cong %d; (4) MAC dich trong VHDL (desMacAddr) = MAC cua PC; "
                "(5) FPGA da nap bitstream." % PORT)
    if s["age"] is not None and s["age"] > 2:
        return "Mat ket noi: %.1f s chua co goi moi." % s["age"]
    if s["bad"] and s["bad"] == s["total"]:
        return "Co goi toi nhung sai khuon dang (kiem tra payload/ cong)."
    return "Ket noi OK."


def fmt_ch(idx):
    return "  --  " if idx is None else "%3d  %8.2f MHz" % (idx, idx_to_mhz(idx))


def run_cli(rx):
    try:
        while True:
            time.sleep(1.0)
            s = rx.snapshot()
            print("[%s] goi=%d loi=%d toc do=%.0f goi/s | CH1 %s | CH2 %s | CH3 %s | nguon=%s" % (
                time.strftime("%H:%M:%S"), s["total"], s["bad"], s["rate"],
                fmt_ch(s["last"][0]), fmt_ch(s["last"][1]), fmt_ch(s["last"][2]),
                "%s:%d" % s["src"] if s["src"] else "-"), flush=True)
            if s["total"] == 0 or (s["age"] or 0) > 2:
                print("   ->", diagnose(s), flush=True)
    except KeyboardInterrupt:
        pass


def run_gui(rx):
    import tkinter as tk
    from tkinter import ttk
    root = tk.Tk()
    root.title("FPGA 3-kenh FFT - UDP monitor (cong %d)" % PORT)
    root.geometry("900x620")
    status = tk.StringVar()
    diag = tk.StringVar()
    ttk.Label(root, textvariable=status, font=("Consolas", 10)).pack(anchor="w", padx=8, pady=(8, 0))
    diag_lbl = ttk.Label(root, textvariable=diag, font=("Segoe UI", 11, "bold"))
    diag_lbl.pack(anchor="w", padx=8, pady=4)

    frm = ttk.Frame(root); frm.pack(fill="x", padx=8)
    cols = ("kenh", "index", "tan so (MHz)", "so lan doi")
    tv = ttk.Treeview(frm, columns=cols, show="headings", height=3)
    for c, w in zip(cols, (80, 100, 160, 120)):
        tv.heading(c, text=c); tv.column(c, width=w, anchor="center")
    tv.pack(side="left")
    for i in range(3):
        tv.insert("", "end", iid=str(i), values=("CH%d" % (i + 1), "-", "-", 0))

    lg = tk.Text(root, height=4, font=("Consolas", 9)); lg.pack(fill="x", padx=8, pady=4)
    cv = tk.Canvas(root, bg="white", highlightthickness=1, highlightbackground="#999")
    cv.pack(fill="both", expand=True, padx=8, pady=8)

    def draw(s):
        cv.delete("all")
        W, H = cv.winfo_width(), cv.winfo_height()
        L, R, T, B = 60, 10, 10, 25
        lo, hi = BAND_OFFSET_MHZ, BAND_OFFSET_MHZ + FS_MHZ / 2
        span_s = 60.0
        now = time.time()
        for k in range(0, 6):
            f = lo + (hi - lo) * k / 5
            y = H - B - (H - T - B) * k / 5
            cv.create_line(L, y, W - R, y, fill="#e5e5e5")
            cv.create_text(L - 6, y, text="%.0f" % f, anchor="e", font=("Consolas", 8))
        cv.create_text(L + 5, T + 2, text="Tan so (MHz) theo thoi gian, 60 s gan nhat", anchor="nw", font=("Segoe UI", 9))
        for c in range(3):
            pts = []
            for t, f in s["hist"][c]:
                if now - t > span_s: continue
                x = L + (W - L - R) * (1 - (now - t) / span_s)
                y = H - B - (H - T - B) * (f - lo) / (hi - lo)
                pts += [x, y]
            if len(pts) >= 4:
                cv.create_line(*pts, fill=CH_COLORS[c], width=2)
            cv.create_text(W - 70, T + 12 + 14 * c, text="CH%d" % (c + 1), fill=CH_COLORS[c], anchor="w", font=("Segoe UI", 10, "bold"))

    def tick():
        s = rx.snapshot()
        status.set("Goi nhan: %d   Loi: %d   Toc do: %.0f goi/s   Nguon: %s   Do dai: %d byte" % (
            s["total"], s["bad"], s["rate"], "%s:%d" % s["src"] if s["src"] else "-", s["length"]))
        msg = diagnose(s)
        diag.set(msg)
        diag_lbl.configure(foreground="#0a7d2c" if msg.startswith("Ket noi OK") else "#c0392b")
        for i in range(3):
            idx = s["last"][i]
            tv.item(str(i), values=("CH%d" % (i + 1), "-" if idx is None else idx,
                                    "-" if idx is None else "%.2f" % idx_to_mhz(idx), s["changes"][i]))
        lg.delete("1.0", "end"); lg.insert("end", "\n".join(s["log"][-4:]))
        draw(s)
        root.after(100, tick)

    tick()
    root.mainloop()


def run_simulator(host, port):
    """Gia lap FPGA: gui goi 256 byte dung khuon dang, tan so tung kenh troi cham."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    base = [60, 120, 180]
    t0 = time.time()
    print("Simulator gui toi %s:%d (Ctrl+C de dung)" % (host, port))
    try:
        while True:
            now = time.time() - t0
            idxs = [max(0, min(255, int(b + 30 * __import__("math").sin(now / (3 + i)) + random.randint(-1, 1))))
                    for i, b in enumerate(base)]
            p = bytearray(PAYLOAD_LEN)
            p[0:11] = bytes([0x00, 0xAA, 0x81, idxs[0] >> 7, idxs[0] & 0x7F, 0x82, idxs[1] >> 7,
                             idxs[1] & 0x7F, 0x83, idxs[2] >> 7, idxs[2] & 0x7F])
            s.sendto(bytes(p), (host, port))
            time.sleep(0.003)   # ~300 goi/s
    except KeyboardInterrupt:
        pass


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bind", default="0.0.0.0", help="dia chi IP cua PC de lang nghe (mac dinh tat ca)")
    ap.add_argument("--port", type=int, default=PORT)
    ap.add_argument("--cli", action="store_true", help="chay dong lenh, khong mo GUI")
    ap.add_argument("--simulate", action="store_true", help="gia lap FPGA gui toi --host")
    ap.add_argument("--host", default="127.0.0.1", help="dia chi nhan cua simulator")
    a = ap.parse_args()
    if a.simulate:
        return run_simulator(a.host, a.port)
    rx = Receiver(a.bind, a.port); rx.start()
    try:
        if a.cli:
            run_cli(rx)
        else:
            try:
                run_gui(rx)
            except Exception as e:      # khong co tkinter / man hinh
                print("Khong mo duoc GUI (%s) -> chuyen sang --cli" % e)
                run_cli(rx)
    finally:
        rx.stop()


if __name__ == "__main__":
    main()
