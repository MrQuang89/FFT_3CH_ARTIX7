# Đo tham số thời gian xung trực tiếp từ dữ liệu ADC

## 1. Có tính được không?
**Có.** ADC lấy mẫu 14 bit ở 230 MSPS, nên xung RF 0.2–5 µs gồm khoảng 46–1150 mẫu liên tiếp. Chỉ cần xác định mẫu nào thuộc xung là đo được:

| Tham số | Cách đo | Độ phân giải |
|---|---|---|
| **PW** (độ rộng xung) | số mẫu mà đường bao vượt ngưỡng | 1 mẫu = 4.348 ns |
| **PRI** (chu kỳ lặp) → PRF | số chu kỳ clock giữa thời điểm bắt đầu 2 xung hợp lệ liên tiếp | 4.348 ns, tối đa 16.7 M chu kỳ ≈ 73 ms (PRI 50–5000 µs nằm gọn) |
| **AMP** (biên độ đỉnh) | giá trị đường bao lớn nhất trong xung | 1 LSB |
| **SEQ** | đếm xung hợp lệ (mod 256) | PC biết có phép đo mới |

Bao gồm cả khả năng đo độ rộng của xung nhìn từ chính dữ liệu số hóa — độc lập với tín hiệu `pulse_detect` (tín hiệu này vẫn chỉ dùng để kích FFT).

## 2. Khó khăn và cách giải quyết
Tín hiệu RF 460–575 MHz lấy mẫu 230 MHz bị *aliasing* xuống 0–115 MHz, nên các mẫu ADC **dao động qua 0**. Nếu so sánh trực tiếp |x| với ngưỡng thì xung bị "thủng" ở các điểm cắt 0. Giải pháp: đường bao bằng **max trượt 8 mẫu** (34.8 ns).
Với tần số alias thấp nhất trong băng (≈10 MHz, chu kỳ 23 mẫu) chỗ |x| nhỏ chỉ kéo dài vài mẫu, nhỏ hơn cửa sổ 8 mẫu nên được lấp đầy.

## 3. Thuật toán (`FTT_512_NEW_CH123/pulse_measure.vhd`)
1. `a0 = |x − ADC_DC|` (bão hòa 14 bit).
2. Cây max 3 tầng: `m2 = max(a[n], a[n−1])`, `m4 = max(m2[n], m2[n−2])`, `env = max(m4[n], m4[n−4])` → `env[n] = max(a[n−7..n])`. Mỗi tầng một thanh ghi nên đủ nhanh ở 230 MHz.
3. Máy trạng thái:
   * `IDLE`: khi `env ≥ THRESH` → bắt đầu xung, lưu `PRI = since_last` (bộ đếm từ lần bắt đầu xung hợp lệ trước).
   * `PULSE`: đếm số mẫu; mỗi mẫu có `env ≥ THRESH` thì ghi lại `last_el`; nếu `env < THRESH` liên tiếp `GAP` mẫu (mặc định 12) thì kết thúc.
   * `WAIT_LOW`: chỉ dùng khi xung dài hơn `MAX_PW` (cắt, bật cờ LONG), chờ xung hạ xuống.
4. **PW = last_el − 7.** Cửa sổ max 8 mẫu kéo dài *cạnh xuống* đúng 7 mẫu, còn cạnh lên không bị trễ, nên trừ hằng số 7 là bù chính xác và không phụ thuộc biên độ (khác với bộ giữ đỉnh phân rã kiểu RC có sai số phụ thuộc biên độ).
5. Xung có PW < `MIN_PW` (4 mẫu ≈ 17 ns) bị coi là nhiễu và bỏ qua; PRI không bị ảnh hưởng.
6. `since_last` ← số chu kỳ từ lúc bắt đầu xung này (để lần sau PRI là khoảng cách đầu–đầu).

