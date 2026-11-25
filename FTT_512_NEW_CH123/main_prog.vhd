
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-------------------------------------
entity top is
    Port (  clk_in 		            : in  STD_LOGIC;
			adc_in1 		        : in     STD_LOGIC_VECTOR (13 downto 0);
			adc_in2 		        : in     STD_LOGIC_VECTOR (13 downto 0);
			adc_in3 		        : in     STD_LOGIC_VECTOR (13 downto 0);
			-----------------------------------------------------------
			pulse_detect            : in  std_logic;
			-----------------------------------------------------------
			adc3_clkp		        : out std_logic; -- FPGA to ADC
			adc3_clkn		        : out std_logic;
			adc3_clk_out_n          : in  std_logic;
			adc3_clk_out_p          : in  std_logic;
			------------------------------------------------------------------
			adc2_clkp		        : out std_logic; -- FPGA to ADC
			adc2_clkn		        : out std_logic;
			adc2_clk_out_n          : in  std_logic;
			adc2_clk_out_p          : in  std_logic;
			------------------------------------------------------------
			adc1_clkp		        : out std_logic; -- FPGA to ADC
			adc1_clkn		        : out std_logic;
			adc1_clk_out_n          : in  std_logic;
			adc1_clk_out_p          : in  std_logic;
			----------------------------------------
			rfd_test                : out  STD_LOGIC;
			dv_test                 : out std_logic;
			-------------------------------------------
			rfd_ch1                : out  STD_LOGIC;
			dv_ch1                 : out std_logic;
			-----------------------------------------
			rfd_ch3                : out  STD_LOGIC;
			dv_ch3                 : out std_logic;
			latch_pulse_test			  : out std_logic;
			--radar_pulse_test  : out std_logic;
			pulse_detect_orig       : out std_logic;
			fifo_rd_en_ethernet_test: out std_logic;
--			-----------------receiver ethernet--------------------------
--			E_EX_CLK 	: out std_logic;
--            CRS_DV 		: in std_logic;
--            RXD 		: in std_logic_vector(1 downto 0);
--            TX_EN 		: out STD_LOGIC;
--            TXD 		: out STD_LOGIC_VECTOR(1 downto 0)
				---------------------------------------
				E_EX_CLK_02 	: out std_logic;
            CRS_DV_02 		: in std_logic;
            RXD_02 		: in std_logic_vector(1 downto 0);
            TX_EN_02 		: out STD_LOGIC;
            TXD_02 		: out STD_LOGIC_VECTOR(1 downto 0)
);		   

end top;
architecture Behavioral of top is
  
--------------------------------CLOCK ZOOMER----------------------------
component clk_zoomer
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT1          : out    std_logic;
  CLK_OUT2          : out    std_logic;
  CLK_OUT3          : out    std_logic
 );
end component;
-------------------------------------------------------------------
component FFT_CH
Generic (
	MAG_LATENCY     : natural := 4;
	TRIGGER_ON_EDGE : boolean := true;
	NBINS           : natural := 256;
	PM_THRESH       : natural := 600;
	PM_GAP          : natural := 12;
	PM_MIN_PW       : natural := 4;
	ADC_DC          : integer := 0;
	TRIG_SOURCE     : natural := 1;
	TRIG_CONFIRM    : natural := 16;
	TRIG_PRE        : natural := 8
);
Port (
	clk_in_230 		        : in  STD_LOGIC;
	adc_in1_ch1		        : in  STD_LOGIC_VECTOR (13 downto 0);
	pulse_detect            : in  std_logic;
	rfd_test_ch1            : out std_logic;
	dv_test_ch1             : out std_logic;
	Latch_pulse_ch1         : out std_logic;
	Index_Max_Out_Ch1       : out STD_LOGIC_VECTOR (9 downto 0);
	Meas_Valid_Ch1          : out std_logic;
	Meas_Data_Ch1           : out std_logic_vector(63 downto 0)
);
END component;
--------------------------------------------------------------------------------
component meas_cdc
    generic ( W : natural := 64 );
    port (
        src_clk   : in  std_logic;
        src_valid : in  std_logic;
        src_data  : in  std_logic_vector(W-1 downto 0);
        dst_clk   : in  std_logic;
        dst_hold  : in  std_logic;
        dst_data  : out std_logic_vector(W-1 downto 0)
    );
