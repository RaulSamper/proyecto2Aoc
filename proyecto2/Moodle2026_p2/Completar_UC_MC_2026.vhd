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
-- Additional Comments: la UC incluye un contador de 2 bits para llevar la cuenta de las transferencias de bloque y una m�quina de estados
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
			-- �rdenes del MIPS
			RE : in  STD_LOGIC; 
			WE : in  STD_LOGIC;
			-- Respuesta al MIPS
			ready : out  STD_LOGIC; -- indica si podemos procesar la orden actual del MIPS en este ciclo. En caso contrario habr� que detener el MIPs
			-- Se�ales de la MC
			hit0 : in  STD_LOGIC; --se activa si hay acierto en la via 0
			hit1 : in  STD_LOGIC; --se activa si hay acierto en la via 1
			via_2_rpl :  in  STD_LOGIC; --indica que via se va a reemplazar
			addr_non_cacheable: in STD_LOGIC; --indica que la direcci�n no debe almacenarse en MC. En este caso porque pertenece a la scratch
			internal_addr: in STD_LOGIC; -- indica que la direcci�n solicitada es de un registro de MC
			MC_WE0 : out  STD_LOGIC;
            MC_WE1 : out  STD_LOGIC;
           	-- Se�ales para indicar la operaci�n que se quiere hacer en el bus
       		MC_bus_Read : out  STD_LOGIC; -- para pedir el bus en acceso de lectura
			MC_bus_Write : out  STD_LOGIC; --  para pedir el bus en acceso de escritura
			MC_tags_WE : out  STD_LOGIC; -- para escribir la etiqueta en la memoria de etiquetas
            palabra : out  STD_LOGIC_VECTOR (1 downto 0);--indica la palabra actual dentro de una transferencia de bloque (1�, 2�...)
            mux_origen: out STD_LOGIC; -- Se utiliza para elegir si el origen de la direcci�n de la palabra y el dato es el Mips (cuando vale 0) o la UC y el bus (cuando vale 1)
			block_addr : out  STD_LOGIC; -- indica si la direcci�n a enviar es la de bloque (rm) o la de palabra (w)
			mux_output: out  std_logic_vector(1 downto 0); -- para elegir si le mandamos al procesador la salida de MC (valor 0),los datos que hay en el bus (valor 1), o un registro interno( valor 2)
			-- se�ales para los contadores de rendimiento de la MC
			inc_m : out STD_LOGIC; -- indica que ha habido un fallo en MC
			inc_w : out STD_LOGIC; -- indica que ha habido una escritura en MC
			inc_r : out STD_LOGIC; -- indica que ha habido una escritura en MC
			inc_cb :out STD_LOGIC; -- indica que ha habido un reemplazo sucio en MC
			-- Gesti�n de errores
			unaligned: in STD_LOGIC; --indica que la direcci�n solicitada por el MIPS no est� alineada
			Mem_ERROR: out std_logic; -- Se activa si en la ultima transferencia el esclavo no respondi� a su direcci�n
			load_addr_error: out std_logic; --para controlar el registro que guarda la direcci�n que caus� error
			-- Gesti�n de los bloques sucios
			send_dirty: out std_logic;-- Indica que hay que enviar la @ del bloque sucio
			Update_dirty	: out  STD_LOGIC; --indica que hay que actualizar los bits dirty tanto por que se ha realizado una escritura, como porque se ha enviado el bloque sucio a memoria
			dirty_bit_rpl : in  STD_LOGIC; --indica si el bloque a reemplazar es sucio
			Block_copied_back	: out  STD_LOGIC; -- indica que se ha enviado a memoria un bloque que estaba sucio. Se usa para elegir la m�scara que quita el bit de sucio
			-- Para gestionar las transferencias a trav�s del bus
			bus_TRDY : in  STD_LOGIC; --indica que la memoria puede realizar la operaci�n solicitada en este ciclo
			Bus_DevSel: in  STD_LOGIC; --indica que la memoria ha reconocido que la direcci�n est� dentro de su rango
			Bus_grant :  in  STD_LOGIC; --indica la concesi�n del uso del bus
			MC_send_addr_ctrl : out  STD_LOGIC; --ordena que se env�en la direcci�n y las se�ales de control al bus
            MC_send_data : out  STD_LOGIC; --ordena que se env�en los datos
            Frame : out  STD_LOGIC; --indica que la operaci�n no ha terminado
            last_word : out  STD_LOGIC; --indica que es el �ltimo dato de la transferencia
            Bus_req :  out  STD_LOGIC --indica la petici�n al �rbitro del uso del bus
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

