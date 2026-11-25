----------------------------------------------------------------------------------
-- meas_cdc : chuyen bus rong (mac dinh 64 bit) tu clock 230 MHz sang 50 MHz
--            bang bat tay toggle (req/ack), dam bao khong "xe" gia tri.
--
--  src: khi src_valid=1, du lieu duoc giu o hold_reg va doi req_t. Trong luc cho
--       ack, du lieu moi nhat duoc cat o pend_reg (xung ngan hon PRI nen hiem khi xay ra).
--  dst: dong bo req_t bang 2 FF; thay doi -> chep hold_reg vao latest, doi ack_t.
--       dst_data chi cap nhat khi dst_hold = '0' (dong bang trong luc Ethernet doc byte).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity meas_cdc is
    generic ( W : natural := 64 );
    port (
        src_clk   : in  std_logic;
        src_valid : in  std_logic;
        src_data  : in  std_logic_vector(W-1 downto 0);
        dst_clk   : in  std_logic;
        dst_hold  : in  std_logic;
        dst_data  : out std_logic_vector(W-1 downto 0)
    );
end meas_cdc;

architecture rtl of meas_cdc is
    signal hold_reg  : std_logic_vector(W-1 downto 0) := (others => '0');
    signal pend_reg  : std_logic_vector(W-1 downto 0) := (others => '0');
    signal pend_flag : std_logic := '0';
    signal req_t     : std_logic := '0';
    signal ack_t     : std_logic := '0';
    signal ack_sync  : std_logic_vector(1 downto 0) := (others => '0');
    signal req_sync  : std_logic_vector(1 downto 0) := (others => '0');
    signal busy      : std_logic;
    signal latest    : std_logic_vector(W-1 downto 0) := (others => '0');
    signal out_r     : std_logic_vector(W-1 downto 0) := (others => '0');

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of ack_sync : signal is "TRUE";
    attribute ASYNC_REG of req_sync : signal is "TRUE";
begin

    busy <= req_t xor ack_sync(1);

    process (src_clk)
    begin
        if rising_edge(src_clk) then
            ack_sync <= ack_sync(0) & ack_t;
            if busy = '0' then
                if pend_flag = '1' then
                    hold_reg  <= pend_reg;
                    pend_flag <= '0';
                    req_t     <= not req_t;
                elsif src_valid = '1' then
                    hold_reg <= src_data;
                    req_t    <= not req_t;
                end if;
            else
                if src_valid = '1' then
                    pend_reg  <= src_data;
                    pend_flag <= '1';
                end if;
            end if;
        end if;
    end process;

    process (dst_clk)
    begin
        if rising_edge(dst_clk) then
            req_sync <= req_sync(0) & req_t;
            if req_sync(1) /= ack_t then
                latest <= hold_reg;
                ack_t  <= req_sync(1);
            end if;
            if dst_hold = '0' then
                out_r <= latest;
            end if;
        end if;
    end process;

    dst_data <= out_r;

end rtl;
