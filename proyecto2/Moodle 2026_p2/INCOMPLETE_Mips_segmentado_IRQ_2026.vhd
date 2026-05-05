----------------------------------------------------------------------------------
-- Description: Segmented Mips as we have studied it in class with:
-- Anticipation unit (incomplete)
-- Stopping unit (incomplete)
-- ID jumps
-- Arithmetic instructions, LW, SW, NOP, and BEQ
-- 32-bit 128-word MI and MD
-- Exception handling: IRQ, ABORT and UNDEF (incomplete) -- IRQ line, ABORT and UNDEF (incomplete)
-- IRQ line
-- New instructions: RTE, JAL and RET (incomplete).
-- Incomplete functionality in this file and in ALU.vhd, UC.vhd, UD.vhd and UA.vhd. Search for tag: COMPLETE
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MIPs_segmentado is
    Port ( 	clk : in  STD_LOGIC;
         reset : in  STD_LOGIC;
         -- Interface with the IO/MD subsystem
         ADDR : OUT std_logic_vector (31 downto 0); --IO/MD Address
         Dout : out std_logic_vector (31 downto 0); -- Data to IO/MD
         Din : in std_logic_vector (31 downto 0);-- Data from IO/MD
		 	WE : OUT std_logic;		-- write enable	for IO/MD
		  	RE : OUT std_logic;		-- read enable for IO/MD
		  	IO_MEM_ready: in std_logic; -- Notifies if the IO/MD subsystem is going to carry out the MIPS command in this cycle.
		  	-- Exceptions
		  	IRQ	: 	in  STD_LOGIC; 
		  	Data_abort: in std_logic --indicates that the last memory access generated an error.
		  	);
end MIPs_segmentado;

architecture Behavioral of MIPs_segmentado is

component reg is
    generic (size: natural := 32);  -- 32 is the default value
	Port ( Din : in  STD_LOGIC_VECTOR (size -1 downto 0);
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
           load : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (size -1 downto 0));
end component;
---------------------------------------------------------------

