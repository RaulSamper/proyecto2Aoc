---------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:38:18 05/15/2014 
-- Design Name: 
-- Module Name:    UC_slave - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: la UC incluye un contador de 2 bits para llevar la cuenta de las transferencias de bloque y una mquina de estados
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
entity UC_MC_CB is
    Port ( 	clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			-- rdenes del MIPS
			RE : in  STD_LOGIC; 
			WE : in  STD_LOGIC;
			-- Respuesta al MIPS
			ready : out  STD_LOGIC; -- indica si podemos procesar la orden actual del MIPS en este ciclo. En caso contrario habr que detener el MIPs
			-- Seales de la MC
			hit0 : in  STD_LOGIC; --se activa si hay acierto en la via 0
			hit1 : in  STD_LOGIC; --se activa si hay acierto en la via 1
			via_2_rpl :  in  STD_LOGIC; --indica que via se va a reemplazar
			addr_non_cacheable: in 
STD_LOGIC; --indica que la direccin no debe almacenarse en MC. En este caso porque pertenece a la scratch
			internal_addr: in STD_LOGIC; -- indica que la direccin solicitada es de un registro de MC
			MC_WE0 : out  STD_LOGIC;
            MC_WE1 : out  STD_LOGIC;
           	-- Seales para indicar la operacin que se quiere hacer en el bus
       		MC_bus_Read : out  STD_LOGIC; -- para pedir el bus en acceso de lectura
			MC_bus_Write : out  STD_LOGIC;
--  para pedir el bus en acceso de escritura
			MC_tags_WE : out  STD_LOGIC;
-- para escribir la etiqueta en la memoria de etiquetas
            palabra : out  STD_LOGIC_VECTOR (1 downto 0);--indica la palabra actual dentro de una transferencia de bloque (1, 2...)
            mux_origen: out STD_LOGIC;
-- Se utiliza para elegir si el origen de la direccin de la palabra y el dato es el Mips (cuando vale 0) o la UC y el bus (cuando vale 1)
			block_addr : out  STD_LOGIC;
-- indica si la direccin a enviar es la de bloque (rm) o la de palabra (w)
			mux_output: out  std_logic_vector(1 downto 0);
-- para elegir si le mandamos al procesador la salida de MC (valor 0),los datos que hay en el bus (valor 1), o un registro interno( valor 2)
			-- seales para los contadores de rendimiento de la MC
			inc_m : out STD_LOGIC;
-- indica que ha habido un fallo en MC
			inc_w : out STD_LOGIC;
-- indica que ha habido una escritura en MC
			inc_r : out STD_LOGIC;
-- indica que ha habido una escritura en MC
			inc_cb :out STD_LOGIC;
-- indica que ha habido un reemplazo sucio en MC
			-- Gestin de errores
			unaligned: in STD_LOGIC;
--indica que la direccin solicitada por el MIPS no est alineada
			Mem_ERROR: out std_logic;
-- Se activa si en la ultima transferencia el esclavo no respondi a su direccin
			load_addr_error: out std_logic;
--para controlar el registro que guarda la direccin que caus error
			-- Gestin de los bloques sucios
			send_dirty: out std_logic;-- Indica que hay que enviar la @ del bloque sucio
			Update_dirty	: out  STD_LOGIC;
--indica que hay que actualizar los bits dirty tanto por que se ha realizado una escritura, como porque se ha enviado el bloque sucio a memoria
			dirty_bit_rpl : in  STD_LOGIC;
--indica si el bloque a reemplazar es sucio
			Block_copied_back	: out  STD_LOGIC;
-- indica que se ha enviado a memoria un bloque que estaba sucio.
Se usa para elegir la mscara que quita el bit de sucio
			-- Para gestionar las transferencias a travs del bus
			bus_TRDY : in  STD_LOGIC;
--indica que la memoria puede realizar la operacin solicitada en este ciclo
			Bus_DevSel: in  STD_LOGIC;
--indica que la memoria ha reconocido que la direccin est dentro de su rango
			Bus_grant :  in  STD_LOGIC;
--indica la concesin del uso del bus
			MC_send_addr_ctrl : out  STD_LOGIC;
--ordena que se enven la direccin y las seales de control al bus
            MC_send_data : out  STD_LOGIC;
--ordena que se enven los datos
            Frame : out  STD_LOGIC;
--indica que la operacin no ha terminado
            last_word : out  STD_LOGIC;
--indica que es el ltimo dato de la transferencia
            Bus_req :  out  STD_LOGIC --indica la peticin al rbitro del uso del bus
			);
