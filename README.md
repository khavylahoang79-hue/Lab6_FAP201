# Lab6_FAP201
# Lab6_FAP201 – Memory Game with 74HC595 Display

## Thông tin chung
- **Môn học:** FAP201 - FPGA Programming
- **Bài thực hành:** Lab06 - Memory Game (FSM, LFSR Pseudo-Random Generator, Key Debounce & 74HC595 7-Segment Controller) (CLO1 & CLO2)
- **Tác giả:** La Hoàng Khả Vy (CE210538)
- **Mục tiêu:** Thiết kế, kiểm chứng và hiện thực trò chơi ghi nhớ chuỗi chớp đèn (Memory Game) 7 vòng chơi trên bo mạch FPGA. Hệ thống tích hợp mạch lọc nhiễu nút nhấn, bộ sinh chuỗi ngẫu nhiên LFSR, FSM điều khiển luồng game và giao tiếp 3 dây nối tiếp với IC đệm 74HC595 để hiển thị điểm số/trạng thái trên LED 7 đoạn.

## Môi trường và Phần cứng
- **Công cụ phát triển:** Gowin EDA
- **Bo mạch (Board):** Xiaomeige ACG525
- **Chip FPGA (Target Device):** GW5A-LV25UG324C2/I1
- **Ngôn ngữ:** VHDL (IEEE 1164 STD_LOGIC, NUMERIC_STD)[cite: 22]

## Nguyên lý hoạt động & Phân tích Architecture
- **Kiến trúc các khối chức năng (Sub-modules Architecture):**
  1. **Lọc nhiễu & Đồng bộ nút nhấn (`key_conditioner`):** Đồng bộ hóa tín hiệu qua Flip-Flop và đếm chống dội (`G_STABLE_CYCLES = 1,000,000` chu kỳ ~ 20ms)[cite: 22]. Chỉ tạo duy nhất 1 xung tích cực (`press_pulse_o`) dài 1 chu kỳ clock đúng thời điểm người dùng **nhấn** nút, loại bỏ hoàn toàn nhiễu dội và sự kiện lặp khi giữ nút[cite: 22, 23].
  2. **Máy trạng thái FSM điều khiển Trò chơi (`lab06_game`):**
     * Quản lý 6 trạng thái: `IDLE`, `PATTERN_OFF`, `PATTERN_SHOW`, `WAIT_PLAYER`, `WIN`, `LOSE`[cite: 22].
     * **Bộ sinh ngẫu nhiên LFSR 8-bit (`lfsr_step`):** Sinh mẫu chớp đèn ngẫu nhiên 7 ký tự (mỗi ký tự dạng One-Hot 3-bit tương ứng với LED0, LED1 hoặc LED2)[cite: 22].
     * **Luồng chơi:** Người chơi phải ghi nhớ và bấm lại chính xác chuỗi LED hiển thị từ vòng 1 đến vòng 7[cite: 22]. Thắng cả 7 vòng $\rightarrow$ trạng thái `WIN`[cite: 22]. Bấm sai nút hoặc bấm đồng thời nhiều nút $\rightarrow$ trạng thái `LOSE`[cite: 22, 23].
  3. **Bộ điều khiển LED 7 đoạn qua 74HC595 (`sevenseg_74hc595`):**
     * Truyền dữ liệu nối tiếp 16-bit (8-bit mã segment + 8-bit chọn LED) qua 3 dây: Dữ liệu (`seg_ds_o`), Xung dịch (`seg_shcp_o`), Xung chốt (`seg_stcp_o`)[cite: 20, 22].
     * Hiển thị điểm số vòng chơi (1..7) khi đang chơi, hiển thị chữ **'A'** khi Thắng (`WIN`) và chữ **'F'** khi Thua (`LOSE`)[cite: 22].

---

## Bảng trạng thái Game & Mức hiển thị (FSM & Display Mapping)

| Trạng thái FSM (`state`) | Mã `status_o` | Mã LED 7 đoạn (74HC595) | Trạng thái vật lý & Mô tả |
| :---: | :---: | :---: | :--- |
| `IDLE` | `"00"` | Điểm số (`1..7`) | Khởi tạo game / Chờ tín hiệu Start[cite: 22] |
| `PATTERN_OFF` | `"00"` | Điểm số hiện tại | Tắt cả 3 LED ngõ ra (Khoảng nghỉ 0.3s giữa các chớp)[cite: 22] |
| `PATTERN_SHOW` | `"00"` | Điểm số hiện tại | Bật chớp LED ngõ ra theo mẫu chuỗi ngẫu nhiên (0.4s)[cite: 22] |
| `WAIT_PLAYER` | `"00"` | Điểm số hiện tại | Tắt các LED ngõ ra, chờ người chơi bấm chuỗi nút phản hồi[cite: 22, 23] |
| `WIN` | `"10"` | **Chữ 'A'** (`0x88`) | Thắng hoàn thành xuất sắc 7 vòng chơi[cite: 22, 23] |
| `LOSE` | `"01"` | **Chữ 'F'** (`0x8E`) | Thua cuộc do bấm sai mẫu hoặc bấm tổ hợp nhiều nút[cite: 22, 23] |

---

## Bảng ánh xạ chân vật lý & Timing Constraints

### Physical Constraints Mapping (`Lab6.cst`)
Tín hiệu được cấu hình trong file `Lab6.cst`[cite: 20]:

| Tín hiệu Port | Chân FPGA | Linh kiện phần cứng | Cấu hình I/O (3.3V Bank VCCIO) |
| :--- | :---: | :--- | :--- |
| `clk_50m_i` | `T9` | System Clock (50 MHz) | `IO_TYPE=LVCMOS33` |
| `key_raw_i[0]` | `B16` | Switch 0 / KEY0 (Input 0 / Replay Start) | `IO_TYPE=LVCMOS33`, `PULL_MODE=UP`[cite: 20, 22] |
| `key_raw_i[1]` | `A15` | Switch 1 / KEY1 (Input 1) | `IO_TYPE=LVCMOS33`, `PULL_MODE=UP`[cite: 20] |
| `key_raw_i[2]` | `C15` | Switch 2 / KEY2 (Input 2) | `IO_TYPE=LVCMOS33`, `PULL_MODE=UP`[cite: 20] |
| `led_pin_o[0]` | `D14` | Output LED 0 / LED0 | `IO_TYPE=LVCMOS33`[cite: 20] |
| `led_pin_o[1]` | `C14` | Output LED 1 / LED1 | `IO_TYPE=LVCMOS33`[cite: 20] |
| `led_pin_o[2]` | `B9` | Output LED 2 / LED2 | `IO_TYPE=LVCMOS33`[cite: 20] |
| `seg_ds_o` | `F4` | 74HC595 Data Serial (DS) | `IO_TYPE=LVCMOS33`[cite: 20, 22] |
| `seg_stcp_o` | `F3` | 74HC595 Latch Clock (STCP) | `IO_TYPE=LVCMOS33`[cite: 20, 22] |
| `seg_shcp_o` | `H4` | 74HC595 Shift Clock (SHCP) | `IO_TYPE=LVCMOS33`[cite: 20, 22] |

### Timing Constraints (`Lab6.sdc`)
Ràng buộc thời gian cho xung nhịp 50 MHz định nghĩa trong file `Lab6.sdc`:
```tcl
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk_50m_i}]
