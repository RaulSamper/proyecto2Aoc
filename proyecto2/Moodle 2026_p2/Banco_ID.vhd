----------------------------------------------------------------------------------
-- Description: Banco de registros que separa las etapas IF e ID. Almacena la instrucción en IR_ID y el PC+4 en PC4_ID
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity Banco_ID is
 Port ( IR_in : in  STD_LOGIC_VECTOR (31 downto 0); -- instrucción leida en IF
        PC4_in:  in  STD_LOGIC_VECTOR (31 downto 0); -- PC+4 sumado en IF
		clk : in  STD_LOGIC;
		reset : in  STD_LOGIC;
        load : in  STD_LOGIC;
        IR_ID : out  STD_LOGIC_VECTOR (31 downto 0); -- instrucción en la etapa ID
        PC4_ID:  out  STD_LOGIC_VECTOR (31 downto 0);
         --nuevo para excepciones
        PC_exception:  in  STD_LOGIC_VECTOR (31 downto 0); -- PC al que se volverá si justo esta instrucción está en MEM cuando llega una excepción. 
        PC_exception_ID:  out  STD_LOGIC_VECTOR (31 downto 0);-- PC+4 en la etapa ID
        --bits de validez
        valid_I_IF: in STD_LOGIC;
        valid_I_ID: out STD_LOGIC ); 
end Banco_ID;

architecture Behavioral of Banco_ID is

begin
SYNC_PROC: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            IR_ID <=  x"00000000";
			PC4_ID <= x"00000000";
			--nuevo
			PC_exception_ID <= x"00000000";
			valid_I_ID <= '0';
         else
            if (load='1') then 
					IR_ID <= IR_in;
					PC4_ID <= PC4_in;
					valid_I_ID <= valid_I_IF;
					--nuevo excepciones
					PC_exception_ID <= PC_exception;
				end if;	
         end if;        
      end if;
   end process;

end Behavioral;

