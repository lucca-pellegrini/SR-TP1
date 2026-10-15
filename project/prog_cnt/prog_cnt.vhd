LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY prog_cnt IS
	PORT (
		nrst        : IN  STD_LOGIC;
		clk_in      : IN  STD_LOGIC;
		pc_ctrl     : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		new_pc_in   : IN  STD_LOGIC_VECTOR(10 DOWNTO 0);
		from_stack  : IN  STD_LOGIC_VECTOR(10 DOWNTO 0);
		next_pc_out : OUT STD_LOGIC_VECTOR(10 DOWNTO 0);
		pc_out      : OUT STD_LOGIC_VECTOR(10 DOWNTO 0)
	);
END ENTITY;

ARCHITECTURE arch OF prog_cnt IS
	SIGNAL pc      : STD_LOGIC_VECTOR(10 DOWNTO 0); -- saída dos flip-flops
	SIGNAL next_pc : STD_LOGIC_VECTOR(10 DOWNTO 0); -- entrada dos flip-flops
BEGIN
	-- Parte combinacional: escolhe o próximo valor do contador. Com 11
	-- bits, pc + 1 volta a 0 depois de 2047 (módulo 2048).
	WITH pc_ctrl SELECT
		next_pc <= pc         WHEN "00",  -- mantém
		           from_stack WHEN "01",  -- carrega o topo da pilha
		           new_pc_in  WHEN "10",  -- carrega um novo valor
		           pc + 1     WHEN "11",  -- incrementa
		           pc         WHEN OTHERS;

	next_pc_out <= next_pc;
	pc_out      <= pc;

	-- Parte sequencial: os flip-flops, com reset assíncrono.
	PROCESS(nrst, clk_in)
	BEGIN
		IF nrst = '0' THEN
			pc <= (OTHERS => '0');
		ELSIF RISING_EDGE(clk_in) THEN
			pc <= next_pc;
		END IF;
	END PROCESS;
END ARCHITECTURE;
