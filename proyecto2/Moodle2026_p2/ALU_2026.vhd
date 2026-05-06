----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:10:07 04/01/2026 
-- Design Name: 
-- Module Name:    ALU - Behavioral with support for vectorial MAC with internal accumulation
-- Additional Comments: by AOC2 Team Unizar 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;



entity ALU_Vector_MAC is
    Port ( DA : in  STD_LOGIC_VECTOR (31 downto 0); --input 1
           DB : in  STD_LOGIC_VECTOR (31 downto 0); --input 2
           valid_I_EX : in  STD_LOGIC;
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
		   ready : out STD_LOGIC; --initially is always '1', but if ALU supports multicycle ops, it will be cero when the output is not ready
           mips_status : in STD_LOGIC_VECTOR (1 downto 0); -- Estado para el Shadow Reg
           rte_ex : in STD_LOGIC; -- Señal RTE para restaurar
           ALUctrl : in  STD_LOGIC_VECTOR (2 downto 0); -- Ops: "000" add, "001" sub, "010" AND, "011" OR, "100" MAC with internal acc, "101" MAC without previous acc.
           Dout : out  STD_LOGIC_VECTOR (31 downto 0)); -- Output
end ALU_Vector_MAC;

architecture Behavioral of ALU_Vector_MAC is

component reg is
    generic (size: natural := 32);  -- por defecto son de 32 bits, pero se puede usar cualquier tamaño
	Port ( Din : in  STD_LOGIC_VECTOR (size -1 downto 0);
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
           load : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (size -1 downto 0));
end component;

-- Estados para la máquina de estados de 3 ciclos
type state_type is (S_MULT, S_SUM, S_ACC);
signal current_state, next_state : state_type;

-- Registros intermedios (pipeline interno de la ALU)
signal p0_reg, p1_reg, p2_reg, p3_reg : Signed(15 downto 0);
signal sum_reg : Signed(17 downto 0);

signal Dout_internal: STD_LOGIC_VECTOR (31 downto 0);
signal ACC_out : STD_LOGIC_VECTOR (31 downto 0) := X"00000000";
signal ACC_shadow : STD_LOGIC_VECTOR (31 downto 0) := X"00000000"; -- Registro sombra
signal mips_status_prev : STD_LOGIC_VECTOR(1 downto 0) := "00";    -- Para detectar flanco de excepción
signal ACC_input, sum_total_ext: Signed (31 downto 0);
signal prod0, prod1, prod2, prod3 : Signed(15 downto 0);
signal sum1, sum2 : Signed(16 downto 0);
signal sum_total : Signed(17 downto 0);
signal load_acc, Acc_op, MAC_start : STD_LOGIC;
begin
-- IMPORTANT
-- VHDL is strongly typed.
-- In VHDL, types do not just describe the size of a signal, they describe its meaning. 
-- A std_logic_vector means “a bundle of bits,” nothing more. 
-- A signed signal means “a two's complement number.” Because the language is strongly typed, VHDL won’t let you accidentally treat raw bits as a number or mix numeric and non-numeric types without being explicit.
-- In VHDL, you need to use the signed type for C2 (two’s-complement) arithmetic because arithmetic operators like +, -, and comparisons are only numerically defined for the signed and unsigned types in numeric_std, not for std_logic_vector. 
-- A std_logic_vector is just a collection of bits with no inherent numerical meaning, so the compiler has no way to know whether those bits represent a positive or negative number or how to interpret the sign bit.
-- By converting the operands to signed, you explicitly tell VHDL to interpret the MSB as the sign bit and to perform proper two’s-complement arithmetic. 
-- After the calculation, the result is typically converted back to std_logic_vector to store it in a register because registers and ports are often defined as std_logic_vector for generality and compatibility with other logic, interfaces, and synthesis tools. 
-- This separation keeps arithmetic correct and unambiguous while still allowing flexible storage and data movement.
-- NOTE: If you add additional registers you will have to adjust types
-- See the ACC_register for an example: 
-- 1) To use ACC_input as input, first it is transformed to std_logic_vector with: std_logic_vector(ACC_input)
-- 2) To use the output for signed arithmetic operations, first it is transformed to signed: else sum_total_ext + signed(ACC_out);

