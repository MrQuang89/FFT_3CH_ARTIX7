# Kích FFT từ xung phát hiện trên dữ liệu ADC (thay cho `pulse_detect`)

## 1. Có làm được không?
**Có.** Mỗi kênh đã có bộ phát hiện xung (`pulse_measure`, đường bao max-trượt 8 mẫu so với ngưỡng). Chỉ cần cho nó phát thêm một xung `trig` khi xác nhận có xung RF, rồi dùng `trig` thay cho `pulse_detect` đã đồng bộ để chuyển FSM của `FFT_CH` từ `S_IDLE` sang `S_CAPTURE`.

Lợi ích: mỗi kênh tự kích theo tín hiệu của chính nó (không cần chung 1 chân detector, không chịu độ trễ/độ nhạy của mạch analog ngoài, không còn bài toán bất đồng bộ), và biết chính xác vị trí xung trong khung FFT.

## 2. Vấn đề phải giải quyết: độ trễ phát hiện
Xung chỉ được xác nhận *sau* khi nó đã bắt đầu, nên nếu bắt đầu ghi 512 mẫu lúc nhận `trig` thì phần đầu xung đã mất (và xung ngắn 0.2 µs = 46 mẫu gần như mất hết). Giải pháp: **ghi trước (pre-trigger)** — cho ADC đi qua đường trễ `PRE_DELAY` mẫu trước khi vào FIFO, sao cho khung 512 mẫu bắt đầu `TRIG_PRE` mẫu *trước* mẫu đầu tiên vượt ngưỡng.

Độ trễ từ mẫu đầu tiên vượt ngưỡng (chỉ số s) đến khi bắt đầu ghi, tính theo chu kỳ clock:

| Bước | Trễ |
|---|---|
| ADC → `a0` → `m2` → `m4` → `env` (4 thanh ghi) | 4 |
| Đếm `TRIG_CONFIRM` mẫu liên tiếp trên ngưỡng (mẫu thứ C) | C − 1 |
| `trig_r` được thanh ghi hóa | 1 |
| FSM thấy `trigger` ở `S_IDLE` → `S_CAPTURE` | 1 |
| Tổng: mẫu đầu tiên ghi vào FIFO tại chu kỳ s + C + 5 | C + 5 |

`PRE_DELAY = TRIG_CONFIRM + 5 + TRIG_PRE` (mặc định 16 + 5 + 8 = 29 mẫu) nên mẫu đầu khung = x[s − TRIG_PRE]. Đường trễ là thanh ghi dịch 14 bit × 29 (SRL, rất nhỏ).

`TRIG_CONFIRM` (mặc định 16 mẫu liên tiếp): một mẫu nhiễu vượt ngưỡng làm đường bao (cửa sổ 8 mẫu) ≥ ngưỡng đúng 8 mẫu liên tiếp, nên đặt C > 8 để loại nhiễu đơn lẻ; xung hợp lệ ≥ 0.2 µs cho ≥ 53 mẫu nên chắc chắn qua. Mỗi xung chỉ kích 1 lần (cờ `fired`); xung dài/CW không kích lại.

## 3. Thay đổi trong code
| File | Thay đổi |
|---|---|
| `pulse_measure.vhd` | Thêm generic `TRIG_CONFIRM`, cổng `trig` (xung 1 chu kỳ), bộ đếm `run_cnt`/cờ `fired` ở trạng thái `S_PULSE`. Phần đo PW/PRI/AMP **không đổi** |
| `FFT_512_CH.vhd` | Thêm generic `TRIG_SOURCE` (1 = ADC, 0 = `pulse_detect` như cũ), `TRIG_CONFIRM`, `TRIG_PRE`. Dùng `generate` chọn nguồn: nhánh ADC dùng `pm_trig` + đường trễ `adc_dly`; nhánh ngoài giữ nguyên bộ đồng bộ 2 FF + bắt sườn. FIFO ghi `adc_cap` thay cho `adc_in1_ch1` |
| `main_prog.vhd` | Hằng số `TRIG_SRC` (=1) truyền vào 3 kênh. Chân `pulse_detect` vẫn nối ra `pulse_detect_orig` để quan sát/so sánh |
| `tools/trigger_model.py`, `sim/tb_pulse_measure.vhd` | Mô hình kiểm chứng; testbench cập nhật cổng `trig` |

Quay lại kích bằng chân ngoài chỉ cần đặt `TRIG_SRC := 0` trong `main_prog.vhd` (khi đó không có đường trễ, giống hệt trước).

## 4. Kiểm chứng đã làm (mô hình Python, `tools/trigger_model.py`)
VHDL **chưa biên dịch/mô phỏng** (không có công cụ Xilinx ở đây). Mô hình lặp lại đúng chuỗi độ trễ ở bảng trên, biên độ 2000, nhiễu 8 LSB, ngưỡng 600:

* Khung FFT bắt đầu **đúng 8 mẫu trước** mẫu đầu tiên vượt ngưỡng, với xung 0.2 µs và 2 µs.
* DFT 512 điểm của khung đó cho bin đỉnh = bin kỳ vọng ±1 ở mọi tần số 470–570 MHz (22/22, 89/89, 134/133.6, 189/189, 244/244.9).
* Không kích giả trên 400 000 mẫu nhiễu σ = 10, 30, 80 LSB; 3 xung PRI 50 µs kích đủ 3 lần.

## 5. Lưu ý
* Ngưỡng `PM_THRESH_CHx` giờ quyết định cả việc kích; ngưỡng thấp → kích giả, cao → bỏ sót xung yếu. Xung yếu hơn ngưỡng sẽ không được FFT (khác với kích bằng detector analog có độ nhạy riêng).
* Bộ FFT bận khoảng 2100+ chu kỳ (≈ 10 µs) cho mỗi xung; xung đến trong lúc bận bị bỏ qua FFT (vẫn được đo PW/PRI). Với PRI 50–5000 µs không ảnh hưởng.
* Khung 512 mẫu (2.2 µs) dài hơn xung 0.2–0.8 µs nên phần ngoài xung chỉ có nhiễu; độ phân giải tần số không đổi, nhưng tỷ số tín hiệu/nhiễu của đỉnh phổ giảm theo độ dài xung (giống kích bằng detector cũ).
* Phụ thuộc vào `MAG_LATENCY` hiện hành không đổi; kích mới không ảnh hưởng đến căn chỉnh chỉ số bin.
