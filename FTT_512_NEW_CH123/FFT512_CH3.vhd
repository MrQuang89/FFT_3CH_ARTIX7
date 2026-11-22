
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
-------------------------------------
entity FFT_CH3 is
    Port (  clk_in_230 		            : in  STD_LOGIC;
			adc_in1_ch1 		        : inOUT  STD_LOGIC_VECTOR (13 downto 0);
			-----------------------------------------------------------
			pulse_detect            : inout std_logic;
			------------------------------------------------
			rfd_test_ch1: out std_logic;
			dv_test_ch1  : out std_logic;
			Latch_pulse_ch1 : out std_logic;
			-----------------------------------------
			Index_Max_Out_Ch1       : out STD_LOGIC_VECTOR (9 downto 0)
);		   

end FFT_CH3;
architecture Behavioral of FFT_CH3 is
  
--------------------------------CLOCK ZOOMER----------------------------
COMPONENT FFT_512
  PORT (
    clk : IN STD_LOGIC;
    ce : IN STD_LOGIC;
    start : IN STD_LOGIC;
	fwd_inv : IN STD_LOGIC;
    fwd_inv_we : IN STD_LOGIC;
	rfd : OUT STD_LOGIC;
	busy : OUT STD_LOGIC;
    edone : OUT STD_LOGIC;
    done : OUT STD_LOGIC;
    dv : OUT STD_LOGIC;
    xn_re : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    xn_im : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    xn_index : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
    xk_index : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
    xk_re : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    xk_im : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    blk_exp : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
  );
END COMPONENT;
---------------------------------------------------------------
COMPONENT fifo_14bits
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    full : OUT STD_LOGIC;
	prog_full: out std_logic;
    empty : OUT STD_LOGIC
  );
END COMPONENT;
------------------------FIFO TO SAVE FFT OUTPUT DATA----------------
COMPONENT FIFO_OUT_RE
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    prog_full : OUT STD_LOGIC
  );
  end component;
  ------------------------------------------------------------------------------
 COMPONENT FFT_OUT_IM
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    prog_full : OUT STD_LOGIC
  );
END COMPONENT;
--------------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------lay 13 bit sau FFT----------------------------------------------
COMPONENT binh_phuong_I
  PORT (
    clk : IN STD_LOGIC;
    a : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
    b : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
    --ce : IN STD_LOGIC;
    p : OUT STD_LOGIC_VECTOR(25 DOWNTO 0)
  );
END COMPONENT;
---------------------------------------------------
COMPONENT binh_phuong_R
  PORT (
    clk : IN STD_LOGIC;
    a : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
    b : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
    --ce : IN STD_LOGIC;
    p : OUT STD_LOGIC_VECTOR(25 DOWNTO 0)
  );
END COMPONENT;
-------------------------------------------------------------------------
COMPONENT tong_binh_phuong
  PORT (
    a : IN STD_LOGIC_VECTOR(25 DOWNTO 0);
    b : IN STD_LOGIC_VECTOR(25 DOWNTO 0);
    clk : IN STD_LOGIC;
	 --ce : IN STD_LOGIC;
    s : OUT STD_LOGIC_VECTOR(26 DOWNTO 0)
  );
END COMPONENT;
--------------------------------------------------------------------
COMPONENT can_bac_hai
  PORT (
    x_in : IN STD_LOGIC_VECTOR(26 DOWNTO 0);
    x_out : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    clk : IN STD_LOGIC
  );
END COMPONENT;
---------------------MAY TRANG THAI HE THONG--------------------------------
type FFT_STATES is (FFT_IDLE, FIFO_WRITE, FIFO_WAIT,
			FIFO_READ, FFT_PROCESS, FFT_UNLOAD, PEAK_SEARCH,CLEAR_MEMORY);
signal rw_state, rw_state_next : FFT_STATES := FFT_IDLE;
------------------------mang hai chieu luu gia tri PEAK-------------------
type rom_type is array (0 to 255) of std_logic_vector(7 downto 0); -----255
	signal Peak_Value_Array: rom_type:=(others => (others => '0')); 
	--signal data2Computer_Array : rom_type:=(others => (others => '0')); 
---------------------CLK OUT SIGNALS--------------------------------------------
signal CLK_50_MHZ, CLK_215_MHZ, CLK_230_MHZ: std_logic:='0';
--------------------------------------------------------------------------------
-- signal for FFT
signal start_FFT:std_logic:='0';
signal sclr:std_logic:='0';
signal fwd_inv,fwd_inv_we:std_logic:='1';
signal scale_sch_we:std_logic:='1';
--------------------------------------------------------------------------------
signal rfd,busy:std_logic:='0';
signal dv,ce:std_logic:='0';