-- Definición de los estados de nuestra Unidad de Control (FSM Principal)
type state_type is (
    Inicio,
    -- Ruta 1: Acceso a palabra única
    Dir_Palabra, Transfiere_Palabra,
    -- Ruta 2: Traer bloque a caché
    Dir_Bloque, Leer_Bloque, Escribir_Tag,
    -- Ruta 3: Salvar bloque sucio 
    CopyBack, Volcar_Bloque_CB,
    -- Estado de cierre
    Fin_Operacion
);


type error_type is (memory_error, No_error); 
signal state, next_state : state_type; 
signal error_state, next_error_state : error_type; 
signal last_word_block: STD_LOGIC; --se activa cuando se esta pidiendo la ultima palabra de un bloque
signal one_word: STD_LOGIC; --se activa cuando solo se quiere transferir una palabra
signal count_enable: STD_LOGIC; -- se activa si se ha recibido una palabra de un bloque para que se incremente el contador de palabras
signal hit: std_logic;
signal palabra_UC : STD_LOGIC_VECTOR (1 downto 0);
begin

hit <= hit0 or hit1;	
 
--el contador nos dice cuantas palabras hemos recibido. Se usa para saber cuando se termina la transferencia del bloque y para direccionar la palabra en la que se escribe el dato leido del bus en la MC
word_counter: counter 	generic map (size => 2)
						port map (clk, reset, count_enable, palabra_UC); --indica la palabra actual dentro de una transferencia de bloque (1�, 2�...)