-- Lógica del siguiente estado y señal ready (Combinacional)
    process(current_state, Acc_op, valid_I_EX)
    begin
        -- Valores por defecto
        ready <= '1';
        next_state <= current_state;
        
        case current_state is
            when S_MULT =>
                if (Acc_op = '1' and valid_I_EX = '1') then
                    ready <= '0'; -- Congelamos el cauce
                    next_state <= S_SUM;
                end if;
            when S_SUM =>
                ready <= '0'; -- Seguimos congelando
                next_state <= S_ACC;
            when S_ACC =>
                ready <= '1'; -- Ya tenemos el dato listo, liberamos el cauce
                next_state <= S_MULT;
            when others =>
                next_state <= S_MULT;
        end case;
    end process;

	-- Actualización de la MEF y almacenamiento en los registros (Secuencial)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= S_MULT;
                p0_reg <= (others => '0');
                p1_reg <= (others => '0');
                p2_reg <= (others => '0');
                p3_reg <= (others => '0');
                sum_reg <= (others => '0');
            else
                current_state <= next_state;
                
                -- Guardamos los resultados de la etapa correspondiente en los registros
                if current_state = S_MULT then
                    p0_reg <= prod0;
                    p1_reg <= prod1;
                    p2_reg <= prod2;
                    p3_reg <= prod3;
                elsif current_state = S_SUM then
                    sum_reg <= sum_total;
                end if;
            end if;
        end if;
    end process;

	-- CICLO 1: Multiplicaciones (se calculan con DA y DB combinacionalmente)
	prod0 <= signed(DA(7 downto 0))   * signed(DB(7 downto 0));
	prod1 <= signed(DA(15 downto 8))  * signed(DB(15 downto 8));
	prod2 <= signed(DA(23 downto 16)) * signed(DB(23 downto 16));
	prod3 <= signed(DA(31 downto 24)) * signed(DB(31 downto 24));

	-- CICLO 2: Sumas (usamos los registros pX_reg guardados en el ciclo anterior)
	sum1 <= (p0_reg(15) & p0_reg) + (p1_reg(15) & p1_reg);
    sum2 <= (p2_reg(15) & p2_reg) + (p3_reg(15) & p3_reg);
    sum_total <= (sum1(16) & sum1) + (sum2(16) & sum2);
	-- sum1 <= (prod0(15) & prod0) + (prod1(15) & prod1);
	-- sum2 <= (prod2(15) & prod2) + (prod3(15) & prod3);
	-- sum_total <= (sum1(16) & sum1) + (sum2(16) & sum2);

	-- CICLO 3: Acumulación y extensión de signo (usamos sum_reg)
	sum_total_ext(17 downto 0) <= sum_reg;
    sum_total_ext(31 downto 18) <= "00000000000000" when sum_reg(17)='0' else "11111111111111";

	--It is important not to update the ACC register with invalid instructions
	Acc_op <= '1' when (ALUctrl(2 downto 1) = "10") else '0'; --Acc operations: "100" and "101" 
	load_acc <= '1' when (Acc_op = '1' and valid_I_EX = '1' and current_state = S_ACC) else '0'; -- Solo guardamos en el acumulador en el último ciclo (S_ACC)
	MAC_start <=   '1' when (ALUctrl(0) = '1') else '0'; -- If ALUCtrl = "101" the accumulation register is restarted
	
	ACC_input	 <= 	sum_total_ext when (MAC_start = '1')
						else sum_total_ext + signed(ACC_out);	
	--reset is currentlly unused in the ALU, but it will be needed if it becomes multicycle
	-- ACC_register: reg 	generic map (size => 32)
	--					port map (	Din => std_logic_vector(ACC_input), clk => clk, reset => '0', load => load_acc, Dout => ACC_out);
	
    -- Gestión del acumulador ante excepciones, RF8 (Guardar estado para que no se pierda al detectar una excepción)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ACC_out <= (others => '0');
                ACC_shadow <= (others => '0');
                mips_status_prev <= "00";
            else
                mips_status_prev <= mips_status; -- Guardamos estado para detectar la entrada
                
                if (mips_status = "11" and mips_status_prev /= "11") then
                    ACC_shadow <= ACC_out;  -- CASO 1: Salvado automático al detectar IRQ
                elsif (rte_ex = '1') then
                    ACC_out <= ACC_shadow;  -- CASO 2: Restauración automática en RTE
                elsif (load_acc = '1') then
                    ACC_out <= std_logic_vector(ACC_input); -- CASO 3: Funcionamiento normal
                end if;
            end if;
        end if;
    end process;
	
	Dout_internal <= 	DA + DB when (ALUctrl="000") 
				else DA - DB when (ALUctrl="001") 
				else DA AND DB when (ALUctrl="010")
				else DA OR DB when (ALUctrl="011")
				else std_logic_vector(ACC_input) when (ALUctrl(2 downto 1) = "10")
				else "00000000000000000000000000000000";
	Dout <= Dout_internal;
	-- to be updated:
	--ready <= '1';
end Behavioral;