end UC_MC_CB;

architecture Behavioral of UC_MC_CB is
 
component counter is 
	generic (
	   size : integer := 10
	);
Port ( clk : in  STD_LOGIC;
	       reset : in  STD_LOGIC;
	       count_enable : in  STD_LOGIC;
	       count : out  STD_LOGIC_VECTOR (size-1 downto 0)
					  );
end component;		           
-- Ejemplos de nombres de estado. No hay que usar estos. Nombrad a vuestros estados con nombres descriptivos.
As se facilita la depuracin
type state_type is (Inicio, single_word_transfer_addr, read_block, write_dirty_block, single_word_transfer_data, block_transfer_addr, block_transfer_data, Send_Addr, Send_ADDR_CB, fallo, CopyBack, bajar_Frame);
type error_type is (memory_error, No_error); 
signal state, next_state : state_type; 
signal error_state, next_error_state : error_type; 
signal last_word_block: STD_LOGIC;
--se activa cuando se est pidiendo la ltima palabra de un bloque
signal one_word: STD_LOGIC;
--se activa cuando slo se quiere transferir una palabra
signal count_enable: STD_LOGIC;
-- se activa si se ha recibido una palabra de un bloque para que se incremente el contador de palabras
signal hit: std_logic;
signal palabra_UC : STD_LOGIC_VECTOR (1 downto 0);
begin

hit <= hit0 or hit1;	
 
--el contador nos dice cuantas palabras hemos recibido.
Se usa para saber cuando se termina la transferencia del bloque y para direccionar la palabra en la que se escribe el dato leido del bus en la MC
word_counter: counter 	generic map (size => 2)
						port map (clk, reset, count_enable, palabra_UC);
--indica la palabra actual dentro de una transferencia de bloque (1, 2...)

last_word_block <= '1' when palabra_UC="11" else '0';--se activa cuando estamos pidiendo la ltima palabra

palabra <= palabra_UC;
State_reg: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            state <= Inicio;
else
            state <= next_state;
         end if;        
      end if;
end process;
 
   ---------------------------------------------------------------------------
-- 2023
-- Mquina de estados para el bit de error
---------------------------------------------------------------------------

error_reg: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then           
            error_state <= No_error;
else
            error_state <= next_error_state;
         end if;   
      end if;
end process;
   
--Salida Mem Error
Mem_ERROR <= '1' when (error_state = memory_error) else '0';
--MEALY State-Machine - Outputs based on state and inputs
   --Sensitivity list: check that all the combinational inputs used are included
   OUTPUT_DECODE: process (state, error_state, hit, last_word_block, bus_TRDY, RE, WE, Bus_DevSel, Bus_grant, via_2_rpl, hit0, hit1, dirty_bit_rpl, addr_non_cacheable, internal_addr, unaligned)
   begin
-- Default values
	MC_WE0 <= '0';
MC_WE1 <= '0';
	MC_bus_Read <= '0';
	MC_bus_Write <= '0';
	MC_tags_WE <= '0';
    ready <= '0';
    mux_origen <= '0';
MC_send_addr_ctrl <= '0';
    MC_send_data <= '0';
    next_state <= state;  
	count_enable <= '0';
	Frame <= '0';
	block_addr <= '0';
inc_m <= '0';
	inc_w <= '0';
	inc_r <= '0';
	inc_cb <= '0';
	Bus_req <= '0';
	one_word <= '0';
mux_output <= "00";
	last_word <= '0';
	next_error_state <= error_state; 
	load_addr_error <= '0';
	send_dirty <= '0';
	Update_dirty <= '0';
Block_copied_back <= '0';
	
	    -- Inicio state          
    CASE state is 
		when Inicio =>

            if (RE = '0' and WE = '0') then
                -- Idle: ningun acceso pendiente
                next_state <= Inicio;
ready      <= '1';

            elsif ((RE = '1') or (WE = '1')) and (unaligned = '1') then
                -- Acceso a direccion no alineada: error inmediato
                next_state       <= Inicio;
ready            <= '1';
                next_error_state <= memory_error;
