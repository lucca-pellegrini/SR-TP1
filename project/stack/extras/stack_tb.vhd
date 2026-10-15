LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all; -- só no testbench, para o modelo de referência
----------------------------------------------------------------
-- Testbench auto-verificável (NÃO faz parte do projeto sintetizável;
-- pode usar PROCESS, WAIT, REPORT etc.)
-- O modelo é um array de 8 inteiros (m(0) = topo). Só o topo é visível
-- na saída; o resto é exposto pelos pops, e por isso há esvaziamentos
-- completos ao longo do teste.
----------------------------------------------------------------
ENTITY stack_tb IS
END ENTITY;

ARCHITECTURE sim OF stack_tb IS
	SIGNAL nrst : STD_LOGIC := '1';
	SIGNAL clk  : STD_LOGIC := '0';
	SIGNAL push, pop : STD_LOGIC := '0';
	SIGNAL din, dout : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
	SIGNAL fim  : BOOLEAN := FALSE;

	TYPE modelo_t IS ARRAY (0 TO 7) OF INTEGER;

	FUNCTION slv11(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN STD_LOGIC_VECTOR(TO_UNSIGNED(n, 11));
	END FUNCTION;
BEGIN
	dut : ENTITY work.stack
		PORT MAP (nrst => nrst, clk_in => clk, stack_in => din,
		          stack_push => push, stack_pop => pop, stack_out => dout);

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
		VARIABLE m            : modelo_t := (OTHERS => 0);
		VARIABLE seed         : INTEGER := 1;

		PROCEDURE confere (nome : IN STRING) IS
		BEGIN
			total := total + 1;
			IF dout /= slv11(m(0)) THEN
				erros := erros + 1;
				IF erros <= 20 THEN
					REPORT "FALHA [" & nome & "] topo=" &
					       INTEGER'IMAGE(TO_INTEGER(UNSIGNED(dout))) &
					       " (esperado " & INTEGER'IMAGE(m(0)) & ")"
					       SEVERITY ERROR;
				END IF;
			END IF;
		END PROCEDURE;

		-- Um ciclo de clock com push/pop; o modelo dá preferência ao push.
		PROCEDURE ciclo (nome : IN STRING; pu, po : IN BOOLEAN; dado : IN INTEGER) IS
		BEGIN
			IF pu THEN push <= '1'; ELSE push <= '0'; END IF;
			IF po THEN pop  <= '1'; ELSE pop  <= '0'; END IF;
			din <= slv11(dado);
			WAIT UNTIL RISING_EDGE(clk);
			IF pu THEN
				FOR i IN 7 DOWNTO 1 LOOP m(i) := m(i - 1); END LOOP;
				m(0) := dado;
			ELSIF po THEN
				FOR i IN 0 TO 6 LOOP m(i) := m(i + 1); END LOOP;
				m(7) := 0;
			END IF;
			WAIT FOR 1 ns;
			confere(nome);
		END PROCEDURE;

		PROCEDURE esvazia (nome : IN STRING) IS
		BEGIN
			FOR i IN 1 TO 8 LOOP
				ciclo(nome & " pop " & INTEGER'IMAGE(i), FALSE, TRUE, 0);
			END LOOP;
		END PROCEDURE;
	BEGIN
		-- Reset inicial
		nrst <= '0';
		WAIT FOR 12 ns;
		confere("reset inicial");
		nrst <= '1';
		WAIT FOR 1 ns;

		-- Enche a pilha (8 pushes) e depois esvazia (LIFO: 800 ... 100)
		FOR i IN 1 TO 8 LOOP
			ciclo("push " & INTEGER'IMAGE(i), TRUE, FALSE, 100 * i);
		END LOOP;
		esvazia("lifo");

		-- Pop com a pilha vazia continua dando zero
		ciclo("pop vazia", FALSE, TRUE, 0);

		-- Stack overflow: 10 pushes, os 2 mais antigos (1 e 2) se perdem
		FOR i IN 1 TO 10 LOOP
			ciclo("overflow push " & INTEGER'IMAGE(i), TRUE, FALSE, i);
		END LOOP;
		esvazia("overflow");

		-- Sem push nem pop, nada muda (mesmo com dado na entrada)
		ciclo("push 1234", TRUE, FALSE, 1234);
		ciclo("nada", FALSE, FALSE, 99);
		ciclo("nada 2", FALSE, FALSE, 2047);

		-- Push e pop juntos: o push tem preferência
		ciclo("push+pop", TRUE, TRUE, 555);
		ciclo("push+pop 2", TRUE, TRUE, 666);
		esvazia("push+pop");

		-- Valores extremos
		ciclo("push 0", TRUE, FALSE, 0);
		ciclo("push 2047", TRUE, FALSE, 2047);
		ciclo("push 1365", TRUE, FALSE, 1365); -- 10101010101
		ciclo("push 682", TRUE, FALSE, 682);   -- 01010101010
		esvazia("extremos");

		-- Reset assíncrono, no meio do ciclo, com a pilha cheia
		FOR i IN 1 TO 8 LOOP
			ciclo("enche " & INTEGER'IMAGE(i), TRUE, FALSE, 200 + i);
		END LOOP;
		WAIT FOR 2 ns;
		nrst <= '0';
		m := (OTHERS => 0);
		WAIT FOR 1 ns;
		confere("reset assincrono");

		-- Reset tem preferência sobre o push
		push <= '1'; din <= slv11(777);
		WAIT UNTIL RISING_EDGE(clk);
		WAIT FOR 1 ns;
		push <= '0';
		confere("reset vence push");
		nrst <= '1';
		WAIT FOR 1 ns;
		esvazia("apos reset");

		-- Aleatório: 1000 ciclos (3/8 push, 3/8 pop, 2/8 nada, às vezes ambos);
		-- esvazia no fim para expor o conteúdo inteiro
		FOR i IN 1 TO 1000 LOOP
			seed := (seed * 75 + 74) MOD 65537;
			ciclo("aleatorio " & INTEGER'IMAGE(i),
			      (seed MOD 8) < 3 OR (seed MOD 8) = 7,
			      (seed MOD 8) >= 3 AND (seed MOD 8) < 6 OR (seed MOD 8) = 7,
			      (seed / 8) MOD 2048);
			IF i MOD 100 = 0 THEN esvazia("aleatorio dreno " & INTEGER'IMAGE(i)); END IF;
		END LOOP;
		esvazia("aleatorio final");

		REPORT "Fim: " & INTEGER'IMAGE(total) & " testes, " &
		       INTEGER'IMAGE(erros) & " erros.";
		ASSERT erros = 0 REPORT "Houve falhas" SEVERITY FAILURE;
		fim <= TRUE;
		WAIT; -- encerra o processo (a simulação termina)
	END PROCESS;
END ARCHITECTURE;
