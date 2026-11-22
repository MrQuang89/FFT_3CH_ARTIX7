----------------------------------------------------------------------------------
-- fifo_fsm_controller : luu index dinh cua 1 kenh vao FIFO bat dong bo
--   (wr_clk = clock 230 MHz cua kenh, rd_clk = 50 MHz cua Ethernet) va
--   cung cap gia tri MOI NHAT cho Ethernet.
--
-- Module nay dung chung cho ca 3 kenh (thay cho 3 ban copy cu).
--
-- Thay doi so voi ban cu:
--  * Phia ghi: wr_en (Latch_pulse, 1 chu ky) duoc ghi truc tiep 1 lan,
--    co kiem tra full (ban cu co the ghi 2 lan / bo qua tuy do tre cua pulse).
--  * Phia doc: lien tuc rut FIFO va giu gia tri moi nhat. data2Com CHI duoc
--    cap nhat khi rd_en (cua so gui Ethernet) = '0', nen 2 byte high/low cua
--    cung 1 index khong bi "xe doi" giua 2 gia tri khac nhau trong luc gui.
--  * Khong doc FIFO khi empty (ban cu doc mu, dout cu bi lap lai).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fifo_fsm_controller is
    Port (
        -- Write interface (clock 230 MHz cua kenh)
        wr_clk      : in  std_logic;
        wr_en       : in  std_logic;                       -- Latch_pulse (1 chu ky)
        IndexMax_In : in  std_logic_vector(9 downto 0);
        -- Read interface (clock 50 MHz)
        rd_clk      : in  std_logic;
        rd_en       : in  std_logic;                       -- '1' trong luc Ethernet dang nap goi
        data2Com    : out std_logic_vector(9 downto 0)
    );
end fifo_fsm_controller;

architecture Behavioral of fifo_fsm_controller is

    component peak_value_fifo is
        Port (
            rst       : in  std_logic;
            wr_clk    : in  std_logic;
            rd_clk    : in  std_logic;
            din       : in  std_logic_vector(9 downto 0);
            wr_en     : in  std_logic;
            rd_en     : in  std_logic;
            dout      : out std_logic_vector(9 downto 0);
            full      : out std_logic;
            empty     : out std_logic;
            prog_full : out std_logic
        );
    end component;

    type rd_state_type is (R_IDLE, R_READ, R_CAPTURE);
    signal rd_state : rd_state_type := R_IDLE;

    signal fifo_wr_en    : std_logic := '0';
    signal fifo_rd_en    : std_logic := '0';
    signal fifo_din      : std_logic_vector(9 downto 0) := (others => '0');
    signal fifo_dout     : std_logic_vector(9 downto 0);
    signal fifo_full     : std_logic;
    signal fifo_empty    : std_logic;
    signal fifo_prog_full: std_logic;

    signal latest        : std_logic_vector(9 downto 0) := (others => '0');
    signal data2Com_r    : std_logic_vector(9 downto 0) := (others => '0');

begin

    U_FIFO : peak_value_fifo
        port map (
            rst       => '0',
            wr_clk    => wr_clk,
            rd_clk    => rd_clk,
            din       => fifo_din,
            wr_en     => fifo_wr_en,
            rd_en     => fifo_rd_en,
            dout      => fifo_dout,
            full      => fifo_full,
            empty     => fifo_empty,
            prog_full => fifo_prog_full
        );

    ------------------------------------------------------------------
    -- Ghi: 1 index moi cho moi Latch_pulse
    ------------------------------------------------------------------
    process (wr_clk)
    begin
        if rising_edge(wr_clk) then
            fifo_wr_en <= wr_en and (not fifo_full);
            fifo_din   <= IndexMax_In;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Doc: rut tung phan tu (FIFO chuan: dout hop le 1 chu ky sau khi doc)
    ------------------------------------------------------------------
    process (rd_clk)
    begin
        if rising_edge(rd_clk) then
            fifo_rd_en <= '0';
            case rd_state is
                when R_IDLE =>
                    if fifo_empty = '0' then
                        fifo_rd_en <= '1';
                        rd_state   <= R_READ;
                    end if;
                when R_READ =>              -- FIFO nhan rd_en o canh nay
                    rd_state <= R_CAPTURE;
                when R_CAPTURE =>           -- dout da cap nhat
                    latest   <= fifo_dout;
                    rd_state <= R_IDLE;
                when others =>
                    rd_state <= R_IDLE;
            end case;

            -- Dong bang ngo ra trong luc Ethernet dang doc cac byte index
            if rd_en = '0' then
                data2Com_r <= latest;
            end if;
        end if;
    end process;

    data2Com <= data2Com_r;

end Behavioral;
