LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY reg_bank_de2 IS
	PORT (
		nrst   : IN  STD_LOGIC;
		clk_in : IN  STD_LOGIC;
		di     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		a_sel  : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		b_sel  : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		wr_ena : IN  STD_LOGIC;
		a_do   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		b_do   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		-- Conteúdo de todos os registradores (R3 & R2 & R1 & R0), só para
		-- visualização (usado pelo de2_reg_bank); não faz parte da interface
		-- original do banco.
		r_all  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END ENTITY;

ARCHITECTURE arch OF reg_bank_de2 IS
	-- Os quatro registradores de 8 bits: r(0) = R0, ..., r(3) = R3
	TYPE banco IS ARRAY (0 TO 3) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL r : banco;

	-- Seletores convertidos em índices do banco
	SIGNAL a_idx, b_idx : INTEGER RANGE 0 TO 3;
BEGIN
	a_idx <= TO_INTEGER(UNSIGNED(a_sel));
	b_idx <= TO_INTEGER(UNSIGNED(b_sel));

	-- Leitura: combinacional, sem clock e sem habilitação ----------------
	a_do <= r(a_idx);
	b_do <= r(b_idx);
	r_all <= r(3) & r(2) & r(1) & r(0);

	-- Escrita: síncrona, só com wr_ena = '1', no registrador apontado por
	-- a_sel. O reset assíncrono vem primeiro na cadeia, logo tem prioridade.
	PROCESS(nrst, clk_in)
	BEGIN
		IF nrst = '0' THEN
			r <= (OTHERS => (OTHERS => '0'));
		ELSIF RISING_EDGE(clk_in) THEN
			IF wr_ena = '1' THEN
				r(a_idx) <= di;
			END IF;
		END IF;
	END PROCESS;
END ARCHITECTURE;
