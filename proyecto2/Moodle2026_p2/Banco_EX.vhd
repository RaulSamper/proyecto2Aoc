----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:46:01 04/07/2014 
-- Design Name: 
-- Module Name:    Banco_EX - Behavioral 
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

entity Banco_EX is
    Port (  clk : in  STD_LOGIC;
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
			ALUctrl_ID: in STD_LOGIC_VECTOR (2 downto 0);
			ALUctrl_EX: out STD_LOGIC_VECTOR (2 downto 0);
           	Reg_Rt_ID : in  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rd_ID : in  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rt_EX : out  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rd_EX : out  STD_LOGIC_VECTOR (4 downto 0);
            -- Nuevo excepción
           	PC_exception_ID:  in  STD_LOGIC_VECTOR (31 downto 0);
           	PC_exception_EX:  out  STD_LOGIC_VECTOR (31 downto 0);
           	-- Nuevo para el retorno de la excepción
           	RTE_ID :  in STD_LOGIC; 
           	RTE_EX :  out STD_LOGIC; 
           	-- Nuevo para anticipación
			Reg_Rs_ID : in  std_logic_vector(4 downto 0);
			Reg_Rs_EX : out std_logic_vector(4 downto 0);
			--Fin nuevo
           	--bits de validez
        	valid_I_EX_in: in STD_LOGIC;
        	valid_I_EX: out STD_LOGIC;
        	-- Puertos para añadir señales
			-- Estos puertos se utilizan para añadir funcionalidades al MIPS que requieran enviar información de una etapa a las etapas siguientes
			-- El banco permite enviar dos señales de un bit (ext_signal_1 y 2) y dos palabras de 32 bits ext_word_1 y 2)
			ext_signal_1_ID: in  STD_LOGIC;
			ext_signal_1_EX: out  STD_LOGIC;
			ext_signal_2_ID: in  STD_LOGIC;
			ext_signal_2_EX: out  STD_LOGIC;
			ext_word_1_ID:  IN  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_1_EX:  OUT  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_2_ID:  IN  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_2_EX:  OUT  STD_LOGIC_VECTOR (31 downto 0)
			--fin puertos extensión
			);
end Banco_EX;

architecture Behavioral of Banco_EX is

begin
SYNC_PROC: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            	busA_EX <=  x"00000000";
				busB_EX <=  x"00000000";
				inm_ext_EX <=  x"00000000";
				RegDst_EX <= '0';
				ALUSrc_EX <= '0';
				MemWrite_EX <= '0';
				MemRead_EX <= '0';
				MemtoReg_EX <= '0';
				RegWrite_EX <= '0';
				 -- Nuevo
				Reg_Rs_EX <= "00000";
				PC_exception_EX <= x"00000000";
				RTE_EX <= '0';
				-- fin Nuevo
				Reg_Rt_EX <= "00000";
				Reg_Rd_EX <= "00000";
				ALUctrl_EX <= "000";
				valid_I_EX <= '0';
				--Puertos extensión
				ext_word_1_EX <= x"00000000";
				ext_word_2_EX <= x"00000000";
				ext_signal_1_EX <= '0';
				ext_signal_2_EX <= '0';
         else
            if (load='1') then 
					busA_EX <= busA;
					busB_EX <= busB;
					RegDst_EX <= RegDst_ID;
					ALUSrc_EX <= ALUSrc_ID;
					MemWrite_EX <= MemWrite_ID;
					MemRead_EX <= MemRead_ID;
					MemtoReg_EX <= MemtoReg_ID;
					RegWrite_EX <= RegWrite_ID;
					 -- Nuevo
					Reg_Rs_EX <= Reg_Rs_ID; 
					PC_exception_EX <= PC_exception_ID;
					RTE_EX <= RTE_ID;
					-- fin Nuevo
					Reg_Rt_EX <= Reg_Rt_ID;
					Reg_Rd_EX <= Reg_Rd_ID;
					ALUctrl_EX <= ALUctrl_ID;
					inm_ext_EX <= inm_ext;
					valid_I_EX <= valid_I_EX_in;
					--Puertos extensión
					ext_word_1_EX <= ext_word_1_ID;
					ext_word_2_EX <= ext_word_2_ID;
					ext_signal_1_EX <= ext_signal_1_ID;
					ext_signal_2_EX <= ext_signal_2_ID;
				end if;	
         end if;        
      end if;
   end process;

end Behavioral;

