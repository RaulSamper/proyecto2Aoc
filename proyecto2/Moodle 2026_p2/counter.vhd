----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:32:21 07/23/2014 
-- Design Name: 
-- Module Name:    contado5 - Behavioral 
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
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity counter is
 generic (
   size : integer := 10
);
Port ( clk : in  STD_LOGIC;
       reset : in  STD_LOGIC;
       count_enable : in  STD_LOGIC;
       count : out  STD_LOGIC_VECTOR (size-1 downto 0));
end counter;

architecture Behavioral of counter is
signal count_int: STD_LOGIC_VECTOR (size-1 downto 0);
begin
process (clk) 
begin
   if clk='1' and clk'event then
      if reset='1' then 
         count_int <= (others => '0');
      elsif count_enable='1' then
         count_int <= count_int + 1;
      end if;
   end if;
end process;
count <= count_int;
end Behavioral;

