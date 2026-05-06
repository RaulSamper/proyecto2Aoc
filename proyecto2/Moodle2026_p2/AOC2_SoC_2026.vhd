-- TestBench Template 

  LIBRARY ieee;
  USE ieee.std_logic_1164.ALL;
  USE ieee.numeric_std.ALL;

  ENTITY AOC2_SoC is
		Port ( 	
			clk : in  STD_LOGIC;
           	reset : in  STD_LOGIC;
           	Ext_IRQ	: 	in  STD_LOGIC; 
           	INT_ACK	: 	out  STD_LOGIC;  --Signal to acknowledge the interrupt
           	IO_input: in STD_LOGIC_VECTOR (31 downto 0); -- 32 bits de entrada para el MIPS para IO
	   	IO_output : out  STD_LOGIC_VECTOR (31 downto 0)); -- 32 bits de salida para el MIPS para IO
END AOC2_SoC;

  ARCHITECTURE behavior OF AOC2_SoC IS 

  -- Component Declaration
  -- MIPS core designed for teaching purposes for AOC 2 subject
	COMPONENT MIPS_segmentado is
    Port ( 	clk : in  STD_LOGIC;
           	reset : in  STD_LOGIC;
           	-- Interface with the IO/MD subsystem
           	ADDR : OUT std_logic_vector (31 downto 0); --Dir solicitada por el Mips
          	Dout : out std_logic_vector (31 downto 0); -- Datos que envia el Mips al subsistema de I/O y MD
           	Din : in std_logic_vector (31 downto 0);-- Datos que recibe el Mips del subsistema de I/O y MD
	 	WE : OUT std_logic;		-- write enable	del MIPS
	  	RE : OUT std_logic;		-- read enable del MIPS			  
	  	IO_MEM_ready: in std_logic; -- Nos avisa de si el subsistema de IO/MD va a realizar en este ciclo la orden del MIPS
	  	-- Exceptions
	  	IRQ	: 	in  STD_LOGIC; 
	  	Data_abort: in std_logic --indica que el último acceso a memoria ha sido un error
		  	);
	end COMPONENT;
 -- Memory and Input/Output elements	
	component IO_Data_Memory_Subsystem is port (
		  CLK : in std_logic;
		  reset: in std_logic; 		
		  -- READ/Write ports with the MIPS core
		  ADDR : in std_logic_vector (31 downto 0); --Dir solicitada por el Mips
          Din : in std_logic_vector (31 downto 0);--entrada de datos desde el Mips
		  WE : in std_logic;		-- write enable	del MIPS
		  RE : in std_logic;		-- read enable del MIPS			  
		  -- New: fetch_inc signal
		  IO_MEM_ready: out std_logic; -- indica si puede hacer la operación solicitada en el ciclo actual
		  Data_abort: out std_logic; --indica que el último acceso a memoria ha sido un error
		  Dout : out std_logic_vector (31 downto 0); --dato que se envía al Mips
		  -- SoC Input/Output ports
		  Ext_IRQ	: 	in  STD_LOGIC;   --External interrupt signal
		  MIPS_IRQ	: 	out  STD_LOGIC;  -- IRQ signal for the MIPS core. It may combine several IRQ signals from different sources 
		  INT_ACK	: 	out  STD_LOGIC;  --Signal to acknowledge the interrupt
		  IO_input: in std_logic_vector (31 downto 0); --dato que viene de una entrada del sistema
		  IO_output : out  STD_LOGIC_VECTOR (31 downto 0) -- 32 bits de salida para el MIPS para IO
		  ); 
	end component;	
 -- Signal definitions    
	SIGNAL IO_MEM_ready, Data_abort, MIPS_IRQ, MIPS_WE, MIPS_RE:  std_logic;
    SIGNAL MIPS_addr, MIPS_Din, MIPS_Dout  :  std_logic_vector(31 downto 0);
  
  BEGIN

  -- Component Instantiation
   	
	IO_Mem: IO_Data_Memory_Subsystem PORT MAP(	clk => clk, reset => reset, Ext_IRQ => Ext_IRQ, IO_input => IO_input, IO_output => IO_output,
										ADDR => MIPS_ADDR, Din => MIPS_Dout, WE => MIPS_WE, RE => MIPS_RE, IO_MEM_ready => IO_MEM_ready,
										Data_abort => Data_abort, Dout => MIPS_Din, MIPS_IRQ => MIPS_IRQ, INT_ACK=> INT_ACK);
	
	MIPS_core: MIPS_segmentado PORT MAP(	clk => clk, reset => reset, IRQ => MIPS_IRQ, ADDR => MIPS_addr, Din => MIPS_Din, Dout => MIPS_Dout,
									WE => MIPS_WE, RE => MIPS_RE, IO_MEM_ready => IO_MEM_ready, Data_abort => Data_abort);
										
										
           	
  END;