load_addr_error  <= '1';

            elsif (RE = '1' and internal_addr = '1') then
                -- Lectura del registro interno ADDR_Error_Reg
                next_state       <= Inicio;
ready            <= '1';
mux_output       <= "10";
                next_error_state <= No_error;
elsif (WE = '1' and internal_addr = '1') then
                -- Intento de escritura sobre registro de solo lectura: error
                next_state       <= Inicio;
ready            <= '1';
                next_error_state <= memory_error;
load_addr_error  <= '1';

            elsif (addr_non_cacheable = '1') then
                -- Acceso a MD Scratch (no cacheable, palabra unica)
                Bus_req      <= '1';
MC_bus_Read  <= RE;
                MC_bus_Write <= WE;
                if (Bus_grant = '1') then
                    next_state <= single_word_transfer_addr;
else
                    next_state <= Inicio;
end if;

            elsif (RE = '1' and hit = '1') then
                -- Acierto de lectura
                next_state <= Inicio;
ready      <= '1';
                inc_r      <= '1';
                mux_output <= "00";
elsif (WE = '1' and hit = '1') then
                -- Acierto de escritura: actualiza vía con dato del MIPS y bit dirty
                next_state   <= Inicio;
ready        <= '1';
                inc_w        <= '1';
Update_dirty <= '1';
                if (hit0 = '1') then
                    MC_WE0 <= '1';
else
                    MC_WE1 <= '1';
end if;

            elsif (WE = '1' and hit = '0') then
                -- Fallo de escritura: write-around (NO trae bloque a MC)
                Bus_req      <= '1';
MC_bus_Write <= '1';
                if (Bus_grant = '1') then
                    inc_m      <= '1';
-- pulso unico cuando arranca el miss
                    next_state <= single_word_transfer_addr;
else
                    next_state <= Inicio;
end if;

            elsif (RE = '1' and hit = '0' and dirty_bit_rpl = '0') then
                -- Fallo de lectura con bloque víctima limpio: solo fetch
                Bus_req     <= '1';
MC_bus_Read <= '1';
                if (Bus_grant = '1') then
                    inc_m      <= '1';
-- pulso unico cuando arranca el miss
                    next_state <= block_transfer_addr;
else
                    next_state <= Inicio;
end if;

            elsif (RE = '1' and hit = '0' and dirty_bit_rpl = '1') then
                -- Fallo de lectura con bloque víctima sucio: copy-back + fetch
                Bus_req      <= '1';
MC_bus_Write <= '1';   -- la primera fase del bus es escritura (CB)
                if (Bus_grant = '1') then
                    inc_m      <= '1';
-- pulso unico cuando arranca el miss
                    inc_cb     <= '1';
-- copy-back contabilizado en arranque
                    next_state <= Send_ADDR_CB;
else
                    next_state <= Inicio;
end if;

            end if;

        -- =====================================================================
        -- single_word_transfer_addr: fase de @ para Scratch o write-around
        -- =====================================================================
        when single_word_transfer_addr =>
            MC_send_addr_ctrl <= '1';
Frame             <= '1';
last_word         <= '1';
-- es la unica palabra
            block_addr        <= '0';
-- @ de palabra (preserva ADDR(3:2))
            MC_bus_Read       <= RE;
MC_bus_Write      <= WE;
            mux_origen        <= '0';
-- @ y dato vienen del MIPS

            if (Bus_DevSel = '1') then
                next_state <= single_word_transfer_data;
else
                -- Nadie reconocio la @: capturar @ ahora (mientras Internal_MC_Bus_ADDR
                -- aun apunta a la palabra causal) y escalar a fallo
                load_addr_error <= '1';
next_state      <= fallo;
            end if;
-- =====================================================================
        -- single_word_transfer_data: fase de datos para Scratch o write-around
        -- =====================================================================
        when single_word_transfer_data =>
            Frame        <= '1';
last_word    <= '1';
            MC_send_data <= WE;     -- enviamos dato si es escritura

            if (Bus_TRDY = '1') then
                if (RE = '1') then
                    mux_output <= "01";
-- conectar bus -> MIPS (lectura Scratch)
                end if;
ready <= '1';
                -- NOTA: inc_w NO se activa aqui.
Las escrituras que pasan por
                -- este estado son: (a) write-around (cacheable, miss): NO
                -- modifica MC, no cuenta como "write to MC";
