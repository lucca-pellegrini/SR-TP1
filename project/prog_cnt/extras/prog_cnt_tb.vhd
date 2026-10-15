LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all; -- só no testbench, para o modelo de referência
----------------------------------------------------------------
-- Testbench auto-verificável (NÃO faz parte do projeto sintetizável;
-- pode usar PROCESS, WAIT, REPORT etc.)
-- O modelo é um inteiro. Em cada ciclo confere-se next_pc_out ANTES da
-- borda (é combinacional) e pc_out/next_pc_out DEPOIS dela.
-- pc_ctrl: 00 mantém, 01 from_stack, 10 new_pc_in, 11 incrementa.
----------------------------------------------------------------
ENTITY prog_cnt_tb IS
END ENTITY;

ARCHITECTURE sim OF prog_cnt_tb IS
	SIGNAL nrst : STD_LOGIC := '1';
	SIGNAL clk  : STD_LOGIC := '0';
	SIGNAL ctrl : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
	SIGNAL novo, pilha, prox, pc : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
	SIGNAL fim  : BOOLEAN := FALSE;

	FUNCTION slv11(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN STD_LOGIC_VECTOR(TO_UNSIGNED(n, 11));
	END FUNCTION;

	FUNCTION img(v : STD_LOGIC_VECTOR) RETURN STRING IS
	BEGIN
		RETURN INTEGER'IMAGE(TO_INTEGER(UNSIGNED(v)));
	END FUNCTION;
BEGIN
	dut : ENTITY work.prog_cnt
		PORT MAP (nrst => nrst, clk_in => clk, pc_ctrl => ctrl,
		          new_pc_in => novo, from_stack => pilha,
		          next_pc_out => prox, pc_out => pc);

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
		VARIABLE modelo       : INTEGER := 0; -- valor dos flip-flops
		VARIABLE esperado_prox : INTEGER;
		VARIABLE seed         : INTEGER := 1;

		PROCEDURE confere (nome : IN STRING; vpc, vprox : IN INTEGER) IS
		BEGIN
			total := total + 1;
			IF pc /= slv11(vpc) OR prox /= slv11(vprox) THEN
				erros := erros + 1;
				IF erros <= 20 THEN
					REPORT "FALHA [" & nome & "] ctrl=" &
					       INTEGER'IMAGE(TO_INTEGER(UNSIGNED(ctrl))) &
					       " pc_out=" & img(pc) & " (esperado " & INTEGER'IMAGE(vpc) &
					       ") next_pc_out=" & img(prox) & " (esperado " & INTEGER'IMAGE(vprox) & ")"
					       SEVERITY ERROR;
				END IF;
			END IF;
		END PROCEDURE;

		-- Próximo valor esperado, a partir do modelo.
		IMPURE FUNCTION proximo (c, n, p : INTEGER) RETURN INTEGER IS
		BEGIN
			CASE c IS
				WHEN 0      => RETURN modelo;
				WHEN 1      => RETURN p;
				WHEN 2      => RETURN n;
				WHEN OTHERS => RETURN (modelo + 1) MOD 2048;
			END CASE;
		END FUNCTION;

		PROCEDURE ciclo (nome : IN STRING; c, n, p : IN INTEGER) IS
		BEGIN
			ctrl <= slv11(c)(1 DOWNTO 0); novo <= slv11(n); pilha <= slv11(p);
			esperado_prox := proximo(c, n, p);
			WAIT FOR 1 ns;
			confere(nome & " (antes da borda)", modelo, esperado_prox); -- combinacional
			WAIT UNTIL RISING_EDGE(clk);
			modelo := esperado_prox;
			WAIT FOR 1 ns;
			confere(nome, modelo, proximo(c, n, p));
		END PROCEDURE;
	BEGIN
		-- Reset inicial
		nrst <= '0';
		WAIT FOR 12 ns;
		confere("reset inicial", 0, 0);
		nrst <= '1';
		WAIT FOR 1 ns;

		-- Mantém, incrementa
		ciclo("mantem", 0, 5, 6);
		ciclo("inc 1", 3, 5, 6);
		ciclo("inc 2", 3, 5, 6);
		ciclo("inc 3", 3, 5, 6);
		ciclo("mantem", 0, 5, 6);

		-- Carrega novo valor (ignora from_stack) e valor da pilha (ignora new_pc_in)
		ciclo("carga new_pc_in", 2, 100, 999);
		ciclo("inc", 3, 100, 999);
		ciclo("carga from_stack", 1, 100, 999);
		ciclo("inc", 3, 100, 999);

		-- Volta a 0 depois de 2047 (módulo 2048)
		ciclo("carga 2046", 2, 2046, 0);
		ciclo("inc -> 2047", 3, 0, 0);
		ciclo("inc -> 0", 3, 0, 0);
		ciclo("inc -> 1", 3, 0, 0);

		-- Valores extremos nas cargas
		ciclo("carga 2047", 2, 2047, 0);
		ciclo("carga 0 da pilha", 1, 0, 0);
		ciclo("carga 1365", 1, 0, 1365);
		ciclo("carga 682", 2, 682, 0);

		-- Reset assíncrono, no meio do ciclo, com pc /= 0
		ciclo("pc = 300", 2, 300, 0);
		WAIT FOR 2 ns;
		nrst <= '0';
		modelo := 0;
		WAIT FOR 1 ns;
		confere("reset assincrono", 0, 300); -- ctrl ainda = 10, new_pc_in = 300

		-- Reset tem preferência sobre o incremento e sobre a carga
		ctrl <= "11";
		WAIT UNTIL RISING_EDGE(clk);
		WAIT FOR 1 ns;
		confere("reset vence inc", 0, 1);
		ctrl <= "10"; novo <= slv11(1234);
		WAIT UNTIL RISING_EDGE(clk);
		WAIT FOR 1 ns;
		confere("reset vence carga", 0, 1234);
		nrst <= '1';
		WAIT FOR 1 ns;
		ciclo("inc apos reset", 3, 0, 0);

		-- Aleatório: 1000 ciclos
		FOR i IN 1 TO 1000 LOOP
			seed := (seed * 75 + 74) MOD 65537;
			ciclo("aleatorio " & INTEGER'IMAGE(i),
			      seed MOD 4, (seed * 7) MOD 2048, (seed * 13) MOD 2048);
		END LOOP;

		REPORT "Fim: " & INTEGER'IMAGE(total) & " testes, " &
		       INTEGER'IMAGE(erros) & " erros.";
		ASSERT erros = 0 REPORT "Houve falhas" SEVERITY FAILURE;
		fim <= TRUE;
		WAIT; -- encerra o processo (a simulação termina)
	END PROCESS;
END ARCHITECTURE;
