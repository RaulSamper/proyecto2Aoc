
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity reg is
    generic (size: natural := 32);  -- por defecto son de 32 bits, pero se puede usar cualquier tamaño
	Port ( Din : in  STD_LOGIC_VECTOR (size -1 downto 0);
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
           load : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (size -1 downto 0));
end REG;

architecture behavioral of REG is

	signal data : std_logic_vector(size-1 downto 0);

begin

	process(clk)
	begin
		if (rising_edge(clk)) then

			if (reset = '1') then
				data <= (others => '0');
			elsif (load = '1') then
				data <= Din;
			end if;

		end if;

	end process;

	Dout <= data;

end behavioral ; -- arch