----------------------FFT INPUTS------------------------------------------------
signal xn_re:std_logic_vector(13 downto 0):=(others=>'0');
signal xn_im:std_logic_vector(13 downto 0):=(others=>'0');

----------------------FFT OUTPUTS-----------------------------------------------
signal xk_re:std_logic_vector(13 downto 0):=(others=>'0');
signal xk_im:std_logic_vector(13 downto 0):=(others=>'0');
signal xn_index,xk_index:std_logic_vector(8 downto 0);
signal scale_sch:std_logic_vector(11 downto 0);
signal data_valid : std_logic;
--------------------------------------------------------------------------------
-- signal for Square
--------------------------------------------------------------------------------
signal sys_clk:std_logic:='0';
signal done1,edone1:std_logic:='0';
--------------------BUFFER LUU DAU RA FFT---------------------------------------
--------------------------------------------------------------------------------
signal rfd_fifo:std_logic;
signal sys_reset:std_logic:='0';
signal fifo_din:std_logic_vector(13 downto 0):=(others=>'0');
signal fifo_dout,fifo_dout_remove :std_logic_vector(13 downto 0):=(others=>'0');
signal fifo_rd_test, fifo_wr_test : std_logic;
signal fifo_full, fifo_empty:std_logic;
--------------------------------------------------------------------------------
signal clk_capture : std_logic:='0';
signal LathPulse : std_logic:='0';
signal fft_fifo_full, fft_fifo_empty : std_logic;
--------------------------------------------------------------------------------
signal data_fifo_full, data_fifo_empty: std_logic:='0';
signal blk_exp : std_logic_vector(4 downto 0);
signal Pulse_hold : std_logic;
signal LathPulseOut_test,ValidPulse : std_logic;
SIGNAL save_ena : STD_LOGIC;
--- FIFO TO SAVE FFT OUPUT ---------
signal save_fifo_full, save_fifo_empty : std_logic;  
signal save_fifo_wr_en, save_fifo_rd_en : std_logic;
signal save_fifo_wr_clk, save_fifo_rd_clk : std_logic;
signal save_fifo_din, save_fifo_dout : std_logic_vector(13 downto 0):=(others=>'0');
-------------------------------------------------------

signal read_counter: integer range 0 to 511:=0;
signal write_counter, unload_counter : integer range 0 to 511:=0;--
signal IndexBuff, Target_Latch : integer range 0 to 255:=0;    ---255
signal Index_Max: std_logic_vector(9 downto 0):=(others=>'0');
signal Index_Max_Out :std_logic_vector(9 downto 0):=(others=>'0');
signal count2Save:integer range 0 to 255:=0;   ---511
signal data2ethernet_counter:integer range 0 to 255:=0;   ---511
signal peaksearch_counter: integer range 0 to 255:=0;    ----255
signal peak_wr_counter,peak_rd_counter :integer range 0 to 255:=0;

signal fft_ready: std_logic;
SIGNAL fifo_wr_en, fifo_rd_en: std_logic;
signal fifo_wr_clk, fifo_rd_clk: std_logic;
signal fifo_prog_full, save_fifo_prog_full: std_logic;
signal reset: std_logic;
signal Latch_pulse : std_logic:='0';
------------------------------------------------------------
signal fifo_im_full, fifo_im_empty : std_logic:='0';
SIGNAL Amp_Re, Amp_Im : std_logic_vector(13 downto 0):=(others=>'0');
signal sig_im, sig_real : std_logic:='0';
signal xkI2, xkR2 : integer range 0 to 8191:=0;   
SIGNAL xkR2_13bit, xkI2_13bit,xkR2_13bit_Buff :std_logic_vector(12 downto 0):=(others=>'0'); 
SIGNAL xkI2_square, xkR2_square :std_logic_vector(25 downto 0):=(others=>'0'); 
signal Sum_of_Square : std_logic_vector(26 downto 0):=(others=>'0');
signal DataBuff : std_logic_vector(13 downto 0):=(others=>'0');	
SIGNAL squareRI, Data_In, Amp_Out : STD_LOGIC_VECTOR(13 DOWNTO 0):=(others=>'0');

SIGNAL save_fifo_R_din, save_fifo_R_dout: std_logic_vector(13 downto 0):=(others=>'0');
SIGNAL save_fifo_I_din, save_fifo_I_dout: std_logic_vector(13 downto 0):=(others=>'0');
SIGNAL fifo_R_clear, fifo_I_clear: std_logic_vector(13 downto 0):=(others=>'0');
signal data2Computer:  std_logic_vector(7 downto 0):=(others=>'0');
signal fifo_rd_en_ethernet, fifo_rd_clk_ethernet: std_logic;

