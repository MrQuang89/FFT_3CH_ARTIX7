----------------------------------------------------------------------------------
-- pulse_measure : do tham so thoi gian cua xung truc tiep tu du lieu ADC 14 bit
--
-- Nguyen ly (xem docs/PHAN_TICH_DO_THOI_GIAN_XUNG.md):
--  1. Bo dem DC, lay tri tuyet doi |x - ADC_DC|.
--  2. Duong bao (envelope) = MAX trong cua so truot 8 mau (cay max 3 tang).
--     Tin hieu RF 460..575 MHz lay mau 230 MHz bi "aliasing" xuong 0..115 MHz,
--     nen |x| dao dong qua 0; cua so max 8 mau (34.8 ns) lap day cac cho ve 0.
--  3. So sanh duong bao voi nguong THRESH. Xung bat dau o mau dau tien >= THRESH,
--     ket thuc khi duong bao < THRESH lien tuc GAP mau.
--  4. Do rong (so mau) = (mau cuoi >= THRESH) - (mau dau >= THRESH) + 1 - 7.
--     Tru 7 vi cua so max 8 mau keo dai canh xuong dung 7 mau (khong phu thuoc bien do).
--  5. PRI = so chu ky clock giua thoi diem bat dau 2 xung hop le lien tiep.
--  6. Bien do = gia tri duong bao lon nhat trong xung.
--
-- Dau ra meas_data (64 bit), phat 1 chu ky meas_valid khi xong 1 xung:
--   [63:48] PW   : do rong xung, don vi = 1 chu ky clock = 1/230 MHz = 4.348 ns
--   [47]    LONG : 1 neu xung dai hon MAX_PW (bi cat)
--   [46]    '0'
--   [45:32] AMP  : bien do dinh (14 bit, ma ADC)
--   [31:8]  PRI  : khoang cach tu xung truoc (chu ky clock); 0xFFFFFF = khong hop le
--   [7:0]   SEQ  : dem xung hop le (mod 256) - de PC biet co phep do moi
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pulse_measure is
    generic (
        THRESH : natural := 600;    -- nguong duong bao (ma ADC, FS = 8192). CHINH THEO MUC TIN HIEU/NHIEU
        GAP    : natural := 12;     -- so mau duong bao < THRESH lien tiep de ket thuc xung (>= 1)
        MIN_PW : natural := 4;      -- xung ngan hon (so mau) bi coi la nhieu
        MAX_PW : natural := 60000;  -- xung dai hon bi cat (<= 65535)
        ADC_DC : integer := 0       -- ma DC cua ADC (0 neu ADC ra bu 2; 8192 neu offset binary da doi dau)
    );
    port (
        clk        : in  std_logic;
        adc        : in  std_logic_vector(13 downto 0);   -- so co dau (bu 2)
        meas_valid : out std_logic;
        meas_data  : out std_logic_vector(63 downto 0)
    );
end pulse_measure;

architecture rtl of pulse_measure is

    constant WIN : natural := 8;   -- do dai cua so max (co dinh, 3 tang)

    type u14_arr is array (natural range <>) of unsigned(13 downto 0);
    type st_t is (S_IDLE, S_PULSE, S_WAIT_LOW);

    signal a0, a0_d1 : unsigned(13 downto 0) := (others => '0');
    signal m2, m4, env : unsigned(13 downto 0) := (others => '0');
    signal m2_s : u14_arr(1 to 2) := (others => (others => '0'));
    signal m4_s : u14_arr(1 to 4) := (others => (others => '0'));

    signal st        : st_t := S_IDLE;
    signal el_cnt    : integer range 0 to 131071 := 0;
    signal last_el   : integer range 0 to 131071 := 0;
    signal gap_cnt   : integer range 0 to 255 := 0;
    signal peak      : unsigned(13 downto 0) := (others => '0');
    signal since_last: unsigned(23 downto 0) := (others => '1');
    signal pri_lat   : unsigned(23 downto 0) := (others => '1');
    signal seq       : unsigned(7 downto 0) := (others => '0');
    signal valid_r   : std_logic := '0';
    signal data_r    : std_logic_vector(63 downto 0) := (others => '0');

    function umax(a, b : unsigned) return unsigned is
    begin
        if a > b then return a; else return b; end if;
    end function;

