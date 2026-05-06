----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:12:11 04/04/2014 
-- Design Name: 
-- Module Name:    memoriaRAM - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
-- Memoria RAM de 128 oalabras de 32 bits
entity IO_Data_Memory_Subsystem is port (
	  CLK : in std_logic;
	  reset: in std_logic; 		
	  -- READ/Write ports with the MIPS core
	  ADDR : in std_logic_vector (31 downto 0); --Dir solicitada por el Mips
      Din : in std_logic_vector (31 downto 0);--entrada de datos desde el Mips
	  WE : in std_logic;		-- write enable	del MIPS
	  RE : in std_logic;		-- read enable del MIPS			  
	  IO_Mem_ready: out std_logic; -- indica si puede hacer la operación solicitada en el ciclo actual
	  Data_abort: out std_logic; --indica que el último acceso a memoria ha sido un error
	  Dout : out std_logic_vector (31 downto 0); --dato que se envía al Mips
	  -- SoC Input/Output ports
	  Ext_IRQ	: 	in  STD_LOGIC;   --External interrupt signal
	  INT_ACK	: 	out  STD_LOGIC;  --Signal to acknowledge the interrupt
	  MIPS_IRQ	: 	out  STD_LOGIC;  -- IRQ signal for the MIPS core. It may combine several IRQ signals from different sources 
	  IO_input: in std_logic_vector (31 downto 0); --dato que viene de una entrada del sistema
	  IO_output : out  STD_LOGIC_VECTOR (31 downto 0) -- 32 bits de salida para el MIPS para IO
		  ); 
end IO_Data_Memory_Subsystem;

-- En este proyecto el IO_Data_Memory_Subsystem está compuesto por una MD de 128 palabras con acceso alineado, y dos registros mapeados en memoria, uno de entrada y otro de salida
-- En el P2 esta parte será más complicada
-- Para poder comprobar que el MIPS para cuando el subsistema no está preparado, IO_Mem_ready se fuerza a '0' 3 de cada 4 ciclos. 
-- Por tanto un lw o sw podrán generar 0, 1, 2 o 3 ciclos de parada.
architecture Behavioral of IO_Data_Memory_Subsystem is

-- Memoria de datos con su controlador de bus
component MD_cont_2026 is port (
		  CLK : in std_logic;
		  reset: in std_logic;
		  Bus_Frame: in std_logic; -- indicates that the manager wants more data
		  bus_last_word : in  STD_LOGIC; -- indicates that it is the last data of the transfer.
		  bus_Read: in std_logic;
		  bus_Write: in std_logic;
		  Bus_Addr : in std_logic_vector (31 downto 0); --@
		  Bus_Data : in std_logic_vector (31 downto 0); --Data  
		  MD_Bus_DEVsel: out std_logic; -- to notify that the address has been recognized as belonging to this module
		  MD_Bus_TRDY: out std_logic; -- to signal that the requested operation is to be performed in the current cycle
		  MD_send_data: out std_logic; -- to send the data to the bus
          MD_Dout : out std_logic_vector (31 downto 0)		  -- data output
		  );
end component;
-- MemoriaCache de datos
COMPONENT MC_datos_CB is port (
			CLK : in std_logic;
			reset : in  STD_LOGIC;
			-- MIPS interface
			-- inputs
			ADDR : in std_logic_vector (31 downto 0); --@ 
			Din : in std_logic_vector (31 downto 0);
			RE : in std_logic;		-- read enable		
			WE : in  STD_LOGIC; 
			-- outputs
			ready : out  std_logic;  -- indicates whether we can perform the requested operation in the current cycle
			Dout : out std_logic_vector (31 downto 0); -- dato output
			-- Nueva señal de error
			Mem_ERROR: out std_logic; -- Activated if the slave did not respond to your address during the last transfer.
			-- bus interface
			-- inputs
			MC_Bus_Din : in std_logic_vector (31 downto 0);-- to read bus data
			Bus_TRDY : in  STD_LOGIC; -- indicates that the server (the data memory) can perform the requested operation in this cycle.
			Bus_DevSel: in  STD_LOGIC; -- indicates that the memory has recognized that the address is within its range.
			MC_Bus_Grant: in  STD_LOGIC; -- indicates that the referee allows the MC to use the bus;
			--salidas
			MC_send_addr_ctrl : out  STD_LOGIC; -- send address and control signals to the bus
			MC_send_data : out  STD_LOGIC; -- send data
			MC_frame : out  STD_LOGIC; -- indicates that the operation has not been completed
			MC_Bus_ADDR : out std_logic_vector (31 downto 0); -- @ 
			MC_Bus_data_out : out std_logic_vector (31 downto 0);-- to send data over the bus
			MC_bus_Read : out  STD_LOGIC; -- to request the bus in read access
			MC_bus_Write : out  STD_LOGIC; --  to request the bus in write access
			MC_Bus_Req: out  STD_LOGIC; -- indicates that the MC wants to use the bus;
			MC_last_word : out  STD_LOGIC --indicates that is the last transfer
			 );
  END COMPONENT;
