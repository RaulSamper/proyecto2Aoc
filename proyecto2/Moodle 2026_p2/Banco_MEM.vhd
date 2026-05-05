----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:28:20 04/07/2014 
-- Design Name: 
-- Module Name:    Banco_MEM - Behavioral 
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

entity Banco_MEM is
Port ( 		ALU_out_EX : in  STD_LOGIC_VECTOR (31 downto 0); 
			ALU_out_MEM : out  STD_LOGIC_VECTOR (31 downto 0); -- instrucción leida en IF
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
         	BusB_EX: in  STD_LOGIC_VECTOR (31 downto 0); -- para los store
			BusB_MEM: out  STD_LOGIC_VECTOR (31 downto 0); -- para los store
			RW_EX : in  STD_LOGIC_VECTOR (4 downto 0); -- registro destino de la escritura
         	RW_MEM : out  STD_LOGIC_VECTOR (4 downto 0);
        	--bits de validez
        	valid_I_EX: in STD_LOGIC;
        	valid_I_MEM: out STD_LOGIC;
        	-- Puertos para añadir señales
			-- Estos puertos se utilizan para añadir funcionalidades al MIPS que requieran enviar información de una etapa a las etapas siguientes
			-- El banco permite enviar dos señales de un bit (ext_signal_1 y 2) y dos palabras de 32 bits ext_word_1 y 2)
			ext_signal_1_EX: in  STD_LOGIC;
			ext_signal_1_MEM: out  STD_LOGIC;
			ext_signal_2_EX: in  STD_LOGIC;
			ext_signal_2_MEM: out  STD_LOGIC;
			ext_word_1_EX:  IN  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_1_MEM:  OUT  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_2_EX:  IN  STD_LOGIC_VECTOR (31 downto 0);
			ext_word_2_MEM:  OUT  STD_LOGIC_VECTOR (31 downto 0)
			--fin puertos extensión
			);
end Banco_MEM;

architecture Behavioral of Banco_MEM is

begin
SYNC_PROC: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            	ALU_out_MEM <= x"00000000";
				BUSB_MEM <= x"00000000";
				RW_MEM <= "00000";
				MemWrite_MEM <= '0';
				MemRead_MEM <= '0';
				MemtoReg_MEM <= '0';
				RegWrite_MEM <= '0';
				valid_I_MEM <= '0';
				--Puertos extensión
				ext_word_1_MEM <= x"00000000";
				ext_word_2_MEM <= x"00000000";
				ext_signal_1_MEM <= '0';
				ext_signal_2_MEM <= '0';
         else
            if (load='1') then 
					ALU_out_MEM <= ALU_out_EX;
					BUSB_MEM <= BUSB_EX;
					RW_MEM <= RW_EX;
					MemWrite_MEM <= MemWrite_EX;
					MemRead_MEM <= MemRead_EX;
					MemtoReg_MEM <= MemtoReg_EX;
					RegWrite_MEM <= RegWrite_EX;
					valid_I_MEM <= valid_I_EX;
					--Puertos extensión
					ext_word_1_MEM <= ext_word_1_EX;
					ext_word_2_MEM <= ext_word_2_EX;
					ext_signal_1_MEM <= ext_signal_1_EX;
					ext_signal_2_MEM <= ext_signal_2_EX;
				end if;	
         end if;        
      end if;
   end process;

end Behavioral;