(b) SW Scratch
                -- (no cacheable): excluido explicitamente por el enunciado.
-- inc_w solo se activa en write-hit dentro del estado Inicio.
                next_state <= Inicio;
else
                next_state <= single_word_transfer_data;
end if;

        -- =====================================================================
        -- block_transfer_addr: fase de @ del fetch (entrada desde Inicio o tras CB)
        -- =====================================================================
        when block_transfer_addr =>
            MC_send_addr_ctrl <= '1';
Frame             <= '1';
block_addr        <= '1';
-- @ de bloque (ADDR(31:4)&"0000")
            MC_bus_Read       <= '1';
mux_origen        <= '1';
-- la UC dirige el flujo de palabra_UC

            if (Bus_DevSel = '1') then
                next_state <= read_block;
else
                load_addr_error <= '1';
next_state      <= fallo;
            end if;
-- =====================================================================
        -- read_block: fase de datos del fetch, recibe 4 palabras
        -- =====================================================================
        when read_block =>
            block_addr <= '1';
mux_origen <= '1';
            Frame      <= '1';
-- mantenido durante todo el estado

            if (Bus_TRDY = '1') then
                count_enable <= '1';
-- Escribir palabra que llega en la via a reemplazar
                if (via_2_rpl = '0') then
                    MC_WE0 <= '1';
else
                    MC_WE1 <= '1';
end if;

                if (last_word_block = '1') then
                    -- Ultima palabra del bloque: cerrar transferencia y escribir tag
                    last_word  <= '1';
-- + Frame='1' + TRDY='1' = arbitro cambia prioridad
                    MC_tags_WE <= '1';
-- la nueva etiqueta queda escrita
                    next_state <= Inicio;
else
                    next_state <= read_block;
end if;
            else
                next_state <= read_block;
end if;

        -- =====================================================================
        -- Send_ADDR_CB: fase de @ del copy-back
        -- =====================================================================
        when Send_ADDR_CB =>
            MC_send_addr_ctrl <= '1';
Frame             <= '1';
block_addr        <= '1';
            MC_bus_Write      <= '1';
-- el CB es una escritura
            send_dirty        <= '1';
-- pone Copy_Back_addr en el bus
            mux_origen        <= '1';
if (Bus_DevSel = '1') then
                next_state <= write_dirty_block;
else
                load_addr_error <= '1';
-- captura Copy_Back_addr (send_dirty='1')
                next_state      <= fallo;
end if;

        -- =====================================================================
        -- write_dirty_block: envia 4 palabras del bloque sucio a MD
        -- =====================================================================
        when write_dirty_block =>
            Frame        <= '1';
-- NO se baja en el ultimo ciclo: retenemos el bus
            block_addr   <= '1';
send_dirty   <= '1';   -- mantiene Copy_Back_addr seleccionada
            mux_origen   <= '1';
MC_send_data <= '1';
            MC_bus_Write <= '1';

            if (Bus_TRDY = '1') then
                count_enable <= '1';
if (last_word_block = '1') then
                    -- Ultima palabra del CB: cerramos la escritura, NO bajamos Frame.
-- En el ciclo siguiente entramos en block_transfer_addr con
                    -- el bus aun retenido (arbitro inhibido por Frame='1').
last_word         <= '1';
                    Block_copied_back <= '1';
-- selecciona la via que limpia dirty
                    Update_dirty      <= '1';
-- habilita el reset del bit dirty
                    next_state        <= block_transfer_addr;
else
                    next_state <= write_dirty_block;
end if;
            else
                next_state <= write_dirty_block;
end if;

        -- =====================================================================
        -- fallo: gestion del error de bus (DevSel='0' detectado)
        -- =====================================================================
        when fallo =>
            -- Frame='0' por defecto: bus liberado.
-- La @ causal ya fue capturada en el estado *_addr previo.
            next_error_state <= memory_error;
ready            <= '1';
-- el MIPS avanza y vera Mem_ERROR='1'
            next_state       <= Inicio;
-- =====================================================================
        -- when others: estados inalcanzables (Send_Addr, CopyBack, bajar_Frame
        -- declarados en state_type pero no usados).
Recuperacion defensiva.
        -- =====================================================================
        when others =>
            next_state <= Inicio;
end CASE;

   end process;

   
end Behavioral;