-- Memoria scratch (Memoria rápida que contesta en el ciclo en el que se le pide algo)
-- Sólo tiene acceso palabra a palabra
  COMPONENT MD_scratch is port (
		  CLK : in std_logic;
		  reset: in std_logic;
		  Bus_Frame: in std_logic; -- indicates that the operation has not been completed
		  bus_Read: in std_logic;
		  bus_Write: in std_logic;
		  Bus_Addr : in std_logic_vector (31 downto 0); --@
		  Bus_Data : in std_logic_vector (31 downto 0); --Data  
		  MD_Bus_DEVsel: out std_logic; -- indicates that the memory has recognized that the address is within its range.
		  MD_Bus_TRDY: out std_logic; -- indicates that the server (the data memory) can perform the requested operation in this cycle.
		  MD_send_data: out std_logic; -- send dato to the bus
          MD_Dout : out std_logic_vector (31 downto 0)		  -- Data output
		  );
end COMPONENT;

COMPONENT Arbitro is
    Port ( 	clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			last_word: in  STD_LOGIC; -- When a transfer is completed, it changes priorities
			bus_frame: in  STD_LOGIC;-- to know that a transfer is in progress
			Bus_TRDY: in  STD_LOGIC; -- to know that the last transfer is going to take place this cycle
    		Req0 : in  STD_LOGIC; -- Requests
           	Req1 : in  STD_LOGIC;
           	Grant0 : out std_LOGIC;
           	Grant1 : out std_LOGIC);
end COMPONENT;

COMPONENT IO_Master is
    Port ( 	clk: in  STD_LOGIC; 
		    reset: in  STD_LOGIC; 
			IO_M_bus_Grant: in std_logic; 
			IO_input: in STD_LOGIC_VECTOR (31 downto 0);
			bus_TRDY : in  STD_LOGIC; -- indicates that the server cannot perform the requested operation in this cycle.
			Bus_DevSel: in  STD_LOGIC; --indicates that the server has recognized that the address is within its range.
			IO_M_ERROR: out std_logic; -- Activates if the server does not respond to its address
			IO_M_Req: out std_logic; 
			IO_M_Read: out std_logic; 
			IO_M_Write: out std_logic;
			IO_M_bus_Frame: out std_logic; 
			IO_M_send_Addr: out std_logic;
			IO_M_send_Data: out std_logic;
			IO_M_last_word: out std_logic;
			IO_M_Addr: out STD_LOGIC_VECTOR (31 downto 0);
			IO_M_Data: out STD_LOGIC_VECTOR (31 downto 0)); 
end COMPONENT;

component reg is
    generic (size: natural := 32);  -- by default are 32-bit, but any size can be used.
	Port ( Din : in  STD_LOGIC_VECTOR (size -1 downto 0);
           clk : in  STD_LOGIC;
	   reset : in  STD_LOGIC;
           load : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (size -1 downto 0));
end component;	

component counter is
 	generic (   size : integer := 10);
	Port ( 	clk : in  STD_LOGIC;
       		reset : in  STD_LOGIC;
       		count_enable : in  STD_LOGIC;
       		count : out  STD_LOGIC_VECTOR (size-1 downto 0));
