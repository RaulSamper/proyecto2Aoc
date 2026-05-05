library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--Mux 4 a 1
entity UD is
    Port ( 	
			valid_I_ID : in  STD_LOGIC; --valid bit for ID
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
			stall_ID		: out  STD_LOGIC -- Indicates that the ID and pre-stages must stop
			); 
end UD;
Architecture Behavioral of UD is
signal dep_rs_EX, dep_rs_Mem, dep_rt_EX, dep_rt_Mem, ld_uso_rs, ld_uso_rt, JAL_uso_rs, JAL_uso_rt, RET_rs, BEQ_rs, BEQ_rt, riesgo_datos_ID, stall_MIPS_internal : std_logic;
signal rs_read, rt_read: STD_LOGIC; 
-- Constants to improve the readability of the code.
CONSTANT NOP_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000000";
CONSTANT ARIT_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000001";
CONSTANT LW_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000010";
CONSTANT SW_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000011";
CONSTANT BEQ_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000100";
CONSTANT JAL_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000101";
CONSTANT RET_opcode : STD_LOGIC_VECTOR (5 downto 0)	:= "000110";
CONSTANT RTE_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "001000";
CONSTANT FI_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "010000";
begin
-------------------------------------------------------------------------------------------------------------------------------
-- Kill_IF:
-- gives the command to kill the instruction that has been read in Fetch.
-- Must be activated each time it is jumped (jump_taken entry), since by default the instruction following the jump has been fetched and if it is jumped it does not have to be executed.
-- IMPORTANT: 
-- if a jump instruction does not have its operands available, it does not know whether to jump or not (for BEQ), or whether to jump in the case of RET. It doesn't matter what it says jump taken. You have to stop and wait until you have the operands
-- if the instruction in ID is not valid, you have to ignore it when it tells you that it is going to jump (the same as if it tells you anything else), but pay attention to the valid instructions.
-- Complete: activate Kill_IF where applicable
-- Anulamos la instrucción leída en IF si hay un salto efectivo, es válida, y NO estamos parados por riesgos de datos.
		Kill_IF <= '1' when (salto_tomado = '1' and valid_I_ID = '1' and riesgo_datos_ID = '0') else '0';
-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
-- Data dependencies:
-- COMPLETE:
-- The code includes an example. You must complete the rest of the options.	
-- 	First detects which operands are used
-- 	Second looks for dependencies
-- Register use: identifies if the current instruction reads Rs or Rt
	rs_read <= '1' when ((IR_op_code = ARIT_opcode) or (IR_op_code = LW_opcode) or (IR_op_code = SW_opcode) or (IR_op_code = BEQ_opcode) or (IR_op_code = RET_opcode) or (IR_op_code = FI_opcode)) else '0';
	-- Rt is not read in instructions: LW, NOP, RTE, RET and JAL
	-- Rt se lee en ARIT, SW y BEQ
	rt_read <= '1' when ((IR_op_code = ARIT_opcode) or (IR_op_code = SW_opcode) or (IR_op_code = BEQ_opcode)) else '0';
	-- Conditions for each dependency:
	-- Notation: dep_rs_EX: data dependecy in Rs, with the instruction in EX stage.
	dep_rs_EX 	<= 	'1' when ((valid_I_EX = '1') AND (valid_I_ID = '1') AND (Reg_Rs_ID = RW_EX) and (RegWrite_EX = '1') and (rs_read = '1'))	else '0';
	--Complete:
	dep_rs_Mem  <=  '1' when ((valid_I_MEM = '1') AND (valid_I_ID = '1') AND (Reg_Rs_ID = RW_Mem) and (RegWrite_Mem = '1') and (rs_read = '1')) else '0';
							
	dep_rt_EX	<=  '1' when ((valid_I_EX = '1') AND (valid_I_ID = '1') AND (Reg_Rt_ID = RW_EX) and (RegWrite_EX = '1') and (rt_read = '1')) else '0';
								
	dep_rt_Mem	<= 	'1' when ((valid_I_MEM = '1') AND (valid_I_ID = '1') AND (Reg_Rt_ID = RW_Mem) and (RegWrite_Mem = '1') and (rt_read = '1')) else '0';