begin

    meas_valid <= valid_r;
    meas_data  <= data_r;

    process (clk)
        variable xs   : signed(15 downto 0);
        variable ax   : unsigned(15 downto 0);
        variable e    : integer range 0 to 131072;
        variable pw_v : integer range 0 to 131071;
        variable seq_n: unsigned(7 downto 0);
    begin
        if rising_edge(clk) then
            ------------------------------------------------------------------
            -- 1) |x - DC| bao hoa 14 bit
            ------------------------------------------------------------------
            xs := resize(signed(adc), 16) - to_signed(ADC_DC, 16);
            if xs < 0 then
                ax := unsigned(-xs);
            else
                ax := unsigned(xs);
            end if;
            if ax > 16383 then
                a0 <= to_unsigned(16383, 14);
            else
                a0 <= ax(13 downto 0);
            end if;

            ------------------------------------------------------------------
            -- 2) cay max 3 tang: cua so 2 -> 4 -> 8 mau
            ------------------------------------------------------------------
            a0_d1 <= a0;
            m2    <= umax(a0, a0_d1);
            m2_s(1) <= m2;
            m2_s(2) <= m2_s(1);
            m4    <= umax(m2, m2_s(2));
            m4_s(1) <= m4;
            for i in 2 to 4 loop
                m4_s(i) <= m4_s(i-1);
            end loop;
            env   <= umax(m4, m4_s(4));

            ------------------------------------------------------------------
            -- 3) may trang thai do xung
            ------------------------------------------------------------------
            valid_r <= '0';
            if since_last /= x"FFFFFF" then
                since_last <= since_last + 1;
            end if;

            case st is
                when S_IDLE =>
                    if env >= THRESH then
                        st      <= S_PULSE;
                        el_cnt  <= 1;
                        last_el <= 1;
                        gap_cnt <= 0;
                        peak    <= env;
                        pri_lat <= since_last;
                    end if;

                when S_PULSE =>
                    e := el_cnt + 1;
                    el_cnt <= e;
                    if env > peak then
                        peak <= env;
                    end if;
                    if env >= THRESH then
                        last_el <= e;
                        gap_cnt <= 0;
                        if e >= MAX_PW then
                            -- xung qua dai: bao ket qua bi cat, cho het xung
                            seq_n := seq + 1;
                            seq   <= seq_n;
                            data_r  <= std_logic_vector(to_unsigned(MAX_PW, 16)) & '1' & '0' &
                                       std_logic_vector(peak) & std_logic_vector(pri_lat) &
                                       std_logic_vector(seq_n);
                            valid_r <= '1';
                            since_last <= to_unsigned(e, 24);
                            st      <= S_WAIT_LOW;
                        end if;
                    else
                        if gap_cnt >= GAP - 1 then
                            if last_el > WIN - 1 then
                                pw_v := last_el - (WIN - 1);
                            else
                                pw_v := 0;
                            end if;
                            if pw_v >= MIN_PW then
                                seq_n := seq + 1;
                                seq   <= seq_n;
                                data_r  <= std_logic_vector(to_unsigned(pw_v, 16)) & '0' & '0' &
                                           std_logic_vector(peak) & std_logic_vector(pri_lat) &
                                           std_logic_vector(seq_n);
                                valid_r <= '1';
                                since_last <= to_unsigned(e, 24);
                            end if;
                            st <= S_IDLE;
                        else
                            gap_cnt <= gap_cnt + 1;
                        end if;
                    end if;

                when S_WAIT_LOW =>
                    if env < THRESH then
                        if gap_cnt >= GAP - 1 then
                            st <= S_IDLE;
                        else
                            gap_cnt <= gap_cnt + 1;
                        end if;
                    else
                        gap_cnt <= 0;
                    end if;

                when others =>
                    st <= S_IDLE;
            end case;
        end if;
    end process;

end rtl;
