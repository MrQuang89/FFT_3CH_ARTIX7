----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity ethernet is
    Port ( 
            sys_clk : in STD_LOGIC;
			--edone1  : in std_logic;
			fifo_rd_save	:out std_logic;
			fifo_clk_save: out std_logic;
			--rfd			: in std_logic;
            			  -- xuat du lieu
			data_in_ch1	: in STD_LOGIC_VECTOR  (9 downto 0);
			data_in_ch2	: in STD_LOGIC_VECTOR  (9 downto 0);
			data_in_ch3	: in STD_LOGIC_VECTOR  (9 downto 0);
--			data_in_ch2		: in STD_LOGIC_VECTOR  (9 downto 0); 	
--			data_in_ch3	    	: in STD_LOGIC_VECTOR  (9 downto 0); 
			--Index_Max_In: in std_logic_vector(8 downto 0);
			--clk_strobe	: out std_logic;
         -----------------------------------------------------
			--threshold_level : out std_logic_vector(15 downto 0);
			--IndexMax: in STD_LOGIC_vector(9 downto 0);
			--Max_Amp   :  in  std_logic_vector(26 downto 0);
         -----------------------------------------------------
			E_EX_CLK : out std_logic;
            CRS_DV : in std_logic;
            RXD : in std_logic_vector(1 downto 0);
            TX_EN : out STD_LOGIC;
            TXD : out STD_LOGIC_VECTOR(1 downto 0)
        );
end ethernet;

architecture Behavioral of ethernet is

COMPONENT udp_ip_rmii
    PORT(
        ---------------------------
        sys_clk : in STD_LOGIC;
        ref_clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        
        -- Interface Network Manager
        --------------------------------------------
        srcAddr : IN std_logic_vector(31 downto 0);
        desAddr : IN std_logic_vector(31 downto 0);
        srcMacAddr : IN std_logic_vector(47 downto 0);
        desMacAddr : IN std_logic_vector(47 downto 0);
        srcPort : IN std_logic_vector(15 downto 0);
        desPort : IN std_logic_vector(15 downto 0);
        
        -- Interface to Application layer
        --------------------------------------------
        -- For send
        sendData : IN std_logic;
        dataLength : IN std_logic_vector(15 downto 0);
        ready : OUT std_logic;
        sendDataFinish : OUT std_logic;
        
        -- For receive
        data_addr : IN std_logic_vector(4 downto 0);
        newData : OUT std_logic;
        data_recv : OUT std_logic_vector(7 downto 0);
        
        -- Interface to DataBuffer
        --------------------------------------------
        data_number : IN std_logic_vector(15 downto 0);
        data_to_send : IN std_logic_vector(7 downto 0);
        dataReadClk : OUT std_logic;
        fr_rdEn : OUT std_logic;
        
        -- Interface to Physical Layer
        --------------------------------------------
        CRS_DV : IN std_logic;
        RXD : IN std_logic_vector(1 downto 0);
        TX_EN : out STD_LOGIC;
        TXD : out STD_LOGIC_VECTOR(1 downto 0)
        );
END COMPONENT;
COMPONENT fifo_8k
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    wr_data_count : OUT STD_LOGIC_VECTOR(12 DOWNTO 0)
  );
END COMPONENT;
type SYS_STATES is (SYS_IDLE, SYS_RETART, SYS_PREPARE, SYS_INIT, SYS_ACTIVE, SYS_WAIT);
type RECV_STATES is (RECV_IDLE, RECV_INIT, RECV_READ);
signal sys_state, sys_state_next : SYS_STATES := SYS_IDLE;

signal recv_state, recv_state_next : RECV_STATES := RECV_IDLE;
signal recv_counter : integer range 0 to 31 := 0;
--signal data : integer range 0 to 255 := 0;
signal ref_clk: std_logic := '0';
signal clk_1MHz : std_logic := '0';
signal counter_1MHz : integer range 0 to 25 := 0;
signal clk_1Hz : std_logic := '0';
signal counter_1Hz : integer range 0 to 499 := 0;
signal flag_send : std_logic := '0';
signal flag_send_clear : std_logic := '0';
signal local_led_2 : STD_LOGIC := '0';
--Inputs
signal rst : std_logic := '0';
signal srcAddr : std_logic_vector(31 downto 0) := (others => '0');
signal desAddr : std_logic_vector(31 downto 0) := (others => '0');
signal srcMacAddr : std_logic_vector(47 downto 0) := (others => '0');
signal desMacAddr : std_logic_vector(47 downto 0) := (others => '0');
signal srcPort : std_logic_vector(15 downto 0) := (others => '0');
signal desPort : std_logic_vector(15 downto 0) := (others => '0');