signal peak_fifo_full, peak_fifo_empty : std_logic;
signal data, Peak_data_save,Data2Ethernet, waste_data :std_logic_vector(7 downto 0);
signal peak_fifo_wr_en, peak_fifo_rd_en, kaka_pulse: std_logic;
signal peak_fifo_prog_empty, peak_fifo_prog_full: std_logic;
signal clear_clk, peak_rd_clk,fifo_im_prog_full: std_logic:='0';
signal rst, remove_rd_en, waste_rd_en, tx_rd_en:std_logic:='0';
signal data_fifo_read_clk, peak_search_clk, clk_ethetnet, peak_fifo_wr_clk: std_logic;
signal remove_counter, waste_counter : integer range 0 to 3:=0;
signal wait_counter,Index_Max_Out_Int: integer range 0 to 255:=0;
----------------------------BEGIN-----------------------------------------------
BEGIN 
sys_reset<='1';
--sclr<='0';
--start_FFT<='0';
ce<='1';
fwd_inv<='1';
fwd_inv_we<='1';
--------------------------------------------
rfd_test_ch1 <= fft_ready;
dv_test_ch1  <= data_valid;
Latch_pulse_ch1 <= Latch_pulse;
---------------------DATA-FIFO--------------------------------------------------
CLK_230_MHZ  <= clk_in_230;
--Index_Max_Out_Ch1 <= Index_Max;
-----------------------------DATA SAVE FOR FFT----------------------

U43 : FFT_512
  PORT MAP (
    clk => CLK_230_MHZ,
    ce => ce,
    start => start_FFT,
    xn_re => xn_re,
    xn_im => xn_im,
    fwd_inv => fwd_inv,
    fwd_inv_we => fwd_inv_we,
    rfd => fft_ready,
    xn_index => xn_index,
    busy => busy,
    edone => edone1,
    done => done1,
    dv => data_valid,
    xk_index => xk_index,
    xk_re => xk_re,
    xk_im => xk_im,
    blk_exp => blk_exp
  );

----------------------------------------------------------------------
	fifo_wr_clk<=  CLK_230_MHZ;
	fifo_rd_clk <= data_fifo_read_clk;   -- NOT CLK_230_MHZ
	reset <= sys_reset;
	--fifo_din <= adc_in1;
--------------------fifo for save ADC sampling radar signal data------
	  U13 : fifo_14bits
	  PORT MAP (
		rst       => '0',
		wr_clk    => fifo_wr_clk,
		rd_clk    => fifo_rd_clk,
		din       => fifo_din,
		wr_en     => fifo_wr_en,
		rd_en     => fifo_rd_en,
		dout      => fifo_dout,
		full      => fifo_full,
		prog_full => fifo_prog_full,
		empty     => fifo_empty
	  );
-------------------------------------------------------------	  
	 save_fifo_wr_clk <= CLK_230_MHZ;   ---230 MHz
	 save_fifo_rd_clk <=  peak_search_clk;    --- NOT CLK_230_MHZ
---------------------fifo for save FFT outputs data--------------------
	U23: FIFO_OUT_RE
	  PORT MAP (
		rst => '0',
		wr_clk => save_fifo_wr_clk,
		rd_clk => save_fifo_rd_clk,
		din    => save_fifo_R_din,
		wr_en  => save_fifo_wr_en,
		rd_en  => save_fifo_rd_en,
		dout   => save_fifo_R_dout,
		full   => save_fifo_full,
		empty  => save_fifo_empty,
		prog_full => save_fifo_prog_full
	  );
-----------------------------------------------------------------------

	  U33 : FFT_OUT_IM
  PORT MAP (
    rst => '0',
    wr_clk => save_fifo_wr_clk,
    rd_clk => save_fifo_rd_clk,
    din => save_fifo_I_din,
    wr_en => save_fifo_wr_en,
    rd_en => save_fifo_rd_en,
    dout => save_fifo_I_dout,
    full => fifo_im_full,
    empty => fifo_im_empty,
    prog_full => fifo_im_prog_full
  );
