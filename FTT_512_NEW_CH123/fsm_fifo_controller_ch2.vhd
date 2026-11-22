library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity fifo_fsm_controller_ch2 is
    Port (
        -- Write Interface
        wr_clk  : in std_logic;
        wr_en   : in std_logic;
        IndexMax_In : in std_logic_vector(9 downto 0);
        full    : in std_logic;

        -- Read Interface
        rd_clk  : in std_logic;
        rd_en   : in std_logic;
        data2Com    : out std_logic_vector(9 downto 0);
        empty   : in std_logic;
		rst_sign : in std_logic
		
    );
end fifo_fsm_controller_ch2;

architecture Behavioral of fifo_fsm_controller_ch2 is

    -- FIFO Component Declaration (assuming it's an external IP)
    component peak_value_fifo is
        Port (
			rst : IN STD_LOGIC;
            wr_clk  : in std_logic;
            rd_clk  : in std_logic;
            din     : in std_logic_vector(9 downto 0);
            wr_en   : in std_logic;
            rd_en   : in std_logic;
            dout    : out std_logic_vector(9 downto 0);
            full    : inout std_logic;
            empty   : inout std_logic;
			prog_full: out std_logic
			-----------------------

        );
    end component;

    -- State Definitions for Write FSM
    type wr_state_type is (IDLE_WRITE, WRITE_DATA);
    signal wr_state_next, wr_state : wr_state_type := IDLE_WRITE;

    -- State Definitions for Read FSM
    type rd_state_type is (IDLE_READ,CLEAR_WASTE,WAIT_SEND,SEND_DATA);
    signal rd_state_next,rd_state : rd_state_type := IDLE_READ;
	
		
	type rom_type_peak is array (0 to 255) of std_logic_vector(9 downto 0); -----255
	signal Peak_Value: rom_type_peak:=(others => (others => '0')); 

    -- FIFO Control Signals
    signal fifo_wr_en : std_logic := '0';
    signal fifo_rd_en : std_logic := '0';
    signal fifo_dout,fifo_data_buff  : std_logic_vector(9 downto 0);
	 -- signal count2Save: integer range 0 to 31:=0;
	 -- signal read_counter: integer range 0 to 31:=0;
	 signal count2Save: integer range 0 to 255:=0;
	 signal read_counter, send_data_counter: integer range 0 to 256:=0;
	 signal data,remove_data: std_logic_vector( 9 downto 0);
	 signal fifo_full, fifo_empty: std_logic;
	 signal indexMax,fifo_din: std_logic_vector(9 downto 0);
	 signal rd_en_in, wr_en_in, fifo_pro_full: std_logic;
	 signal remove_counter: integer:=0;
	 signal wait_counter: integer range 0 to 255:=0;--255
	 signal write_counter: integer range 0 to 1023:=0;

begin
	--data2Com <= Peak_Value(10);
    -- Instantiate the FIFO Generator
    U_FIFO_ch2 : peak_value_fifo
        port map (
			rst =>'0',
			--rst     => rst_sign,
            wr_clk  => wr_clk,
            rd_clk  => rd_clk,
            din     => fifo_din,
            wr_en   => fifo_wr_en,
            rd_en   => fifo_rd_en,
            dout    => fifo_dout,  ---fifo_dout
            full    => fifo_full,
            empty   => fifo_empty,
			prog_full => fifo_pro_full
        );

    --dout <= fifo_dout;  -- Connect output data
	wr_en_in <= wr_en;
	rd_en_in <= rd_en;
	--indexMax <= IndexMax_In;
    -- FSM for Write Operation
-------------------------------
    process (wr_state,wr_clk)
    begin	
		--wr_state_next <= IDLE_WRITE;
	if(wr_clk'event and wr_clk='1') then
		case wr_state is
			when IDLE_WRITE =>
				fifo_wr_en <= '0';
				if (wr_en_in = '1' and fifo_full = '0' )then
					wr_state <= WRITE_DATA;
					
				end if;

			when WRITE_DATA =>
				fifo_wr_en <= '1';
				fifo_din <=IndexMax_In;
				wr_state <= IDLE_WRITE;
			when others =>
				wr_state <= IDLE_WRITE;
		end case;
	end if;
    end process;
	
	 --------------------------------------------------------
	----------------------------------------------
    process (rd_state,rd_clk,rd_en_in)
    begin
	if(rd_clk'event and rd_clk='1') then
		case rd_state is
			when IDLE_READ =>
				fifo_rd_en <= '0';
				if(wait_counter=255) then  ---255
				--if(fifo_pro_full='1') then
					rd_state <= CLEAR_WASTE;
				--else
					--rd_state <= WAIT_SEND;
				end if;
			WHEN CLEAR_WASTE  => 
				fifo_rd_en <= '1';
				if(remove_counter=1) then
					remove_counter <=0;
					rd_state <= WAIT_SEND;
				else
					remove_counter <= remove_counter+1;
					remove_data    <= fifo_dout;
				end if;
			when WAIT_SEND =>
				fifo_rd_en <= '0';
				if (rd_en_in = '1') then
					rd_state <= SEND_DATA;
				end if;
			when SEND_DATA  =>
				fifo_rd_en <= '1';
				data2Com <= fifo_dout;
				rd_state <= IDLE_READ;
			when others =>
				rd_state <= IDLE_READ;
		end case;
	end if;
    end process;
	-------------------------------------------
	-----------------------------------------------------------
	process(rd_clk,rd_state)
    begin
			 if(rd_clk'event and rd_clk = '1') then	
				 if(rd_state = IDLE_READ) then	
					 wait_counter <= wait_counter + 1; 
				 else
					 wait_counter <= 0;
				 end if;
			 end if;
    end process;


end Behavioral;