--Sender
signal sendData : std_logic := '0';
signal dataLength : std_logic_vector(15 downto 0) := (others => '0');
signal sendStatus : std_logic_vector(2 downto 0);
signal ready : std_logic;
signal sendDataFinish : std_logic;
signal dataReadClk : std_logic;
signal fr_rdEn : std_logic;

signal rmii_tx_en :std_logic;
signal rmii_txd : std_logic_vector(1 downto 0);

--Receiver
signal newData :std_logic;
signal data_recv : std_logic_vector(7 downto 0);
signal data_addr : std_logic_vector(4 downto 0);

signal rmii_crs_dv : std_logic;
signal rmii_rxd : std_logic_vector(1 downto 0);
signal byte_control : std_logic_vector(7 downto 0);
signal byte1, byte2,byte3,byte4: std_logic_vector(7 downto 0);
signal Byte2_Index,Byte3_Index : std_logic_vector(7 downto 0);
signal Byte4_Index, Byte5_Index : std_logic_vector(7 downto 0);
signal Byte6_Index, Byte7_Index : std_logic_vector(7 downto 0);
-- FIFO
signal fifo_wr_clk : std_logic;
signal fifo_rd_clk : std_logic;
signal fifo_din : std_logic_vector(7 downto 0);
signal fifo_wr_en : std_logic;
signal fifo_rd_en : std_logic;
signal fifo_dout : std_logic_vector(7 downto 0);
signal fifo_full : std_logic;
signal fifo_empty : std_logic;
signal fifo_data_count : std_logic_vector(12 downto 0);
signal data_number : std_logic_vector(15 downto 0) := (others => '0');
--- leng data
--signal byteTranfer:integer range 0 to 1023:=0;
signal sys_counter : integer range 0 to 255:= 0;  ---255
constant byteTranfer: integer:= 256;---512
signal time_active: integer range 0 to 255:=0; ----511

signal data2Send:std_logic_vector(7 downto 0);
signal data : integer range 0 to 255 := 0;

