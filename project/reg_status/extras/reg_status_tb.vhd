LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all; -- só no testbench, para o modelo de referência
----------------------------------------------------------------
-- Testbench auto-verificável (NÃO faz parte do projeto sintetizável;
-- pode usar PROCESS, WAIT, REPORT etc.)
-- Ordem dos bits: "C H Z V N" (bit 4 ... bit 0)
----------------------------------------------------------------
ENTITY reg_status_tb IS
END ENTITY;

ARCHITECTURE sim OF reg_status_tb IS
	SIGNAL nrst : STD_LOGIC := '1';
	SIGNAL clk  : STD_LOGIC := '0';
	SIGNAL d, e, q : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
	SIGNAL fim  : BOOLEAN := FALSE;

	FUNCTION slv5(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN STD_LOGIC_VECTOR(TO_UNSIGNED(n, 5));
	END FUNCTION;

	FUNCTION bits(v : STD_LOGIC_VECTOR) RETURN STRING IS
		VARIABLE s : STRING(1 TO v'LENGTH);
		VARIABLE t : STRING(1 TO 3);
	BEGIN
		FOR i IN 0 TO v'LENGTH - 1 LOOP
			t := STD_LOGIC'IMAGE(v(v'HIGH - i));
			s(i + 1) := t(2);
		END LOOP;
		RETURN s;
	END FUNCTION;
BEGIN
	dut : ENTITY work.reg_status
		PORT MAP (nrst => nrst, clk_in => clk, status_reg_in => d,
		          status_reg_wr_ena => e, status_reg_out => q);

	-- Clock de 10 ns, até o fim do teste.
	PROCESS
	BEGIN
		WHILE NOT fim LOOP
			clk <= '0'; WAIT FOR 5 ns;
			clk <= '1'; WAIT FOR 5 ns;
		END LOOP;
		WAIT;
	END PROCESS;

	PROCESS
		VARIABLE total, erros : INTEGER := 0;
		VARIABLE modelo       : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
		VARIABLE seed         : INTEGER := 1;

		PROCEDURE confere (nome : IN STRING) IS
		BEGIN
			total := total + 1;
			IF q /= modelo THEN
				erros := erros + 1;
				IF erros <= 20 THEN
					REPORT "FALHA [" & nome & "] in=" & bits(d) & " ena=" & bits(e) &
					       " | out=" & bits(q) & " (esperado " & bits(modelo) & ")"
					       SEVERITY ERROR;
				END IF;
			END IF;
		END PROCEDURE;

		-- Um ciclo de clock; só os bits habilitados são atualizados no modelo.
		PROCEDURE ciclo (nome : IN STRING; dado, ena : IN STD_LOGIC_VECTOR(4 DOWNTO 0)) IS
		BEGIN
			d <= dado; e <= ena;
			WAIT UNTIL RISING_EDGE(clk);
			FOR i IN 0 TO 4 LOOP
				IF ena(i) = '1' THEN modelo(i) := dado(i); END IF;
			END LOOP;
			WAIT FOR 1 ns;
			confere(nome);
		END PROCEDURE;
	BEGIN
		-- Reset inicial
		nrst <= '0';
		WAIT FOR 12 ns;
		confere("reset inicial");
		nrst <= '1';
		WAIT FOR 1 ns;

		-- Escreve todos de uma vez
		ciclo("todos = 10101", "10101", "11111");
		ciclo("todos = 01010", "01010", "11111");
		ciclo("todos = 11111", "11111", "11111");

		-- Sem habilitação, nada muda
		ciclo("sem ena", "00000", "00000");

		-- Um bit por vez: zera cada registrador individualmente
		ciclo("so RN", "00000", "00001");
		ciclo("so RV", "00000", "00010");
		ciclo("so RZ", "00000", "00100");
		ciclo("so RH", "00000", "01000");
		ciclo("so RC", "00000", "10000");

		-- Um bit por vez: seta cada registrador individualmente
		ciclo("so RC = 1", "11111", "10000");
		ciclo("so RZ = 1", "11111", "00100");
		ciclo("so RN = 1", "11111", "00001");

		-- Dado diferente de cada habilitação: só entra o que está habilitado
		ciclo("ena 10101 din 01010", "01010", "10101");
		ciclo("ena 01010 din 10101", "10101", "01010");

		-- Reset assíncrono, no meio do ciclo
		WAIT UNTIL RISING_EDGE(clk);
		WAIT FOR 2 ns;
		nrst <= '0';
		modelo := (OTHERS => '0');
		WAIT FOR 1 ns;
		confere("reset assincrono");

		-- Reset tem preferência sobre a escrita
		d <= "11111"; e <= "11111";
		WAIT UNTIL RISING_EDGE(clk);
		WAIT FOR 1 ns;
		confere("reset vence escrita");
		nrst <= '1';
		WAIT FOR 1 ns;

		-- Aleatório: 500 ciclos
		FOR i IN 1 TO 500 LOOP
			seed := (seed * 75 + 74) MOD 65537;
			ciclo("aleatorio " & INTEGER'IMAGE(i), slv5(seed MOD 32), slv5((seed / 32) MOD 32));
		END LOOP;

		REPORT "Fim: " & INTEGER'IMAGE(total) & " testes, " &
		       INTEGER'IMAGE(erros) & " erros.";
		ASSERT erros = 0 REPORT "Houve falhas" SEVERITY FAILURE;
		fim <= TRUE;
		WAIT; -- encerra o processo (a simulação termina)
	END PROCESS;
END ARCHITECTURE;
