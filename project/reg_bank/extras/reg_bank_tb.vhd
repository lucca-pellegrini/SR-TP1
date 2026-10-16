LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all; -- só no testbench, para o modelo de referência
----------------------------------------------------------------
-- Testbench auto-verificável (NÃO faz parte do projeto sintetizável;
-- pode usar PROCESS, WAIT, REPORT etc.)
-- O modelo de referência é um array local, atualizado a cada borda de
-- subida; depois de cada ciclo, as 16 combinações (a_sel, b_sel) são
-- lidas e comparadas com o modelo.
----------------------------------------------------------------
ENTITY reg_bank_tb IS
END ENTITY;

ARCHITECTURE sim OF reg_bank_tb IS
	SIGNAL nrst, wr_ena : STD_LOGIC := '1';
	SIGNAL clk          : STD_LOGIC := '0';
	SIGNAL di, a_do, b_do : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL a_sel, b_sel : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
	SIGNAL fim          : BOOLEAN := FALSE;

	TYPE banco IS ARRAY (0 TO 3) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

	FUNCTION slv8(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN STD_LOGIC_VECTOR(TO_UNSIGNED(n, 8));
	END FUNCTION;

	FUNCTION slv2(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN STD_LOGIC_VECTOR(TO_UNSIGNED(n, 2));
	END FUNCTION;

	FUNCTION img(v : STD_LOGIC_VECTOR) RETURN STRING IS
	BEGIN
		RETURN INTEGER'IMAGE(TO_INTEGER(UNSIGNED(v)));
	END FUNCTION;
BEGIN
	dut : ENTITY work.reg_bank
		PORT MAP (nrst => nrst, clk_in => clk, di => di, a_sel => a_sel,
		          b_sel => b_sel, wr_ena => wr_ena, a_do => a_do, b_do => b_do,
		          r_all => OPEN);

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
		VARIABLE modelo       : banco := (OTHERS => (OTHERS => '0'));
		VARIABLE seed         : INTEGER := 1;

		-- Lê as 16 combinações de (a_sel, b_sel) e compara com o modelo.
		PROCEDURE confere (nome : IN STRING) IS
		BEGIN
			FOR sa IN 0 TO 3 LOOP
				FOR sb IN 0 TO 3 LOOP
					a_sel <= slv2(sa); b_sel <= slv2(sb);
					WAIT FOR 1 ns;
					total := total + 1;
					IF a_do /= modelo(sa) OR b_do /= modelo(sb) THEN
						erros := erros + 1;
						IF erros <= 20 THEN
							REPORT "FALHA [" & nome & "] a_sel=" & INTEGER'IMAGE(sa) &
							       " a_do=" & img(a_do) & " (esperado " & img(modelo(sa)) &
							       ") b_sel=" & INTEGER'IMAGE(sb) &
							       " b_do=" & img(b_do) & " (esperado " & img(modelo(sb)) & ")"
							       SEVERITY ERROR;
						END IF;
					END IF;
				END LOOP;
			END LOOP;
		END PROCEDURE;

		-- Um ciclo de clock com os valores dados e atualização do modelo.
		PROCEDURE ciclo (sel : IN INTEGER; dado : IN INTEGER; ena : IN BOOLEAN) IS
		BEGIN
			a_sel <= slv2(sel); di <= slv8(dado);
			IF ena THEN wr_ena <= '1'; ELSE wr_ena <= '0'; END IF;
			WAIT UNTIL RISING_EDGE(clk);
			IF ena THEN modelo(sel) := slv8(dado); END IF;
			WAIT FOR 1 ns;
			wr_ena <= '0';
		END PROCEDURE;

		PROCEDURE zera_modelo IS
		BEGIN
			modelo := (OTHERS => (OTHERS => '0'));
		END PROCEDURE;
	BEGIN
		-- Reset inicial
		nrst <= '0';
		WAIT FOR 12 ns;
		confere("reset inicial");
		nrst <= '1';
		WAIT FOR 1 ns;

		-- Escreve cada registrador com um valor diferente
		ciclo(0, 16#11#, TRUE); confere("escreve R0");
		ciclo(1, 16#22#, TRUE); confere("escreve R1");
		ciclo(2, 16#33#, TRUE); confere("escreve R2");
		ciclo(3, 16#44#, TRUE); confere("escreve R3");

		-- Sem wr_ena nada é escrito, mesmo com clock e di mudando
		ciclo(1, 16#FF#, FALSE); confere("wr_ena = 0");
		ciclo(3, 16#AA#, FALSE); confere("wr_ena = 0 (R3)");

		-- Sobrescreve (0 e FF cobrem todos os bits nos dois sentidos)
		ciclo(2, 16#FF#, TRUE); confere("R2 = FF");
		ciclo(2, 16#00#, TRUE); confere("R2 = 00");
		ciclo(0, 16#A5#, TRUE); confere("R0 = A5");

		-- Reset assíncrono, no meio do ciclo (longe de qualquer borda)
		WAIT UNTIL RISING_EDGE(clk);
		WAIT FOR 2 ns;
		nrst <= '0';
		zera_modelo;
		WAIT FOR 1 ns;
		confere("reset assincrono");

		-- Reset tem preferência: com wr_ena = '1' e borda de subida, não escreve
		a_sel <= "01"; di <= slv8(16#77#); wr_ena <= '1';
		WAIT UNTIL RISING_EDGE(clk);
		WAIT FOR 1 ns;
		wr_ena <= '0';
		confere("reset vence escrita");
		nrst <= '1';
		WAIT FOR 1 ns;

		-- Volta a escrever depois do reset
		ciclo(1, 16#5A#, TRUE); confere("escreve apos reset");

		-- Aleatório: 400 ciclos, 3/4 deles com escrita
		FOR i IN 1 TO 400 LOOP
			seed := (seed * 75 + 74) MOD 65537;
			ciclo(seed MOD 4, (seed / 4) MOD 256, ((seed / 1024) MOD 4) /= 0);
			confere("aleatorio " & INTEGER'IMAGE(i));
		END LOOP;

		REPORT "Fim: " & INTEGER'IMAGE(total) & " testes, " &
		       INTEGER'IMAGE(erros) & " erros.";
		ASSERT erros = 0 REPORT "Houve falhas" SEVERITY FAILURE;
		fim <= TRUE;
		WAIT; -- encerra o processo (a simulação termina)
	END PROCESS;
END ARCHITECTURE;
