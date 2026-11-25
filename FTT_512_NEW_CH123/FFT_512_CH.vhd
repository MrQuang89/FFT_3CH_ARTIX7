----------------------------------------------------------------------------------
-- FFT_CH : mot kenh xu ly FFT 512 diem + tim dinh pho (peak search)
--
-- Module nay thay the 3 file copy-paste cu (FFT_512_CH1/CH2/CH3.vhd).
-- Ca 3 kenh dung chung 1 entity, chi khac nhau o clock/ADC noi vao.
--
-- Luong xu ly (1 clock duy nhat = clk_in_230):
--   IDLE -> CAPTURE (ghi 512 mau ADC vao FIFO) -> PREFETCH -> START
--        -> LOAD (cap 512 mau cho FFT, doc FIFO theo RFD)
--        -> UNLOAD (ghi 512 ket qua FFT, chi khi DV=1, vao 2 FIFO Re/Im)
--        -> SETTLE -> SEARCH (doc het 512 mau, tinh |X|, tim dinh trong NBINS bin dau)
--        -> FINISH (phat Latch_pulse 1 chu ky + Index_Max_Out) -> IDLE
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FFT_CH is
    generic (
        -- So chu ky tu luc dout cua FIFO_OUT_RE/IM hop le den luc ngo ra
        -- can_bac_hai (squareRI) hop le (binh_phuong + tong + can bac hai).
        -- Gia tri 4 suy ra tu file "KHAO SAT DO TAN SO.xlsx" (do lech
        -- trung binh +6.0 bin cua ban cu). Hieu chinh lai neu can:
        -- tang MAG_LATENCY neu index do duoc van lon hon dung, giam neu nho hon.
        MAG_LATENCY     : natural := 4;
        -- true : chi chay 1 lan FFT tren moi suon len cua pulse_detect
        -- false: chay lien tuc khi pulse_detect = '1' (hanh vi cu)
        TRIGGER_ON_EDGE : boolean := true;
        -- So bin (tinh tu bin 0) duoc dung de tim dinh (512 diem -> 256 bin duong)
        NBINS           : natural := 256;
        -- Tham so do thoi gian xung (xem pulse_measure.vhd)
        PM_THRESH       : natural := 600;
        PM_GAP          : natural := 12;
        PM_MIN_PW       : natural := 4;
        ADC_DC          : integer := 0
    );
    Port (  clk_in_230          : in  STD_LOGIC;
            adc_in1_ch1         : in  STD_LOGIC_VECTOR (13 downto 0);
            pulse_detect        : in  std_logic;   -- bat dong bo, duoc dong bo 2 FF ben trong
            rfd_test_ch1        : out std_logic;
            dv_test_ch1         : out std_logic;
            Latch_pulse_ch1     : out std_logic;
            Index_Max_Out_Ch1   : out STD_LOGIC_VECTOR (9 downto 0);
            -- Ket qua do thoi gian xung (1 xung meas_valid moi xung RF do duoc)
            Meas_Valid_Ch1      : out std_logic;
            Meas_Data_Ch1       : out std_logic_vector(63 downto 0)
    );
end FFT_CH;

