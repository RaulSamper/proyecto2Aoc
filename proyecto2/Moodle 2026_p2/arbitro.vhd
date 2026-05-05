----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:02:29 04/04/2014 
-- Design Name: 
-- Module Name:    reg32 - Behavioral 
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

entity Arbitro is
    Port ( 	clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			bus_frame: in  STD_LOGIC;-- para saber que hay una transferenica en curso
			last_word: in  STD_LOGIC; -- Cuando termina una transferencia cambiamos las prioridades
			Bus_TRDY: in  STD_LOGIC; --para saber que la ultima transferencia va a realizarse este ciclo
    		Req0 : in  STD_LOGIC; -- hay dos solicitudes
           	Req1 : in  STD_LOGIC;
           	Grant0 : out std_LOGIC;
           	Grant1 : out std_LOGIC);
end Arbitro;

architecture Behavioral of Arbitro is
signal priority : std_logic;
begin
-- La prioridad de concesión es round robin. Es decir se alterna la prioridad entre los dos dispositivos
SYNC_PROC: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            priority <= '0';
         elsif (bus_frame= '1') and (last_word = '1')and (Bus_TRDY = '1') then -- Cuando sabemos que la transferencia está en su ultimo ciclo se cambian las prioridades
            priority <= not priority;
         end if;        
      end if;
   end process;
   -- La señal Frame inhibe al árbitro
   grant1 <= (not(bus_frame) and ((Req1 and priority) or (Req1 and not(Req0)))); --si req 1 está activado y prioridad vale 1	se concede el bus al dispositivo 1
   grant0 <= (not(bus_frame) and ((Req0 and not(priority)) or (Req0 and not(Req1)))); --si req0 está activado y prioridad vale 0	y se concede el bus al dispositivo 0
end Behavioral;

