-- Testbench tu kiem tra pulse_measure (CHUA duoc chay trong moi truong soan thao;
-- chay bang ISim: them file nay + pulse_measure.vhd vao Simulation, top = tb_pulse_measure).
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_pulse_measure is
end tb_pulse_measure;

architecture sim of tb_pulse_measure is
    signal clk : std_logic := '0';
    signal adc : std_logic_vector(13 downto 0) := (others => '0');
    signal mv  : std_logic;
    signal md  : std_logic_vector(63 downto 0);
    signal n   : integer := 0;
    signal pulses_seen : integer := 0;
    constant W1 : integer := 100;   -- do rong xung 1 (mau)
    constant W2 : integer := 46;    -- do rong xung 2 (mau)
    constant START1 : integer := 200;
    constant START2 : integer := 2200;
begin
    clk <= not clk after 2.174 ns;   -- 230 MHz

    dut : entity work.pulse_measure
        generic map (THRESH => 600, GAP => 12, MIN_PW => 4, MAX_PW => 60000, ADC_DC => 0, TRIG_CONFIRM => 16)
        port map (clk => clk, adc => adc, trig => open, meas_valid => mv, meas_data => md);

    -- tin hieu: RF alias 0.2 chu ky/mau, bien do 2000, xung chu nhat
    stim : process (clk)
        variable v : real;
        variable inpulse : boolean;
    begin
        if rising_edge(clk) then
            n <= n + 1;
            inpulse := (n >= START1 and n < START1 + W1) or (n >= START2 and n < START2 + W2);
            if inpulse then
                v := 2000.0 * sin(2.0 * MATH_PI * 0.2 * real(n) + 0.7);
            else
                v := 0.0;
            end if;
            adc <= std_logic_vector(to_signed(integer(v), 14));
        end if;
    end process;

    check : process (clk)
        variable pw  : integer;
        variable pri : integer;
    begin
        if rising_edge(clk) then
            if mv = '1' then
                pulses_seen <= pulses_seen + 1;
                pw  := to_integer(unsigned(md(63 downto 48)));
                pri := to_integer(unsigned(md(31 downto 8)));
                if pulses_seen = 0 then
                    assert abs(pw - W1) <= 2 report "PW1 sai: " & integer'image(pw) severity error;
                    assert pri = 16#FFFFFF# report "PRI xung dau phai khong hop le" severity error;
                else
                    assert abs(pw - W2) <= 2 report "PW2 sai: " & integer'image(pw) severity error;
                    assert abs(pri - (START2 - START1)) <= 2 report "PRI sai: " & integer'image(pri) severity error;
                end if;
                report "PW=" & integer'image(pw) & " mau, PRI=" & integer'image(pri) & " chu ky";
            end if;
            if n = 3000 then
                assert pulses_seen = 2 report "so xung do duoc != 2" severity error;
                report "TESTBENCH XONG" severity failure;
            end if;
        end if;
    end process;
end sim;