-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
-- Data hazards:
	-- 1) lw_uso: Si en EX hay un LW y nosotros necesitamos ese registro.
	ld_uso_rs <= 	'1' when (dep_rs_EX = '1' and MemRead_EX = '1') else '0';
	ld_uso_rt <= 	'1' when (dep_rt_EX = '1' and MemRead_EX = '1') else '0';
									
	-- 2) BEQ: BEQ reads the registers in ID, and we do not have a forwarding network in that stage
	-- Si en ID hay un BEQ y hay cualquier dependencia con EX o MEM, paramos (no hay anticipación a ID).
	BEQ_rs	<= 	'1' when (IR_op_code = BEQ_opcode and (dep_rs_EX = '1' or dep_rs_Mem = '1')) else '0';
	BEQ_rt	<= 	'1' when (IR_op_code = BEQ_opcode and (dep_rt_EX = '1' or dep_rt_Mem = '1')) else '0';
		
	-- 3) RET: Similar to beq hazard, but taking into account that RET only uses Rs
	-- Igual que BEQ, pero RET solo usa el registro Rs.
	RET_rs	<= 	'1' when (IR_op_code = RET_opcode and (dep_rs_EX = '1' or dep_rs_Mem = '1')) else '0';
	
	-- 4) JAL: if an instruction wants to read the register in which the JAL writes, will the short-circuit network work?
	-- JAL does not write the ALU_out or MDR data, but the PC_WB. 
	-- JAL: can be managed in several ways. One of them is to stop. It is not mandatory to stop in JALs, but if you do, use these signals. If you do not need to stop, just leave them at 0.
	-- JAL no genera problemas directos de lectura que requieran parada, así que las dejamos a 0
	JAL_uso_rs	<= 	'0';
	JAL_uso_rt <= 	'0';
	
	-- If any of the data hazards conditions are met, the IF and ID stages are stopped.
	riesgo_datos_ID <= BEQ_rt OR BEQ_rs OR ld_uso_rs OR ld_uso_rt OR RET_rs OR JAL_uso_rs OR JAL_uso_rt;
	
	stall_ID <= riesgo_datos_ID;
-------------------------------------------------------------------------------------------------------------------------------
-- stall_MIPS: used to stop the entire processor when the memory cannot perform the requested operation in the current cycle (i.e. when IO_MEM_ready is 0). 
-- Why do we stop the whole processor and not just the memory stage and the previous ones? 
		-- The reason is that if they are not stopped, data that was going to be anticipated may be lost. In the following example you see:
		-- ADD R1, R2, R3 F D E M W
		-- LW R8, 0(R7) 	F D E M M M M W
		-- ADD R6, R1, R4 	  F D E E E E M W
		-- ADD R6 cannot read R1 in ID, but does not stop because it can anticipate it. However, LW R8 stops its execution several cycles because the memory is not ready.
		-- If we allow ADD R1 to continue, the data we wanted to anticipate disappears, and when ADD R6 goes to read it, it will not be there. 
		-- The solution is to stop ADD R1 as well:
		-- ADD R1, R2, R3 F  D  E  M  W  W  W  W  W    
		-- LW R8, 0(R7) 	 F  D  E  M  M  M  M  M  W
		-- ADD R6, R1, R4 	    F  D  E  E  E  E  E  M  W
		-- In this way ADD R6 can perform its anticipation. Writing the same data several times does not consume energy, so there is no real penalty either. However, if you don't want to write the same data multiple times to BR, you can disable writing to the register bank when the mips is stopped.
-- stall_MIPS_internal is defined to be readable in the code (in vhdl the outputs of an entity cannot be read inside the entity. 
	stall_MIPS_internal <= (not(IO_MEM_ready) and valid_I_MEM) or not(ALU_ready);
	stall_MIPS <= stall_MIPS_internal;
-------------------------------------------------------------------------------------------------------------------------------
end Behavioral;