component adder32 is
    Port ( Din0 : in  STD_LOGIC_VECTOR (31 downto 0);
           Din1 : in  STD_LOGIC_VECTOR (31 downto 0);
           Dout : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component mux4_1 is
  Port (   DIn0 : in  STD_LOGIC_VECTOR (31 downto 0);
           DIn1 : in  STD_LOGIC_VECTOR (31 downto 0);
           DIn2 : in  STD_LOGIC_VECTOR (31 downto 0);
           DIn3 : in  STD_LOGIC_VECTOR (31 downto 0);
		   ctrl : in  STD_LOGIC_VECTOR (1 downto 0);
           Dout : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component mux2_1 is
  Port (   DIn0 : in  STD_LOGIC_VECTOR (31 downto 0);
           DIn1 : in  STD_LOGIC_VECTOR (31 downto 0);
		   ctrl : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component memoriaRAM_I is port (
		  CLK : in std_logic;
		  ADDR : in std_logic_vector (31 downto 0); --@
          Din : in std_logic_vector (31 downto 0);--Data input
          WE : in std_logic;		-- write enable	
		  RE : in std_logic;		-- read enable		  
		  Dout : out std_logic_vector (31 downto 0));
end component;

component Banco_ID is
 Port ( IR_in : in  STD_LOGIC_VECTOR (31 downto 0); -- Instruction read in IF
        PC4_in:  in  STD_LOGIC_VECTOR (31 downto 0); -- PC+4 added in IF
		clk : in  STD_LOGIC;
		reset : in  STD_LOGIC;
        load : in  STD_LOGIC;
        IR_ID : out  STD_LOGIC_VECTOR (31 downto 0); -- ID instruction
        PC4_ID:  out  STD_LOGIC_VECTOR (31 downto 0);
        --NEW for excepcions
        PC_exception:  in  STD_LOGIC_VECTOR (31 downto 0); -- For exception return
        PC_exception_ID:  out  STD_LOGIC_VECTOR (31 downto 0);
        --valid bits
        valid_I_IF: in STD_LOGIC;
        valid_I_ID: out STD_LOGIC ); 
end component;

COMPONENT BReg
    PORT(
         clk : IN  std_logic;
		 reset : in  STD_LOGIC;
         RA : IN  std_logic_vector(4 downto 0);
         RB : IN  std_logic_vector(4 downto 0);
         RW : IN  std_logic_vector(4 downto 0);
         BusW : IN  std_logic_vector(31 downto 0);
         RegWrite : IN  std_logic;
         BusA : OUT  std_logic_vector(31 downto 0);
         BusB : OUT  std_logic_vector(31 downto 0)
        );
END COMPONENT;

component Ext_signo is
    Port ( inm : in  STD_LOGIC_VECTOR (15 downto 0);
           inm_ext : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component two_bits_shifter is
    Port ( Din : in  STD_LOGIC_VECTOR (31 downto 0);
           Dout : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component UC is
Port ( 		valid_I_ID : in  STD_LOGIC; --valid bit
			IR_op_code : in  STD_LOGIC_VECTOR (5 downto 0);
         	Branch : out  STD_LOGIC;
           	RegDst : out  STD_LOGIC;
           	ALUSrc : out  STD_LOGIC;
		   	MemWrite : out  STD_LOGIC;
           	MemRead : out  STD_LOGIC;
           	MemtoReg : out  STD_LOGIC;
           	RegWrite : out  STD_LOGIC;
          	jal : out  STD_LOGIC; --jal instruction 
        	ret : out  STD_LOGIC; --ret instruction
			undef: out STD_LOGIC; --indicates that the operation code does not belong to a known instruction. In this processor, it is used only for debugging.
           	 -- New signals
		   	RTE	: out  STD_LOGIC -- RTE instruction 
			  -- END New signals
           );
end component;
-- NEW
-- HAZARD UNIT
component UD is
Port (   	valid_I_ID : in  STD_LOGIC; --valid bit for ID
			valid_I_EX : in  STD_LOGIC; --valid bit for EX
			valid_I_MEM : in  STD_LOGIC; --valid bit for MEM
			Reg_Rs_ID: in  STD_LOGIC_VECTOR (4 downto 0); --Rs and Rt records in the ID stage
		  	Reg_Rt_ID	: in  STD_LOGIC_VECTOR (4 downto 0);
			MemRead_EX	: in std_logic; -- information about the instruction in EX (destination, if it reads from memory and if it writes in the register bank)
			RegWrite_EX	: in std_logic;
			RW_EX			: in  STD_LOGIC_VECTOR (4 downto 0);
			RegWrite_Mem	: in std_logic;-- information about the instruction in Mem (destination and if it writes in the register bank)
			RW_Mem			: in  STD_LOGIC_VECTOR (4 downto 0);
			IR_op_code	: in  STD_LOGIC_VECTOR (5 downto 0); -- operation code of the instruction in ID
         	salto_tomado			: in std_logic; -- 1 if there is a jump 0 otherwise
         	--Nuevo
         	ALU_ready : in std_logic; -- Indicates that the ALU can performs its operation in the current cycle,
         	JAL_EX : in std_logic; -- Indicates that the instruction in EX is a JAL
         	JAL_MEM : in std_logic; -- Indicates that the instruction in MEM is a JAL
         	IO_MEM_ready: in std_logic; -- Notifies if the IO/MD subsystem is going to carry out the MIPS command in this cycle.
			stall_MIPS: out  STD_LOGIC; -- Indicates that all stages must stop
			Kill_IF		: out  STD_LOGIC; -- Indicates that the IF instruction should not be executed (prediction miss)
			stall_ID		: out  STD_LOGIC); -- Indicates that the ID and pre-stages must stop
end component;

COMPONENT Banco_EX
    PORT(
         	 clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			load : in  STD_LOGIC;
	        busA : in  STD_LOGIC_VECTOR (31 downto 0);
           	busB : in  STD_LOGIC_VECTOR (31 downto 0);
			busA_EX : out  STD_LOGIC_VECTOR (31 downto 0);
           	busB_EX : out  STD_LOGIC_VECTOR (31 downto 0);
           	RegDst_ID : in  STD_LOGIC;
           	ALUSrc_ID : in  STD_LOGIC;
           	MemWrite_ID : in  STD_LOGIC;
           	MemRead_ID : in  STD_LOGIC;
           	MemtoReg_ID : in  STD_LOGIC;
           	RegWrite_ID : in  STD_LOGIC;
			inm_ext: IN  std_logic_vector(31 downto 0);
			inm_ext_EX: OUT  std_logic_vector(31 downto 0);
           	RegDst_EX : out  STD_LOGIC;
           	ALUSrc_EX : out  STD_LOGIC;
           	MemWrite_EX : out  STD_LOGIC;
           	MemRead_EX : out  STD_LOGIC;
           	MemtoReg_EX : out  STD_LOGIC;
           	RegWrite_EX : out  STD_LOGIC;
			-- New: for the porwarding unit (UA)
			Reg_Rs_ID : in  std_logic_vector(4 downto 0);
			Reg_Rs_EX : out std_logic_vector(4 downto 0);
			--END new
			ALUctrl_ID: in STD_LOGIC_VECTOR (2 downto 0);
			ALUctrl_EX: out STD_LOGIC_VECTOR (2 downto 0);
           	Reg_Rt_ID : in  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rd_ID : in  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rt_EX : out  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rd_EX : out  STD_LOGIC_VECTOR (4 downto 0);
            -- New exceptions
           	PC_exception_ID:  in  STD_LOGIC_VECTOR (31 downto 0);
           	PC_exception_EX:  out  STD_LOGIC_VECTOR (31 downto 0);
           	-- New to return from exception
           	RTE_ID :  in STD_LOGIC; 
           	RTE_EX :  out STD_LOGIC; 
           	--valid bits
        	valid_I_EX_in: in STD_LOGIC;
        	valid_I_EX: out STD_LOGIC;
        	-- Extension ports
			-- These ports are used to add functionality to the MIPS that requires sending information from one stage to the following stages.
			-- The bank allows sending two one-bit signals (ext_signal_1 and 2) and two 32-bit words ext_word_1 and 2).
			ext_signal_1_ID: in  STD_LOGIC;
			ext_signal_1_EX: out  STD_LOGIC;
			ext_signal_2_ID: in  STD_LOGIC;
			ext_signal_2_EX: out  STD_LOGIC;
			ext_word_1_ID:  IN  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_1_EX:  OUT  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_2_ID:  IN  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_2_EX:  OUT  STD_LOGIC_VECTOR (31 downto 0)
			-- END extension ports
			);
    END COMPONENT;
-- NEW        
-- FORWARDING unit (anticipación)
    COMPONENT UA
	Port(
			valid_I_MEM : in  STD_LOGIC; --valid bits
			valid_I_WB : in  STD_LOGIC; 
			Reg_Rs_EX: IN  std_logic_vector(4 downto 0); 
			Reg_Rt_EX: IN  std_logic_vector(4 downto 0);
			RegWrite_MEM: IN std_logic;
			RW_MEM: IN  std_logic_vector(4 downto 0);
			RegWrite_WB: IN std_logic;
			RW_WB: IN  std_logic_vector(4 downto 0);
			MUX_ctrl_A: out std_logic_vector(1 downto 0);
			MUX_ctrl_B: out std_logic_vector(1 downto 0)
		);
	end component;

	
	COMPONENT ALU_Vector_MAC is
    Port ( DA : in  STD_LOGIC_VECTOR (31 downto 0); --input 1
           DB : in  STD_LOGIC_VECTOR (31 downto 0); --input 2
           valid_I_EX : in  STD_LOGIC;
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
		   ready : out STD_LOGIC; --initially is always '1', but if ALU supports multicycle ops, it will be cero when the output is not ready
           mips_status : in STD_LOGIC_VECTOR (1 downto 0); 
           rte_ex : in STD_LOGIC;                          
		   ALUctrl : in  STD_LOGIC_VECTOR (2 downto 0); -- Ops: "000" add, "001" sub, "010" AND, "011" OR, "100" MAC with internal acc, "101" MAC without previous acc.
           Dout : out  STD_LOGIC_VECTOR (31 downto 0)); -- Output
    END COMPONENT;
	 
	component mux2_5bits is
	Port ( DIn0 : in  STD_LOGIC_VECTOR (4 downto 0);
		   DIn1 : in  STD_LOGIC_VECTOR (4 downto 0);
		   ctrl : in  STD_LOGIC;
		   Dout : out  STD_LOGIC_VECTOR (4 downto 0));
	end component;
	
COMPONENT Banco_MEM
    PORT(
       		ALU_out_EX : in  STD_LOGIC_VECTOR (31 downto 0); 
			ALU_out_MEM : out  STD_LOGIC_VECTOR (31 downto 0); 
         	clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
    		load : in  STD_LOGIC;
			MemWrite_EX : in  STD_LOGIC;
    	    MemRead_EX : in  STD_LOGIC;
        	MemtoReg_EX : in  STD_LOGIC;
         	RegWrite_EX : in  STD_LOGIC;
			MemWrite_MEM : out  STD_LOGIC;
        	MemRead_MEM : out  STD_LOGIC;
         	MemtoReg_MEM : out  STD_LOGIC;
         	RegWrite_MEM : out  STD_LOGIC;
         	BusB_EX: in  STD_LOGIC_VECTOR (31 downto 0); -- FOR SW instruction
			BusB_MEM: out  STD_LOGIC_VECTOR (31 downto 0); 
			RW_EX : in  STD_LOGIC_VECTOR (4 downto 0); 
         	RW_MEM : out  STD_LOGIC_VECTOR (4 downto 0);
        	--valid bits
        	valid_I_EX: in STD_LOGIC;
        	valid_I_MEM: out STD_LOGIC;
        	-- Extension ports
			-- These ports are used to add functionality to the MIPS that requires sending information from one stage to the following stages.
			-- The bank allows sending two one-bit signals (ext_signal_1 and 2) and two 32-bit words ext_word_1 and 2).
			ext_signal_1_EX: in  STD_LOGIC;
			ext_signal_1_MEM: out  STD_LOGIC;
			ext_signal_2_EX: in  STD_LOGIC;
			ext_signal_2_MEM: out  STD_LOGIC;
			ext_word_1_EX:  IN  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_1_MEM:  OUT  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_2_EX:  IN  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_2_MEM:  OUT  STD_LOGIC_VECTOR (31 downto 0)
			-- END extension ports
	);
END COMPONENT;
 
    COMPONENT Banco_WB
    PORT(
        ALU_out_MEM : in  STD_LOGIC_VECTOR (31 downto 0); 
		ALU_out_WB : out  STD_LOGIC_VECTOR (31 downto 0); 
		MEM_out : in  STD_LOGIC_VECTOR (31 downto 0); 
		MDR : out  STD_LOGIC_VECTOR (31 downto 0); --memory data register
        clk : in  STD_LOGIC;
		reset : in  STD_LOGIC;
        load : in  STD_LOGIC;
		MemtoReg_MEM : in  STD_LOGIC;
        RegWrite_MEM : in  STD_LOGIC;
		MemtoReg_WB : out  STD_LOGIC;
        RegWrite_WB : out  STD_LOGIC;
        RW_MEM : in  STD_LOGIC_VECTOR (4 downto 0); 
        RW_WB : out  STD_LOGIC_VECTOR (4 downto 0); 
        --valid bits
        valid_I_WB_in: in STD_LOGIC;
        valid_I_WB: out STD_LOGIC;
        -- Extension ports
		-- These ports are used to add functionality to the MIPS that requires sending information from one stage to the following stages.
		-- The bank allows sending two one-bit signals (ext_signal_1 and 2) and two 32-bit words ext_word_1 and 2).
		ext_signal_1_MEM: in  STD_LOGIC;
		ext_signal_1_WB: out  STD_LOGIC;
		ext_signal_2_MEM: in  STD_LOGIC;
		ext_signal_2_WB: out  STD_LOGIC;
		ext_word_1_MEM:  IN  STD_LOGIC_VECTOR (31 downto 0);
		ext_word_1_WB:  OUT  STD_LOGIC_VECTOR (31 downto 0);
		ext_word_2_MEM:  IN  STD_LOGIC_VECTOR (31 downto 0);
		ext_word_2_WB:  OUT  STD_LOGIC_VECTOR (31 downto 0)
		-- END extension ports
		);
    END COMPONENT; 
    
    COMPONENT counter 
 	generic (
   			size : integer := 10);
	Port ( 	clk : in  STD_LOGIC;
       		reset : in  STD_LOGIC;
       		count_enable : in  STD_LOGIC;
       		count : out  STD_LOGIC_VECTOR (size-1 downto 0));
	end COMPONENT;
	
	COMPONENT Exception_manager is
    Port ( 	clk : in  STD_LOGIC;
           	reset : in  STD_LOGIC;
           	IRQ	: 	in  STD_LOGIC; 
           	Data_abort: in std_logic; --indicates that the last memory access was an error.
           	undef: in STD_LOGIC; --indicates that the operation code does not belong to a known instruction. In this processor, it is used only for debugging.
           	RTE_ID: in STD_LOGIC; -- indicates that in ID there is a valid Exception return instruction
           	RTE_EX: in STD_LOGIC; -- indicates that in EX there is a valid Exception return instruction
           	valid_I_ID: in STD_LOGIC; -- valid bits
           	valid_I_EX: in STD_LOGIC; 
           	valid_I_MEM: in STD_LOGIC;
           	stall_MIPS: in STD_LOGIC; -- indicates that all stages of the mips must be stopped.
           	PC_out: std_logic_vector(31 downto 0);-- current pc
           	PC_exception_EX: std_logic_vector(31 downto 0); --PC of the Ins in EX
           	PC_exception_ID: std_logic_vector(31 downto 0); --PC of the Ins in ID
           	Exception_accepted: out STD_LOGIC; -- Reports that an exception will be made in the current cycle.
           	Exception_LR_output: out std_logic_vector(31 downto 0)
           	);         	
	end COMPONENT;
--------------------------------------------------------------------------	
-- Internal signals MIPS	
	CONSTANT ARIT : STD_LOGIC_VECTOR (5 downto 0) := "000001";
	signal load_PC, RegWrite_ID, RegWrite_EX, RegWrite_MEM, RegWrite_WB, RegWrite, Z, Branch_ID, RegDst_ID, RegDst_EX, ALUSrc_ID, ALUSrc_EX: std_logic;
	signal MemtoReg_ID, MemtoReg_EX, MemtoReg_MEM, MemtoReg_WB, MemWrite_ID, MemWrite_EX, MemWrite_MEM, MemRead_ID, MemRead_EX, MemRead_MEM: std_logic;
	signal PC_in, PC_out, four, PC4, Dirsalto_ID, IR_in, IR_ID, PC4_ID, inm_ext_EX, ALU_Src_out : std_logic_vector(31 downto 0);
	signal BusW, BusA, BusB, BusA_EX, BusB_EX, BusB_MEM, inm_ext, inm_ext_x4, ALU_out_EX, ALU_out_MEM, ALU_out_WB, Mem_out, MDR : std_logic_vector(31 downto 0);
	signal RW_EX, RW_MEM, RW_WB, Reg_Rs_ID, Reg_Rs_EX, Reg_Rt_ID, Reg_Rd_EX, Reg_Rt_EX: std_logic_vector(4 downto 0);
	signal ALUctrl_ID, ALUctrl_EX : std_logic_vector(2 downto 0);
	signal ALU_INT_out, Mux_A_out, Mux_B_out: std_logic_vector(31 downto 0);
	signal IR_op_code: std_logic_vector(5 downto 0);
	signal MUX_ctrl_A, MUX_ctrl_B : std_logic_vector(1 downto 0);
	signal salto_tomado: std_logic;
-- NEW SIGNALS
	signal stall_ID, stall_MIPS, RegWrite_EX_mux_out, Kill_IF, reset_ID, load_ID, load_EX, load_Mem, load_WB : std_logic;
	signal Write_output, write_output_UC : std_logic;
	signal ALU_ready : std_logic;
-- SIGNALS for Exceptions--
	signal MIPS_status, status_input: std_logic_vector(1 downto 0);
	signal PC_exception_EX, PC_exception_ID, Exception_LR_output: std_logic_vector(31 downto 0);
	signal Exception_accepted, RTE_ID, RTE_EX, reset_EX, reset_MEM: std_logic;													
	signal Undef: std_logic;
-- Valid Bits
	signal valid_I_IF, valid_I_ID,  valid_I_EX, valid_I_EX_in, valid_I_MEM, valid_I_MEM_in, valid_I_WB: std_logic;
-- Counters
	signal cycles: std_logic_vector(15 downto 0);
	signal Ins, data_stalls, control_stalls, Mem_stalls, EX_stalls, Exceptions, Exception_cycles: std_logic_vector(7 downto 0);
	signal inc_cycles, inc_I, inc_data_stalls, inc_EX_stalls, inc_control_stalls, inc_Mem_stalls, inc_Exceptions, inc_Exception_cycles : std_logic;
-- 4 to 1 muxes control signals we have added for writing in BR for jal	
	signal ctrl_Mux4a1_escritura_BR: std_logic_vector (1 downto 0);
-- COMPLETE:
	--New signals to transmit information for jal instruction and ret
	--if you need to propagate the signals to other stages, define the necessary signals. Example: jal_EX, jal_MEM...
	signal PC4_EX, PC4_MEM, PC4_WB : std_logic_vector(31 downto 0);
	signal jal_ID, ret_ID, jal_EX, jal_MEM, jal_WB : std_logic; 
	

begin

	-- ****************************************************************************************************
	------------------------------------------FETCH STAGE-------------------------------------------------------------------
	pc: reg generic map (size => 32)
			port map (	Din => PC_in, clk => clk, reset => reset, load => load_PC, Dout => PC_out);
	
	------------------------------------------------------------------------------------
	-- COMPLETE:
	-- load_pc is set to 1 because in the current version the processor never stops.
	-- If we want to stop an instruction in the fetch stage, we have to set it to 0 -- If we stop the MIPS or the ID stage, we also have to stop in IF.
	-- If we stop the MIPS or the ID stage, we also have to stop in IF. 
	-- Interaction with exceptions:
	-- If the whole processor is stopped we do not process the exception.
	-- If we are stopped in ID, we do process it (we don't care about the instruction in ID, we will kill it).
	load_pc <= '0' when (stall_ID = '1' or stall_MIPS = '1') else '1';
	
	-- END COMPLETE;
	------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------
	 -- la x en x"00000004" indica que está en hexadecimal
	adder_4: adder32 port map (Din0 => PC_out, Din1 => x"00000004", Dout => PC4);
	------------------------------------------------------------------------------------
	-- COMPLETE: NEW MUX FOR PC
	-- Instead of using a mux component we are going to use a when else sentence which describes its funcionality. This allows us to change the size of the mux easily without having to modify the component.		
	-- Complete: eliminate the "--" to include the supported Exceptions, and complete the code with the correct conditions. See example for data abort.
	-- This code is the input mux to the PC: it choose between PC+4, the jump address generated in ID, the address of the exception handling routine, or the return address of the exception.
	-- The order assigns priority if two or more conditions are fulfilled.	
	
	PC_in <= 	x"00000008" 		when (Exception_accepted = '1') and (Data_abort = '1') else -- If a data abort arrives we jump to address 0x00000008.
				x"0000000C" 		when (Exception_accepted = '1') and (UNDEF = '1') else -- If an UNDEF arrives, we jump to address 0x0000000C.
				x"00000100" 		when (Exception_accepted = '1') and (IRQ = '1') else -- If an IRQ arrives, jump to address 0x00000004
					--x"00000004" 		when (Exception_accepted = '1') and (IRQ = '1') else -- If an IRQ arrives, jump to address 0x00000004
				Exception_LR_output when RTE_ID = '1' else 	--@ retorno. If it is an RTE we revert to the @ we had stored in the Exception_LR			
				-- Entrada para el RET, poned lo que toque: 				when RET_ID = '1' else 	--The address stored in the Rs register outgoing from port A of the BR is chosen.
				busA                when RET_ID = '1' else  -- RET: El próximo PC es la dirección guardada en el registro Rs (busA).
				Dirsalto_ID 		when salto_tomado = '1' else --@ Jump of the BEQ and JAL. The RTE and RET may also activate the "salto_tomado" signal, but  but due to the order of the sentence, RET or RTE will be chosen first			PC4; -- PC+4
				PC4; -- PC+4
								
	------------------------------------------------------------------------------------
	-- Memoria de instrucciones. Tiene el puerto de escritura inhabilitado (WE='0')
	Mem_I: memoriaRAM_I PORT MAP (CLK => CLK, ADDR => PC_out, Din => x"00000000", WE => '0', RE => '1', Dout => IR_in);
	------------------------------------------------------------------------------------
	-- NEW
	-- ID bank reset: we reset the bank if there is an accepted exception, because in that case the instructions in IF, ID and EX are killed. 
	reset_ID <= (reset or Exception_accepted);
	
	--------------------------------------------------------------
	-- NEW: In this processor sometimes we have to invalidate an instruction
	-- invalidation of the instruction. If in ID it is detected that the IF instruction should not be executed, the valid_I_IF signal is deactivated.
	valid_I_IF <= not(kill_IF);
	-----------------------------------------------------------------
	-- NEW: In the labs it does not stop
	-- COMPLETE:
	--			stall_ID stops the execution of the ID stage, but it should also stop the previous stage. YOU HAVE TO INCLUDE THE CODE THAT DO THAT
	-- 			It should also stop when stall_MIPS is active
	load_ID <= '0' when (stall_ID = '1' or stall_MIPS = '1') else '1';

	Banco_IF_ID: Banco_ID port map (	IR_in => IR_in, PC4_in => PC4, clk => clk, reset => reset_ID, load => load_ID, IR_ID => IR_ID, PC4_ID => PC4_ID, 
										--Nuevo
										valid_I_IF => valid_I_IF, valid_I_ID => valid_I_ID,  
										PC_exception => PC_out, PC_exception_ID => PC_exception_ID); 
	--
	------------------------------------------ID STAGE-------------------------------------------------------------------
	Reg_Rs_ID <= IR_ID(25 downto 21);
	Reg_Rt_ID <= IR_ID(20 downto 16);
	--------------------------------------------------
	-- REGISTER BANK
	
	-- only valid instructions write
	RegWrite <= RegWrite_WB and valid_I_WB;
	
	INT_Register_bank: BReg PORT MAP (clk => clk, reset => reset, RA => Reg_Rs_ID, RB => Reg_Rt_ID, RW => RW_WB, BusW => BusW, RegWrite => RegWrite, BusA => BusA, BusB => BusB);
	
	-------------------------------------------------------------------------------------
	sign_ext: Ext_signo port map (inm => IR_ID(15 downto 0), inm_ext => inm_ext);
	
	two_bits_shift: two_bits_shifter	port map (Din => inm_ext, Dout => inm_ext_x4);
	
	adder_dir: adder32 port map (Din0 => inm_ext_x4, Din1 => PC4_ID, Dout => Dirsalto_ID);
	
	Z <= '1' when (busA=busB) else '0';
	
	-------------------------------------------------------------------------------------
	IR_op_code <= IR_ID(31 downto 26);
	
	-- If the Instruction in ID is invalid, UNDEF is activated.
	UC_seg: UC port map (valid_I_ID => valid_I_ID, IR_op_code => IR_op_code, Branch => Branch_ID, RegDst => RegDst_ID,  ALUSrc => ALUSrc_ID, MemWrite => MemWrite_ID,  
								MemRead => MemRead_ID, MemtoReg => MemtoReg_ID, RegWrite => RegWrite_ID, 
								-- signals for JAL and RET
								jal => jal_ID, ret => ret_ID,
								--New signals
								-- RTE
								RTE => RTE_ID,
								--end new
								undef => undef);
	
	
	------------------------------------------------------------------------------------							
	-- Salto tomado must be triggered whenever the instruction in D produces a jump in execution.
	-- This includes jumps taken in the BEQs (Z AND Branch_ID), jal, ret and RTE.
	-- IMPORTANT: if the instruction is not valid, it is not jumped.
	salto_tomado <= ((Z AND Branch_ID) or RTE_ID or jal_ID or ret_ID);
								
	------------------------Hazard Unit/Unidad de detención-----------------------------------
	-- NEW
	-- You must complete the unit so that it generates the following signals correctly:
	-- Kill_IF: kills the instruction being read in the IF stage (so that it is not executed).
	-- stall_ID: stops the execution of the ID and IF stages when there is a hazard (riesgo)
	-- IMPORTANT: to detect a hazard, first check that the instructions involved are valid; invalid instructions do not generate risks because they are not instructions to be executed.
	-- IMPORTANT: to detect a producer-consumer relationship, you must check that there is both a producer and a consumer. 
	-- Not all instructions produce/write data to the BR, nor do they all consume/read both operands (rs and rt).
	-- NEW: stall_MIPS: used to stall the whole processor when the memory cannot perform the requested operation in the current cycle (i.e. when IO_MEM_ready	
	-------------------------------------------------------------------------------------
	
	Unidad_detencion_riesgos: UD port map (	valid_I_ID => valid_I_ID, valid_I_EX => valid_I_EX, valid_I_MEM => valid_I_MEM, Reg_Rs_ID => Reg_Rs_ID, Reg_Rt_ID => Reg_Rt_ID, MemRead_EX => MemRead_EX, RW_EX => RW_EX, RegWrite_EX => RegWrite_EX,
											RW_Mem => RW_Mem, RegWrite_Mem => RegWrite_Mem, IR_op_code => IR_op_code, salto_tomado => salto_tomado,  ALU_ready => ALU_ready,
											kill_IF => kill_IF, stall_ID => stall_ID,
											JAL_EX => JAL_EX, JAL_MEM => JAL_MEM,
											IO_MEM_ready => IO_MEM_ready, stall_MIPS => stall_MIPS);
								
	-- NEW
	-- If we are stopped at ID, the instruction sent to the EX stage is set as invalid.
	-- The EX instruction will be valid the next cycle, if the ID instruction is valid and there is no stop.
	valid_I_EX_in	<=  valid_I_ID and not( stall_ID);				
				
	-------------------------------------------------------------------------------------
	-- if the operation is arithmetic (i.e.: IR_op_code= 000001) we use at the funct field
	-- since currently there are only 4 operations in the alu, the least significant bits of the func field of the instruction are sufficient	
	-- if it is not arithmetic we give it the value of the sum (000)
	ALUctrl_ID <= IR_ID(2 downto 0) when IR_op_code= ARIT else "000"; 
	
	-- NEW
	-- Reset of EX bank: reset the bank if there is an accepted exception, because in that case the instructions in IF, ID and EX are killed.
	reset_EX <= (reset or Exception_accepted);
	-- ID/EX Bank 
	-- COMPLETE: If parar_MIPS is enabled, stop execution, and keep each instruction at its current stage.
	load_EX <= '0' when stall_MIPS = '1' else '1';
	Banco_ID_EX: Banco_EX PORT MAP ( 	clk => clk, reset => reset_EX, load => load_EX, busA => busA, busB => busB, busA_EX => busA_EX, busB_EX => busB_EX,
						RegDst_ID => RegDst_ID, ALUSrc_ID => ALUSrc_ID, MemWrite_ID => MemWrite_ID, MemRead_ID => MemRead_ID,
						MemtoReg_ID => MemtoReg_ID, RegWrite_ID => RegWrite_ID, RegDst_EX => RegDst_EX, ALUSrc_EX => ALUSrc_EX,
						MemWrite_EX => MemWrite_EX, MemRead_EX => MemRead_EX, MemtoReg_EX => MemtoReg_EX, RegWrite_EX => RegWrite_EX,
						-- New: dato for forwarding
						Reg_Rs_ID => Reg_Rs_ID,
						Reg_Rs_EX => Reg_Rs_EX,
						-- New: to send the PC to MEM stage
						PC_exception_ID => PC_exception_ID, PC_exception_EX => PC_exception_EX, 
						-- NEW: for RTE
           				RTE_ID =>  RTE_ID, RTE_EX => RTE_EX,
						--END NEW
						ALUctrl_ID => ALUctrl_ID, ALUctrl_EX => ALUctrl_EX, inm_ext => inm_ext, inm_ext_EX=> inm_ext_EX,
						Reg_Rt_ID => IR_ID(20 downto 16), Reg_Rd_ID => IR_ID(15 downto 11), Reg_Rt_EX => Reg_Rt_EX, Reg_Rd_EX => Reg_Rd_EX, 
						valid_I_EX_in => valid_I_EX_in, valid_I_EX => valid_I_EX,
						-- Extension ports. Initially they are disconnected
						ext_word_1_ID => PC4_ID, ext_word_2_ID => x"00000000", ext_signal_1_ID => JAL_ID, ext_signal_2_ID => '0',
						ext_word_1_EX => PC4_EX, ext_word_2_EX => open, ext_signal_1_EX => JAL_EX, ext_signal_2_EX => open
						);  		
	
	------------------------------------------EX STAGE-------------------------------------------------------------------
	---------------------------------------------------------------------------------
	-- NEW
	-- COMPLETE: Incomplete integer forwarding unit (Unidad de anticipación). You must design it taking into account which registers each instruction reads and writes.
	-- Inputs: Reg_Rs_EX, Reg_Rt_EX, RegWrite_MEM, RW_MEM, RegWrite_WB, RW_WB
	-- Outputs: MUX_ctrl_A, MUX_ctrl_B
	Unidad_Ant_INT: UA port map (	valid_I_MEM => valid_I_MEM, valid_I_WB => valid_I_WB, Reg_Rs_EX => Reg_Rs_EX, Reg_Rt_EX => Reg_Rt_EX, RegWrite_MEM => RegWrite_MEM,
									RW_MEM => RW_MEM, RegWrite_WB => RegWrite_WB, RW_WB => RW_WB, MUX_ctrl_A => MUX_ctrl_A, MUX_ctrl_B => MUX_ctrl_B);
	-- forwarding Muxes
	Mux_A: mux4_1 port map  ( DIn0 => BusA_EX, DIn1 => ALU_out_MEM, DIn2 => busW, DIn3 => x"00000000", ctrl => MUX_ctrl_A, Dout => Mux_A_out);
	Mux_B: mux4_1 port map  ( DIn0 => BusB_EX, DIn1 => ALU_out_MEM, DIn2 => busW, DIn3 => x"00000000", ctrl => MUX_ctrl_B, Dout => Mux_B_out);
	
	----------------------------------------------------------------------------------
	
	
	muxALU_src: mux2_1 port map (Din0 => Mux_B_out, DIn1 => inm_ext_EX, ctrl => ALUSrc_EX, Dout => ALU_Src_out);
	
	--reset is currentlly unused in the ALU, but it will be needed if it becomes multicycle
	ALU_MIPs: ALU_Vector_MAC PORT MAP ( clk => clk, 
										reset => reset, --reset_EX
										valid_I_EX => valid_I_EX, 
										DA => Mux_A_out, 
										DB => ALU_Src_out, 
										ALUctrl => ALUctrl_EX, 
										Dout => ALU_out_EX, 
										ready => ALU_ready,
										mips_status => mips_status, 
    									rte_ex      => RTE_EX);
	
	
	mux_dst: mux2_5bits port map (Din0 => Reg_Rt_EX, DIn1 => Reg_Rd_EX, ctrl => RegDst_EX, Dout => RW_EX);
	
	reset_MEM <= (reset);
	-- New: If an exception arrives we kill the EX instruction, so we should not let it pass to MEM. 
	-- As in other cases we can use the validity bit.
	valid_I_MEM_in <= valid_I_EX and not(Exception_accepted);
	-- New: if stopped at EX, no new instruction must be loaded into the MEM etap.
	-- COMPLETE: If para_MIPS is enabled, stop execution, and keep each instruction in its current stage.
	load_MEM <= '0' when stall_MIPS = '1' else '1';
	Banco_EX_MEM: Banco_MEM PORT MAP ( 	ALU_out_EX => ALU_out_EX, ALU_out_MEM => ALU_out_MEM, clk => clk, reset => reset_MEM, load => load_MEM, MemWrite_EX => MemWrite_EX,
										MemRead_EX => MemRead_EX, MemtoReg_EX => MemtoReg_EX, RegWrite_EX => RegWrite_EX, MemWrite_MEM => MemWrite_MEM, MemRead_MEM => MemRead_MEM,
										MemtoReg_MEM => MemtoReg_MEM, RegWrite_MEM => RegWrite_MEM, 
										--COMPLETE: If we use BusB_EX the sw will not be able to make shorts on rt
										-- which signal should we use to use the shorting network?
										BusB_EX => Mux_B_out,  
										--FIN COMPLETAR
										BusB_MEM => BusB_MEM, RW_EX => RW_EX, RW_MEM => RW_MEM,
										valid_I_EX => valid_I_MEM_in, valid_I_MEM => valid_I_MEM,
										-- Extension ports. Initially they are disconnected
										ext_word_1_EX => PC4_EX, ext_word_2_EX => x"00000000", ext_signal_1_EX => JAL_EX, ext_signal_2_EX => '0',
										ext_word_1_MEM => PC4_MEM, ext_word_2_MEM => open, ext_signal_1_MEM => JAL_MEM, ext_signal_2_MEM => open
										);
	
	--
	------------------------------------------Etapa MEM-------------------------------------------------------------------
	--
	-- COMPLETE: Exception Manager
	Exception_Mng:  Exception_manager PORT MAP (clk => clk, reset => reset, IRQ => IRQ, Data_abort => Data_abort, undef => undef, RTE_EX => RTE_EX,
												RTE_ID => RTE_ID, valid_I_ID => valid_I_ID, valid_I_EX => valid_I_EX, valid_I_MEM => valid_I_MEM,
												stall_MIPS => stall_MIPS, PC_out => PC_out, PC_exception_EX => PC_exception_EX, PC_exception_ID => PC_exception_ID,
												Exception_accepted => Exception_accepted, Exception_LR_output => Exception_LR_output);  
           	

	
	-- NEW: in this stage we access the IO/MD subsystem. As we have taken it out of the MIPS, the component does not appear directly, only the signals. 
	-- The component is in the SOC
	-- Interface with the IO/MD subsystem
	WE <= MemWrite_MEM and valid_I_MEM; --Write signal to the IO/MD subsystem. Only written if it is a valid instruction
	RE <= MemRead_MEM and valid_I_MEM; --Write signal to the IO/MD subsystem. Only read if it is a valid instruction
	ADDR <= ALU_out_MEM; --@ sent from the MIPS to the IO/MD subsystem
	Dout <= BusB_MEM; --Data sent from the MIPS to the IO/MD subsystem
	-- In the interface there is also the IO_MEM_ready input that tells us whether the IO/MD subsystem is going to carry out the IO/MD operation in this cycle.
	Mem_out <= Din; --Data read from the IO/MD subsystem     	
	    	
	--Nuevo: si paramos en EX no hay que cargar una instrucción nueva en la etap MEM
	-- COMPLETE: If para_MIPS is enabled, stop execution, and keep each instruction at its current stage.
	load_WB <= '0' when stall_MIPS = '1' else '1';
	
	Banco_MEM_WB: Banco_WB PORT MAP ( 	ALU_out_MEM => ALU_out_MEM, ALU_out_WB => ALU_out_WB, Mem_out => Mem_out, MDR => MDR, clk => clk, reset => reset, load => load_WB, 
										MemtoReg_MEM => MemtoReg_MEM, RegWrite_MEM => RegWrite_MEM, MemtoReg_WB => MemtoReg_WB, RegWrite_WB => RegWrite_WB, 
										RW_MEM => RW_MEM, RW_WB => RW_WB,
										valid_I_WB_in => valid_I_MEM, valid_I_WB => valid_I_WB,
										-- Extension ports. Initially they are disconnected
										ext_word_1_MEM => PC4_MEM, ext_word_2_MEM => x"00000000", ext_signal_1_MEM => JAL_MEM, ext_signal_2_MEM => '0',
										ext_word_1_WB => PC4_WB, ext_word_2_WB => open, ext_signal_1_WB => JAL_WB, ext_signal_2_WB => open
										);
	
	--
	------------------------------------------WB STAGE-------------------------------------------------------------------
	-- Initially only two inputs are used, and the other two are disconnected, but they can be used for the new instructions.	
	-- To do this, the necessary connections must be made, and the control signal of the multiplexer must be set.	
	-- Complete with your solution for JAL
	-- Si la instrucción es JAL, el control del MUX debe ser "10" para dejar pasar PC+4 y guardarla en el banco de registros.
    -- Si no es un JAL, mantenemos el comportamiento original ('0' & MemtoReg_WB).
	ctrl_Mux4a1_escritura_BR <= "10" when JAL_WB = '1' else ('0' & MemtoReg_WB);
	mux_busW: mux4_1 port map (Din0 => ALU_out_WB, DIn1 => MDR, DIn2 => PC4_WB, DIn3 => PC4_WB, ctrl => ctrl_Mux4a1_escritura_BR, Dout => busW);
	
	-- Lógica para generar mips_status en el Top-Level y pasarlo a la ALU
    process(clk, reset)
    begin
        if reset = '1' then
            mips_status <= "00";
        elsif rising_edge(clk) then
            if Exception_accepted = '1' then
                mips_status <= "11"; -- Entramos en excepción
            elsif RTE_EX = '1' then
                mips_status <= "00"; -- Volvemos a modo usuario
            end if;
        end if;
    end process;

--------------------------------------------------------------------------------------------------
----------- NEW
----------- EVENT COUNTERS.  They allow us to calculate performance metrics such as CPI and check that the expected stops have occurred
-------------------------------------------------------------------------------------------------- 
	-- Total cycle counter
	cont_cycles: counter 	generic map (size => 16)
							port map (clk => clk, reset => reset, count_enable => inc_cycles, count => cycles);
	-- Executed Instructions Counter
	cont_I: counter 		generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_I, count => Ins);
	-- Number of exceptions counter	
	cont_Exceptions: counter 		generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_Exceptions, count => Exceptions);
	-- Stop counters
	-- Allow us to analyse performance penalties.
	-- IMPORTANT: when stalling, only one of the counters should be incremented. For example, if there is a data risk, and the memory for the processor 4 cycles, those 4 stops are due to the memory, not the data risk. When the memory allows to continue, that is when the stop due to the risk will occur, and only then should it be counted.
	-- Data hazard stalls counter							
	cont_data_stalls: counter generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_data_stalls, count => data_stalls);
	-- Control hazard stalls counter
	cont_control_stalls: counter generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_control_stalls, count => control_stalls);
	-- Memory stalls counters
	cont_Memory_stalls : counter generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_Mem_stalls, count => Mem_stalls);						
	-- Data hazard stalls counter							
	cont_EX_stalls: counter generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_EX_stalls, count => EX_stalls);						
							
							
	------------------------------------------------------------------------------------
	-- Complete. Verify that the results match the simulation. Do not count the same stall twice in different counters. 
	inc_cycles <= '1';--Done

	-- Instrucciones válidas que completan la etapa WB
	inc_I <= valid_I_WB; 
	
	-- Ciclos de parada debido a riesgos de datos 
    inc_data_stalls <= '1' when (stall_ID = '1' and stall_MIPS = '0') else '0'; 

    -- Ciclos de parada debido a riesgos de control 
    inc_control_stalls <= '1' when (Kill_IF = '1' and stall_MIPS = '0') else '0';

	-- Número total de excepciones aceptadas
	inc_Exceptions <= Exception_accepted;

	-- Ciclos de parada estructurales debido a referencias a memoria multiciclo (la memoria aún no está lista)
	inc_Mem_stalls <= '1' when (stall_MIPS = '1' and IO_MEM_ready = '0') else '0';

	-- Ciclos de parada estructurales generados por las operaciones MAC multiciclo (la ALU pide más ciclos)
	inc_EX_stalls <= '1' when (stall_MIPS = '1' and ALU_ready = '0') else '0'; 
	
	------------------------------------------------------------------------------------			
end Behavioral;


