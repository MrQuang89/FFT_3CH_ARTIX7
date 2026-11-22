# Ghi chú kiểm tra & sửa lỗi – FFT 3 kênh Artix-7 (xc7a100t)

> Chưa chạy lại ISE/mô phỏng trong môi trường này (không có công cụ Xilinx). Cần **Synthesize → Implement** lại
> trong ISE 14.x và kiểm tra `top.twr` + đo lại bằng bảng khảo sát tần số.

## Lỗi tìm thấy và đã sửa
| # | Vị trí | Lỗi | Sửa |
|---|--------|-----|-----|
| 1 | `FFT_512_CH*` | FIFO kết quả FFT (1024 từ) mỗi frame ghi 512 từ nhưng chỉ đọc ~256 → dữ liệu cũ tồn đọng, vài frame sau FIFO đầy, peak search đọc dữ liệu frame cũ/mirror | Đọc hết 512 từ mỗi frame |
| 2 | `FFT_512_CH*` | `Latch_pulse`, `IndexBuff`, `DataBuff` gán ở nhánh `else` **ngoài** `rising_edge` → latch + glitch; `peaksearch_counter` bị gán 2 lần (tràn 255→256) | Toàn bộ FSM + peak search nằm trong 1 process đồng bộ, Latch_pulse là xung 1 chu kỳ |
| 3 | `FFT_512_CH*` | Cấp dữ liệu cho FFT trễ so với RFD (mất ~4 mẫu đầu, thiếu mẫu cuối); ghi ADC mất mẫu 511, lặp mẫu 510 | Prefetch mẫu 0, `rd_en = RFD` → đúng 512 mẫu, cùng chu kỳ RFD (Input Data Timing = no offset) |
| 4 | `FFT_512_CH*` | Ghi kết quả FFT không dựa vào `DV` → word 0 là bin 1 (lệch 1 bin, mất DC) | Ghi theo `DV`, word i = bin i |
| 5 | `FFT_512_CH*` | Index không bù độ trễ pipeline (FIFO + nhân + cộng + căn bậc hai): file `KHAO SAT DO TAN SO.xlsx` cho thấy index lệch đều **+6.0 bin** (≈2.7 MHz, trung bình 5.5–6.8) | Căn index theo pipeline bằng generic `MAG_LATENCY` |
| 6 | `FFT_512_CH*` | `pulse_detect` bất đồng bộ đưa thẳng vào FSM 230 MHz (metastability), khai báo `inout`, kích theo mức → chạy FFT lặp lại khi xung dài | Đồng bộ 2 FF + phát hiện sườn lên (generic `TRIGGER_ON_EDGE`) |
| 7 | `fifo_fsm_controller*` | Ghi FIFO có thể ghi 2 lần; đọc FIFO khi rỗng; `data2Com` có thể đổi giữa lúc Ethernet đang đọc byte cao/byte thấp của index (giá trị bị "xé") | Ghi 1 lần/xung; đọc liên tục lấy giá trị mới nhất; `data2Com` đóng băng khi `rd_en`=1 |
| 8 | `main_prog.vhd` | `adc_in*`, `pulse_detect`, `adc*_clk_out_*` khai báo `inout` dù chỉ là input (sinh IOBUF thừa) | Đổi thành `in` |
| 9 | `pins_config.ucf` | **Không có ràng buộc thời gian nào** ("No timing constraints found") → PAR không hề kiểm tra 230 MHz | Thêm `PERIOD 10 ns` cho `clk_in` (ISE tự suy ra 3 clock 230 MHz) + `TIG` cho `pulse_detect` |
| 10 | `Ethernet_module.vhd` | `desPort => srcPort` | `desPort => desPort` (giá trị trùng nên không đổi hành vi) |

## Tái cấu trúc để chạy 3 kênh đồng thời
* 3 file FFT copy-paste (`FFT_512_CH1/CH2`, `FFT512_CH3`; CH1 khác CH2/CH3 ở 1 dòng) → **1 entity `FFT_CH`** (`FFT_512_CH.vhd`) dùng 3 lần trong `top`.
* 3 file FIFO controller → **1 entity `fifo_fsm_controller`** (`fifo_fsm_controller.vhd`).
* `FTT_512_NEW.xise` và `top.prj` đã cập nhật danh sách file.
* Tài nguyên báo cáo cũ: 3 kênh dùng 114/240 DSP48, 26 % LUT → còn dư chỗ. Các kênh chỉ giao tiếp với nhau qua FIFO bất đồng bộ (230 → 50 MHz).

## Cần bạn kiểm tra trên phần cứng
1. `MAG_LATENCY` mặc định = 4 (suy ra từ bảng khảo sát; các core `binh_phuong_*`, `tong_binh_phuong`, `can_bac_hai` là netlist nên không biết độ trễ chính xác). Đo lại bảng tần số: sai số trung bình phải về ≈ 0 (±1 bin = 0.45 MHz). Nếu còn lệch thì chỉnh generic này.
2. Thiết kế chưa từng được kiểm tra thời gian ở 230 MHz (synthesis ước lượng 8.1 ns). Sau khi thêm constraint, xem `top.twr`; nếu không đạt, đường nghi ngờ nhất là `can_bac_hai`/`tong_binh_phuong` (thêm pipeline cho IP) và `rd_en = RFD` của FIFO ADC.
3. Kênh 2 trong bảng khảo sát luôn lớn hơn kênh 1/3 khoảng +1 index (hex). Đây không phải lỗi logic VHDL (3 kênh giờ cùng code) nên nhiều khả năng do pha/độ trễ ADC2 hoặc đường tín hiệu; cần kiểm tra phần cứng.
4. Khuyến nghị (chưa đổi để không phá hành vi đang chạy): xuất clock ADC bằng `ODDR`, thêm `IOB` cho thanh ghi chốt ADC, đổi `CLK_50_MHZ` (chia bằng FF) thành đầu ra thứ 4 của MMCM (VCO 1150 MHz ÷ 23 = 50 MHz), và thêm `OFFSET IN` theo datasheet ADC. Các IOSTANDARD ADC3 (LVTTL) khác ADC1/2 (LVCMOS25) — kiểm tra điện áp bank trên sơ đồ mạch.