last_word_block <= '1' when palabra_UC="11" else '0';--se activa cuando estamos pidiendo la �ltima palabra

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
-- Máquina de estados para el bit de error
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
   OUTPUT_DECODE: process (state, hit, last_word_block, bus_TRDY, RE, WE, Bus_DevSel, Bus_grant, via_2_rpl, hit0, hit1, dirty_bit_rpl, addr_non_cacheable, internal_addr, unaligned)
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
        -- Estado Inicio          
		    if (RE = '0' and WE = '0') then -- si no piden nada no hacemos nada
				next_state <= Inicio;
				ready <= '1';
			elsif ((RE = '1') or (WE = '1')) and  (unaligned ='1') then -- si el procesador quiere leer una dirección no alineada
				-- Se procesa el error y se ignora la solicitud
				next_state <= Inicio;
				ready <= '1';
				next_error_state <= memory_error; --Ultima dirección incorrecta (no alineada)
				load_addr_error <= '1';
		    elsif (RE= '1' and  internal_addr ='1') then -- si quieren leer un registro de la MC se lo mandamos
		    	next_state <= Inicio;
				ready <= '1';
				mux_output <= "10"; -- La salida es un registro interno de la MC
				next_error_state <= No_error; --Cuando se lee el registro interno el controlador quita la seal de error
			elsif (WE = '1'  and  internal_addr ='1') then -- si quieren escribir en el registro interno de la MC se genera un error porque es slo de lectura
		    	next_state <= Inicio;
				ready <= '1';
				next_error_state <= memory_error; --Ultima dirección incorrecta (intento de escritura en registro de lectura)
				load_addr_error <= '1';
			elsif (RE= '1' and  hit='1') then -- si piden y es acierto de lectura mandamos el dato
		        next_state <= Inicio;
				ready <= '1';
				inc_r <= '1'; -- se lee la MC
				mux_output <= "00"; --Es el valor por defecto. No hace falta ponerlo. La salida es un dato almacenado en la MC
			elsif ( WE= '1' and  hit='1') then -- si piden y es acierto de escritura 
		        next_state <= Inicio;
                ready <= '1';
                inc_w <= '1';          -- Contador de escrituras en caché
                Update_dirty <= '1';   -- Marcamos el bloque como modificado (sucio)
                -- Escribimos el dato solo en la vía que ha acertado
                if (hit0 = '1') then
                    MC_WE0 <= '1';
                elsif (hit1 = '1') then
                    MC_WE1 <= '1';
                end if;
			elsif (((RE= '1') or (WE= '1')) and (hit='0')) then  --fallo de lectura
				Bus_req <= '1'; -- Pedimos el bus
                if (Bus_grant = '1') then
                    -- El �rbitro nos ha dado permiso, bifurcamos seg�n el caso:
                    if (addr_non_cacheable = '1' or WE = '1') then
                        -- Ruta 1: Acceso a Scratch o Fallo de Escritura (Write-Around)
                        next_state <= Dir_Palabra; 
                    else
                        -- Rutas 2 y 3: Fallo de lectura (Hay que traer un bloque de MD)
                        if (dirty_bit_rpl = '1') then
                            next_state <= CopyBack; -- El bloque que vamos a pisar esta sucio
                        else
                            next_state <= Dir_Bloque;   -- El bloque que vamos a pisar esta limpio
                        end if;
                    end if;
                else
                    -- Si el bus lo tiene el IO_Master, seguimos esperando aqui
                    next_state <= Inicio;
                end if;
			end if;
    when Dir_Palabra =>             
        -- Estado Dir_Palabra: Enviamos la dirección y pasamos a la fase de datos
                Bus_req <= '1';             -- Mantenemos la petición del bus para no perder el turno
                Frame <= '1';               -- Iniciamos la transferencia activando la señal Frame
                MC_send_addr_ctrl <= '1';   -- Ordenamos que salgan la dirección y las señales de control al bus
                one_word <= '1';            -- Indicamos que la transferencia será de una sola palabra
                
                -- Solo contamos el fallo si NO es un acceso a la Scratch
                if (addr_non_cacheable = '0') then
                    inc_m <= '1';           
                end if;             
                
                -- Elegimos la operación del bus dependiendo de la orden original del MIPS
                if (WE = '1') then
                    MC_bus_Write <= '1';    -- Queremos escribir en memoria
                else
                    MC_bus_Read <= '1';     -- Queremos leer de memoria
                end if;

                -- Quitamos la comprobación del time-out de aquí para darle 1 ciclo de margen a la memoria
                -- Pasamos incondicionalmente al siguiente estado
                next_state <= Transfiere_Palabra;

        when Transfiere_Palabra =>          
        -- Estado Transfiere_Palabra: Sincronización para transferir 1 sola palabra
                Bus_req <= '1';             -- Mantenemos el control del bus
                Frame <= '1';               -- Mantenemos la transferencia activa
                last_word <= '1';           -- Como es una única palabra, activamos que es la última

                -- Mantenemos la orden de lectura o escritura en el bus
                if (WE = '1') then
                    MC_bus_Write <= '1';    -- Queremos escribir
                    MC_send_data <= '1';    -- Ordenamos a los cables que envíen el dato físico
                else
                    MC_bus_Read <= '1';     -- Queremos leer
                end if;

                -- Comprobamos si el esclavo reconoce la dirección (1 ciclo después)
                if (Bus_DevSel = '0') then
                    next_error_state <= memory_error; -- Activamos el estado de error
                    load_addr_error <= '1'; --Activamos el registro de dirección de error
                    ready <= '1'; -- Liberamos al MIPS para que procese el Data Abort
                    next_state <= Inicio; -- Se produce un error en la memoria
                
                -- Si la memoria sí reconoció la dirección, esperamos a que esté lista (TRDY)
                elsif (bus_TRDY = '0') then
                    -- El esclavo es lento y necesita más tiempo. Nos quedamos dando vueltas aquí.
                    next_state <= Transfiere_Palabra;
                else
                    -- El esclavo ha levantado TRDY ('1'). La transferencia se ha completado.
                    ready <= '1'; -- Avisamos al MIPS para que avance y no se quede congelado
                    if (RE = '1') then
                        mux_output <= "01"; -- Redirigimos el dato desde el bus directo al MIPS
                    end if;
                    next_state <= Inicio; -- Vamos al ciclo de cierre
                end if;
		
		when Dir_Bloque =>          
        -- Estado Dir_Bloque: Pedimos a Memoria Principal un bloque entero (4 palabras)
                Bus_req <= '1';             -- Mantenemos el control del bus
                Frame <= '1';               -- Iniciamos la transferencia PCI
                MC_send_addr_ctrl <= '1';   -- Enviamos la dirección al bus
                MC_bus_Read <= '1';         -- Como traemos un bloque nuevo, siempre es lectura
                block_addr <= '1';          -- Le decimos al multiplexor que envíe la dirección base del bloque
                inc_m <= '1';               -- Contamos 1 fallo de caché

                -- Quitamos la comprobación del time-out de aquí para darle 1 ciclo a la Memoria Principal
                -- Pasamos directamente a intentar recibir las 4 palabras
                next_state <= Leer_Bloque;

        when Leer_Bloque =>             
        -- Estado Leer_Bloque: Bucle para recibir las 4 palabras de la ráfaga
                Bus_req <= '1';             -- Mantenemos el control del bus
                Frame <= '1';               -- Mantenemos la transferencia activa
                MC_bus_Read <= '1';         -- Seguimos diciendo que queremos leer
                mux_origen <= '1';          -- Conectamos la caché al bus y al contador
                
                -- Avisamos al bus desde el primer momento si toca la última palabra
                if (last_word_block = '1') then
                    last_word <= '1'; 
                end if;
                
                -- Comprobamos el time-out del bus (1 ciclo después de mandar la dirección)
                if (Bus_DevSel = '0') then
                    -- Nadie responde. Abortamos la petición y volvemos a Inicio
                    next_error_state <= memory_error;
                    load_addr_error <= '1';
                    ready <= '1'; -- Liberamos al MIPS para que procese el Data Abort
                    next_state <= Inicio;
                
                -- Si la memoria sí ha respondido (DevSel=1), esperamos a que el dato esté listo (TRDY)
                elsif (bus_TRDY = '1') then
                    -- Acabamos de recibir una palabra válida
                    -- La guardamos en la vía correspondiente de la caché
                    if (via_2_rpl = '0') then
                        MC_WE0 <= '1';
                    else
                        MC_WE1 <= '1';
                    end if;
                    count_enable <= '1';    -- Le damos un pulso al contador interno para que sume +1
                    
                    -- Si es esta la última palabra del bloque (la número 4)    
                    if (last_word_block = '1') then
                        next_state <= Escribir_Tag; -- Salimos del bucle
                    else
                        -- Todavía quedan palabras por llegar
                        next_state <= Leer_Bloque;  
                    end if;
                else
                    next_state <= Leer_Bloque; -- Damos otra vuelta sin contar esperando al TRDY
                end if;

		when Escribir_Tag => 			
        -- Estado Escribir_Tag: Oficializamos la llegada del nuevo bloque
				MC_tags_WE <= '1';          -- Damos la orden de guardar la etiqueta en la memoria
				-- Como la transferencia del bus terminó en el ciclo anterior (con el last_word),
				-- ya no ponemos Bus_req ni Frame a '1'. Dejamos que caigan a '0' (sus valores por defecto)
				-- para liberar el bus para otros dispositivos.
				next_state <= Fin_Operacion;

		when Fin_Operacion =>
        -- Estado Fin_Operacion: Limpieza final y reactivación del sistema
				ready <= '1';               -- Devolvemos el ready al MIPS para que continúe
				
				-- Al no poner nada más, todas las señales de control del bus están a '0'
				next_state <= Inicio;       -- Volvemos al estado de reposo a esperar la siguiente orden
		
		when CopyBack =>            
        -- Estado CopyBack: Iniciamos el rescate del bloque sucio hacia la Memoria Principal
                Bus_req <= '1';             -- Mantenemos el control del bus
                Frame <= '1';               -- Iniciamos la transferencia PCI
                MC_send_addr_ctrl <= '1';   -- Enviamos la dirección al bus
                MC_bus_Write <= '1';        -- Vamos a volcar un bloque, el bus debe escribir
                block_addr <= '1';          -- Vamos a mover un bloque entero de 4 palabras
                inc_cb <= '1';              -- Contamos 1 reemplazo de bloque sucio
                send_dirty <= '1';          -- Obliga a la caché a enviar la dirección del bloque antiguo, no la del MIPS

                -- Quitamos la comprobación del time-out de aquí para darle 1 ciclo a la Memoria Principal
                -- Pasamos incondicionalmente a volcar el bloque
                next_state <= Volcar_Bloque_CB;

        when Volcar_Bloque_CB =>            
        -- Estado Volcar_Bloque_CB: Bucle para enviar las 4 palabras sucias a Memoria Principal
                Bus_req <= '1';             -- Mantenemos el control del bus
                Frame <= '1';               -- Mantenemos la transferencia activa
                MC_bus_Write <= '1';        -- Vamos a volcar un bloque, el bus debe escribir
                mux_origen <= '1';          -- Obliga a la caché a usar el contador (palabra 0, 1, 2, 3)
                MC_send_data <= '1';        -- Volcamos físicamente los datos al bus

                if (last_word_block = '1') then
                    last_word <= '1'; 
                end if;

                -- Comprobamos el time-out del bus (1 ciclo después de mandar la dirección)
                if (Bus_DevSel = '0') then
                    -- Nadie responde en la dirección antigua. Abortamos y volvemos a Inicio
                    next_error_state <= memory_error;
                    load_addr_error <= '1';
                    ready <= '1';
                    next_state <= Inicio;
                
                -- Sincronizamos con el esclavo (Memoria Principal) si ha respondido
                elsif (bus_TRDY = '1') then
                    -- El esclavo ha guardado la palabra actual
                    count_enable <= '1';    -- Damos un pulso para pasar a la siguiente palabra
                    
                    -- Comprobamos si acabamos de enviar la palabra 4
                    if (last_word_block = '1') then
                        Block_copied_back <= '1';   -- Ordenamos a la caché que limpie la marca de "sucio"
                        next_state <= Dir_Bloque; 
                    else
                        -- Aún quedan palabras sucias por volcar
                        next_state <= Volcar_Bloque_CB;
                    end if;
                else
                    -- El esclavo está ocupado, esperamos dando una vuelta
                    next_state <= Volcar_Bloque_CB;
                end if;

		when others =>

	end CASE;    
	
		
   end process;
 
   
end Behavioral;