begin 
	 ref_clk <= sys_clk;
	 E_EX_CLK <= sys_clk;
    --data_number <= conv_std_logic_vector(1024,16);
    data_number(12 downto 0) <= fifo_data_count;
    data_number(15 downto 13) <= (others => '0');
    --dataLength <= conv_std_logic_vector(20,16);
   -- byteTranfer<= 1024;
	time_active<= byteTranfer-1;
    dataLength <= conv_std_logic_vector(byteTranfer,16); -- so Byte gui
    desMacAddr <= x"F0DEF1140B14"; -- dia chi MAC cua may tinh
	 --desMacAddr <= x"B44506882ED9";
    srcMacAddr <= x"001234567890";
    desAddr <= x"0A000004";--10.0.0.4
	 --desAddr <= x"C0A80004";   --192.168.0.4
    srcAddr <= x"0A000005"; --10.0.0.5
	 --srcAddr <= x"C0A8002C"; --192.168.0.44
    
    --desPort <= x"0058";
	 desPort <= x"0402";  ---0400
    --srcPort <= x"0058";
	 srcPort <= x"0402";  --0400
    --Led1 <= clk_1Hz;
    TX_EN <= rmii_tx_en;
    TXD <= rmii_txd; 
    rmii_crs_dv <= CRS_DV;
    rmii_rxd <= RXD;
	------------------------------------------
	--threshold_level(15 downto 8) <=byte2;
	--threshold_level(7 downto 0) <=byte3;
    -- Clock Generator
    process(sys_clk)
    begin
        if(sys_clk'event and sys_clk = '1') then
            if(counter_1MHz = 24) then
                counter_1MHz <= 0;
                clk_1MHz <= not clk_1MHz;
            else
                counter_1MHz <= counter_1MHz + 1;
            end if;
        end if;
    end process;
    --
    process(clk_1MHz)
    begin
        if(clk_1MHz'event and clk_1MHz = '1') then
            if(counter_1Hz = 149) then
                counter_1Hz <= 0;
                clk_1Hz <= not clk_1Hz;
            else
                counter_1Hz <= counter_1Hz + 1;
            end if;
        end if;
    end process;
   --clk_strobe<= clk_1Hz;
    ----------------------------------------
    -- Reset system
    process(sys_state)
    begin
        if(sys_state = SYS_RETART) then
            rst <= '0';
        else
            rst <= '1';
        end if;
    end process;
	
	
    
    process(sys_state,sys_counter)
    begin
        if(sys_state = SYS_ACTIVE) then
			fifo_wr_en <= '1';
        else
            fifo_wr_en <= '0';
        end if;
    end process;
    fifo_wr_clk <= not sys_clk;
    --
	fifo_rd_save<= fifo_wr_en;
	fifo_clk_save<=  sys_clk;
    ----------------------------------------
    -- Send data
    process(sys_state)
    begin
        if(sys_state = SYS_INIT) then
            sendData <= '1';
        else
            sendData <= '0';
        end if;
    end process;
    process(clk_1Hz, flag_send_clear)
    begin
        if(flag_send_clear = '1') then
            flag_send <= '0';
        elsif(clk_1Hz'event and clk_1Hz = '1') then
            flag_send <= '1';
        end if;
    end process;
    process(sys_state)
    begin
        if(sys_state = SYS_INIT) then
            flag_send_clear <= '1';
        else
            flag_send_clear <= '0';
        end if;
    end process;

    -- Read received data
    process(sys_clk, recv_state)
    begin
        if(sys_clk'event and sys_clk = '1') then
            if(recv_state = RECV_INIT) then
                recv_counter <= 0;
            elsif(recv_state = RECV_READ) then
                recv_counter <= recv_counter + 1;
            end if;
        end if;
    end process;
    
    data_addr <= conv_std_logic_vector(recv_counter, 5);
	 -- Nhan du lieu
        -- Byte2
 process(sys_clk, recv_counter, data_recv)
    begin
        if(sys_clk'event and sys_clk = '1') then
            if(recv_counter = 0) then				
                byte1 <= data_recv;
				end if;
			end if;	
    end process;
        -- Byte2
    process(sys_clk, recv_counter, data_recv)
    begin
        if(sys_clk'event and sys_clk = '1') then
            if(recv_counter = 1) then				
                byte2 <= data_recv;
				end if;
			end if;	
    end process; 
	-- byte_out		<= byte2;
	        -- Byte2
    process(sys_clk, recv_counter, data_recv)
    begin
        if(sys_clk'event and sys_clk = '1') then
            if(recv_counter = 2) then				
                byte3 <= data_recv;
				end if;
			end if;	
    end process; 
	-- byte_out		<= byte2;
    -------------------------------------------
    -- System counter
    process(sys_clk,sys_state)
    begin
        if(sys_clk'event and sys_clk = '1') then
            if(sys_state = SYS_INIT or sys_state = SYS_RETART) then
                sys_counter <= 0;
            elsif(sys_state = SYS_PREPARE or sys_state = SYS_ACTIVE) then
                sys_counter <= sys_counter + 1;
            end if;
        end if;
    end process;
    
    ----------------------------------------
    --
    Inst_udp_ip_rmii: udp_ip_rmii
    PORT MAP(
        sys_clk => sys_clk,
        ref_clk => ref_clk,
        rst => rst,
        -- Interface Network Manager
        --------------------------------------------
        srcAddr => srcAddr,
        desAddr => desAddr,
        srcMacAddr => srcMacAddr,
        desMacAddr => desMacAddr,
        srcPort => srcPort,
        desPort => srcPort,
        -- Interface to Application layer
        --------------------------------------------
        -- For send
        sendData => sendData,
        dataLength => dataLength,
        ready => ready,
        sendDataFinish => sendDataFinish,
        -- For receive
        data_addr => data_addr,
        newData => newData,
        data_recv => data_recv,
        -- Interface to DataBuffer
        --------------------------------------------
        data_number => data_number,
        data_to_send => fifo_dout,
        dataReadClk => fifo_rd_clk,
        fr_rdEn => fifo_rd_en,
        -- Interface to Physical Layer
        --------------------------------------------
        CRS_DV => rmii_crs_dv,
        RXD => rmii_rxd,
        TX_EN => rmii_tx_en,
        TXD => rmii_txd
    );
	
	
	
	-- Write data to FIFO
    --fifo_din <= data_in;--conv_std_logic_vector(data, 8);
	
	
    Inst_fifo_8k : fifo_8k
    PORT MAP (
        rst => not rst,
        wr_clk => fifo_wr_clk,
        rd_clk => fifo_rd_clk,
        din => fifo_din,
        wr_en => fifo_wr_en,
        rd_en => fifo_rd_en,
        dout => fifo_dout,
        full => fifo_full,
        empty => fifo_empty,
        wr_data_count => fifo_data_count
    );
  
    -------------------------------------------
    -- Main State Machine
    process(sys_state, flag_send,sys_counter,time_active )
    begin
        sys_state_next <= SYS_IDLE;
        
        case sys_state is
            when SYS_IDLE =>
                sys_state_next <= SYS_RETART;
            when SYS_RETART =>
                sys_state_next <= SYS_WAIT;
            when SYS_PREPARE =>
                if(sys_counter = 7) then
                    sys_state_next <= SYS_INIT;
                else
                    sys_state_next <= SYS_PREPARE;
                end if;
            when SYS_INIT =>
				 -- if(rfd ='1')then
					 sys_state_next <= SYS_ACTIVE;
				 -- else
					 -- sys_state_next<= SYS_INIT;
				 -- end if;
            when SYS_ACTIVE =>
                if(sys_counter = time_active) then
                    sys_state_next <= SYS_WAIT;
                else
                    sys_state_next <= SYS_ACTIVE;
                end if; 
            when SYS_WAIT =>
                if(flag_send = '1') then
                    sys_state_next <= SYS_PREPARE;
                else
                    sys_state_next <= SYS_WAIT;
                end if;
            when others =>
                sys_state_next <= SYS_IDLE;
        end case;
    end process;
    process(sys_clk, sys_state_next)
    begin
        if(sys_clk'event and sys_clk = '1') then
            sys_state <= sys_state_next;
        end if;
    end process;
    -- Receiver State Machine
    process(recv_state, newData, recv_counter)
    begin
        
        recv_state_next <= RECV_IDLE;
        
        case recv_state is 
            when RECV_IDLE =>
                if(newData = '1') then
                    recv_state_next <= RECV_INIT;
                else
                    recv_state_next <= RECV_IDLE;
                end if;
                
            when RECV_INIT =>
                recv_state_next <= RECV_READ;
                
            when RECV_READ =>
                if(recv_counter = 15) then
                    recv_state_next <= RECV_IDLE;
                else
                    recv_state_next <= RECV_READ;
                end if; 
                
            when others =>
                recv_state_next <= RECV_IDLE;
        end case;
    end process;
    
    process(sys_clk, recv_state_next, rst)
    begin
        if(rst = '0') then
            recv_state <= RECV_IDLE;
        elsif(sys_clk'event and sys_clk = '1') then
            recv_state <= recv_state_next;
        end if;
    end process;
	 ---------------------------------------------------------------------
	     --Generate data to send
	   process(sys_clk, fifo_wr_en, sys_state)
	   begin
		   if(sys_state = SYS_INIT) then
			   data <= 0;
		   elsif(sys_clk'event and sys_clk = '1') then
			   if(fifo_wr_en = '1') then
				   if(data = 255) then
					   data <= 0;
				   else
					   data <= data + 1;
				   end if;
			   end if;
		   end if;
	   end process;
	 ---------------------------------------------------------------------
	 -- process(sys_clk, data_in_ch1, data_in_ch2,data_in_ch3)
	 -- begin
		-- if(sys_clk'event and sys_clk='1') then
			  Byte2_Index <= "00000" & data_in_ch1(9 downto 7);
			  Byte3_Index <= '0'& data_in_ch1(6 downto 0);
			  
			  Byte4_Index <= "00000" & data_in_ch2(9 downto 7);
			  Byte5_Index <= '0'& data_in_ch2(6 downto 0);
		--	  
			  Byte6_Index <= "00000" & data_in_ch3(9 downto 7);
			  Byte7_Index <= '0'& data_in_ch3(6 downto 0);
		-- end if;
	-- end process;
	 
	 	process(data,Byte2_Index, Byte3_Index,Byte4_Index,
				Byte5_Index,Byte6_Index, Byte7_Index)
			begin
			if(data=1)then	
				fifo_din <=X"AA";
			elsif(data=2)then
				fifo_din <=X"81";
			elsif(data=3)then	
				fifo_din<= Byte2_Index;
			elsif(data=4) then
				fifo_din<= Byte3_Index;
				----------------------
			elsif(data=5)then
				fifo_din <=X"82";
			elsif(data=6)then	
				fifo_din<= Byte4_Index;
			elsif(data=7) then
				fifo_din<= Byte5_Index;
--				---------------------
			elsif(data=8)then
				fifo_din <=X"83";
			elsif(data=9)then	
				fifo_din<= Byte6_Index;
			elsif(data=10) then
				fifo_din<= Byte7_Index;	
			else
				fifo_din<= X"00";
			end if;
		end process;
	 
	 
	 
	 
	 
end Behavioral;