architecture Behavioral of FFT_CH is

    ---------------------------- IP cores ------------------------------------
    COMPONENT FFT_512
      PORT (
        clk        : IN  STD_LOGIC;
        ce         : IN  STD_LOGIC;
        start      : IN  STD_LOGIC;
        fwd_inv    : IN  STD_LOGIC;
        fwd_inv_we : IN  STD_LOGIC;
        rfd        : OUT STD_LOGIC;
        busy       : OUT STD_LOGIC;
        edone      : OUT STD_LOGIC;
        done       : OUT STD_LOGIC;
        dv         : OUT STD_LOGIC;
        xn_re      : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        xn_im      : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        xn_index   : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
        xk_index   : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
        xk_re      : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        xk_im      : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        blk_exp    : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
      );
    END COMPONENT;

    COMPONENT fifo_14bits
      PORT (
        rst       : IN  STD_LOGIC;
        wr_clk    : IN  STD_LOGIC;
        rd_clk    : IN  STD_LOGIC;
        din       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        wr_en     : IN  STD_LOGIC;
        rd_en     : IN  STD_LOGIC;
        dout      : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        full      : OUT STD_LOGIC;
        prog_full : OUT STD_LOGIC;
        empty     : OUT STD_LOGIC
      );
    END COMPONENT;

    COMPONENT FIFO_OUT_RE
      PORT (
        rst       : IN  STD_LOGIC;
        wr_clk    : IN  STD_LOGIC;
        rd_clk    : IN  STD_LOGIC;
        din       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        wr_en     : IN  STD_LOGIC;
        rd_en     : IN  STD_LOGIC;
        dout      : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        full      : OUT STD_LOGIC;
        empty     : OUT STD_LOGIC;
        prog_full : OUT STD_LOGIC
      );
    END COMPONENT;

    COMPONENT FFT_OUT_IM
      PORT (
        rst       : IN  STD_LOGIC;
        wr_clk    : IN  STD_LOGIC;
        rd_clk    : IN  STD_LOGIC;
        din       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        wr_en     : IN  STD_LOGIC;
        rd_en     : IN  STD_LOGIC;
        dout      : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        full      : OUT STD_LOGIC;
        empty     : OUT STD_LOGIC;
        prog_full : OUT STD_LOGIC
      );
    END COMPONENT;

    COMPONENT binh_phuong_I
      PORT (
        clk : IN  STD_LOGIC;
        a   : IN  STD_LOGIC_VECTOR(12 DOWNTO 0);
        b   : IN  STD_LOGIC_VECTOR(12 DOWNTO 0);
        p   : OUT STD_LOGIC_VECTOR(25 DOWNTO 0)
      );
    END COMPONENT;

    COMPONENT binh_phuong_R
      PORT (
        clk : IN  STD_LOGIC;
        a   : IN  STD_LOGIC_VECTOR(12 DOWNTO 0);
        b   : IN  STD_LOGIC_VECTOR(12 DOWNTO 0);
        p   : OUT STD_LOGIC_VECTOR(25 DOWNTO 0)
      );
    END COMPONENT;

    COMPONENT tong_binh_phuong
      PORT (
        a   : IN  STD_LOGIC_VECTOR(25 DOWNTO 0);
        b   : IN  STD_LOGIC_VECTOR(25 DOWNTO 0);
        clk : IN  STD_LOGIC;
        s   : OUT STD_LOGIC_VECTOR(26 DOWNTO 0)
      );
    END COMPONENT;

    COMPONENT can_bac_hai
      PORT (
        x_in  : IN  STD_LOGIC_VECTOR(26 DOWNTO 0);
        x_out : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        clk   : IN  STD_LOGIC
      );
    END COMPONENT;

    COMPONENT pulse_measure
      GENERIC (
        THRESH : natural;
        GAP    : natural;
        MIN_PW : natural;
        MAX_PW : natural;
        ADC_DC : integer
      );
      PORT (
        clk        : IN  STD_LOGIC;
        adc        : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        meas_valid : OUT STD_LOGIC;
        meas_data  : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
      );
    END COMPONENT;

    ---------------------------- FSM -----------------------------------------
    type state_t is (S_IDLE, S_CAPTURE, S_PREFETCH, S_START, S_LOAD,
                     S_UNLOAD, S_SETTLE, S_SEARCH, S_FINISH);
    signal state : state_t := S_IDLE;

    signal clk : std_logic;

    -- dong bo hoa pulse_detect (bat dong bo) vao clk
    signal pulse_sync : std_logic_vector(2 downto 0) := (others => '0');
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of pulse_sync : signal is "TRUE";
    signal trigger : std_logic;

    signal cnt : unsigned(9 downto 0) := (others => '0');

    -- FFT
    signal start_fft  : std_logic := '0';
    signal fft_rfd    : std_logic;
    signal fft_dv     : std_logic;
    signal fft_busy, fft_edone, fft_done : std_logic;
    signal xn_re, xn_im : std_logic_vector(13 downto 0);
    signal xn_index, xk_index : std_logic_vector(8 downto 0);
    signal xk_re, xk_im : std_logic_vector(13 downto 0);
    signal blk_exp : std_logic_vector(4 downto 0);
    signal in_load : std_logic := '0';

    -- FIFO chua mau ADC (ghi 512, doc cap cho FFT)
    signal in_din, in_dout : std_logic_vector(13 downto 0) := (others => '0');
    signal in_wr_en  : std_logic := '0';
    signal in_rd_pre : std_logic := '0';
    signal in_rd_en  : std_logic;
    signal in_full, in_empty, in_prog_full : std_logic;

    -- FIFO chua ket qua FFT
    signal save_r_din, save_i_din   : std_logic_vector(13 downto 0) := (others => '0');
    signal save_r_dout, save_i_dout : std_logic_vector(13 downto 0);
    signal save_wr_en : std_logic := '0';
    signal save_rd_en : std_logic := '0';
    signal save_r_full, save_r_empty, save_r_pfull : std_logic;
    signal save_i_full, save_i_empty, save_i_pfull : std_logic;

    -- Tinh bien do |X| = sqrt(Re^2 + Im^2)
    signal re_mag, im_mag   : std_logic_vector(12 downto 0);
    signal re_sq, im_sq     : std_logic_vector(25 downto 0);
    signal sum_sq           : std_logic_vector(26 downto 0);
    signal squareRI         : std_logic_vector(13 downto 0);

    -- Peak search
    signal rd_sr      : std_logic_vector(MAG_LATENCY downto 0) := (others => '0');
    signal mag_valid  : std_logic;
    signal mag_idx    : unsigned(9 downto 0) := (others => '0');
    signal best_val   : unsigned(13 downto 0) := (others => '0');
    signal best_idx   : unsigned(9 downto 0)  := (others => '0');
    signal latch_pulse_r : std_logic := '0';
    signal index_out  : std_logic_vector(9 downto 0) := (others => '0');

