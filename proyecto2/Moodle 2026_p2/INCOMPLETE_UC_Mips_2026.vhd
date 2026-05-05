----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:14:28 04/07/2014 
-- Design Name: 
-- Module Name:    UC - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity UC is
    Port ( valid_I_ID : in  STD_LOGIC; --valid bit
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
end UC;

architecture Behavioral of UC is
-- to improve readability
CONSTANT NOP_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000000";
CONSTANT ARIT_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000001";
CONSTANT LW_opcode : STD_LOGIC_VECTOR (5 downto 0) 		:= "000010";
CONSTANT SW_opcode : STD_LOGIC_VECTOR (5 downto 0) 		:= "000011";
CONSTANT BEQ_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000100";
CONSTANT JAL_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "000101";
CONSTANT RET_opcode : STD_LOGIC_VECTOR (5 downto 0)		:= "000110";
CONSTANT RTE_opcode : STD_LOGIC_VECTOR (5 downto 0) 	:= "001000";
--CONSTANT FI_opcode : STD_LOGIC_VECTOR (5 downto 0) 		:= "010000"; --2026: not used
begin

UC_mux : process (IR_op_code, valid_I_ID)
begin 
	-- By default we set all signals to 0 which is the value that guarantees that we do not alter anything.
	Branch <= '0'; RegDst <= '0'; ALUSrc <= '0'; MemWrite <= '0'; MemRead <= '0'; MemtoReg <= '0'; RegWrite <= '0'; UNDEF <= '0';
	jal <= '0'; ret <= '0'; RTE <= '0'; 
	IF valid_I_ID = '1' then --if the instruction is valid we analyse its operation code
		CASE IR_op_code IS
		--NOP 
			WHEN  NOP_opcode  	=>  
			--ARIT
			WHEN  ARIT_opcode  	=> 	RegDst <= '1'; RegWrite <= '1'; 
			--LW
			WHEN  LW_opcode  	=>  ALUSrc <= '1'; MemRead <= '1'; MemtoReg <= '1'; RegWrite <= '1'; 
			--SW
			WHEN  SW_opcode  	=>  ALUSrc <= '1'; MemWrite <= '1'; 
			--BEQ
			WHEN  BEQ_opcode  	=>  Branch <= '1'; 
			------------------------------------------------
			-- COMPLETE
			------------------------------------------------
			-- JAL
			WHEN  jal_opcode  	=>  jal <= '1'; RegWrite <= '1'; -- Escribe un dato en el banco de registros
			-- RET
			WHEN  RET_opcode  	=>  ret <= '1'; -- RET sirve para volver del salto, solamente lee
			--RTE
			WHEN  RTE_opcode  	=>  RTE <= '1'; -- Any more signals?
			-- OP code undefined
			WHEN  OTHERS 	  	=> UNDEF <= '1';
		  END CASE;
	END IF;
end process;
end Behavioral;

