
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
-------------------------------------
entity top is
    Port (  clk_in 		            : in  STD_LOGIC;
			adc_in1 		        : inOUT  STD_LOGIC_VECTOR (13 downto 0);
			adc_in2 		        : inOUT  STD_LOGIC_VECTOR (13 downto 0);
			adc_in3 		        : inOUT  STD_LOGIC_VECTOR (13 downto 0);
			-----------------------------------------------------------
			pulse_detect            : inout std_logic;
			-----------------------------------------------------------
			adc3_clkp		        : out std_logic; -- FPGA to ADC
			adc3_clkn		        : out std_logic;
			adc3_clk_out_n          : inout std_logic;
			adc3_clk_out_p          : inout std_logic;
			------------------------------------------------------------------
			adc2_clkp		        : out std_logic; -- FPGA to ADC
			adc2_clkn		        : out std_logic;
			adc2_clk_out_n          : inout std_logic;
			adc2_clk_out_p          : inout std_logic;
			------------------------------------------------------------
			adc1_clkp		        : out std_logic; -- FPGA to ADC
			adc1_clkn		        : out std_logic;
			adc1_clk_out_n          : inout std_logic;
			adc1_clk_out_p          : inout std_logic;
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
component FFT_CH1 
Port (
	clk_in_230 		            : in  STD_LOGIC;
	adc_in1_ch1		        : inOUT  STD_LOGIC_VECTOR (13 downto 0);
	pulse_detect            : inout std_logic;
	rfd_test_ch1: out std_logic;
	dv_test_ch1  : out std_logic;
	Latch_pulse_ch1 : out std_logic;
	Index_Max_Out_Ch1       : out STD_LOGIC_VECTOR (9 downto 0)
);
END component;
------------------------------------------------------------------------
component FFT_CH2 
Port (
	clk_in_230 		            : in  STD_LOGIC;
	adc_in1_ch1		        : inOUT  STD_LOGIC_VECTOR (13 downto 0);
	pulse_detect            : inout std_logic;
	rfd_test_ch1: out std_logic;
	dv_test_ch1  : out std_logic;
	Latch_pulse_ch1 : out std_logic;
	Index_Max_Out_Ch1       : out STD_LOGIC_VECTOR (9 downto 0)
);
END component;
-----------------------------------------------------------------------
component FFT_CH3 
Port (
	clk_in_230 		            : in  STD_LOGIC;
	adc_in1_ch1		        : inOUT  STD_LOGIC_VECTOR (13 downto 0);
	pulse_detect            : inout std_logic;
	rfd_test_ch1: out std_logic;
	dv_test_ch1  : out std_logic;
	Latch_pulse_ch1 : out std_logic;
	Index_Max_Out_Ch1       : out STD_LOGIC_VECTOR (9 downto 0)
);
END component;
--------------------------------------------------------------------------------
component fifo_fsm_controller 
    Port (
        -- Write Interface
        wr_clk  : in std_logic;
        wr_en   : in std_logic;
        IndexMax_In  : in std_logic_vector(9 downto 0);
        full    : in std_logic;

        -- Read Interface
        rd_clk  : in std_logic;
        rd_en   : in std_logic;
        data2Com    : out std_logic_vector(9 downto 0);
        empty   : in std_logic;
		rst_sign : in std_logic
		
    );
end component;
----------------------------------------------
component fifo_fsm_controller_ch2 
    Port (
        -- Write Interface
        wr_clk  : in std_logic;
        wr_en   : in std_logic;
        IndexMax_In  : in std_logic_vector(9 downto 0);
        full    : in std_logic;

        -- Read Interface
        rd_clk  : in std_logic;
        rd_en   : in std_logic;
        data2Com    : out std_logic_vector(9 downto 0);
        empty   : in std_logic;
		rst_sign : in std_logic
		
    );
end component;
-----------------------------------
component fifo_fsm_controller_ch3 
    Port (
        -- Write Interface
        wr_clk  : in std_logic;
        wr_en   : in std_logic;
        IndexMax_In  : in std_logic_vector(9 downto 0);
        full    : in std_logic;

        -- Read Interface
        rd_clk  : in std_logic;
        rd_en   : in std_logic;
        data2Com    : out std_logic_vector(9 downto 0);
        empty   : in std_logic;
		rst_sign : in std_logic
		
    );
end component;
--------------------------------------------------------------------------------
component ethernet
    Port ( 
			sys_clk        : in STD_LOGIC;
			data_in_ch1	    	: in STD_LOGIC_VECTOR  (9 downto 0); 
			data_in_ch2	    	: in STD_LOGIC_VECTOR  (9 downto 0); 
			data_in_ch3	    	: in STD_LOGIC_VECTOR  (9 downto 0); 
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
---------------------MAY TRANG THAI MO RONG XUNG CUA SONG-----------------
type ETHERNET_TX_STATES is (TX_IDLE, TX_WRITE,TX_WAIT,TX_READ,TX_NEXT_WRITE );
signal tx_state, tx_next : ETHERNET_TX_STATES := TX_IDLE;
------------------------mang hai chieu luu gia tri PEAK-------------------
type rom_type is array (0 to 255) of std_logic_vector(7 downto 0); -----255
	signal Peak_Value_Array: rom_type:=(others => (others => '0')); 
	--signal data2Computer_Array : rom_type:=(others => (others => '0')); 
---------------------CLK OUT SIGNALS--------------------------------------------
signal CLK_50_MHZ, CLK_230_MHZ_CH1, CLK_230_MHZ,CLK_230_MHZ_CH2: std_logic:='0';
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
signal read_counter: integer range 0 to 511:=0;
signal write_counter, unload_counter : integer range 0 to 511:=0;--
signal IndexBuff, Target_Latch : integer range 0 to 255:=0;    ---255
signal Index_Max: std_logic_vector(9 downto 0):=(others=>'0');
signal Index_Max_Out, Index_Max_Ch1,Index_Max_Ch2,Index_Max_Ch3 :std_logic_vector(9 downto 0):=(others=>'0');
signal Index_Max_Ch1_val, Index_Max_Ch2_val :std_logic_vector(9 downto 0):=(others=>'0');
--signal Index_Max, Index_Max_Out: std_logic_vector(7 downto 0):=(others=>'0');
signal count2Save:integer range 0 to 255:=0;   ---511
signal data2ethernet_counter:integer range 0 to 255:=0;   ---511
signal peaksearch_counter: integer range 1 to 255:=1;    ----255
signal peak_wr_counter,peak_rd_counter :integer range 0 to 255:=0;

signal peak_fifo_full_ch1, peak_fifo_empty_ch1 : std_logic;
signal peak_fifo_full_ch3, peak_fifo_empty_ch3 : std_logic;

signal peak_fifo_wr_en, peak_fifo_rd_en, kaka_pulse: std_logic;
signal peak_fifo_empty_ch2,peak_fifo_full_ch2: std_logic;
signal clear_clk, peak_rd_clk, peak_wr_clk: std_logic:='0';
signal rst, remove_rd_en, waste_rd_en, tx_rd_en:std_logic:='0';
signal data_fifo_read_clk, peak_search_clk, clk_ethetnet, peak_fifo_wr_clk: std_logic;
signal remove_counter, waste_counter : integer range 0 to 3:=0;
signal wait_counter: integer range 0 to 511:=0;  --255
signal fifo_rd_en_ethernet, fifo_rd_clk_ethernet: std_logic;
signal Latch_pulse_ch1, Latch_pulse_ch2, Latch_pulse_ch3 : std_logic;
signal adc1_clk_buff, adc2_clk_buff, clk_in_buff, adc3_clk_buff :std_logic;
signal time_to_next_write_counter : integer range 0 to 125:=0;----
signal adc2_clk_out_n_buff, adc2_clk_out_p_buff: std_logic;
signal adc1_clk_out_n_buff, adc1_clk_out_p_buff: std_logic;
SIGNAL clk_out_p_test: std_logic;
signal test_counter: integer;
signal adc_in1_two_complt: signed(13 downto 0);
signal adc_in1_in: std_logic_vector(13 downto 0);
-----------------------------------------------
signal clk_25mhz, clk_1khz, clk_1mhz, clk_1hz, fifo_rd_clk : std_logic;
signal clk_50hz, clk_100hz, clk_500hz, clk_200hz: std_logic;
---------------------------------
signal stm_reset_counter: integer;
signal stm_srt: std_logic:='0';
signal main_reset: std_logic:='0';
signal Data2Ethernet1,Data2Ethernet2,Data2Ethernet3 : std_logic_vector(9 downto 0);
------------------------------------------------------------------------------
signal adc1_valid_data, adc2_valid_data, adc3_valid_data : std_logic_vector(13 downto 0);
signal rfd_test_ch1, rfd_test_ch2, dv_test_ch2, dv_test_ch1: std_logic;
signal rfd_test_ch3, dv_test_ch3: std_logic;
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
				CRS_DV         =>  CRS_DV_02,
				RXD            =>  RXD_02,
				fifo_rd_save   =>  fifo_rd_en_ethernet,
				fifo_clk_save  =>  fifo_rd_clk_ethernet,
				E_EX_CLK       =>  E_EX_CLK_02,
				TX_EN          =>  TX_EN_02,
				TXD            =>  TXD_02
				);	
	-------------------------------------
 FFT512_CH1: FFT_CH1
 PORT MAP(
	clk_in_230 		         => CLK_230_MHZ_CH1,
	adc_in1_ch1 		   => adc1_valid_data,
	-----------------------------------------------------------
	pulse_detect         => pulse_detect,
	-----------------------------------
	rfd_test_ch1           => rfd_test_ch1,
	dv_test_ch1            => dv_test_ch1,
	Latch_pulse_ch1        => Latch_pulse_ch1,
	-----------------------------------------------------------
	Index_Max_Out_Ch1    => Index_Max_Ch1
);
-------------------------------------------------------------
  FFT512_CH2: FFT_CH2
  PORT MAP(
	clk_in_230 		         => CLK_230_MHZ_CH2,
	adc_in1_ch1 		   => adc2_valid_data,
	-----------------------------------------------------------
	pulse_detect         => pulse_detect,
	-----------------------------------
	rfd_test_ch1           => rfd_test_ch2,
	dv_test_ch1            => dv_test_ch2,
	Latch_pulse_ch1        => Latch_pulse_ch2,
	-----------------------------------------------------------
	Index_Max_Out_Ch1    => Index_Max_Ch2
);
---------------------------------------------
  FFT512_CH3: FFT_CH3
  PORT MAP(
	clk_in_230 		         => CLK_230_MHZ,
	adc_in1_ch1 		   => adc3_valid_data,
	-----------------------------------------------------------
	pulse_detect         => pulse_detect,
	-----------------------------------
	rfd_test_ch1           => rfd_test_ch3,
	dv_test_ch1            => dv_test_ch3,
	Latch_pulse_ch1        => Latch_pulse_ch3,
	-----------------------------------------------------------
	Index_Max_Out_Ch1    => Index_Max_Ch3
);

---------------------------------------------------------
	U111: fifo_fsm_controller
	   Port map(  
       -- Write Interface
       wr_clk  =>  CLK_230_MHZ_CH1,
       wr_en     =>  Latch_pulse_ch1,
       IndexMax_In   => Index_Max_Ch1,
       full  => peak_fifo_full_ch1,
       -- Read Interface
       rd_clk    => CLK_50_MHZ,
       rd_en     => fifo_rd_en_ethernet,
       data2Com  => Data2Ethernet1,
       empty     => peak_fifo_empty_ch1,
		----------reset-------------
		rst_sign => main_reset
		
   );
-----------------------------------------------------
	U222: fifo_fsm_controller_ch2
	   Port map(  
        -- Write Interface
        wr_clk  =>  CLK_230_MHZ_CH2,
        wr_en     =>  Latch_pulse_ch2,
        IndexMax_In   => Index_Max_Ch2,
        full  => peak_fifo_full_ch2,
        -- Read Interface
        rd_clk    => CLK_50_MHZ,
        rd_en     => fifo_rd_en_ethernet,
        data2Com  => Data2Ethernet2,
        empty     => peak_fifo_empty_ch2,
		----------reset-------------
		rst_sign => main_reset
		
    );
	 -------------------------------------------------------
	 	U333: fifo_fsm_controller_ch3
	   Port map(  
        -- Write Interface
        wr_clk  =>  CLK_230_MHZ,
        wr_en     =>  Latch_pulse_ch3,
        IndexMax_In   => Index_Max_Ch3,
        full  => peak_fifo_full_ch3,
        -- Read Interface
        rd_clk    => CLK_50_MHZ,
        rd_en     => fifo_rd_en_ethernet,
        data2Com  => Data2Ethernet3,
        empty     => peak_fifo_empty_ch3,
		----------reset-------------
		rst_sign => main_reset
		
    );
------------------------------------------------------------	
	
end Behavioral;