end component;

-- Bus signals
signal Bus_Data_Addr:  std_logic_vector(31 downto 0); 
signal Bus_TRDY, Bus_Devsel, bus_Read, bus_Write, Bus_Frame, Bus_last_word: std_logic;
--MC signals
signal MC_Bus_Din, MC_Bus_ADDR, MC_Bus_data_out, MC_Dout: std_logic_vector (31 downto 0);
signal MC_send_addr_ctrl, MC_send_data, MC_frame, MC_bus_Read, MC_bus_write, MC_last_word, RE_MEM, WE_MEM: std_logic;
-- MD_scratch signals
signal MD_scratch_Dout:  std_logic_vector(31 downto 0); 
signal MD_scratch_Bus_DEVsel, MD_scratch_send_data, MD_scratch_Bus_TRDY: std_logic;
-- MD signals
signal MD_Dout:  std_logic_vector(31 downto 0); 
signal MD_Bus_DEVsel, MD_send_data, MD_Bus_TRDY: std_logic;
-- Signals for arbitration
signal MC_Bus_Grant, MC_Bus_Req: std_logic;
signal IO_M_bus_Grant, IO_M_Req: std_logic;-- señales para simular otros dispositivos que solicitan el bus
--IO Master
signal IO_M_Addr, IO_M_Data:  std_logic_vector(31 downto 0); 
signal IO_M_read, IO_M_write, IO_M_last_word, IO_M_bus_Frame, IO_M_send_Addr, IO_M_send_Data, IO_M_ERROR: std_logic;
-- Monitoring signals
signal IO_M_count: STD_LOGIC_VECTOR (7 downto 0);
-- Error signals
signal Mem_ERROR: std_logic;
-- Signals for Input/output/ack registers
signal load_output, IO_addr, addr_input, addr_output, addr_ack, ack_input :  std_logic;
signal Input_data, Output_data: std_logic_vector (31 downto 0);
signal ack_input_vector, INT_ACK_vector : std_logic_vector (0 downto 0);
-- Internal signals
signal Mem_ready_internal, Data_abort_internal: std_logic;
begin
 
--------------------------------------------------------------------------------------------------
-- Decoder to detect whether the signal belongs to memory or to memory-mapped registers
-- Valid IO addresses: x “00007000” and x “0000700C” There are 4 addressable registers, although only 3 are used.
	IO_addr <= '1' when (ADDR(31 downto 4) = x"0000700") else '0'; 
	addr_input <= '1' when ((IO_addr='1') and (ADDR(3 downto 0)= "0000")) else '0'; --x"00007000"
	addr_output <= '1' when ((IO_addr='1') and (ADDR(3 downto 0)= "0100")) else '0';--x"00007004"
	addr_ack <= '1' when ((IO_addr='1') and (ADDR(3 downto 0)= "1000")) else '0';--x"00007008"

--------------------------------------------------------------------------------------------
--   Data Cache Memory
------------------------------------------------------------------------------------------------
	-- If the address is not an IO register, we ask the memory subsystem for it.
	RE_MEM <= RE and not(IO_addr);
	WE_MEM <= WE and not(IO_addr);	
	
	MC: MC_datos_CB PORT MAP(	clk=> clk, reset => reset, ADDR => ADDR, Din => Din, RE => RE_MEM, WE => WE_MEM, ready => Mem_ready_internal, Dout => MC_Dout, 
							MC_Bus_Din => MC_Bus_Din, Bus_TRDY => Bus_TRDY, Bus_DevSel => Bus_DevSel, MC_send_addr_ctrl => MC_send_addr_ctrl, 
							MC_send_data => MC_send_data, MC_frame => MC_frame, MC_Bus_ADDR => MC_Bus_ADDR, MC_Bus_data_out => MC_Bus_data_out, 
							MC_Bus_Req => MC_Bus_Req, MC_Bus_Grant => MC_Bus_Grant, MC_last_word => MC_last_word,
							Mem_ERROR => Mem_ERROR, MC_bus_Read => MC_bus_Read, MC_bus_Write => MC_bus_Write);