## 4. Đóng gói và truyền
```
FFT_CH ── pulse_measure (230 MHz) ── meas_valid + 64 bit ──► meas_cdc (230→50 MHz) ──► Ethernet_module
```
* `meas_cdc`: bắt tay toggle req/ack, bus 64 bit không bao giờ bị "xé"; đầu ra đóng băng khi Ethernet đang đọc byte (`fifo_rd_en_ethernet = 1`).
* Payload UDP vẫn 256 byte, **byte 0–10 giữ nguyên** (tương thích phần mềm cũ), thêm byte 11–37:

| Byte | Nội dung |
|---|---|
| 11 | 0x91 (CH1) |
| 12–13 | PW (16 bit, đơn vị 4.348 ns) |
| 14–15 | bit 15 = LONG (xung bị cắt), bit 13..0 = AMP |
| 16–18 | PRI (24 bit, đơn vị 4.348 ns); 0xFFFFFF = chưa có xung trước |
| 19 | SEQ |
| 20–28 | giống trên, marker 0x92 (CH2) |
| 29–37 | giống trên, marker 0x93 (CH3) |

* PC: `pc_software/fpga_udp_monitor.py` giải mã và hiển thị PW (ns), PRI (µs), PRF (Hz), biên độ, SEQ, số xung mới nhận.

## 5. Kiểm chứng đã làm
Chưa có công cụ Xilinx/mô phỏng VHDL trong môi trường soạn thảo, nên **VHDL chưa được biên dịch hay mô phỏng**. Thay vào đó `tools/pulse_measure_model.py` mô hình hóa đúng từng bước thuật toán (cùng cửa sổ, ngưỡng, GAP, bù 7 mẫu) và chạy trên tín hiệu RF 470–570 MHz, biên độ 2000, nhiễu 8 LSB, sườn 10 ns, ngưỡng 600:

| PW thật | PW đo | Sai số |
|---|---|---|
| 200, 400, 800, 2000 ns | 191–196, 391–396, 791–796, 1991–1996 ns | −1 đến −2 mẫu (−4 đến −9 ns), mọi tần số |

PRI đo được 4001 mẫu cho PRI thật 4000 (±1 mẫu); xung đầu tiên báo PRI không hợp lệ; 200 000 mẫu nhiễu σ = 30 LSB không sinh xung giả nào.
Có kèm testbench `sim/tb_pulse_measure.vhd` (tự kiểm tra) để chạy bằng ISim — **chưa chạy**.

## 6. Giới hạn và việc cần làm trên phần cứng
* **Ngưỡng `THRESH` (mặc định 600 LSB ≈ 7 % thang đo) phải chỉnh theo mức nhiễu/tín hiệu thật**, riêng từng kênh qua `PM_THRESH_CH1..3` trong `main_prog.vhd`. PW đo tại mức ngưỡng cố định nên xung biên độ nhỏ (sườn lên chậm) cho PW hơi ngắn hơn; có thể dùng biên độ AMP gửi lên để bù ở PC. Ngưỡng nên ≈ 30–50 % biên độ xung nhỏ nhất cần đo, và ≥ 5σ nhiễu.
* Mã ADC giả định **bù 2**. Nếu ADC ra offset binary, đặt `ADC_DC` (hoặc đảo bit MSB trước khi vào) cho đúng.
* Độ phân giải 1 mẫu (4.35 ns) với sai lệch hệ thống ≈ −1.5 mẫu như bảng trên; có thể hiệu chuẩn bằng hằng số ở PC bằng xung chuẩn.
* Xung < 0.2 µs ở mức tín hiệu thấp có thể bị nhiễu làm lệch ±1–2 mẫu.
* Thiết kế ở 230 MHz chưa kiểm tra PAR: đường `max` 14 bit một chu kỳ nên dễ đạt, nhưng cần xem `top.twr`.
* Thêm 3 × pulse_measure + 3 × meas_cdc dùng rất ít tài nguyên (không DSP, không BRAM).
