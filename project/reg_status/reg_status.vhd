LIBRARY ieee;
USE ieee.std_logic_1164.all;

-- Ordem dos bits (a mesma de flags_out da ALU): 0 = RN, 1 = RV, 2 = RZ,
-- 3 = RH, 4 = RC.
ENTITY reg_status IS
	PORT (
		nrst              : IN  STD_LOGIC;
		clk_in            : IN  STD_LOGIC;
		status_reg_in     : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		status_reg_wr_ena : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		status_reg_out    : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
END ENTITY;

ARCHITECTURE arch OF reg_status IS
	SIGNAL regs : STD_LOGIC_VECTOR(4 DOWNTO 0); -- estado atual
	SIGNAL prox : STD_LOGIC_VECTOR(4 DOWNTO 0); -- próximo estado
BEGIN
	-- Cada bit é um multiplexador 2x1 controlado pela sua habilitação:
	-- habilitado, recebe a entrada; senão, mantém o valor atual.
	prox <= (status_reg_in AND status_reg_wr_ena) OR
	        (regs AND (NOT status_reg_wr_ena));

	status_reg_out <= regs;

	PROCESS(nrst, clk_in)
	BEGIN
		IF nrst = '0' THEN
			regs <= (OTHERS => '0');
		ELSIF RISING_EDGE(clk_in) THEN
			regs <= prox;
		END IF;
	END PROCESS;
END ARCHITECTURE;