-------------------------------------------------------------------------
	Amp_Re <= save_fifo_R_dout;
	Amp_Im <= save_fifo_I_dout;
	sig_real  <= Amp_Re(13);
	sig_im    <= Amp_Im(13);
	process(Amp_Re,Amp_Im,sig_im,sig_real) 
	begin
		if(sig_im ='1')then
			xkI2<= 8191-conv_integer(Amp_Im(12 downto 0)); ----16384 BANG 2 MU 14
		else
			xkI2<= conv_integer(Amp_Im(12 downto 0));
		end if;
		----------------------------------------------------------
		if(sig_real='1')then
			xkR2<= 8191-conv_integer(Amp_Re(12 downto 0));
		else
			xkR2<= conv_integer(Amp_Re(12 downto 0));
		end if;
	end process;
	
	xkI2_13bit <= conv_std_logic_vector(xkI2,13);
	xkR2_13bit <= conv_std_logic_vector(xkR2,13);	    
---------------------------------------------------------------------
binh_phuong_I3 : binh_phuong_I
  PORT MAP (
	 clk =>  CLK_230_MHZ,
	 a => xkI2_13bit,
	 b => xkI2_13bit,
     p => xkI2_square    
  );
  ---------------------------------------
 binh_phuong_R3 : binh_phuong_R
  PORT MAP (
	 clk =>  CLK_230_MHZ,
	 a => xkR2_13bit,
	 b => xkR2_13bit,
     p => xkR2_square   
  ); 
-----------------------------------------------------------------------
-----------------------core thuc hien phep cong-------------------
tinh_tong_CH3 : tong_binh_phuong
  PORT MAP (
    a => xkI2_square,   ----
    b => xkR2_square,   ----2
    clk =>  CLK_230_MHZ, ---not 
    s => Sum_of_Square   ----26-0
  );
------------------------------------------------------------------
Inst_can_bac_hai_CH3 : can_bac_hai
  PORT MAP (
    x_in => Sum_of_Square,
    x_out => squareRI,
    clk =>   CLK_230_MHZ
  );
	  
--------------------MAY TRANG THAI DIEU KHIEN FFT----------------------