begin

    clk <= clk_in_230;

    ------------------------- hang so cho FFT --------------------------------
    xn_re <= in_dout;                     -- khong offset: du lieu cung chu ky voi RFD
    xn_im <= (others => '0');

    rfd_test_ch1      <= fft_rfd;
    dv_test_ch1       <= fft_dv;
    Latch_pulse_ch1   <= latch_pulse_r;
    Index_Max_Out_Ch1 <= index_out;

    ------------------------- Do thoi gian xung tu ADC ------------------------
    U_PM : pulse_measure
      GENERIC MAP (
        THRESH => PM_THRESH,
        GAP    => PM_GAP,
        MIN_PW => PM_MIN_PW,
        MAX_PW => 60000,
        ADC_DC => ADC_DC
      )
      PORT MAP (
        clk        => clk,
        adc        => adc_in1_ch1,
        meas_valid => Meas_Valid_Ch1,
        meas_data  => Meas_Data_Ch1
      );

    ------------------------- trigger ----------------------------------------
    trigger <= (pulse_sync(1) and not pulse_sync(2)) when TRIGGER_ON_EDGE
               else pulse_sync(1);

    ------------------------- FFT core ---------------------------------------
    U_FFT : FFT_512
      PORT MAP (
        clk        => clk,
        ce         => '1',
        start      => start_fft,
        fwd_inv    => '1',
        fwd_inv_we => '1',
        xn_re      => xn_re,
        xn_im      => xn_im,
        rfd        => fft_rfd,
        xn_index   => xn_index,
        busy       => fft_busy,
        edone      => fft_edone,
        done       => fft_done,
        dv         => fft_dv,
        xk_index   => xk_index,
        xk_re      => xk_re,
        xk_im      => xk_im,
        blk_exp    => blk_exp
      );

    ------------------------- FIFO mau ADC -----------------------------------
    -- Doc FIFO trong khi RFD = '1' (FFT nhan 1 mau/chu ky). Mau dau tien da
    -- duoc "prefetch" vao dout truoc khi phat START nen FFT nhan dung mau 0
    -- ngay chu ky RFD dau tien (khong con mat/lech mau nhu ban cu).
    in_rd_en <= in_rd_pre or (fft_rfd and in_load);

    U_IN_FIFO : fifo_14bits
      PORT MAP (
        rst       => '0',
        wr_clk    => clk,
        rd_clk    => clk,
        din       => in_din,
        wr_en     => in_wr_en,
        rd_en     => in_rd_en,
        dout      => in_dout,
        full      => in_full,
        prog_full => in_prog_full,
        empty     => in_empty
      );

    ------------------------- FIFO ket qua FFT -------------------------------
    U_OUT_RE : FIFO_OUT_RE
      PORT MAP (
        rst       => '0',
        wr_clk    => clk,
        rd_clk    => clk,
        din       => save_r_din,
        wr_en     => save_wr_en,
        rd_en     => save_rd_en,
        dout      => save_r_dout,
        full      => save_r_full,
        empty     => save_r_empty,
        prog_full => save_r_pfull
      );

    U_OUT_IM : FFT_OUT_IM
      PORT MAP (
        rst       => '0',
        wr_clk    => clk,
        rd_clk    => clk,
        din       => save_i_din,
        wr_en     => save_wr_en,
        rd_en     => save_rd_en,
        dout      => save_i_dout,
        full      => save_i_full,
        empty     => save_i_empty,
        prog_full => save_i_pfull
      );

    ------------------------- Bien do ----------------------------------------
    -- So bu 2 14 bit -> do lon 13 bit (bu 1: giu nguyen cach tinh cu)
    re_mag <= not save_r_dout(12 downto 0) when save_r_dout(13) = '1'
              else save_r_dout(12 downto 0);
    im_mag <= not save_i_dout(12 downto 0) when save_i_dout(13) = '1'
              else save_i_dout(12 downto 0);

    U_SQ_I : binh_phuong_I
      PORT MAP (clk => clk, a => im_mag, b => im_mag, p => im_sq);

    U_SQ_R : binh_phuong_R
      PORT MAP (clk => clk, a => re_mag, b => re_mag, p => re_sq);

    U_SUM : tong_binh_phuong
      PORT MAP (a => im_sq, b => re_sq, clk => clk, s => sum_sq);

    U_SQRT : can_bac_hai
      PORT MAP (x_in => sum_sq, x_out => squareRI, clk => clk);

    mag_valid <= rd_sr(MAG_LATENCY);

    ------------------------- FSM + peak search (1 process, 1 clock) ---------
    main_proc : process(clk)
    begin
        if rising_edge(clk) then
            -- dong bo pulse_detect
            pulse_sync <= pulse_sync(1 downto 0) & pulse_detect;

            -- gia tri mac dinh (xung 1 chu ky)
            start_fft     <= '0';
            in_wr_en      <= '0';
            in_rd_pre     <= '0';
            save_wr_en    <= '0';
            save_rd_en    <= '0';
            latch_pulse_r <= '0';

            -- du lieu luon chay qua thanh ghi
            in_din     <= adc_in1_ch1;
            save_r_din <= xk_re;
            save_i_din <= xk_im;

            case state is
                ------------------------------------------------------------
                when S_IDLE =>
                    cnt <= (others => '0');
                    if trigger = '1' then
                        state <= S_CAPTURE;
                    end if;

                ------------------------------------------------------------
                -- Ghi dung 512 mau ADC lien tiep vao FIFO
                when S_CAPTURE =>
                    in_wr_en <= '1';
                    if cnt = 511 then
                        cnt   <= (others => '0');
                        state <= S_PREFETCH;
                    else
                        cnt <= cnt + 1;
                    end if;

                ------------------------------------------------------------
                -- Doc truoc mau 0 de dout san sang truoc khi FFT can
                when S_PREFETCH =>
                    if in_empty = '0' then
                        in_rd_pre <= '1';
                        state     <= S_START;
                    end if;

                ------------------------------------------------------------
                when S_START =>
                    start_fft <= '1';
                    in_load   <= '1';
                    cnt       <= (others => '0');
                    state     <= S_LOAD;

                ------------------------------------------------------------
                -- Dem 512 chu ky RFD = '1' (FIFO duoc doc cung chu ky o tren)
                when S_LOAD =>
                    if fft_rfd = '1' then
                        if cnt = 511 then
                            cnt     <= (others => '0');
                            in_load <= '0';
                            state   <= S_UNLOAD;
                        else
                            cnt <= cnt + 1;
                        end if;
                    end if;

                ------------------------------------------------------------
                -- Ghi 512 ket qua FFT vao FIFO, chi nhung chu ky co DV = '1'
                -- => FIFO word i = bin i (khong con bi lech 1 bin nhu ban cu)
                when S_UNLOAD =>
                    save_wr_en <= fft_dv;
                    if fft_dv = '1' then
                        if cnt = 511 then
                            cnt   <= (others => '0');
                            state <= S_SETTLE;
                        else
                            cnt <= cnt + 1;
                        end if;
                    end if;

                ------------------------------------------------------------
                -- Cho co empty cua 2 FIFO Re/Im ha xuong (dong bo con tro)
                when S_SETTLE =>
                    if save_r_empty = '0' and save_i_empty = '0' then
                        state <= S_SEARCH;
                    end if;

                ------------------------------------------------------------
                -- Doc HET 512 mau (truoc day chi doc ~256 -> FIFO bi day dan
                -- va tim dinh tren du lieu cu cua frame truoc)
                when S_SEARCH =>
                    save_rd_en <= '1';
                    if cnt = 511 then
                        cnt   <= (others => '0');
                        state <= S_FINISH;
                    else
                        cnt <= cnt + 1;
                    end if;

                ------------------------------------------------------------
                when S_FINISH =>
                    if latch_pulse_r = '1' then
                        state <= S_IDLE;
                    end if;

                when others =>
                    state <= S_IDLE;
            end case;

            ------------------------------------------------------------------
            -- Duong ong tim dinh: rd_sr(k) = save_rd_en tre (k+1) chu ky
            -- (dout hop le tu rd_sr(0)), mag_valid = tre them MAG_LATENCY.
            ------------------------------------------------------------------
            rd_sr(0) <= save_rd_en;
            for i in 1 to MAG_LATENCY loop
                rd_sr(i) <= rd_sr(i-1);
            end loop;

            if mag_valid = '1' then
                if mag_idx < NBINS and unsigned(squareRI) > best_val then
                    best_val <= unsigned(squareRI);
                    best_idx <= mag_idx;
                end if;

                if mag_idx = 511 then
                    -- da xu ly du 512 mau: chot ket qua
                    index_out     <= std_logic_vector(best_idx);
                    latch_pulse_r <= '1';
                    mag_idx       <= (others => '0');
                    best_val      <= (others => '0');
                    best_idx      <= (others => '0');
                else
                    mag_idx <= mag_idx + 1;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