end component;
--------------------------------------------------------------------------------
component fifo_fsm_controller
    Port (
        wr_clk      : in  std_logic;
        wr_en       : in  std_logic;
        IndexMax_In : in  std_logic_vector(9 downto 0);
        rd_clk      : in  std_logic;
        rd_en       : in  std_logic;
        data2Com    : out std_logic_vector(9 downto 0)
    );
end component;
--------------------------------------------------------------------------------
component ethernet
    Port ( 
			sys_clk        : in STD_LOGIC;
			data_in_ch1	    	: in STD_LOGIC_VECTOR  (9 downto 0); 
			data_in_ch2	    	: in STD_LOGIC_VECTOR  (9 downto 0); 
			data_in_ch3	    	: in STD_LOGIC_VECTOR  (9 downto 0); 
			meas_ch1	    	: in STD_LOGIC_VECTOR  (63 downto 0);
			meas_ch2	    	: in STD_LOGIC_VECTOR  (63 downto 0);
			meas_ch3	    	: in STD_LOGIC_VECTOR  (63 downto 0);
			--Index_Max_In: in std_logic_vector(8 downto 0);
			CRS_DV         : in std_logic;
			RXD            : in std_logic_vector(1 downto 0);
			fifo_rd_save	: out std_logic;
			fifo_clk_save  : out std_logic;
			E_EX_CLK       : out std_logic;
			TX_EN          : out STD_LOGIC;
			TXD            : out STD_LOGIC_VECTOR(1 downto 0)
        );
end component;
-------------------------------------------------------------------------------
---------------------CLK OUT SIGNALS--------------------------------------------
signal CLK_50_MHZ, CLK_230_MHZ_CH1, CLK_230_MHZ, CLK_230_MHZ_CH2: std_logic:='0';
signal adc1_clk_buff, adc2_clk_buff, adc3_clk_buff, clk_in_buff : std_logic;
---------------------- KET QUA TUNG KENH ---------------------------------------
signal Index_Max_Ch1, Index_Max_Ch2, Index_Max_Ch3 : std_logic_vector(9 downto 0):=(others=>'0');
signal Latch_pulse_ch1, Latch_pulse_ch2, Latch_pulse_ch3 : std_logic;
signal Data2Ethernet1, Data2Ethernet2, Data2Ethernet3 : std_logic_vector(9 downto 0);
signal fifo_rd_en_ethernet, fifo_rd_clk_ethernet: std_logic;
-- Tham so thoi gian xung: mien 230 MHz tung kenh va mien 50 MHz (sau CDC)
signal meas_valid_ch1, meas_valid_ch2, meas_valid_ch3 : std_logic;
signal meas_data_ch1, meas_data_ch2, meas_data_ch3 : std_logic_vector(63 downto 0);
signal meas50_ch1, meas50_ch2, meas50_ch3 : std_logic_vector(63 downto 0);
-- Nguon kich FFT: 1 = tu du lieu ADC cua tung kenh, 0 = chan pulse_detect ngoai (cu)
constant TRIG_SRC : natural := 1;
-- Nguong do xung rieng tung kenh (ma ADC, FS = 8192). CHINH THEO MUC NHIEU/TIN HIEU THUC TE
constant PM_THRESH_CH1 : natural := 600;
constant PM_THRESH_CH2 : natural := 600;
constant PM_THRESH_CH3 : natural := 600;
------------------------ ADC (da chot theo clock cua tung kenh) ------------------
signal adc1_valid_data, adc2_valid_data, adc3_valid_data : std_logic_vector(13 downto 0);
signal rfd_test_ch1, dv_test_ch1 : std_logic;
signal rfd_test_ch2, dv_test_ch2 : std_logic;
signal rfd_test_ch3, dv_test_ch3 : std_logic;
----------------------------BEGIN-----------------------------------------------
BEGIN 
------------------------------------------
rfd_test <= rfd_test_ch2;
dv_test <=  dv_test_ch2;