----------------------------------------------------------------------
----------------------------------------------------------------------
    process(rw_state, fft_ready, save_ena, write_counter, read_counter,Latch_pulse,
					data_valid, pulse_detect, fifo_rd_en_ethernet,unload_counter, count2Save)
    begin   
       if(CLK_230_MHZ'event and CLK_230_MHZ = '1') then 
        case rw_state_next is 
			WHEN FFT_IDLE =>
			   fifo_wr_en <= '0';
			   fifo_rd_en <= '0';
			   start_FFT <= '0';
			   save_fifo_wr_en <= '0';
			   save_fifo_rd_en <= '0';
			   if(pulse_detect = '1' ) then
					rw_state_next <= FIFO_WRITE;	
               else
					rw_state_next <= FFT_IDLE;
               end if;
			----------------------------------------------------------			   
            when FIFO_WRITE =>     -----save ADC data to FIFO
			   fifo_wr_en <= '1';
			   fifo_rd_en <= '0';
			   save_fifo_wr_en <= '0';
			   save_fifo_rd_en <= '0';
			   if(write_counter = 511) then  ---511
					start_FFT <= '1';
					rw_state_next <= FIFO_WAIT;
                else
					rw_state_next <= FIFO_WRITE;
               end if;
			-----------------------------------------------------------
			when FIFO_WAIT =>
				fifo_wr_en <= '0';
				fifo_rd_en <= '0';
				start_FFT <= '0';
				save_fifo_wr_en <= '0';
				save_fifo_rd_en <= '0';
			   if(fft_ready = '1') then
					rw_state_next <= FIFO_READ;
			   else
					rw_state_next <= FIFO_WAIT;
               end if;  
			-----------------------------------------------------------
            when FIFO_READ	=>             --- Read data from FIFO for FFT process
				fifo_wr_en <= '0';
				fifo_rd_en <= '1';
				save_fifo_wr_en <= '0';
				save_fifo_rd_en <= '0';
				if(read_counter = 511)then
					rw_state_next  <= FFT_PROCESS;
				else
					rw_state_next  <= FIFO_READ;
				end if;	
			-----------------------------------------------------------
			when FFT_PROCESS	=>
				fifo_wr_en <= '0';
				fifo_rd_en <= '0';
				save_fifo_wr_en <= '0';
				save_fifo_rd_en <= '0';
				if(data_valid = '1')then
					rw_state_next  <= FFT_UNLOAD;
				else
					rw_state_next  <= FFT_PROCESS;
				end if;	
			-----------------------------------------------------------
			when FFT_UNLOAD	=>           ----write FFT output data to SAVE_FIFO
				fifo_wr_en <= '0';
				fifo_rd_en <= '0';
				start_FFT <= '0';
				--Latch_pulse <='0';
				save_fifo_wr_en <= '1';
				save_fifo_rd_en <= '0';
				if(unload_counter = 511)then
					rw_state_next  <= PEAK_SEARCH;
				else
					rw_state_next  <= FFT_UNLOAD;
				end if;	
			when PEAK_SEARCH  =>
				fifo_wr_en <= '0';
				fifo_rd_en <= '0';	
				start_FFT <= '0';
				save_fifo_wr_en <= '0';
				save_fifo_rd_en <= '1';
				if(Latch_pulse ='1')then
					rw_state_next  <= CLEAR_MEMORY;
				else
					rw_state_next  <= PEAK_SEARCH;
				end if;
			when CLEAR_MEMORY =>
				fifo_wr_en <= '0';
				fifo_rd_en <= '1';
				start_FFT <= '0';
				save_fifo_wr_en <= '0';
				save_fifo_rd_en <= '1';
				if(remove_counter=1) then
					rw_state_next <= FFT_IDLE;
				else
					rw_state_next <= CLEAR_MEMORY;
				end if;
			-----------------------------------------------------------
            when others =>
					rw_state_next <= FFT_IDLE;
        end case;
	end if;
    end process;
----------------------------------------------------------------------
-------------------------------------------------------------------
----------------------save ADC DATA TO FIFO----------------------------
   process(CLK_230_MHZ,rw_state_next,adc_in1_ch1)
    begin
			if(rw_state_next = FIFO_WRITE) then
				if(CLK_230_MHZ'event and CLK_230_MHZ = '1') then	
				
					if(write_counter=511) then
						write_counter <=0;
					else		
						write_counter <= write_counter + 1; 
						fifo_din <= adc_in1_ch1;
					end if;
				-- else
					-- write_counter <= 0;
					-- fifo_din <= (others=>'0');
				end if;
			end if;
    end process;
--------------------------------------------------------------------
data_fifo_read_clk <=  CLK_230_MHZ;

--LOAD DATA FROM FIFO TO FFT TO CALCUTATION PROCESS----------------
    process(CLK_230_MHZ,rw_state_next)
    begin
		if(rw_state_next = FIFO_READ) then	
			if(CLK_230_MHZ'event and CLK_230_MHZ = '1') then	
				
					if(read_counter=511) then
						read_counter<=0;
					else	
						xn_re   <= fifo_dout;
						xn_im   <= (others=>'0');
						read_counter <= read_counter + 1; 
					end if;
				-- else
					-- read_counter <= 0;
				end if;
			end if;
    end process;
	
--------SAVE FFT OUTPUT DATA TO NEW FIFO --------
    process(CLK_230_MHZ,rw_state_next)
    begin
		if(rw_state_next = FFT_UNLOAD) then	
			if(CLK_230_MHZ'event and CLK_230_MHZ = '1') then	
				
					if(unload_counter=511) then
						unload_counter <= 0;
					else
						save_fifo_R_din  <= xk_re;
						save_fifo_I_din  <= xk_im;
						unload_counter <= unload_counter + 1; 
					end if;
				end if;
			end if;
    end process;
-----------------------------------------------------
peak_search_clk <=  CLK_230_MHZ;

--------------------------------------------------------------------------
	     process(peak_search_clk,rw_state_next, done1, squareRI)
		begin
				if(rw_state_next = PEAK_SEARCH) then
					if(peak_search_clk'event and peak_search_clk = '1') then
						if(peaksearch_counter>254 AND peaksearch_counter <=255) then
							peaksearch_counter <= 0;
							Latch_pulse<='1';						
							Index_Max_Out_Ch1 <= conv_std_logic_vector(IndexBuff,10);	
						else
			
							Data_In <= squareRI;
							if(Data_In > DataBuff) then
								DataBuff  <= Data_In;
								IndexBuff <= peaksearch_counter;
							end if;
						end if;
						peaksearch_counter <= peaksearch_counter + 1; 	
					end if;		
				else	
					
					 IndexBuff <=0;
					 Latch_pulse<='0';
					 DataBuff <=(others=>'0');	
				end if;
		end process;
	----------------------------------------------
	-----------------------------------------------
	 process(rw_state_next)
	 begin
	 if(CLK_230_MHZ'event and CLK_230_MHZ = '1') then
		if(rw_state_next = CLEAR_MEMORY )then
			if(remove_counter=1) then
				 remove_counter <=0;
			else
				 remove_counter <= remove_counter+1;
				 fifo_dout_remove <= fifo_dout;
				 fifo_R_clear <= save_fifo_R_dout;
				 fifo_I_clear <= save_fifo_I_dout;
			end if;
		end if;
	 end if;
	 end process;
	
	
end Behavioral;