------------------------------------------------------------------------------------------------	
-- Data memory controller
------------------------------------------------------------------------------------------------
	controlador_MD: MD_cont_2026 PORT MAP (
          CLK => CLK,
          reset => reset,
          Bus_Frame => Bus_Frame,
		  bus_last_word => bus_last_word,
          bus_Read => bus_Read,
		  bus_Write => bus_Write,
		  Bus_Addr => Bus_Data_Addr,
	  	  Bus_data => Bus_Data_Addr,
          MD_Bus_DEVsel => MD_Bus_DEVsel,
          MD_Bus_TRDY => MD_Bus_TRDY,
          MD_send_data => MD_send_data,
          MD_Dout => MD_Dout
        );

------------------------------------------------------------------------------------------------	
-- Data Scratch Memory
------------------------------------------------------------------------------------------------
	M_scratch: MD_scratch PORT MAP (
          CLK => CLK,
          reset => reset,
          Bus_Frame => Bus_Frame,
          bus_Read => bus_Read,
		  bus_Write => bus_Write,
          Bus_Addr => Bus_Data_Addr,
	  	  Bus_data => Bus_Data_Addr,
          MD_Bus_DEVsel => MD_scratch_Bus_DEVsel,
          MD_Bus_TRDY => MD_scratch_Bus_TRDY,
          MD_send_data => MD_Scratch_send_data,
          MD_Dout => MD_Scratch_Dout
        );

------------------------------------------------------------------------------------------------	 
	MC_Bus_Din <= Bus_Data_Addr;
------------------------------------------------------------------------------------------------	 
------------------------------------------------------------------------------------------------
--   	BUS: shared lines and tri-state buffers. When nothing is sent there are two options: 1) it remains in high impedance “Z” state, 2) wired OR: when nothing is sent, the default status is “0”
------------------------------------------------------------------------------------------------

	Bus_Data_Addr <= 	MC_Bus_data_out when MC_send_data = '1' 	else 
			 			MD_Dout when MD_send_data = '1' 			else 
						MD_Scratch_Dout when MD_Scratch_send_data = '1' 	else 
						MC_Bus_ADDR when (MC_send_addr_ctrl='1') 	else 
						IO_M_Addr when (IO_M_send_Addr='1') 	else 
						x"00000000" when ((MC_send_data = '0')and (MD_send_data = '0') and (MD_Scratch_send_data = '0') and (IO_M_send_Data = '0') and (MC_send_addr_ctrl='0') and (IO_M_send_Addr='0')) else 
						"ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"; 
	--Control
	--********************************************************************
	bus_Read 	<= 	MC_bus_Read when (MC_send_addr_ctrl='1') else
							IO_M_read when (IO_M_send_Addr = '1') else 
							'0';
	bus_Write  	<= 	MC_bus_Write when (MC_send_addr_ctrl='1') else
							IO_M_write when (IO_M_send_Addr = '1') else 
							'0';
									
	Bus_Frame <= MC_frame or IO_M_bus_Frame; -- The bus is busy if either of the two masters is using it
	
	Bus_last_word <= 	MC_last_word 		when (MC_frame='1') else 
							IO_M_last_word 	when (IO_M_bus_Frame='1') ELSE
							'0';
	
-- Memory signals
	Bus_DevSel <= MD_Bus_DEVsel or MD_scratch_Bus_DEVsel; 
	Bus_TRDY <= MD_Bus_TRDY or MD_scratch_Bus_TRDY; 
	
-- Arbitration
	
	Arbitraje: arbitro port map(clk => clk, reset => reset, Req0 => MC_Bus_Req, Req1 => IO_M_Req, Grant0 => MC_Bus_Grant, Grant1 => IO_M_bus_Grant, 
								Bus_Frame=> Bus_Frame, Bus_TRDY=> Bus_TRDY, last_word => Bus_last_word);
------------------------------------------------------------------------------------------------	
-- This counter tells us how many cycles have been able to use the IO master. 
-- Its purpose is to see if we release the bus as soon as possible or if we hold it back too long.
	
	cont_IO: counter 		generic map (size => 8)
						port map (clk => clk, reset => reset, count_enable => IO_M_bus_Grant, count => IO_M_count);	
