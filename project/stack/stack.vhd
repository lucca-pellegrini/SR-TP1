LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY stack IS
	PORT (
		nrst       : IN  STD_LOGIC;
		clk_in     : IN  STD_LOGIC;
		stack_in   : IN  STD_LOGIC_VECTOR(10 DOWNTO 0);
		stack_push : IN  STD_LOGIC;
		stack_pop  : IN  STD_LOGIC;
		stack_out  : OUT STD_LOGIC_VECTOR(10 DOWNTO 0)
	);
END ENTITY;

ARCHITECTURE arch OF stack IS
	-- Os oito registradores de 11 bits: r(0) é o topo e r(7) é o fundo.
	TYPE pilha IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(10 DOWNTO 0);
	SIGNAL r : pilha;
BEGIN
	stack_out <= r(0);

	-- A pilha é um registrador de deslocamento. Push e pop são testados
	-- na ordem do IF, então o push tem preferência. Sem nenhum dos dois,
	-- nada é atribuído e os registradores mantêm seus valores.
	PROCESS(nrst, clk_in)
	BEGIN
		IF nrst = '0' THEN
			r <= (OTHERS => (OTHERS => '0'));
		ELSIF RISING_EDGE(clk_in) THEN
			IF stack_push = '1' THEN
				r(0)      <= stack_in;
				r(1 TO 7) <= r(0 TO 6);        -- o fundo (r(7)) se perde
			ELSIF stack_pop = '1' THEN
				r(0 TO 6) <= r(1 TO 7);        -- o topo (r(0)) é descartado
				r(7)      <= (OTHERS => '0');
			END IF;
		END IF;
	END PROCESS;
END ARCHITECTURE;
