library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UA is
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
	end UA;

Architecture Behavioral of UA is
signal Corto_A_Mem, Corto_B_Mem, Corto_A_WB, Corto_B_WB: std_logic;
begin


-- Incomplete design. We give you this as an example. You must complete it yourselves
-- We activate the signal Corto_A_Mem, when we detect that the operand stored in A (Rs) is the same as the one written by the instruction in the Mem stage.
-- Important: we only activate the forwarding if the instruction in the MEM stage is valid.
-- IMPORTANT: the JAL instruction is somewhat special because the data it writes to BR is different from the rest.
-- Is it possible to use the forwarding network in the JAL-distance use cases 1 and 2? Is there any case that does not -- Can it happen in this processor -- What solution do you propose?
-- Example: Jal r1, @jump; @jump: ADD R1, R2, R1; 
	
	-- MEM tiene el dato que Rs necesita
	Corto_A_Mem <= '1' when ((Reg_Rs_EX = RW_MEM) and (RegWrite_MEM = '1') and (valid_I_MEM = '1'))	else '0';
	
	-- MEM tiene el dato que Rt necesita
	Corto_B_Mem <= '1' when ((Reg_Rt_EX = RW_MEM) and (RegWrite_MEM = '1') and (valid_I_MEM = '1')) else '0';
	
	-- WB tiene el dato que Rs necesita
	Corto_A_WB	<= '1' when ((Reg_Rs_EX = RW_WB)  and (RegWrite_WB = '1')  and (valid_I_WB = '1')) else '0';
	
	-- WB tiene el dato que Rt necesita	
	Corto_B_WB	<= '1' when ((Reg_Rt_EX = RW_WB)  and (RegWrite_WB = '1')  and (valid_I_WB = '1')) else '0';
	-- With the above signals, the input of the muxes is chosen:
	-- input 00: corresponds to the data from the register bank
	-- input 01: data from the Mem stage
	-- input 10: data from the WB stage
	-- Complete: We give an example for the Corto_A_Mem, you must add the rest of cases
	
	-- Control de los Multiplexores 
    -- Prioridad: La etapa MEM es más reciente (el cálculo es más nuevo) que WB, así que se comprueba primero.
	MUX_ctrl_A <= 	"01" when (Corto_A_Mem = '1') else -- 01: Dato desde la etapa MEM
                    "10" when (Corto_A_WB = '1') else  -- 10: Dato desde la etapa WB
                    "00";                              -- 00: Dato normal desde el Banco de Registros
	MUX_ctrl_B <= 	"01" when (Corto_B_Mem = '1') else 
                    "10" when (Corto_B_WB = '1') else  
                    "00";	
end Behavioral;