------------------------------------------------------------------------------------------------	
-- Modulo_IO: again and again writes whatever is in the input IO_M_input in the last word of the Scratch. This is a way to make an external input visible to the processor.
-- Most commonly it would have an addressable register, and would act as a slave on the bus, rather than as a master. But we have done it this way so that there are two masters competing for the bus.
	Modulo_IO: IO_Master port map(	clk => clk, reset => reset, 
														IO_M_Req => IO_M_Req, 
														IO_M_bus_Grant => IO_M_bus_Grant, 
														IO_M_bus_Frame=> IO_M_bus_Frame, 
														IO_input => io_input,
														IO_M_read => IO_M_read, 
														IO_M_write => IO_M_write,
														IO_M_Addr => IO_M_Addr,
														IO_M_Data => IO_M_Data,
														IO_M_ERROR => IO_M_ERROR,
														bus_trdy => bus_trdy,
														Bus_DevSel => Bus_DevSel,
														IO_M_send_Addr => IO_M_send_Addr,
														IO_M_send_Data => IO_M_send_Data,
														IO_M_last_word => IO_M_last_word);
	

------------------------------------------------------------------------------------------------	
-- Data abort 
 	Data_abort_internal <= Mem_Error; --  If the access generates an error we alert the processor by activating data_abort
--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
-- Input/output registers
-- 
-- Input_Reg: It allows to read the 32 bits of system input. Its associated address is “01000000”
-- Output_Reg: It allows writing to the 32-bit input of the system. Its associated address is “01000004”
--------------------------------------------------------------------------------------------------
	Input_Reg: reg generic map (size => 32)
					port map (	Din => IO_input, clk => clk, reset => reset, load => '1', Dout => Input_data);
	-- The content of the Output_Reg is visible from the outside.		
	load_output <= '1' when (addr_output='1') and (WE = '1') else '0';
	-- 
	Output_Reg: reg generic map (size => 32)
					port map (	Din => Din, clk => clk, reset => reset, load => load_output, Dout => Output_data);
	IO_output <= Output_data	;
	-- ACK_Reg to report that the external INT has been serviced
	-- It has only one bit, and is automatically set to 0 after each write. It does this to make the RTI lighter (so you don't have to set a '1', and then a '0' to prevent the next INT from thinking it has already been serviced).
	-- and also to avoid giving the ACK to two interruptions that are very close together, when only the first one has been processed.
	-- If the @ of the Ack is indicated and the write command is given, bit 0 of the input data will be loaded into the register. Otherwise a 0 will be set.
	ACK_input <= Din(0) and addr_ack and WE; 
	ACK_input_vector <= (0 => ACK_input);-- The register component uses vectors for input and output (in this case 1 bit). This line assigns a signal to bit 0 of the vector. It is a way to go from std_logic to STD_logic_vector.
	ACK_Reg: reg 	generic map (size => 1)
					port map (	Din => ACK_input_vector, clk => clk, reset => reset, load => '1', Dout => INT_ACK_vector);
	INT_ACK <= INT_ACK_vector(0);

--------------------------------------------------------------------------------------------------
----------- Outputs for Mips
-------------------------------------------------------------------------------------------------- 
Dout <= Input_data 	when ((addr_input = '1') and (RE='1')) else -- It is used to send the data of the input record
		Output_data when ((addr_output = '1') and (RE='1')) else -- It is used to send the data from the output register
		x"000BAD00" when Mem_ready_internal = '0' else -- Value for debugging, if it appears in your registers you are reading data when the memory is not ready.
		MC_Dout	 	when Mem_ready_internal = '1' else -- the memory internally checks that RE is '1'.
		x"00000000"; -- default

--Interrupts: There may be many interrupt sources. But currently we only have the external one

MIPS_IRQ <= Ext_IRQ;
	
-- Assignment of internal outputs

IO_Mem_ready   <= Mem_ready_internal;
Data_abort <= Data_abort_internal;
end Behavioral;