rfd_ch1 <= rfd_test_ch1;
dv_ch1 <=  dv_test_ch1;

rfd_ch3 <= rfd_test_ch3;
dv_ch3 <=  dv_test_ch3;
----------------------------------------
adc1_clk_buff <=  CLK_230_MHZ_CH1;
adc2_clk_buff <=  CLK_230_MHZ_CH2;
--adc2_clk_buff <= not CLK_230_MHZ_CH1;
adc3_clk_buff <=  CLK_230_MHZ;
-----------------ADC1-----------------------------
process(adc1_clk_buff,adc_in1)
begin 
	if(adc1_clk_buff'event and adc1_clk_buff='1') then
			adc1_valid_data <= adc_in1;
	end if;
end process;
-------------------ADC2---------------------------------
process(adc2_clk_buff,adc_in2)
begin 
	if(adc2_clk_buff'event and adc2_clk_buff='1') then
			adc2_valid_data <= adc_in2;
	end if;
end process;

-------------ADC3-------------------------------
process(adc3_clk_buff,adc_in3)
begin 
	if(adc3_clk_buff'event and adc3_clk_buff='1') then
			adc3_valid_data <= adc_in3;
	end if;
end process;

clk_in_buff <= clk_in;
---------------------------------------------
process(clk_in_buff)
begin 
	if(clk_in_buff'event and clk_in_buff='1') then
		CLK_50_MHZ <= not CLK_50_MHZ;
	end if;
end process;
---------------------DATA-FIFO--------------------------------------------------
--latch_pulse_test          <=  Latch_pulse_ch1;
latch_pulse_test <= Latch_pulse_ch2;
pulse_detect_orig         <= pulse_detect;

---------------230 mhz clock FOR ADC-------------------------------
adc1_clkn<=  adc1_clk_buff;
adc1_clkp<=  not adc1_clk_buff;--not
-----------------------
adc2_clkn<=   adc2_clk_buff;
adc2_clkp<= not adc2_clk_buff;
-----------------------------------
adc3_clkn<=  adc3_clk_buff;
adc3_clkp<= not  adc3_clk_buff;
--------------------capture data from AD4149-----------------------	
--------------------------------------------------------------------
clk_zoom_inst : clk_zoomer
  port map
   (
    CLK_IN1 => clk_in,
    CLK_OUT1 => CLK_230_MHZ,
	CLK_OUT2 => CLK_230_MHZ_CH2,
	CLK_OUT3 => CLK_230_MHZ_CH1);
--------------------------------------
--------------------------------------
Ethernet_unit02:ethernet
		port map(
				sys_clk		   =>  CLK_50_MHZ,
				data_in_ch1	       =>  Data2Ethernet1,
				data_in_ch2	       =>  Data2Ethernet2,
				data_in_ch3	       =>  Data2Ethernet3,
				meas_ch1       =>  meas50_ch1,
				meas_ch2       =>  meas50_ch2,
				meas_ch3       =>  meas50_ch3,
				CRS_DV         =>  CRS_DV_02,
				RXD            =>  RXD_02,
				fifo_rd_save   =>  fifo_rd_en_ethernet,
				fifo_clk_save  =>  fifo_rd_clk_ethernet,
				E_EX_CLK       =>  E_EX_CLK_02,
				TX_EN          =>  TX_EN_02,
				TXD            =>  TXD_02
				);	
	-------------------------------------
FFT512_CH1: FFT_CH
 GENERIC MAP (PM_THRESH => PM_THRESH_CH1, TRIG_SOURCE => TRIG_SRC)
 PORT MAP(
	clk_in_230          => CLK_230_MHZ_CH1,
	adc_in1_ch1         => adc1_valid_data,
	pulse_detect        => pulse_detect,
	rfd_test_ch1        => rfd_test_ch1,
	dv_test_ch1         => dv_test_ch1,
	Latch_pulse_ch1     => Latch_pulse_ch1,
	Index_Max_Out_Ch1   => Index_Max_Ch1,
	Meas_Valid_Ch1      => meas_valid_ch1,
	Meas_Data_Ch1       => meas_data_ch1
);
-- CDC 230 MHz -> 50 MHz cho tham so xung, dong bang khi Ethernet dang doc
U_CDC1: meas_cdc
   generic map (W => 64)
   port map (src_clk => CLK_230_MHZ_CH1, src_valid => meas_valid_ch1, src_data => meas_data_ch1,
             dst_clk => CLK_50_MHZ, dst_hold => fifo_rd_en_ethernet, dst_data => meas50_ch1);
-------------------------------------------------------------
FFT512_CH2: FFT_CH
 GENERIC MAP (PM_THRESH => PM_THRESH_CH2, TRIG_SOURCE => TRIG_SRC)
 PORT MAP(
	clk_in_230          => CLK_230_MHZ_CH2,
	adc_in1_ch1         => adc2_valid_data,
	pulse_detect        => pulse_detect,
	rfd_test_ch1        => rfd_test_ch2,
	dv_test_ch1         => dv_test_ch2,
	Latch_pulse_ch1     => Latch_pulse_ch2,
	Index_Max_Out_Ch1   => Index_Max_Ch2,
	Meas_Valid_Ch1      => meas_valid_ch2,
	Meas_Data_Ch1       => meas_data_ch2
);
-- CDC 230 MHz -> 50 MHz cho tham so xung, dong bang khi Ethernet dang doc
U_CDC2: meas_cdc
   generic map (W => 64)
   port map (src_clk => CLK_230_MHZ_CH2, src_valid => meas_valid_ch2, src_data => meas_data_ch2,
             dst_clk => CLK_50_MHZ, dst_hold => fifo_rd_en_ethernet, dst_data => meas50_ch2);
---------------------------------------------
FFT512_CH3: FFT_CH
 GENERIC MAP (PM_THRESH => PM_THRESH_CH3, TRIG_SOURCE => TRIG_SRC)
 PORT MAP(
	clk_in_230          => CLK_230_MHZ,
	adc_in1_ch1         => adc3_valid_data,
	pulse_detect        => pulse_detect,
	rfd_test_ch1        => rfd_test_ch3,
	dv_test_ch1         => dv_test_ch3,
	Latch_pulse_ch1     => Latch_pulse_ch3,
	Index_Max_Out_Ch1   => Index_Max_Ch3,
	Meas_Valid_Ch1      => meas_valid_ch3,
	Meas_Data_Ch1       => meas_data_ch3
);
-- CDC 230 MHz -> 50 MHz cho tham so xung, dong bang khi Ethernet dang doc
U_CDC3: meas_cdc
   generic map (W => 64)
   port map (src_clk => CLK_230_MHZ, src_valid => meas_valid_ch3, src_data => meas_data_ch3,
             dst_clk => CLK_50_MHZ, dst_hold => fifo_rd_en_ethernet, dst_data => meas50_ch3);
---------------------------------------------------------
-- FIFO luu index dinh cua tung kenh (230 MHz -> 50 MHz)
U111: fifo_fsm_controller
   Port map(
       wr_clk      => CLK_230_MHZ_CH1,
       wr_en       => Latch_pulse_ch1,
       IndexMax_In => Index_Max_Ch1,
       rd_clk      => CLK_50_MHZ,
       rd_en       => fifo_rd_en_ethernet,
       data2Com    => Data2Ethernet1
   );
-----------------------------------------------------
U222: fifo_fsm_controller
   Port map(
       wr_clk      => CLK_230_MHZ_CH2,
       wr_en       => Latch_pulse_ch2,
       IndexMax_In => Index_Max_Ch2,
       rd_clk      => CLK_50_MHZ,
       rd_en       => fifo_rd_en_ethernet,
       data2Com    => Data2Ethernet2
   );
-------------------------------------------------------
U333: fifo_fsm_controller
   Port map(
       wr_clk      => CLK_230_MHZ,
       wr_en       => Latch_pulse_ch3,
       IndexMax_In => Index_Max_Ch3,
       rd_clk      => CLK_50_MHZ,
       rd_en       => fifo_rd_en_ethernet,
       data2Com    => Data2Ethernet3
   );
------------------------------------------------------------
fifo_rd_en_ethernet_test <= fifo_rd_en_ethernet;

end Behavioral;

